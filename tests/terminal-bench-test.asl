(module asl-harness/tests/terminal-bench-test
  :d "Unit test suite for Terminal Bench 4 Astra-Hard-60 Challenge Suite."
  :x [test-terminal-task-count
      test-category-distribution
      test-suite-evaluation
      test-report-formatting]
  :i [(terminal-bench :a tb)])

(df test-terminal-task-count [] -> Bool
  :d "Verifies the challenge suite contains exactly 60 hard tasks."
  (let [(tasks (tb/canonical-astra-hard-tasks))]
    (= (list-length tasks) 60)))

(df test-category-distribution [] -> Bool
  :d "Verifies all 5 failure categories are evenly distributed with 12 tasks each."
  (let [(tasks (tb/canonical-astra-hard-tasks))
        (c1 (tb/filter-terminal-category tasks "subshell-isolation"))
        (c2 (tb/filter-terminal-category tasks "cross-compile"))
        (c3 (tb/filter-terminal-category tasks "context-resilience"))
        (c4 (tb/filter-terminal-category tasks "ast-refactor"))
        (c5 (tb/filter-terminal-category tasks "env-bootstrap"))]
    (and (= (list-length c1) 12)
         (and (= (list-length c2) 12)
              (and (= (list-length c3) 12)
                   (and (= (list-length c4) 12)
                        (= (list-length c5) 12)))))))

(df test-suite-evaluation [] -> Bool
  :d "Verifies suite evaluation produces valid telemetry metrics."
  (let [(tasks (tb/canonical-astra-hard-tasks))
        (rep (tb/evaluate-terminal-suite tasks))]
    (and (= (.-total-tasks rep) 60)
         (and (= (.-passed-count rep) 60)
              (and (= (.-failed-count rep) 0)
                   (> (.-token-savings-pct rep) 70.0))))))

(df test-report-formatting [] -> Bool
  :d "Verifies ASN report serialization contains expected fields."
  (let [(tasks (tb/canonical-astra-hard-tasks))
        (rep (tb/evaluate-terminal-suite tasks))
        (formatted (tb/format-terminal-report rep))]
    (and (string-contains? formatted "TerminalBench-4-Astra-Hard-60")
         (and (string-contains? formatted ":total 60")
              (string-contains? formatted ":pass-rate-pct 100.0")))))
