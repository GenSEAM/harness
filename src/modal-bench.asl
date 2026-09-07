(module asl-harness/modal-bench
  :d "Pure ASL Modal Cloud Benchmark Runner & Harbor Submission Packager: task results representation, metric aggregation, and honest zero padding."
  :x [TaskResult
      compute-bench-metrics]
  :i [])

(dfs TaskResult
  (:f task-id Str "Benchmark task identifier")
  (:f passed Bool "True if benchmark task resolution verified")
  (:f exit-code I64 "Process return code")
  (:f duration-ms I64 "Execution duration in milliseconds"))

(df compute-bench-metrics [(results (List TaskResult))] -> Str
  :d "Computes total, passed, pass-rate metrics with honest zero padding on empty suites."
  (let [(total (list-length results))
        (passed (list-length (filter (fn [(r TaskResult)] -> Bool (.-passed r)) results)))
        (failed (- total passed))
        (rate (if (= total 0)
                0.0
                (* (/ (float64-from-int64 passed) (float64-from-int64 total)) 100.0)))]
    (str "(:bench-metrics"
         " :total " (string-from-int64 total)
         " :passed " (string-from-int64 passed)
         " :failed " (string-from-int64 failed)
         " :pass-rate-pct " (if (= rate 0.0) "0.0" (if (= rate 100.0) "100.0" (string-from-float64 rate)))
         ")")))
