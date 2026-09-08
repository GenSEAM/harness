(module asl-harness/tests/sovereign-runner-test
  :d "Falsifiable unit verification suite for pure ASL sovereign benchmark runner, supervision, and receipt ledger."
  :x [test-benchmark-matrix-construction
      test-solvable-tasks-execution
      test-unsolved-hard-tasks-execution
      test-timeout-supervision
      test-mixed-challenge-matrix-execution
      test-benchmark-receipt-formatting
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

(df run-tests [] -> Bool
  :d "Runs all sovereign benchmark runner unit and integration tests."
  (and (test-benchmark-matrix-construction)
       (and (test-solvable-tasks-execution)
            (and (test-unsolved-hard-tasks-execution)
                 (and (test-timeout-supervision)
                      (and (test-mixed-challenge-matrix-execution)
                           (test-benchmark-receipt-formatting)))))))
