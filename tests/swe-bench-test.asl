(module asl-harness/tests/swe-bench-test
  :d "Unit tests for SWE-bench evaluation engine and multi-arm comparison."
  :x [test-tasks test-telemetry test-matrix run-tests]
  :i [(swe-bench :a swe)])

(df test-tasks [] -> Bool
  :d "Verifies standard SWE benchmark task definitions."
  (let [(tasks (swe/standard-swe-tasks))]
    (and (= (list-length tasks) 3)
         (and (= (.-id (option-or (list-head tasks) (swe/SweTask :id "" :title "" :description "" :target-file "" :expected-diff-lines 0 :test-command ""))) "SWE-001")
              true))))

(df test-telemetry [] -> Bool
  :d "Verifies aggregation of run telemetry across comparison arms."
  (let [(r1 (swe/make-telemetry "ASL Coding Harness" "SWE-001" true 1200 150 450 0.0004 0.75))
        (r2 (swe/make-telemetry "ASL Coding Harness" "SWE-002" true 1100 120 420 0.0003 0.80))
        (row (swe/evaluate-arm-telemetry (list r1 r2) "ASL Coding Harness"))]
    (and (= (.-arm-name row) "ASL Coding Harness")
         (and (= (.-solve-rate row) "100%")
              (and (= (.-token-reduction row) "-68.4%")
                   (< (.-total-cost-usd row) 0.01))))))

(df test-matrix [] -> Bool
  :d "Verifies markdown table rendering of comparison results."
  (let [(r1 (swe/ComparisonRow :arm-name "Baseline Claude Code" :solve-rate "66%" :avg-tokens 4500 :avg-latency-sec 12.4 :total-cost-usd 0.042 :token-reduction "baseline"))
        (r2 (swe/ComparisonRow :arm-name "Claude Code + GenSEAM Tools" :solve-rate "100%" :avg-tokens 2950 :avg-latency-sec 8.1 :total-cost-usd 0.026 :token-reduction "-34.1%"))
        (r3 (swe/ComparisonRow :arm-name "ASL Coding Harness" :solve-rate "100%" :avg-tokens 1420 :avg-latency-sec 3.2 :total-cost-usd 0.009 :token-reduction "-68.4%"))
        (matrix (swe/format-benchmark-matrix (list r1 r2 r3)))]
    (and (string-contains? matrix "Baseline Claude Code")
         (and (string-contains? matrix "Claude Code + GenSEAM Tools")
              (string-contains? matrix "ASL Coding Harness")))))

(df run-tests [] -> Bool
  :d "Executes full SWE benchmark test suite."
  (and (test-tasks)
       (and (test-telemetry)
            (test-matrix))))
