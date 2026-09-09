(module asl-harness/tests/terminal-bench-gateway-test
  :d "Deterministic unit verification test suite for Gemma 31B Terminal Bench setup with L7 Cognitive Gateway."
  :x [test-gateway-config
      test-think-quarantine
      test-esh-interception
      test-budget-ceiling-enforcement
      test-ctrf-subtest-gradient
      test-solvable-challenge-pass
      run-tests]
  :i [(provider :a prov)
      (sovereign_runner :a sr)
      (model_calibration :a mc)])

(df test-gateway-config [] -> Bool
  :d "Verifies default LLM Gateway configuration points to Gemma 31B with standard budget."
  (let [(cfg (prov/default-gateway-config))]
    (do
      (assert (= (.-model cfg) "gemma-4-31b-it") "model is gemma-4-31b-it")
      (assert (= (.-max-tokens cfg) 4096) "max tokens budget is 4096")
      true)))

(df test-think-quarantine [] -> Bool
  :d "Verifies L7 Cognitive Gateway demuxes and quarantines <think> reasoning scratchpad."
  (let [(raw "<think>\nInvestigating crash in custom-memory-heap-crash\nFound double free in slab allocator\n</think>\nIdentified memory corruption root cause.")
        (resp (prov/parse-model-response raw false))]
    (do
      (assert (= (.-text resp) "Identified memory corruption root cause.") "user text is stripped of think block")
      (assert (= (.-finish-reason resp) "stop") "finish reason is stop")
      true)))

(df test-esh-interception [] -> Bool
  :d "Verifies verbal Execution Simulation Hallucinations without verified runtime proof are rejected."
  (let [(raw "Task complete. All tests pass cleanly.")
        (resp (prov/parse-model-response raw false))]
    (do
      (assert (= (.-finish-reason resp) "esh_rejected") "unverified verbal claim rejected as esh_rejected")
      (assert (not (= (.-finish-reason resp) "stop")) "finish reason is not stop")
      true)))

(df test-budget-ceiling-enforcement [] -> Bool
  :d "Verifies epistemic guardrail halts execution before runaway token inflation."
  (let [(rail (sr/make-default-guardrail))
        (trace (sr/run-guarded-epistemic-task "TB4-HARD-04" 3 10000 rail))]
    (do
      (assert (<= (.-total-tokens trace) 35000) "token consumption strictly bounded below 35k ceiling")
      (assert (.-circuit-tripped trace) "circuit breaker trips on hard challenge loop threshold")
      true)))

(df test-ctrf-subtest-gradient [] -> Bool
  :d "Verifies CTRF subtest tracking delivers continuous scalar loss gradient on hard challenges."
  (let [(ctrf-raw "{\"results\":{\"summary\":{\"tests\":6,\"passed\":4,\"failed\":2,\"pending\":0,\"skipped\":0,\"other\":0}}}")
        (summary (mc/parse-ctrf-summary ctrf-raw))
        (loss (mc/compute-scalar-loss summary 10000))
        (progress (mc/compute-loss-progress loss))]
    (do
      (assert (> progress 0.5) "progress ratio reflects 4/6 passed subtests (> 0.5)")
      (assert (< progress 1.0) "progress ratio reflects incomplete resolution (< 1.0)")
      (assert (< (.-ceiling-loss loss) 0.5) "ceiling loss is reduced below 0.5 on partial pass")
      true)))

(df test-solvable-challenge-pass [] -> Bool
  :d "Verifies solvable baseline challenges pass cleanly under sovereign epistemic loop."
  (let [(trace (sr/run-epistemic-task "TB4-SOLV-01" 2 10000))]
    (do
      (assert (.-passed trace) "solvable task TB4-SOLV-01 passes verification")
      (assert (= (.-mode trace) 2) "mode 2 standard epistemic loop executed")
      (assert (< (.-total-tokens trace) 2000) "token economy strictly below 2000 tokens")
      true)))

(df run-tests [] -> Bool
  :d "Executes complete Terminal Bench Gateway test suite."
  (do
    (test-gateway-config)
    (test-think-quarantine)
    (test-esh-interception)
    (test-budget-ceiling-enforcement)
    (test-ctrf-subtest-gradient)
    (test-solvable-challenge-pass)
    true))
