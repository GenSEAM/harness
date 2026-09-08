(module asl-harness/step-middleware
  :d "Step Middleware Hook Adapter and Interceptor Dispatcher for Agent Harness."
  :x [StepHookAdapter
      wire-step-plugins
      dispatch-step-interceptors
      adapter-active-count
      adapter-has-hook?]
  :i [(onion :a on)
      (plugin_host :a host)])

(dfs StepHookAdapter
  (:f pipeline on/OnionPipeline "Underlying topologically sorted onion pipeline")
  (:f adapter-name Str "Identifier of the step hook adapter instance")
  (:f active-hooks (List Str) "List of active lifecycle event hooks registered"))

(df contains-hook? [(hooks (List Str)) (needle Str)] -> Bool
  :d "Checks if needle hook tag exists in hook list."
  (fold (fn [(found Bool) (h Str)] -> Bool
          (or found (= h needle)))
        false
        hooks))

(df collect-active-hooks [(pipeline on/OnionPipeline)] -> (List Str)
  :d "Collects distinct active lifecycle hook event tags from pipeline middlewares."
  (let [(mws (.-sorted pipeline))]
    (fold (fn [(acc (List Str)) (m on/Middleware)] -> (List Str)
            (let [(tag (on/middleware-kind-tag (.-kind m)))]
              (if (contains-hook? acc tag)
                  acc
                  (list-append acc (list tag)))))
          (list)
          mws)))

(df wire-step-plugins [(pipeline on/OnionPipeline)] -> StepHookAdapter
  :d "Wires configured onion pipeline into a unified step hook adapter."
  (let [(hooks (collect-active-hooks pipeline))]
    (StepHookAdapter
      :pipeline pipeline
      :adapter-name "asl-step-hook-adapter"
      :active-hooks hooks)))

(df dispatch-step-interceptors [(adapter StepHookAdapter) (ctx on/StepContext)] -> on/StepDecision
  :d "Dispatches step context through registered interceptors in the step hook adapter."
  (host/execute-step-pipeline (.-pipeline adapter) ctx))

(df adapter-active-count [(adapter StepHookAdapter)] -> I64
  :d "Returns count of active lifecycle hooks registered in adapter."
  (list-length (.-active-hooks adapter)))

(df adapter-has-hook? [(adapter StepHookAdapter) (hook-tag Str)] -> Bool
  :d "Checks if adapter has registered middlewares for specified hook tag."
  (contains-hook? (.-active-hooks adapter) hook-tag))
