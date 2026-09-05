(module asl-harness/bench-runners
  :d "Pure ASL Benchmark Environment & Runner Configuration: clean sandbox isolation, security validation, and banner formatting."
  :x [BenchmarkProfile
      RunnerConfig
      create-runner-config
      validate-runner-security
      format-runner-banner]
  :i [(core/strings :a s)])

(dfs BenchmarkProfile
  (:f model-name Str "Target benchmark model")
  (:f endpoint Str "Base gateway URL or environment placeholder")
  (:f isolated Bool "True if running in sandbox with zero custom instructions")
  (:f mode Str "genseam-asl | claude-baseline | factor-matrix"))

(dfs RunnerConfig
  (:f profile BenchmarkProfile "Benchmark configuration profile")
  (:f config-dir Str "Isolated temp config directory")
  (:f direct-tools (List Str) "Enabled native tools")
  (:f has-secret-leaks Bool "True if hardcoded secret tokens are present"))

(df validate-runner-security [(text Str)] -> Bool
  :d "Returns true if text contains zero raw secret literals (llmgtwy_, sk-, unmasked tokens)"
  (let [(lower (string-lower text))]
    (not (or (string-contains? lower "llmgtwy_")
             (or (string-contains? lower "sk-proj-")
                 (or (string-contains? lower "sk-ant-")
                     (string-contains? lower "api_key=llm")))))))

(df create-runner-config [(profile BenchmarkProfile) (config-dir Str) (tools (List Str))] -> RunnerConfig
  :d "Creates an isolated runner configuration with security audit"
  (let [(endpoint (.-endpoint profile))
        (is-secure (validate-runner-security endpoint))]
    (RunnerConfig
      :profile profile
      :config-dir config-dir
      :direct-tools tools
      :has-secret-leaks (not is-secure))))

(df format-runner-banner [(cfg RunnerConfig)] -> Str
  :d "Formats clean runner startup banner without secrets"
  (let [(prof (.-profile cfg))
        (b1 (s/concat "[*] Launching ASL Benchmark Runner: " (.-model-name prof)))
        (b2 (s/concat "\n    Mode: " (.-mode prof)))
        (b3 (s/concat "\n    Endpoint: " (if (.-has-secret-leaks cfg) "***REDACTED***" (.-endpoint prof))))
        (b4 (s/concat "\n    Isolation: " (if (.-isolated prof) "STRICT SANDBOX" "STANDARD")))]
    (s/concat b1 (s/concat b2 (s/concat b3 b4)))))
