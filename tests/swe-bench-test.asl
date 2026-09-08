(module asl-harness/tests/swe-bench-test
  :d "Unit tests for SWE-bench evaluation engine, multi-arm comparison, and SWE-006 monorepo benchmark."
  :x [test-tasks test-telemetry test-matrix test-six-arm-matrix test-swe-006 run-tests]
  :i [(swe-bench :a swe)])

(df test-tasks [] -> Bool
  :d "Verifies standard SWE benchmark task definitions including SWE-006."
  (let [(tasks (swe/standard-swe-tasks))]
    (assert (= (list-length tasks) 6) "task count is 6")
    (assert (= (.-id (option-or (list-head tasks) (swe/SweTask :id "" :title "" :description "" :target-file "" :expected-diff-lines 0 :test-command ""))) "SWE-001") "first task is SWE-001")
    true))

(df test-telemetry [] -> Bool
  :d "Verifies aggregation of run telemetry across comparison arms."
  (let [(r1 (swe/make-telemetry "ASL Coding Harness" "SWE-001" true 1200 150 450 0.0004 0.75))
        (r2 (swe/make-telemetry "ASL Coding Harness" "SWE-002" true 1100 120 420 0.0003 0.80))
        (row (swe/evaluate-arm-telemetry (list r1 r2) "ASL Coding Harness"))]
    (assert (= (.-arm-name row) "ASL Coding Harness") "arm name matches")
    (assert (= (.-solve-rate row) "100%") "solve rate is 100%")
    (assert (= (.-token-reduction row) "-68.4%") "token reduction is -68.4%")
    (assert (< (.-total-cost-usd row) 0.01) "total cost < 0.01")
    true))

(df test-matrix [] -> Bool
  :d "Verifies markdown table rendering of comparison results."
  (let [(r1 (swe/ComparisonRow :arm-name "Baseline Claude Code" :solve-rate "66%" :avg-tokens 4500 :avg-latency-sec 12.4 :total-cost-usd 0.042 :token-reduction "baseline"))
        (r2 (swe/ComparisonRow :arm-name "Claude Code + GenSEAM Tools" :solve-rate "100%" :avg-tokens 2950 :avg-latency-sec 8.1 :total-cost-usd 0.026 :token-reduction "-34.1%"))
        (r3 (swe/ComparisonRow :arm-name "ASL Coding Harness" :solve-rate "100%" :avg-tokens 1420 :avg-latency-sec 3.2 :total-cost-usd 0.009 :token-reduction "-68.4%"))
        (matrix (swe/format-benchmark-matrix (list r1 r2 r3)))]
    (assert (string-contains? matrix "Baseline Claude Code") "contains Baseline Claude Code")
    (assert (string-contains? matrix "Claude Code + GenSEAM Tools") "contains Claude Code + GenSEAM Tools")
    (assert (string-contains? matrix "ASL Coding Harness") "contains ASL Coding Harness")
    true))

(df test-six-arm-matrix [] -> Bool
  :d "Verifies full 6-arm benchmark matrix covers Gemma 31B across harnesses, Python and ASL."
  (let [(rows (swe/standard-six-arm-benchmark))
        (formatted (swe/format-benchmark-matrix rows))]
    (assert (= (list-length rows) 6) "rows count is 6")
    (assert (string-contains? formatted "Gemma 31B (Our Agent) + Python") "contains Gemma Python")
    (assert (string-contains? formatted "Gemma 31B (Our Agent) + ASL") "contains Gemma ASL")
    (assert (string-contains? formatted "Gemma 31B (Claude Code CLI) + ASL (RAW / NO TOOLS)") "contains Claude RAW")
    (assert (string-contains? formatted "Gemma 31B (Claude Code CLI) + ASL + ASL Tooling") "contains Claude ASL Tooling")
    true))

(df test-swe-006 [] -> Bool
  :d "Verifies SWE-006 cross-package blast radius and ghost API migration task definition."
  (let [(t (swe/swe-006-task))
        (found (swe/find-swe-task (swe/standard-swe-tasks) "SWE-006"))]
    (assert (= (.-id t) "SWE-006") "id is SWE-006")
    (assert (= (.-target-file t) "packages/core/src/service.asl") "target file matches")
    (assert (= (.-expected-diff-lines t) 12) "expected diff lines is 12")
    (assert (option-is-some? found) "found SWE-006")
    true))

(df run-tests [] -> Bool
  :d "Executes full SWE benchmark test suite."
  (do
    (test-tasks)
    (test-telemetry)
    (test-matrix)
    (test-six-arm-matrix)
    (test-swe-006)
    true))
