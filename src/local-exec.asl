(module asl-harness/local-exec
  :d "Local & WebAssembly Tool Execution Router: executes deterministic tools without LLM round-trips."
  :x [ExecutionTier RouteDecision should-execute-locally route-and-execute format-savings-report]
  :i [(coding :a c)])

(dfe ExecutionTier
  (:c tier-local-wasm [] "Direct in-memory WebAssembly / runtime execution")
  (:c tier-local-host [] "Direct OS process execution in isolated sandbox")
  (:c tier-remote-llm [] "Delegation to remote model endpoint"))

(dfs RouteDecision
  (:f tool-name Str "Target tool name")
  (:f tier ExecutionTier "Selected routing tier")
  (:f estimated-savings-tokens I64 "Tokens saved by avoiding LLM hop")
  (:f estimated-latency-ms I64 "Target execution latency in ms"))

(df should-execute-locally [(tool-name Str)] -> Bool
  :d "Returns true if tool is safe, deterministic, and can execute without model intervention."
  (or (= tool-name "fs-read")
      (or (= tool-name "fs-list")
          (or (= tool-name "ast-search")
              (or (= tool-name "intel-query")
                  (or (= tool-name "git-status")
                      (or (= tool-name "ast-patch")
                          (or (= tool-name "str-replace")
                              (or (= tool-name "intel-preload")
                                  (or (= tool-name "intel-impact")
                                      (or (= tool-name "intel-health")
                                          (= tool-name "deps-resolve"))))))))))))

(df plan-route [(tool-name Str)] -> RouteDecision
  :d "Calculates optimal execution tier and estimated savings."
  (if (should-execute-locally tool-name)
      (RouteDecision
        :tool-name tool-name
        :tier (tier-local-wasm)
        :estimated-savings-tokens 650
        :estimated-latency-ms 2)
      (RouteDecision
        :tool-name tool-name
        :tier (tier-remote-llm)
        :estimated-savings-tokens 0
        :estimated-latency-ms 850)))

(df route-and-execute [(call c/ToolCall)] -> c/ToolResult
  :d "Routes tool call to local runner if deterministic, bypassing LLM round-trip."
  (let [(name (.-tool-name call))]
    (if (should-execute-locally name)
        (c/execute-builtin-tool call)
        (c/ToolResult :call-id (.-id call) :tool-name name :success false :output "" :error-msg "Tool requires remote LLM execution tier"))))

(df format-savings-report [(routed-calls I64)] -> Str
  :d "Reports token and latency savings achieved through local tool execution."
  (let [(tokens-saved (* routed-calls 650))]
    (str "⚡ Local Execution: " (string-from-int64 routed-calls)
         " tool call(s) executed locally. Saved ~"
         (string-from-int64 tokens-saved) " tokens; ~95% latency reduction.")))
