(module asl-harness/m1-bench-test
  :d "Unit verification test suite for Mac M1 Inference & Real SLM Benchmarks"
  :x [test-create-model-arm-budget-label
      test-strict-offline-websearch-disabled
      test-m1-telemetry-computation
      test-evaluate-model-arms
      test-format-m1-report
      run-m1-bench-tests]
  :i [(m1-bench :a mb)])

(df test-create-model-arm-budget-label [] -> Bool
  :d "Tests model arm initialization and explicit budget labels"
  (let [(arm0 (mb/create-model-arm "Qwen2.5-Coder-0.5B" 0))
        (arm1000 (mb/create-model-arm "Qwen2.5-Coder-7B" 1000))]
    (and (= (.-budget-label arm0) "Non-Thinking (0 tokens)")
         (= (.-budget-label arm1000) "Thinking (1000 tokens)")
         (not (.-websearch-enabled arm0))
         (not (.-websearch-enabled arm1000)))))

(df test-strict-offline-websearch-disabled [] -> Bool
  :d "Tests anti-cheating offline verification gate"
  (let [(valid-arm (mb/create-model-arm "Gemma-31B" 0))
        (bad-arm (mb/ModelArm :model-name "Cheat" :thinking-tokens 0 :budget-label "" :websearch-enabled true))
        (bad-res (mb/evaluate-model-arm bad-arm "SWE-001"))]
    (and (mb/verify-offline-isolation valid-arm)
         (not (mb/verify-offline-isolation bad-arm))
         (not (.-passed bad-res)))))

(df test-m1-telemetry-computation [] -> Bool
  :d "Tests tokens per second throughput calculation"
  (let [(tel (mb/record-m1-telemetry 100 200 2000 4096 true))]
    (and (.-offline-verified tel)
         (= (as-i64 (.-tokens-per-sec tel)) 100)
         (= (.-memory-peak-mb tel) 4096))))

(df test-evaluate-model-arms [] -> Bool
  :d "Tests evaluating multiple small model arms on M1"
  (let [(arm1 (mb/create-model-arm "Qwen2.5-Coder-0.5B" 0))
        (arm2 (mb/create-model-arm "Qwen2.5-Coder-1.5B" 0))
        (arm3 (mb/create-model-arm "Qwen2.5-Coder-3B" 0))
        (arm4 (mb/create-model-arm "Qwen2.5-Coder-7B" 1000))
        (arm5 (mb/create-model-arm "Gemma-31B" 1000))
        (res1 (mb/evaluate-model-arm arm1 "task-1"))
        (res4 (mb/evaluate-model-arm arm4 "task-4"))]
    (and (.-passed res1)
         (.-passed res4)
         (> (.-test-pass-rate res4) (.-test-pass-rate res1)))))

(df test-format-m1-report [] -> Bool
  :d "Tests markdown formatting of M1 benchmark matrix report"
  (let [(arm1 (mb/create-model-arm "Qwen2.5-Coder-0.5B" 0))
        (arm2 (mb/create-model-arm "Qwen2.5-Coder-7B" 1000))
        (res1 (mb/evaluate-model-arm arm1 "t1"))
        (res2 (mb/evaluate-model-arm arm2 "t2"))
        (report (mb/generate-m1-matrix-report (list res1 res2)))
        (formatted (mb/format-m1-report report))]
    (and (= (.-total-arms report) 2)
         (string-contains? formatted "Mac M1 LLM Benchmark Matrix")
         (string-contains? formatted "WebSearch: DISABLED")
         (string-contains? formatted "Non-Thinking (0 tokens)")
         (string-contains? formatted "Thinking (1000 tokens)"))))

(df run-m1-bench-tests [] -> Bool
  :d "Runs complete test suite for Mac M1 LLM benchmarks"
  (and (test-create-model-arm-budget-label)
       (test-strict-offline-websearch-disabled)
       (test-m1-telemetry-computation)
       (test-evaluate-model-arms)
       (test-format-m1-report)))
