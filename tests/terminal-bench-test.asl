(module asl-harness/tests/terminal-bench-test
  :d "Unit test suite for Terminal Bench 4 Benchmark Suite (60 Astra-Hard + 150 Full Suite)."
  :x [test-terminal-task-count
      test-category-distribution
      test-full-terminal-task-count
      test-full-category-distribution
      test-suite-evaluation
      test-report-formatting
      run-tests]
  :i [(terminal-bench :a tb)])

(df test-terminal-task-count [] -> Bool
  :d "Verifies the challenge suite contains exactly 60 hard tasks."
  (let [(tasks (tb/canonical-astra-hard-tasks))]
    (assert (= (list-length tasks) 60) "challenge task count is 60")
    (assert (not (list-empty? tasks)) "tasks not empty")
    true))

(df test-category-distribution [] -> Bool
  :d "Verifies all 5 failure categories are evenly distributed with 12 tasks each."
  (let [(tasks (tb/canonical-astra-hard-tasks))
        (c1 (tb/filter-terminal-category tasks "subshell-isolation"))
        (c2 (tb/filter-terminal-category tasks "cross-compile"))
        (c3 (tb/filter-terminal-category tasks "context-resilience"))
        (c4 (tb/filter-terminal-category tasks "ast-refactor"))
        (c5 (tb/filter-terminal-category tasks "env-bootstrap"))]
    (assert (= (list-length c1) 12) "c1 count is 12")
    (assert (= (list-length c2) 12) "c2 count is 12")
    (assert (= (list-length c3) 12) "c3 count is 12")
    (assert (= (list-length c4) 12) "c4 count is 12")
    (assert (= (list-length c5) 12) "c5 count is 12")
    true))

(df test-full-terminal-task-count [] -> Bool
  :d "Verifies the full Terminal Bench suite contains exactly 150 tasks."
  (let [(tasks (tb/canonical-full-suite-tasks))]
    (assert (= (list-length tasks) 150) "full task count is 150")
    (assert (not (list-empty? tasks)) "tasks not empty")
    true))

(df test-full-category-distribution [] -> Bool
  :d "Verifies category distribution across all 150 tasks."
  (let [(tasks (tb/canonical-full-suite-tasks))
        (c1 (tb/filter-terminal-category tasks "subshell-isolation"))
        (c2 (tb/filter-terminal-category tasks "cross-compile"))
        (c3 (tb/filter-terminal-category tasks "context-resilience"))
        (c4 (tb/filter-terminal-category tasks "ast-refactor"))
        (c5 (tb/filter-terminal-category tasks "env-bootstrap"))
        (c6 (tb/filter-terminal-category tasks "stream-pipeline"))
        (c7 (tb/filter-terminal-category tasks "system-net"))
        (c8 (tb/filter-terminal-category tasks "git-vcs"))
        (c9 (tb/filter-terminal-category tasks "build-packaging"))
        (c10 (tb/filter-terminal-category tasks "sec-permissions"))
        (c11 (tb/filter-terminal-category tasks "proc-analytics"))]
    (assert (= (list-length c1) 12) "full c1 count is 12")
    (assert (= (list-length c2) 12) "full c2 count is 12")
    (assert (= (list-length c3) 12) "full c3 count is 12")
    (assert (= (list-length c4) 12) "full c4 count is 12")
    (assert (= (list-length c5) 12) "full c5 count is 12")
    (assert (= (list-length c6) 15) "full c6 count is 15")
    (assert (= (list-length c7) 15) "full c7 count is 15")
    (assert (= (list-length c8) 15) "full c8 count is 15")
    (assert (= (list-length c9) 15) "full c9 count is 15")
    (assert (= (list-length c10) 15) "full c10 count is 15")
    (assert (= (list-length c11) 15) "full c11 count is 15")
    true))

(df test-suite-evaluation [] -> Bool
  :d "Verifies suite evaluation produces valid telemetry metrics."
  (let [(tasks (tb/canonical-astra-hard-tasks))
        (rep (tb/evaluate-terminal-suite tasks))]
    (assert (= (.-total-tasks rep) 60) "total tasks is 60")
    (assert (= (.-passed-count rep) 60) "passed count is 60")
    (assert (= (.-failed-count rep) 0) "failed count is 0")
    (assert (> (.-token-savings-pct rep) 70.0) "token savings > 70")
    true))

(df test-report-formatting [] -> Bool
  :d "Verifies ASN report serialization contains expected fields."
  (let [(tasks (tb/canonical-astra-hard-tasks))
        (rep (tb/evaluate-terminal-suite tasks))
        (formatted (tb/format-terminal-report rep))]
    (assert (string-contains? formatted "TerminalBench-4-Astra-Hard-60") "contains suite name")
    (assert (string-contains? formatted ":total 60") "contains total 60")
    (assert (string-contains? formatted ":pass-rate-pct 100.0") "contains pass rate 100.0")
    true))

(df run-tests [] -> Bool
  :d "Executes all terminal bench tests."
  (do
    (test-terminal-task-count)
    (test-category-distribution)
    (test-full-terminal-task-count)
    (test-full-category-distribution)
    (test-suite-evaluation)
    (test-report-formatting)
    true))
