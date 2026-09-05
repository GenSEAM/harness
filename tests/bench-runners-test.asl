(module asl-harness-tests/bench-runners-test
  :d "Unit tests for pure ASL benchmark runner environment and security verifier"
  :x [test-create-runner-config
      test-validate-runner-security-clean
      test-validate-runner-security-leak
      test-format-runner-banner
      run-tests]
  :i [(asl-harness/bench-runners :a br)
      (core/strings :a s)])

(df test-create-runner-config [] -> Bool
  (let [(prof (br/BenchmarkProfile
                :model-name "gemma-4-31b-it"
                :endpoint "https://api.llmgateway.io/v1"
                :isolated true
                :mode "genseam-asl"))
        (cfg (br/create-runner-config prof "/tmp/isolated-test" (list "fs" "exec" "ast")))]
    (and (== (.-config-dir cfg) "/tmp/isolated-test")
         (== (list-length (.-direct-tools cfg)) 3)
         (not (.-has-secret-leaks cfg)))))

(df test-validate-runner-security-clean [] -> Bool
  (let [(clean-str "export LLM_GATEWAY_API_KEY=\"$ENV_VAR_SECRET\"")]
    (br/validate-runner-security clean-str)))

(df test-validate-runner-security-leak [] -> Bool
  (let [(leaked-str "export LLM_GATEWAY_API_KEY=\"llmgtwy_vLHJNl0D6XpsifrNXg2zKVtXDEX26m93H5E4g8RX\"")]
    (not (br/validate-runner-security leaked-str))))

(df test-format-runner-banner [] -> Bool
  (let [(prof (br/BenchmarkProfile
                :model-name "qwen-2.5-1.5b"
                :endpoint "http://localhost:11434"
                :isolated true
                :mode "factor-matrix"))
        (cfg (br/create-runner-config prof "/tmp/test" (list "intel")))
        (banner (br/format-runner-banner cfg))]
    (and (string-contains? banner "Launching ASL Benchmark Runner: qwen-2.5-1.5b")
         (string-contains? banner "Mode: factor-matrix")
         (string-contains? banner "STRICT SANDBOX"))))

(df run-tests [] -> Bool
  (and (test-create-runner-config)
       (test-validate-runner-security-clean)
       (test-validate-runner-security-leak)
       (test-format-runner-banner)))
