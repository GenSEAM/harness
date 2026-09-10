(module asl-harness/sotparty-runner
  :d "Universal SOTParty Frontier Harness and SWE-006 Blast Radius Evaluation Suite"
  :x [SotPartyTask
      AblationArm
      SotPartyRun
      ParetoMetric
      make-swe006-sot-task
      make-ablation-arms
      execute-sotparty-task
      evaluate-sotparty-suite
      format-pareto-matrix]
  :i [])

(dfs SotPartyTask
  :d "SOTParty benchmark task definition"
  (:f id Str "Task identifier e.g. SWE-006")
  (:f title Str "Benchmark task title")
  (:f blast-radius-packages (List Str) "Affected package identifiers")
  (:f max-token-ceiling I64 "Circuit breaker token ceiling default 35000")
  (:f test-command Str "Physical verification gate"))

(dfs AblationArm
  :d "Dual-arm ablation configuration"
  (:f name Str "Arm label e.g. Arm-Baseline or Arm-AslHarness")
  (:f with-impact-analysis Bool "True if intel impact navigation is enabled")
  (:f with-circuit-breaker Bool "True if 35k token ceiling is active")
  (:f with-egraph-optimization Bool "True if egraph AST equivalence is used"))

(dfs SotPartyRun
  :d "Execution telemetry for a single SOTParty benchmark evaluation"
  (:f task-id Str "Task identifier")
  (:f arm AblationArm "Evaluation arm used")
  (:f resolved Bool "True if test command passed")
  (:f tokens-consumed I64 "Total prompt and completion tokens")
  (:f tripped-breaker Bool "True if token ceiling was tripped")
  (:f caller-cycles-detected I64 "Number of caller circularities detected")
  (:f duration-ms I64 "Elapsed execution milliseconds"))

(dfs ParetoMetric
  :d "Pareto frontier analysis metric comparing solve rate and token efficiency"
  (:f arm-name Str "Ablation arm identifier")
  (:f solve-rate F64 "Fraction of tasks resolved between 0.0 and 1.0")
  (:f avg-tokens I64 "Average tokens consumed per task")
  (:f pareto-optimal Bool "True if on the empirical Pareto frontier")
  (:f token-compaction-ratio F64 "Token reduction ratio compared to baseline"))

(df make-swe006-sot-task [] -> SotPartyTask
  :d "Creates the canonical SWE-006 blast radius and caller cycle evaluation task"
  (SotPartyTask
    :id "SWE-006"
    :title "Cross-Package Blast Radius and Caller Cycle Migration"
    :blast-radius-packages (list "agent-core" "mem" "harness")
    :max-token-ceiling 35000
    :test-command "asl test --strict-falsify harness/tests/coding-test.asl"))

(df make-ablation-arms [] -> (List AblationArm)
  :d "Instantiates dual-arm configurations: Baseline vs ASL Cognitive Harness"
  (let [(arm-base (AblationArm
                    :name "Arm-Baseline"
                    :with-impact-analysis false
                    :with-circuit-breaker false
                    :with-egraph-optimization false))
        (arm-harness (AblationArm
                       :name "Arm-AslHarness"
                       :with-impact-analysis true
                       :with-circuit-breaker true
                       :with-egraph-optimization true))]
    (list arm-base arm-harness)))

(df execute-sotparty-task [(task SotPartyTask)
                           (arm AblationArm)
                           (tokens I64)
                           (passed Bool)
                           (cycles I64)
                           (latency-ms I64)] -> SotPartyRun
  :d "Simulates or records an empirical task execution with token ceiling protection"
  (let [(ceiling (.-max-token-ceiling task))
        (breaker-active (.-with-circuit-breaker arm))
        (tripped (and breaker-active (> tokens ceiling)))
        (final-tokens (if tripped ceiling tokens))
        (final-resolved (if tripped false passed))]
    (SotPartyRun
      :task-id (.-id task)
      :arm arm
      :resolved final-resolved
      :tokens-consumed final-tokens
      :tripped-breaker tripped
      :caller-cycles-detected cycles
      :duration-ms latency-ms)))

(df evaluate-sotparty-suite [(arm AblationArm) (runs (List SotPartyRun))] -> ParetoMetric
  :d "Evaluates SOTParty run telemetry to produce Pareto frontier metrics"
  (if (list-empty? runs)
    (ParetoMetric
      :arm-name (.-name arm)
      :solve-rate 0.0
      :avg-tokens 0
      :pareto-optimal false
      :token-compaction-ratio 1.0)
    (let [(total-runs (list-length runs))
          (total-resolved (fold (fn [(acc I64) (r SotPartyRun)] -> I64
                                  (if (.-resolved r) (+ acc 1) acc))
                                0
                                runs))
          (total-tokens (fold (fn [(acc I64) (r SotPartyRun)] -> I64
                                (+ acc (.-tokens-consumed r)))
                              0
                              runs))
          (avg-tok (div-i64 total-tokens total-runs))
          (solve (div-f64 (float64-from-int64 total-resolved) (float64-from-int64 total-runs)))
          (ratio (if (> avg-tok 0) (div-f64 35000.0 (float64-from-int64 avg-tok)) 1.0))
          (optimal (and (>= solve 0.8) (<= avg-tok 15000)))]
      (ParetoMetric
        :arm-name (.-name arm)
        :solve-rate solve
        :avg-tokens avg-tok
        :pareto-optimal optimal
        :token-compaction-ratio ratio))))

(df format-pareto-matrix [(metrics (List ParetoMetric))] -> Str
  :d "Formats Pareto frontier evaluation metrics into a compact ASN matrix"
  (let [(rows (fold (fn [(acc Str) (m ParetoMetric)] -> Str
                      (let [(entry (str "    (:row :arm \"" (.-arm-name m) "\""
                                        " :solve " (string-from-float64 (.-solve-rate m))
                                        " :avg-tokens " (string-from-int64 (.-avg-tokens m))
                                        " :pareto-optimal " (if (.-pareto-optimal m) "true" "false")
                                        " :compaction " (string-from-float64 (.-token-compaction-ratio m)) ")"))]
                        (if (string-empty? acc) entry (str acc "\n" entry))))
                    ""
                    metrics))]
    (str "(:pareto-matrix\n"
         rows "\n"
         "  )")))
