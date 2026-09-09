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
                :endpoint "http://127.0.0.1:8765/v1"
                :isolated true
                :mode "genseam-asl"))
        (cfg (br/create-runner-config prof "/tmp/isolated-test" (list "fs" "exec" "ast")))]
    (assert (= (.-config-dir cfg) "/tmp/isolated-test") "config-dir matches")
    (assert (= (list-length (.-direct-tools cfg)) 3) "three direct tools")
    (assert (not (.-has-secret-leaks cfg)) "no secret leaks in runner config")
    true))

(df test-validate-runner-security-clean [] -> Bool
  (let [(clean-str "export LLM_GATEWAY_API_KEY=\"$ENV_VAR_SECRET\"")]
    (assert (br/validate-runner-security clean-str) "clean string passes security validation")
    (assert (not (br/validate-runner-security "export LLM_GATEWAY_API_KEY=\"llmgtwy_vLHJNl0D6XpsifrNXg2zKVtXDEX26m93H5E4g8RX\"")) "leaked secret rejected")
    true))

(df test-validate-runner-security-leak [] -> Bool
  (let [(leaked-str "export LLM_GATEWAY_API_KEY=\"llmgtwy_vLHJNl0D6XpsifrNXg2zKVtXDEX26m93H5E4g8RX\"")]
    (assert (not (br/validate-runner-security leaked-str)) "leaked secret caught by security validation")
    (assert (br/validate-runner-security "export LLM_GATEWAY_API_KEY=\"$ENV_VAR_SECRET\"") "clean secret accepted")
    true))

(df test-format-runner-banner [] -> Bool
  (let [(prof (br/BenchmarkProfile
                :model-name "qwen-2.5-1.5b"
                :endpoint "http://localhost:11434"
                :isolated true
                :mode "factor-matrix"))
        (cfg (br/create-runner-config prof "/tmp/test" (list "intel")))
        (banner (br/format-runner-banner cfg))]
    (assert (string-contains? banner "Launching ASL Benchmark Runner: qwen-2.5-1.5b") "banner has model name")
    (assert (string-contains? banner "Mode: factor-matrix") "banner has mode")
    (assert (string-contains? banner "STRICT SANDBOX") "banner notes sandbox")
    true))

(df run-tests [] -> Bool
  (do
    (test-create-runner-config)
    (test-validate-runner-security-clean)
    (test-validate-runner-security-leak)
    (test-format-runner-banner)
    true))
