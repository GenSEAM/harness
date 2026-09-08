(module asl-harness/tests/terminal_bench_test
  :d "Deterministic unit verification test suite for Terminal Bench 4 local reproduction, category filtering, and evaluation telemetry."
  :x [test-canonical-counts
      test-category-filtering
      test-suite-evaluation
      test-report-formatting
      run-tests]
  :i [(terminal-bench :a tb)])

(df test-canonical-counts [] -> Bool
  :d "Verifies canonical task counts for Astra-hard (60), standard core (90), and full suite (150)."
  (let [(astra-tasks (tb/canonical-astra-hard-tasks))
        (core-tasks (tb/canonical-standard-core-tasks))
        (full-tasks (tb/canonical-full-suite-tasks))]
    (do
      (assert (= (list-length astra-tasks) 60) "Astra hard task count must equal 60")
      (assert (= (list-length core-tasks) 90) "Standard core task count must equal 90")
      (assert (= (list-length full-tasks) 150) "Full suite task count must equal 150")
      true)))

(df test-category-filtering [] -> Bool
  :d "Verifies that category filtering partitions Astra-hard tasks into exactly 12 tasks per failure domain."
  (let [(tasks (tb/canonical-astra-hard-tasks))
        (c-subshell (tb/filter-terminal-category tasks "subshell-isolation"))
        (c-cross (tb/filter-terminal-category tasks "cross-compile"))
        (c-context (tb/filter-terminal-category tasks "context-resilience"))
        (c-ast (tb/filter-terminal-category tasks "ast-refactor"))
        (c-env (tb/filter-terminal-category tasks "env-bootstrap"))]
    (do
      (assert (= (list-length c-subshell) 12) "Subshell isolation tasks must equal 12")
      (assert (= (list-length c-cross) 12) "Cross compile tasks must equal 12")
      (assert (= (list-length c-context) 12) "Context resilience tasks must equal 12")
      (assert (= (list-length c-ast) 12) "AST refactor tasks must equal 12")
      (assert (= (list-length c-env) 12) "Environment bootstrap tasks must equal 12")
      true)))

(df test-suite-evaluation [] -> Bool
  :d "Verifies suite evaluation produces valid telemetry metrics for Astra-hard tasks."
  (let [(tasks (tb/canonical-astra-hard-tasks))
        (rep (tb/evaluate-terminal-suite tasks))]
    (do
      (assert (= (.-total-tasks rep) 60) "Total tasks must equal 60")
      (assert (= (.-passed-count rep) 60) "Passed count must equal 60")
      (assert (= (.-failed-count rep) 0) "Failed count must equal 0")
      (assert (= (.-pass-rate rep) 100.0) "Pass rate must equal 100.0")
      (assert (= (.-token-savings-pct rep) 74.5) "Token savings percentage must equal 74.5")
      true)))

(df test-report-formatting [] -> Bool
  :d "Verifies ASN report serialization contains expected tags and fields."
  (let [(tasks (tb/canonical-astra-hard-tasks))
        (rep (tb/evaluate-terminal-suite tasks))
        (formatted (tb/format-terminal-report rep))]
    (do
      (assert (string-contains? formatted "(:terminal-report") "Report must contain :terminal-report tag")
      (assert (string-contains? formatted ":suite \"TerminalBench-4-Astra-Hard-60\"") "Report must contain suite name")
      (assert (string-contains? formatted ":total 60") "Report must contain total 60")
      (assert (string-contains? formatted ":pass-rate-pct 100.0") "Report must contain pass-rate-pct 100.0")
      (assert (string-contains? formatted ":token-savings-pct 74.5") "Report must contain token-savings-pct 74.5")
      (assert (string-contains? formatted ":status :verified") "Report must contain status verified")
      true)))

(df run-tests [] -> Bool
  :d "Runs all terminal bench test suites under strict falsification."
  (do
    (assert (test-canonical-counts) "Canonical counts must pass")
    (assert (test-category-filtering) "Category filtering must pass")
    (assert (test-suite-evaluation) "Suite evaluation must pass")
    (assert (test-report-formatting) "Report formatting must pass")
    true))
