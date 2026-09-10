(module asl-harness/sotparty-runner-test
  :d "Unit verification test suite for Universal SOTParty Frontier Harness"
  :x [test-swe006-task-construction
      test-ablation-arms-setup
      test-execution-normal-pass
      test-circuit-breaker-trip
      test-pareto-frontier-evaluation
      test-format-pareto-matrix
      run-tests]
  :i [(sotparty_runner :a sot)])

(df test-swe006-task-construction [] -> Bool
  :d "Verifies canonical SWE-006 task configuration"
  (let [(task (sot/make-swe006-sot-task))]
    (assert (= (.-id task) "SWE-006") "Task ID must be SWE-006")
    (assert (= (.-max-token-ceiling task) 35000) "Circuit breaker ceiling must be 35000 tokens")
    (assert (= (list-length (.-blast-radius-packages task)) 3) "Must identify 3 blast radius packages")
    (assert (list-contains? (.-blast-radius-packages task) "agent-core") "Must include agent-core")
    true))

(df test-ablation-arms-setup [] -> Bool
  :d "Verifies baseline vs ASL harness ablation configurations"
  (let [(arms (sot/make-ablation-arms))
        (base (option-or (list-head arms) (sot/AblationArm :name "" :with-impact-analysis false :with-circuit-breaker false :with-egraph-optimization false)))
        (harness (option-or (list-head (option-or (list-tail arms) (list))) (sot/AblationArm :name "" :with-impact-analysis false :with-circuit-breaker false :with-egraph-optimization false)))]
    (assert (= (list-length arms) 2) "Must configure exactly 2 ablation arms")
    (assert (= (.-name base) "Arm-Baseline") "First arm is Baseline")
    (assert (not (.-with-circuit-breaker base)) "Baseline has no circuit breaker")
    (assert (= (.-name harness) "Arm-AslHarness") "Second arm is ASL Harness")
    (assert (.-with-circuit-breaker harness) "ASL Harness equips 35k circuit breaker")
    true))

(df test-execution-normal-pass [] -> Bool
  :d "Verifies successful task execution within token budget"
  (let [(task (sot/make-swe006-sot-task))
        (arms (sot/make-ablation-arms))
        (harness (option-or (list-head (option-or (list-tail arms) (list))) (sot/AblationArm :name "" :with-impact-analysis false :with-circuit-breaker false :with-egraph-optimization false)))
        (run (sot/execute-sotparty-task task harness 12000 true 0 450))]
    (assert (.-resolved run) "Task must resolve successfully")
    (assert (not (.-tripped-breaker run)) "Circuit breaker must not trip")
    (assert (= (.-tokens-consumed run) 12000) "Tokens consumed must match 12000")
    (assert (= (.-duration-ms run) 450) "Duration must record 450ms")
    true))

(df test-circuit-breaker-trip [] -> Bool
  :d "Verifies 35k token ceiling triggers circuit breaker and halts execution"
  (let [(task (sot/make-swe006-sot-task))
        (arms (sot/make-ablation-arms))
        (harness (option-or (list-head (option-or (list-tail arms) (list))) (sot/AblationArm :name "" :with-impact-analysis false :with-circuit-breaker false :with-egraph-optimization false)))
        (run (sot/execute-sotparty-task task harness 42000 true 2 1200))]
    (assert (not (.-resolved run)) "Tripped run must not be marked resolved")
    (assert (.-tripped-breaker run) "Circuit breaker must trip on 42000 tokens")
    (assert (= (.-tokens-consumed run) 35000) "Tokens consumed capped at 35000 ceiling")
    true))

(df test-pareto-frontier-evaluation [] -> Bool
  :d "Verifies Pareto frontier scoring and token compaction computation"
  (let [(task (sot/make-swe006-sot-task))
        (arms (sot/make-ablation-arms))
        (harness (option-or (list-head (option-or (list-tail arms) (list))) (sot/AblationArm :name "" :with-impact-analysis false :with-circuit-breaker false :with-egraph-optimization false)))
        (r1 (sot/execute-sotparty-task task harness 8000 true 0 300))
        (r2 (sot/execute-sotparty-task task harness 12000 true 0 400))
        (runs (list r1 r2))
        (metric (sot/evaluate-sotparty-suite harness runs))]
    (assert (= (.-solve-rate metric) 1.0) "Solve rate must be 1.0 for 2 passing runs")
    (assert (= (.-avg-tokens metric) 10000) "Average tokens must be 10000")
    (assert (.-pareto-optimal metric) "Must be recognized as Pareto optimal")
    (assert (> (.-token-compaction-ratio metric) 3.0) "Token compaction ratio must exceed 3.0x")
    true))

(df test-format-pareto-matrix [] -> Bool
  :d "Verifies ASN Pareto matrix serialization"
  (let [(task (sot/make-swe006-sot-task))
        (arms (sot/make-ablation-arms))
        (harness (option-or (list-head (option-or (list-tail arms) (list))) (sot/AblationArm :name "" :with-impact-analysis false :with-circuit-breaker false :with-egraph-optimization false)))
        (r1 (sot/execute-sotparty-task task harness 10000 true 0 350))
        (metric (sot/evaluate-sotparty-suite harness (list r1)))
        (mat (sot/format-pareto-matrix (list metric)))]
    (assert (string-contains? mat ":pareto-matrix") "Matrix must contain header")
    (assert (string-contains? mat "Arm-AslHarness") "Matrix must include arm name")
    (assert (string-contains? mat ":pareto-optimal true") "Matrix must display pareto status")
    true))

(df run-tests [] -> Bool
  :d "Executes all SOTParty runner test cases"
  (and (test-swe006-task-construction)
       (and (test-ablation-arms-setup)
            (and (test-execution-normal-pass)
                 (and (test-circuit-breaker-trip)
                      (and (test-pareto-frontier-evaluation)
                           (test-format-pareto-matrix)))))))
