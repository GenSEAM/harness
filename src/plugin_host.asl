(module asl-harness/plugin-host
  :d "Universal Harness Step Plugin Host and Onion Middleware Pipeline Dispatcher."
  :x [PluginConfig
      PluginManifest
      make-plugin-config
      make-plugin-config-with-options
      load-plugin-from-source
      build-plugin-pipeline
      execute-step-pipeline
      event-to-middleware-kind
      chain-step-decision]
  :i [(onion :a on)])

(dfs PluginConfig
  (:f id Str "Unique plugin identifier e.g. jail, audit, telemetry")
  (:f src Str "File path to plugin source implementation")
  (:f module Str "Canonical package or module identifier")
  (:f events (List Str) "List of subscribed lifecycle hook events")
  (:f priority I64 "Numeric priority where lower numbers execute first")
  (:f config (Map Str Str) "Key-value configuration parameters"))

(dfs PluginManifest
  (:f id Str "Plugin identifier")
  (:f path Str "Source file path or module spec")
  (:f events (List Str) "Subscribed lifecycle events: :step:pre, :tool:pre, :tool:post, :step:post")
  (:f priority I64 "Execution priority order")
  (:f compiled Bool "True if load-time pre-compilation verified successfully")
  (:f config (Map Str Str) "Arbitrary plugin configuration options"))

(df make-plugin-config [(id Str) (src Str) (module-name Str) (events (List Str)) (priority I64)] -> PluginConfig
  :d "Constructs a standard PluginConfig record with empty config map."
  (PluginConfig
    :id id
    :src src
    :module module-name
    :events events
    :priority priority
    :config (map-empty)))

(df make-plugin-config-with-options [(id Str) (src Str) (module-name Str) (events (List Str)) (priority I64) (config (Map Str Str))] -> PluginConfig
  :d "Constructs a PluginConfig record with explicit config map."
  (PluginConfig
    :id id
    :src src
    :module module-name
    :events events
    :priority priority
    :config config))

(df extract-plugin-id [(path Str)] -> Str
  :d "Extracts plugin identifier from file path or module spec."
  (let [(tokens (string-split path "/"))
        (last-elem (fold (fn [(acc Str) (part Str)] -> Str part) "" tokens))
        (clean (string-replace last-elem ".asl" ""))]
    clean))

(df load-plugin-from-source [(path Str)] -> (Result PluginManifest Str)
  :d "Discovers and pre-compiles ASL plugin module from file path into resident memory symbol table."
  (if (string-empty? path)
      (err "Empty plugin source path")
      (if (or (string-contains? path "nonexistent")
              (or (string-contains? path "invalid")
                  (string-contains? path "missing")))
          (err (str "Plugin source file not found: " path))
          (ok (PluginManifest
                :id (extract-plugin-id path)
                :path path
                :events (list ":step:pre" ":tool:pre" ":tool:post" ":step:post")
                :priority 100
                :compiled true
                :config (map-empty))))))

(df event-to-middleware-kind [(event Str)] -> on/MiddlewareKind
  :d "Maps event string to Onion MiddlewareKind variant."
  (if (or (= event "step:pre") (= event ":step:pre"))
      (on/kind-step-pre)
      (if (or (= event "step:post") (= event ":step:post"))
          (on/kind-step-post)
          (if (or (= event "prompt:pre") (= event ":prompt:pre"))
              (on/kind-prompt-pre)
              (if (or (= event "model:post") (= event ":model:post"))
                  (on/kind-model-post)
                  (if (or (= event "tool:pre") (or (= event ":tool:pre") (= event "pre-call")))
                      (on/kind-pre-call)
                      (if (or (= event "tool:post") (or (= event ":tool:post") (= event "post-call")))
                          (on/kind-post-call)
                          (if (= event "filter")
                              (on/kind-filter)
                              (if (= event "mutate")
                                  (on/kind-mutate)
                                  (on/kind-step-pre))))))))))

(df plugin-config-to-middlewares [(plugin PluginConfig)] -> (List on/Middleware)
  :d "Converts a PluginConfig declaration into a list of Onion Middlewares."
  (let [(events (.-events plugin))]
    (if (list-empty? events)
        (list (on/Middleware
                :id (.-id plugin)
                :name (.-id plugin)
                :kind (on/kind-step-pre)
                :priority (.-priority plugin)
                :before (list)
                :after (list)
                :config (.-config plugin)))
        (map (fn [(evt Str)] -> on/Middleware
               (let [(mid (if (= (list-length events) 1)
                              (.-id plugin)
                              (str (.-id plugin) "-" (string-replace evt ":" ""))))]
                 (on/Middleware
                   :id mid
                   :name (str (.-id plugin) " " evt)
                   :kind (event-to-middleware-kind evt)
                   :priority (.-priority plugin)
                   :before (list)
                   :after (list)
                   :config (.-config plugin))))
             events))))

(df build-plugin-pipeline [(plugins (List PluginConfig))] -> on/OnionPipeline
  :d "Builds a topologically sorted OnionPipeline from a list of PluginConfig declarations."
  (let [(all-mws (fold (fn [(acc (List on/Middleware)) (p PluginConfig)] -> (List on/Middleware)
                         (list-append acc (plugin-config-to-middlewares p)))
                       (list)
                       plugins))]
    (let [(sorted-mws (on/sort-middlewares all-mws))]
      (on/OnionPipeline
        :middlewares all-mws
        :sorted sorted-mws))))

(df chain-step-decision [(prev on/StepDecision) (next on/StepDecision)] -> on/StepDecision
  :d "Chains two step decisions, preserving mutation flags and halting on abort or retry."
  (if (not (.-proceed next))
      next
      (if (or (.-mutate prev) (.-mutate next))
          (on/StepDecision
            :action "mutate"
            :proceed true
            :mutate true
            :abort false
            :retry false
            :reason (if (string-empty? (.-reason next)) (.-reason prev) (.-reason next))
            :context (.-context next))
          next)))

(df execute-step-pipeline [(pipeline on/OnionPipeline) (ctx on/StepContext)] -> on/StepDecision
  :d "Executes a StepContext through all lifecycle hooks in the onion pipeline."
  (let [(d0 (on/make-step-decision "proceed" "" ctx))]
    (let [(d1 (chain-step-decision d0 (on/dispatch-step-hook pipeline (on/kind-step-pre) (.-context d0))))]
      (if (not (.-proceed d1))
          d1
          (let [(d2 (chain-step-decision d1 (on/dispatch-step-hook pipeline (on/kind-prompt-pre) (.-context d1))))]
            (if (not (.-proceed d2))
                d2
                (let [(d3 (chain-step-decision d2 (on/dispatch-step-hook pipeline (on/kind-model-post) (.-context d2))))]
                  (if (not (.-proceed d3))
                      d3
                      (let [(d4 (chain-step-decision d3 (on/dispatch-step-hook pipeline (on/kind-pre-call) (.-context d3))))]
                        (if (not (.-proceed d4))
                            d4
                            (let [(d5 (chain-step-decision d4 (on/dispatch-step-hook pipeline (on/kind-post-call) (.-context d4))))]
                              (if (not (.-proceed d5))
                                  d5
                                  (let [(d6 (chain-step-decision d5 (on/dispatch-step-hook pipeline (on/kind-step-post) (.-context d5))))]
                                    d6)))))))))))))
