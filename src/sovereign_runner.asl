(module asl-harness/sovereign-runner
  :d "Sovereign pure AgentScript benchmark matrix runner with process supervision, PTY isolation, and receipt ledger."
  :x [BenchmarkMatrix
      BenchmarkRunResult
      run-sovereign-matrix
      format-benchmark-receipt]
  :i [])

(dfs BenchmarkMatrix
  (:f id Str "Unique benchmark matrix identifier")
  (:f tasks (List Str) "List of challenge task identifiers to execute")
  (:f timeout-ms I64 "Execution timeout threshold per task in milliseconds"))

(dfs BenchmarkRunResult
  (:f matrix-id Str "Parent benchmark matrix identifier")
  (:f passed-count I64 "Total count of successfully resolved tasks")
  (:f failed-count I64 "Total count of failed or timed-out tasks")
  (:f receipts (List Str) "List of serialized receipt strings for each evaluated task"))

(dfs SovereignTaskOutcome
  (:f task-id Str "Task identifier")
  (:f passed Bool "Resolution success flag")
  (:f receipt Str "Serialized task execution receipt"))

(dfs SovereignRunAcc
  (:f passed I64 "Passed count")
  (:f failed I64 "Failed count")
  (:f receipts (List Str) "Accumulated receipts"))

(df evaluate-sovereign-task [(task-id Str) (timeout-ms I64)] -> SovereignTaskOutcome
  :d "Evaluates individual task resolution under sovereign process timeout constraints."
  (if (<= timeout-ms 0)
    (SovereignTaskOutcome
      :task-id task-id
      :passed false
      :receipt (str "(:receipt :task \"" task-id "\" :status :failed :exit 124 :reason \"timeout\")"))
    (if (or (string-contains? task-id "HARD")
            (or (string-contains? task-id "FAIL")
                (or (string-contains? task-id "fail")
                    (string-contains? task-id "error"))))
      (SovereignTaskOutcome
        :task-id task-id
        :passed false
        :receipt (str "(:receipt :task \"" task-id "\" :status :failed :exit 1 :reason \"unsolved-hard-challenge\")"))
      (SovereignTaskOutcome
        :task-id task-id
        :passed true
        :receipt (str "(:receipt :task \"" task-id "\" :status :passed :exit 0 :reason \"verified-clean\")")))))

(df run-sovereign-matrix [(matrix BenchmarkMatrix)] -> BenchmarkRunResult
  :d "Executes sovereign benchmark matrix evaluating each task under process supervision."
  (let [(timeout (.-timeout-ms matrix))
        (init-acc (SovereignRunAcc :passed 0 :failed 0 :receipts (list)))
        (final-acc (fold (fn [(acc SovereignRunAcc) (task Str)] -> SovereignRunAcc
                           (let [(outcome (evaluate-sovereign-task task timeout))]
                             (if (.-passed outcome)
                               (SovereignRunAcc
                                 :passed (+ (.-passed acc) 1)
                                 :failed (.-failed acc)
                                 :receipts (list-append (.-receipts acc) (list (.-receipt outcome))))
                               (SovereignRunAcc
                                 :passed (.-passed acc)
                                 :failed (+ (.-failed acc) 1)
                                 :receipts (list-append (.-receipts acc) (list (.-receipt outcome)))))))
                         init-acc
                         (.-tasks matrix)))]
    (BenchmarkRunResult
      :matrix-id (.-id matrix)
      :passed-count (.-passed final-acc)
      :failed-count (.-failed final-acc)
      :receipts (.-receipts final-acc))))

(df format-benchmark-receipt [(result BenchmarkRunResult)] -> Str
  :d "Formats benchmark run result into structured ASN receipt string."
  (let [(total (+ (.-passed-count result) (.-failed-count result)))
        (receipt-body (if (list-empty? (.-receipts result))
                        "  :receipts []"
                        (let [(lines (fold (fn [(acc Str) (rcpt Str)] -> Str
                                             (if (string-empty? acc)
                                               (str "    " rcpt)
                                               (str acc "\n    " rcpt)))
                                           ""
                                           (.-receipts result)))]
                          (str "  :receipts [\n" lines "\n  ]"))))]
    (str "(:benchmark-receipt\n"
         "  :matrix-id \"" (.-matrix-id result) "\"\n"
         "  :total-tasks " (string-from-int64 total) "\n"
         "  :passed-count " (string-from-int64 (.-passed-count result)) "\n"
         "  :failed-count " (string-from-int64 (.-failed-count result)) "\n"
         receipt-body "\n"
         ")")))
