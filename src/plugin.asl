(module asl-harness/plugin
  :d "Flexible Pluggable Harness Extension System with Native Built-Ins in Pure ASL"
  :x [PluginCapability
      AgentPlugin
      PluginRegistry
      create-plugin
      registry-create
      registry-add
      registry-find
      registry-get-tools
      build-standard-harness-plugins
      evaluate-plugin-guards]
  :i [(config :a cfg)
      (core/strings :a s)])

(dfs PluginCapability
  (:f provided-tools (List Str) "List of tool identifiers registered by the plugin")
  (:f system-prompts (List Str) "List of prompt behavioral guidelines injected by the plugin")
  (:f hooks (List cfg/PluginHook) "Lifecycle execution hooks")
  (:f dependencies (List Str) "Required prerequisite plugin IDs")
  (:f conflicts (List Str) "Declared mutually incompatible plugin IDs")
  (:f predicates (List cfg/HookPredicate) "Conditional execution hook predicates"))

(dfs AgentPlugin
  (:f id Str "Unique plugin identifier e.g. builtin-code-intel")
  (:f name Str "Human-readable plugin name")
  (:f version Str "Semantic version string")
  (:f enabled Bool "Activation flag")
  (:f priority I64 "Evaluation priority (1 = highest)")
  (:f capability PluginCapability "Provided capabilities and contracts"))

(dfs PluginRegistry
  (:f plugins (List AgentPlugin) "Registered plugins list")
  (:f active-count I64 "Number of enabled plugins"))

(df create-plugin [(id Str) (name Str) (ver Str) (prio I64) (cap PluginCapability)] -> AgentPlugin
  :d "Constructs an enabled AgentPlugin record."
  (AgentPlugin
    :id id
    :name name
    :version ver
    :enabled true
    :priority prio
    :capability cap))

(df registry-create [] -> PluginRegistry
  :d "Initializes an empty PluginRegistry."
  (PluginRegistry
    :plugins (list)
    :active-count 0))

(df registry-add [(reg PluginRegistry) (plugin AgentPlugin)] -> PluginRegistry
  :d "Adds or replaces a plugin in the registry."
  (let [(filtered (filter (fn [(p AgentPlugin)] -> Bool (!= (.-id p) (.-id plugin))) (.-plugins reg)))
        (updated (append filtered plugin))
        (active (list-length (filter (fn [(p AgentPlugin)] -> Bool (.-enabled p)) updated)))]
    (PluginRegistry
      :plugins updated
      :active-count active)))

(df registry-find [(reg PluginRegistry) (plugin-id Str)] -> (Option AgentPlugin)
  :d "Finds a registered plugin by ID."
  (fold (fn [(acc (Option AgentPlugin)) (p AgentPlugin)] -> (Option AgentPlugin)
          (mt acc
            ((some _) acc)
            ((none) (if (= (.-id p) plugin-id) (some p) (none)))))
        (none)
        (.-plugins reg)))

(df registry-get-tools [(reg PluginRegistry)] -> (List Str)
  :d "Collects all tool names provided by active plugins."
  (fold (fn [(acc (List Str)) (p AgentPlugin)] -> (List Str)
          (if (.-enabled p)
              (let [(tools (.-provided-tools (.-capability p)))]
                (fold (fn [(iacc (List Str)) (t Str)] -> (List Str)
                        (if (contains-string? iacc t) iacc (append iacc t)))
                      acc
                      tools))
              acc))
        (list)
        (.-plugins reg)))

(df contains-string? [(items (List Str)) (needle Str)] -> Bool
  :d "Checks if string list contains needle."
  (fold (fn [(found Bool) (item Str)] -> Bool
          (or found (= item needle)))
        false
        items))

(df build-standard-harness-plugins [] -> PluginRegistry
  :d "Constructs the standard harness plugin registry with native built-ins."
  (let [(p-intel (create-plugin
                   "builtin-code-intel"
                   "Codebase Intelligence & Horizon Paging"
                   "1.0.0"
                   1
                   (PluginCapability
                     :provided-tools (list "intel-preload" "intel-impact" "intel-health")
                     :system-prompts (list "Always use intel-preload before modifying unknown files.")
                     :hooks (list (cfg/hook-pre-call))
                     :dependencies (list)
                     :conflicts (list)
                     :predicates (list))))
        (p-guard (create-plugin
                   "builtin-ast-guard"
                   "AST Mutation Gate & Trace Sanitizer"
                   "1.0.0"
                   1
                   (PluginCapability
                     :provided-tools (list "audit-ast-mutation" "sanitize-trace")
                     :system-prompts (list "Never delete protected assertions; verify AST deltas.")
                     :hooks (list (cfg/hook-post-call))
                     :dependencies (list)
                     :conflicts (list)
                     :predicates (list))))
        (p-css (create-plugin
                 "builtin-css-cascade"
                 "CSS Cascade & Variable Extractor"
                 "1.0.0"
                 2
                 (PluginCapability
                   :provided-tools (list "extract-css-variables" "resolve-computed-style")
                   :system-prompts (list "Compute CSS cascade specificity inline without bloated external tools.")
                   :hooks (list)
                   :dependencies (list)
                   :conflicts (list)
                   :predicates (list))))
        (p-comp (create-plugin
                  "builtin-component-mapper"
                  "Component Usage Mapper & Design Policy Guard"
                  "1.0.0"
                  2
                  (PluginCapability
                    :provided-tools (list "scan-component-usages" "batch-transform-classes" "audit-design-policy")
                    :system-prompts (list "Enforce design system component usage; ban raw input tags.")
                    :hooks (list (cfg/hook-pre-call))
                    :dependencies (list)
                    :conflicts (list)
                    :predicates (list))))
        (p-poly (create-plugin
                  "builtin-polyglot-sandbox"
                  "Polyglot AST & In-Memory Script Sandbox"
                  "1.0.0"
                  2
                  (PluginCapability
                    :provided-tools (list "extract-ast-outline" "run-sandboxed-script")
                    :system-prompts (list "Run untrusted polyglot code in isolated in-memory sandboxes.")
                    :hooks (list (cfg/hook-error))
                    :dependencies (list)
                    :conflicts (list)
                    :predicates (list))))
        (reg0 (registry-create))
        (reg1 (registry-add reg0 p-intel))
        (reg2 (registry-add reg1 p-guard))
        (reg3 (registry-add reg2 p-css))
        (reg4 (registry-add reg3 p-comp))
        (reg5 (registry-add reg4 p-poly))]
    reg5))

(df hook-tag [(h cfg/PluginHook)] -> Str
  :d "Internal tag string for PluginHook enum variant."
  (mt h
    ((cfg/hook-pre-call) "pre")
    ((cfg/hook-post-call) "post")
    ((cfg/hook-model-response) "resp")
    ((cfg/hook-error) "err")))

(df hook-eq? [(h1 cfg/PluginHook) (h2 cfg/PluginHook)] -> Bool
  :d "Compares two PluginHook enum variants."
  (= (hook-tag h1) (hook-tag h2)))

(df evaluate-plugin-guards [(plugin AgentPlugin) (hook cfg/PluginHook) (tool-name Str)] -> Bool
  :d "Evaluates plugin lifecycle hooks and hook predicates against target tool invocation."
  (if (not (.-enabled plugin))
      true
      (let [(cap (.-capability plugin))
            (preds (.-predicates cap))
            (hooks (.-hooks cap))
            (has-hook (fold (fn [(found Bool) (h cfg/PluginHook)] -> Bool
                              (or found (hook-eq? h hook)))
                            false
                            hooks))]
        (if (not has-hook)
            true
            (let [(denied (fold (fn [(is-denied Bool) (p cfg/HookPredicate)] -> Bool
                                  (if is-denied
                                      true
                                      (if (and (hook-eq? (.-hook-type p) hook)
                                               (cfg/evaluate-hook-predicate p tool-name "guard"))
                                          (= (.-action-override p) "deny")
                                          false)))
                                false
                                preds))]
              (not denied))))))
