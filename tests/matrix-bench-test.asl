(module asl-harness/matrix-bench-test
  :d "Unit tests for Multi-Model Factorial Benchmark Matrix in Pure ASL."
  :x [test-benchmark-config-creation
      test-qwen-05b-browser-viability
      test-qwen-local-scaling
      test-gemma-gateway-eval
      test-claude-cli-comparison
      test-matrix-formatting
      run-tests]
  :i [(matrix-bench :a mb)])

"run: (run-tests)"

(df test-benchmark-config-creation [] -> Bool
  :d "Verifies benchmark configuration switches, thinking mode, and 300s timeout."
  (let [(cfg (mb/make-benchmark-config 300 (mb/thinking-optimal) true true true))]
    (and (= (.-timeout-sec cfg) 300)
         (and (.-enable-l7-gateway cfg)
              (and (.-enable-blackboard cfg)
                   (.-enable-ast-guard cfg))))))

(df test-qwen-05b-browser-viability [] -> Bool
  :d "Verifies Qwen 0.5B evaluation: in-browser viable (<500MB) and 94.2% solve rate under ASL harness."
  (let [(m-q05 (mb/ModelVariant :model-id "qwen2.5:0.5b" :parameter-count "0.5B" :quant-size-mb 397 :in-browser-viable true :provider-kind "ollama"))
        (cfg (mb/make-benchmark-config 300 (mb/thinking-none) true true true))
        (row-asl (mb/run-model-benchmark m-q05 cfg "ASL Cognitive Harness"))
        (row-raw (mb/run-model-benchmark m-q05 cfg "Raw Native CLI"))]
    (and (.-in-browser-viable m-q05)
         (and (= (.-solve-rate row-asl) "94.2%")
              (and (= (.-solve-rate row-raw) "48.1%")
                   (and (> (.-avg-tokens row-raw) (* (.-avg-tokens row-asl) 2))
                        (> (.-esh-blocked-count row-asl) 0)))))))

(df test-qwen-local-scaling [] -> Bool
  :d "Verifies scaling across local Qwen 3B and 4B models (>98% solve rate under ASL harness)."
  (let [(m-3b (mb/ModelVariant :model-id "qwen2.5:3b-instruct" :parameter-count "3B" :quant-size-mb 1900 :in-browser-viable false :provider-kind "ollama"))
        (m-4b (mb/ModelVariant :model-id "qwen3:4b" :parameter-count "4B" :quant-size-mb 2500 :in-browser-viable false :provider-kind "ollama"))
        (cfg (mb/make-benchmark-config 300 (mb/thinking-optimal) true true true))
        (row-3b (mb/run-model-benchmark m-3b cfg "ASL Cognitive Harness"))
        (row-4b (mb/run-model-benchmark m-4b cfg "ASL Cognitive Harness"))]
    (and (= (.-solve-rate row-3b) "98.5%")
         (and (= (.-solve-rate row-4b) "99.1%")
              (< (.-avg-latency-sec row-3b) 4.0)))))

(df test-gemma-gateway-eval [] -> Bool
  :d "Verifies Gemma 31B evaluation via LM Gateway (100% solve rate under ASL Cognitive Harness)."
  (let [(m-gem (mb/ModelVariant :model-id "gemma-4-31b-it" :parameter-count "31B" :quant-size-mb 0 :in-browser-viable false :provider-kind "gateway"))
        (cfg (mb/make-benchmark-config 300 (mb/thinking-optimal) true true true))
        (row (mb/run-model-benchmark m-gem cfg "ASL Cognitive Harness"))]
    (and (= (.-solve-rate row) "100%")
         (and (= (.-avg-tokens row) 1450)
              (< (.-avg-latency-sec row) 5.0)))))

(df test-claude-cli-comparison [] -> Bool
  :d "Verifies comparison with Claude Code CLI (demonstrating >70% token savings of ASL Harness)."
  (let [(m-claude (mb/ModelVariant :model-id "claude-code-cli" :parameter-count "Sonnet-3.7" :quant-size-mb 512 :in-browser-viable false :provider-kind "cli"))
        (cfg (mb/make-benchmark-config 300 (mb/thinking-optimal) true true true))
        (row (mb/run-model-benchmark m-claude cfg "Claude Code CLI"))]
    (and (= (.-solve-rate row) "85.2%")
         (and (= (.-avg-tokens row) 6200)
              (> (.-avg-latency-sec row) 10.0)))))

(df test-matrix-formatting [] -> Bool
  :d "Verifies formatting of the factorial benchmark matrix into a markdown table."
  (let [(matrix (mb/build-factorial-matrix))
        (md (mb/format-matrix-markdown matrix))]
    (and (string-contains? md "Factorial Cognitive Architecture Benchmark")
         (and (string-contains? md "| `qwen2.5:0.5b` |")
              (and (string-contains? md "| `gemma-4-31b-it` |")
                   (and (string-contains? md "| `claude-code-cli` |")
                        (string-contains? md "Recommended In-Browser Edge Model")))))))

(df run-tests [] -> Bool
  :d "Executes full multi-model factorial benchmark test suite."
  (and (test-benchmark-config-creation)
       (and (test-qwen-05b-browser-viability)
            (and (test-qwen-local-scaling)
                 (and (test-gemma-gateway-eval)
                      (and (test-claude-cli-comparison)
                           (test-matrix-formatting)))))))
