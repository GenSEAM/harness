(module asl-harness/m1-bench-test
  :d "Unit verification test suite for Mac M1 Inference & Real SLM Benchmarks"
  :x [test-create-model-arm-budget-label
      test-strict-offline-websearch-disabled
      test-m1-telemetry-computation
      test-evaluate-model-arms
      test-format-m1-report
      run-m1-bench-tests
      run-tests]
  :i [(m1-bench :a mb)])

(df test-create-model-arm-budget-label [] -> Bool
  :d "Tests model arm initialization and explicit budget labels"
  (let [(arm0 (mb/create-model-arm "Qwen2.5-Coder-0.5B" 0))
        (arm1000 (mb/create-model-arm "Qwen2.5-Coder-7B" 1000))]
    (assert (= (.-budget-label arm0) "Non-Thinking (0 tokens)") "arm0 budget label")
    (assert (= (.-budget-label arm1000) "Thinking (1000 tokens)") "arm1000 budget label")
    (assert (not (.-websearch-enabled arm0)) "arm0 websearch disabled")
    (assert (not (.-websearch-enabled arm1000)) "arm1000 websearch disabled")
    true))

(df test-strict-offline-websearch-disabled [] -> Bool
  :d "Tests anti-cheating offline verification gate"
  (let [(valid-arm (mb/create-model-arm "Gemma-31B" 0))
        (bad-arm (mb/ModelArm :model-name "Cheat" :thinking-tokens 0 :budget-label "" :websearch-enabled true))
        (bad-res (mb/evaluate-model-arm bad-arm "SWE-001"))]
    (assert (mb/verify-offline-isolation valid-arm) "valid arm is isolated")
    (assert (not (mb/verify-offline-isolation bad-arm)) "bad arm is not isolated")
    (assert (not (.-passed bad-res)) "bad arm evaluation failed")
    true))

(df test-m1-telemetry-computation [] -> Bool
  :d "Tests tokens per second throughput calculation"
  (let [(tel (mb/record-m1-telemetry 100 200 2000 4096 true))]
    (assert (.-offline-verified tel) "telemetry offline verified")
    (assert (= (as-i64 (.-tokens-per-sec tel)) 100) "100 tokens per sec")
    (assert (= (.-memory-peak-mb tel) 4096) "memory peak is 4096")
    true))

(df test-evaluate-model-arms [] -> Bool
  :d "Tests evaluating multiple small model arms on M1"
  (let [(arm1 (mb/create-model-arm "Qwen2.5-Coder-0.5B" 0))
        (arm2 (mb/create-model-arm "Qwen2.5-Coder-1.5B" 0))
        (arm3 (mb/create-model-arm "Qwen2.5-Coder-3B" 0))
        (arm4 (mb/create-model-arm "Qwen2.5-Coder-7B" 1000))
        (arm5 (mb/create-model-arm "Gemma-31B" 1000))
        (res1 (mb/evaluate-model-arm arm1 "task-1"))
        (res4 (mb/evaluate-model-arm arm4 "task-4"))]
    (assert (.-passed res1) "res1 passed")
    (assert (.-passed res4) "res4 passed")
    (assert (> (.-test-pass-rate res4) (.-test-pass-rate res1)) "res4 pass rate > res1")
    true))

(df test-format-m1-report [] -> Bool
  :d "Tests markdown formatting of M1 benchmark matrix report"
  (let [(arm1 (mb/create-model-arm "Qwen2.5-Coder-0.5B" 0))
        (arm2 (mb/create-model-arm "Qwen2.5-Coder-7B" 1000))
        (res1 (mb/evaluate-model-arm arm1 "t1"))
        (res2 (mb/evaluate-model-arm arm2 "t2"))
        (report (mb/generate-m1-matrix-report (list res1 res2)))
        (formatted (mb/format-m1-report report))]
    (assert (= (.-total-arms report) 2) "report total arms is 2")
    (assert (string-contains? formatted "Mac M1 LLM Benchmark Matrix") "report header present")
    (assert (string-contains? formatted "WebSearch: DISABLED") "websearch disabled text")
    (assert (string-contains? formatted "Non-Thinking (0 tokens)") "non-thinking text")
    (assert (string-contains? formatted "Thinking (1000 tokens)") "thinking text")
    true))

(df run-m1-bench-tests [] -> Bool
  :d "Runs complete test suite for Mac M1 LLM benchmarks"
  (do
    (test-create-model-arm-budget-label)
    (test-strict-offline-websearch-disabled)
    (test-m1-telemetry-computation)
    (test-evaluate-model-arms)
    (test-format-m1-report)
    true))

(df run-tests [] -> Bool
  :d "Alias for run-m1-bench-tests"
  (run-m1-bench-tests))
