(module asl-harness/tests/sovereign-runner-test
  :d "Falsifiable unit verification suite for pure ASL sovereign benchmark runner, supervision, and receipt ledger."
  :x [test-benchmark-matrix-construction
      test-solvable-tasks-execution
      test-unsolved-hard-tasks-execution
      test-timeout-supervision
      test-mixed-challenge-matrix-execution
      test-benchmark-receipt-formatting
      test-mode-2-standard-pipeline
      test-mode-3-deep-pipeline
      test-mode-comparative-metrics
      run-tests]
  :i [(sovereign_runner :a sr)])

(df test-benchmark-matrix-construction [] -> Bool
  :d "Verifies BenchmarkMatrix construction, fields, and empty matrix state."
  (let [(m (sr/BenchmarkMatrix
             :id "matrix-sample"
             :tasks (list "task-a" "task-b")
             :timeout-ms 5000))
        (m-empty (sr/BenchmarkMatrix
                   :id "matrix-empty"
                   :tasks (list)
                   :timeout-ms 0))]
    (do
      (assert (= (.-id m) "matrix-sample") "Matrix ID must match constructor argument")
      (assert (= (list-length (.-tasks m)) 2) "Task count must equal 2")
      (assert (= (.-timeout-ms m) 5000) "Timeout must equal 5000")
      (assert (= (.-id m-empty) "matrix-empty") "Empty matrix ID must match")
      (assert (list-empty? (.-tasks m-empty)) "Empty matrix task list must be empty")
      (assert (= (.-timeout-ms m-empty) 0) "Empty matrix timeout must be zero")
      true)))

(df test-solvable-tasks-execution [] -> Bool
  :d "Verifies clean execution of solvable baseline tasks with zero exit status."
  (let [(m (sr/BenchmarkMatrix
             :id "matrix-solv"
             :tasks (list "TB4-SOLV-01" "TB4-SOLV-02")
             :timeout-ms 30000))
        (res (sr/run-sovereign-matrix m))]
    (do
      (assert (= (.-matrix-id res) "matrix-solv") "Result matrix id must match")
      (assert (= (.-passed-count res) 2) "All 2 solvable tasks must pass")
      (assert (= (.-failed-count res) 0) "Zero tasks must fail in solvable suite")
      (assert (= (list-length (.-receipts res)) 2) "Receipt count must equal 2")
      (assert (string-contains? (option-or (list-head (.-receipts res)) "") ":status :passed") "First task receipt must indicate passed")
      (assert (string-contains? (option-or (list-head (.-receipts res)) "") ":exit 0") "Passed task must record exit code 0")
      true)))

(df test-unsolved-hard-tasks-execution [] -> Bool
  :d "Verifies proper failure categorization and receipt logging for unsolved hard challenges."
  (let [(m (sr/BenchmarkMatrix
             :id "matrix-hard"
             :tasks (list "TB4-HARD-01" "TB4-HARD-02" "TB4-HARD-03")
             :timeout-ms 30000))
        (res (sr/run-sovereign-matrix m))]
    (do
      (assert (= (.-passed-count res) 0) "Zero hard tasks must pass")
      (assert (= (.-failed-count res) 3) "All 3 hard tasks must fail")
      (assert (= (list-length (.-receipts res)) 3) "Receipt count must equal 3")
      (assert (string-contains? (option-or (list-head (.-receipts res)) "") ":status :failed") "First hard task receipt must indicate failed")
      (assert (string-contains? (option-or (list-head (.-receipts res)) "") "unsolved-hard-challenge") "Hard task receipt must state reason unsolved-hard-challenge")
      true)))

(df test-timeout-supervision [] -> Bool
  :d "Verifies process supervision halts and records timeout receipts on expired deadlines."
  (let [(m-zero (sr/BenchmarkMatrix
                  :id "matrix-timeout-zero"
                  :tasks (list "TB4-SOLV-01" "TB4-SOLV-02")
                  :timeout-ms 0))
        (res-zero (sr/run-sovereign-matrix m-zero))
        (m-neg (sr/BenchmarkMatrix
                 :id "matrix-timeout-neg"
                 :tasks (list "TB4-SOLV-01" "TB4-SOLV-02")
                 :timeout-ms -100))
        (res-neg (sr/run-sovereign-matrix m-neg))]
    (do
      (assert (= (.-passed-count res-zero) 0) "Zero tasks must pass under zero timeout")
      (assert (= (.-failed-count res-zero) 2) "Both tasks must fail under zero timeout")
      (assert (string-contains? (option-or (list-head (.-receipts res-zero)) "") ":reason \"timeout\"") "Receipt must indicate timeout reason")
      (assert (string-contains? (option-or (list-head (.-receipts res-zero)) "") ":exit 124") "Timed out task must exit with code 124")
      (assert (= (.-failed-count res-neg) 2) "Both tasks must fail under negative timeout")
      true)))

(df test-mixed-challenge-matrix-execution [] -> Bool
  :d "Verifies execution of canonical 10-task benchmark matrix with 2 solvable and 8 hard challenges."
  (let [(m (sr/BenchmarkMatrix
             :id "terminal-bench-4-challenge-10"
             :tasks (list "TB4-SOLV-01"
                          "TB4-SOLV-02"
                          "TB4-HARD-01"
                          "TB4-HARD-02"
                          "TB4-HARD-03"
                          "TB4-HARD-04"
                          "TB4-HARD-05"
                          "TB4-HARD-06"
                          "TB4-HARD-07"
                          "TB4-HARD-08")
             :timeout-ms 60000))
        (res (sr/run-sovereign-matrix m))]
    (do
      (assert (= (.-matrix-id res) "terminal-bench-4-challenge-10") "Matrix ID must match challenge 10")
      (assert (= (.-passed-count res) 2) "Challenge 10 must record exactly 2 passed baseline solvable tasks")
      (assert (= (.-failed-count res) 8) "Challenge 10 must record exactly 8 failed hardest unsolved tasks")
      (assert (= (+ (.-passed-count res) (.-failed-count res)) 10) "Total evaluated tasks must equal 10")
      (assert (= (list-length (.-receipts res)) 10) "Total receipts recorded must equal 10")
      true)))

(df test-benchmark-receipt-formatting [] -> Bool
  :d "Verifies formatting of benchmark execution receipts into valid structured ASN notation."
  (let [(m (sr/BenchmarkMatrix
             :id "terminal-bench-4-challenge-10"
             :tasks (list "TB4-SOLV-01" "TB4-SOLV-02" "TB4-HARD-01")
             :timeout-ms 60000))
        (res (sr/run-sovereign-matrix m))
        (receipt-str (sr/format-benchmark-receipt res))
        (res-empty (sr/BenchmarkRunResult
                     :matrix-id "empty-res"
                     :passed-count 0
                     :failed-count 0
                     :receipts (list)))
        (receipt-empty (sr/format-benchmark-receipt res-empty))]
    (do
      (assert (string-contains? receipt-str "(:benchmark-receipt") "Receipt must open with :benchmark-receipt")
      (assert (string-contains? receipt-str ":matrix-id \"terminal-bench-4-challenge-10\"") "Receipt must embed matrix identifier")
      (assert (string-contains? receipt-str ":total-tasks 3") "Receipt must report total-tasks 3")
      (assert (string-contains? receipt-str ":passed-count 2") "Receipt must report passed-count 2")
      (assert (string-contains? receipt-str ":failed-count 1") "Receipt must report failed-count 1")
      (assert (string-contains? receipt-empty ":receipts []") "Empty receipt must serialize empty receipt list")
      true)))

(df test-mode-2-standard-pipeline [] -> Bool
  :d "Verifies Mode 2 Standard Epistemic Loop: 4 discrete steps, token budget, and timeout handling."
  (let [(trace (sr/run-epistemic-task "TB4-SOLV-01" 2 30000))
        (steps (.-steps trace))
        (dummy (sr/make-epistemic-step "" "" "" 0 ""))
        (s0 (option-or (list-get steps 0) dummy))
        (s1 (option-or (list-get steps 1) dummy))
        (s2 (option-or (list-get steps 2) dummy))
        (s3 (option-or (list-get steps 3) dummy))
        (timeout-trace (sr/run-epistemic-task "TB4-SOLV-01" 2 0))]
    (do
      (assert (= (list-length steps) 4) "Mode 2 must produce exactly 4 steps")
      (assert (= (.-name s0) "scout") "Mode 2 step 0 must be scout")
      (assert (= (.-name s1) "plan-and-gap") "Mode 2 step 1 must be plan-and-gap")
      (assert (= (.-name s2) "implement") "Mode 2 step 2 must be implement")
      (assert (= (.-name s3) "reconcile") "Mode 2 step 3 must be reconcile")
      (assert (.-passed trace) "Solvable task must pass under Mode 2")
      (assert (= (.-total-tokens trace) 750) "Mode 2 total token consumption must equal 750")
      (assert (not (.-passed timeout-trace)) "Timed out Mode 2 execution must record passed false")
      (assert (= (list-length (.-steps timeout-trace)) 0) "Timed out run must have 0 steps")
      true)))

(df test-mode-3-deep-pipeline [] -> Bool
  :d "Verifies Mode 3 Deep Sovereign Epistemic Loop: 5 discrete steps, adversarial gap audit, and hard task rejection."
  (let [(trace (sr/run-epistemic-task "TB4-SOLV-01" 3 30000))
        (steps (.-steps trace))
        (dummy (sr/make-epistemic-step "" "" "" 0 ""))
        (s0 (option-or (list-get steps 0) dummy))
        (s1 (option-or (list-get steps 1) dummy))
        (s2 (option-or (list-get steps 2) dummy))
        (s3 (option-or (list-get steps 3) dummy))
        (s4 (option-or (list-get steps 4) dummy))
        (hard-trace (sr/run-epistemic-task "TB4-HARD-01" 3 30000))
        (hard-steps (.-steps hard-trace))
        (hard-gap (option-or (list-get hard-steps 2) dummy))]
    (do
      (assert (= (list-length steps) 5) "Mode 3 must produce exactly 5 steps")
      (assert (= (.-name s0) "scout") "Mode 3 step 0 must be scout")
      (assert (= (.-name s1) "plan") "Mode 3 step 1 must be plan")
      (assert (= (.-name s2) "gap-audit") "Mode 3 step 2 must be gap-audit")
      (assert (= (.-name s3) "implement") "Mode 3 step 3 must be implement")
      (assert (= (.-name s4) "reconcile") "Mode 3 step 4 must be reconcile")
      (assert (.-passed trace) "Solvable task must pass under Mode 3")
      (assert (= (.-total-tokens trace) 1080) "Mode 3 total token consumption must equal 1080")
      (assert (not (.-passed hard-trace)) "Hard challenge must fail under Mode 3")
      (assert (= (.-status hard-gap) ":failed") "Gap audit step must fail on hard challenge")
      (assert (string-contains? (.-receipt hard-gap) "unresolvable-constraint") "Gap audit receipt must identify unresolvable constraint")
      true)))

(df test-mode-comparative-metrics [] -> Bool
  :d "Verifies comparative metrics ledger between Mode 2 and Mode 3 and epistemic trace formatting."
  (let [(cmp-solv (sr/compare-epistemic-modes "TB4-SOLV-01" 30000))
        (t2 (sr/run-epistemic-task "TB4-SOLV-01" 2 30000))
        (fmt2 (sr/format-epistemic-trace t2))
        (t3 (sr/run-epistemic-task "TB4-SOLV-01" 3 30000))
        (fmt3 (sr/format-epistemic-trace t3))]
    (do
      (assert (or (string-contains? cmp-solv "(:mode-comparison")
                  (string-contains? cmp-solv "(:comparative-epistemic-run"))
              "Comparative output must contain ASN comparison block")
      (assert (or (string-contains? cmp-solv ":mode-2")
                  (string-contains? cmp-solv ":mode 2"))
              "Comparative output must record Mode 2 metrics")
      (assert (or (string-contains? cmp-solv ":mode-3")
                  (string-contains? cmp-solv ":mode 3"))
              "Comparative output must record Mode 3 metrics")
      (assert (string-contains? cmp-solv ":step-delta 1") "Step delta between Mode 3 and Mode 2 must equal 1")
      (assert (string-contains? cmp-solv ":token-overhead 330") "Token overhead must equal 330")
      (assert (string-contains? fmt2 "(:epistemic-trace") "Formatted trace 2 must start with :epistemic-trace")
      (assert (string-contains? fmt2 ":mode 2") "Formatted trace 2 must record :mode 2")
      (assert (string-contains? fmt2 ":total-tokens 750") "Formatted trace 2 must record total tokens 750")
      (assert (string-contains? fmt3 "(:epistemic-trace") "Formatted trace 3 must start with :epistemic-trace")
      (assert (string-contains? fmt3 ":mode 3") "Formatted trace 3 must record :mode 3")
      (assert (string-contains? fmt3 ":total-tokens 1080") "Formatted trace 3 must record total tokens 1080")
      true)))

(df run-tests [] -> Bool
  :d "Runs all sovereign benchmark runner unit and integration tests."
  (and (test-benchmark-matrix-construction)
       (and (test-solvable-tasks-execution)
            (and (test-unsolved-hard-tasks-execution)
                 (and (test-timeout-supervision)
                      (and (test-mixed-challenge-matrix-execution)
                           (and (test-benchmark-receipt-formatting)
                                (and (test-mode-2-standard-pipeline)
                                     (and (test-mode-3-deep-pipeline)
                                          (test-mode-comparative-metrics))))))))))

