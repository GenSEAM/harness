(module asl-harness/skills-projection-test
  :d "Continuous Verification Suite ensuring skills are deterministically projected from Harness models"
  :x [test-teleology-mandate-projections
      test-steps-pipeline-projection
      test-gap-audit-contract-projection
      test-anti-hallucination-projection
      run-projection-tests
      run-tests]
  :i [(teleology :a tel)
      (steps-pipeline :a pipe)
      (anti_hallucination :a anti)])

(df test-teleology-mandate-projections [] -> Bool
  :d "Tests that all 4 teleological mandates project valid archetype IDs and non-empty values"
  (let [(scout (tel/make-scout-mandate))
        (planner (tel/make-planner-mandate))
        (impl (tel/make-implementer-mandate))
        (auditor (tel/make-auditor-mandate))]
    (assert (= (.-archetype-id scout) "scout") "scout archetype id matches")
    (assert (= (.-archetype-id planner) "planner") "planner archetype id matches")
    (assert (= (.-archetype-id impl) "implementer") "implementer archetype id matches")
    (assert (= (.-archetype-id auditor) "auditor") "auditor archetype id matches")
    (assert (> (list-length (.-values scout)) 0) "scout has declared values")
    (assert (> (list-length (.-values planner)) 0) "planner has declared values")
    (assert (> (list-length (.-values impl)) 0) "implementer has declared values")
    (assert (> (list-length (.-values auditor)) 0) "auditor has declared values")
    true))

(df test-steps-pipeline-projection [] -> Bool
  :d "Tests that the standard 5-phase steps and 7-stage epistemic reflection pipelines create valid phases"
  (let [(std-phases (pipe/make-standard-phases "test-task"))
        (epi-phases (pipe/make-epistemic-7-phases "test-task"))]
    (assert (= (list-length std-phases) 5) "standard pipeline creates exactly 5 phases")
    (let [(p1 (option-or (list-head std-phases) (pipe/StepPhase :id "" :name "" :stage "" :gate-command "" :status "" :findings (list))))]
      (assert (= (.-stage p1) "scout") "first standard phase stage is scout"))
    (assert (= (list-length epi-phases) 7) "epistemic pipeline creates exactly 7 stages")
    (let [(e1 (option-or (list-head epi-phases) (pipe/StepPhase :id "" :name "" :stage "" :gate-command "" :status "" :findings (list))))]
      (assert (= (.-stage e1) "s1-ingest") "first epistemic stage is s1-ingest"))
    true))

(df test-gap-audit-contract-projection [] -> Bool
  :d "Tests that GapAuditResult preserves structural invariants"
  (let [(res (pipe/GapAuditResult
               :verdict "approve"
               :omissions (list)
               :bloat-warnings (list)
               :invariants-preserved true
               :recommendations (list "keep minimal")))]
    (assert (.-invariants-preserved res) "gap audit preserves invariants")
    (assert (= (.-verdict res) "approve") "gap audit reports approve verdict")
    true))

(df test-anti-hallucination-projection [] -> Bool
  :d "Tests that anti-hallucination FSM balancer normalizes unclosed delimiters"
  (let [(unbalanced "(:batch (:out \"test.asl\"")
        (balanced (anti/balance-delimiters unbalanced))]
    (assert (string-ends-with? balanced "))") "anti-hallucination auto-balances S-expressions")
    true))

(df run-projection-tests [] -> Bool
  :d "Runs all skills projection verification tests"
  (do
    (test-teleology-mandate-projections)
    (test-steps-pipeline-projection)
    (test-gap-audit-contract-projection)
    (test-anti-hallucination-projection)
    true))

(df run-tests [] -> Bool
  :d "Alias for run-projection-tests"
  (run-projection-tests))
