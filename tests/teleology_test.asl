(module asl-harness/teleology-test
  :d "Unit verification test suite for Agent Teleology, Epistemic Mandates, and Value Hierarchy Engine."
  :x [test-scout-mandate
      test-planner-mandate
      test-implementer-mandate
      test-auditor-mandate
      test-arbiter-mandate
      test-mandate-tuple
      test-global-anti-tamper
      test-custom-mandate
      test-prompt-formatting
      test-adaptive-dag-replanning
      test-epistemic-primitives
      run-tests]
  :i [(teleology :a tel)
      (steps-pipeline :a sp)])

(df test-scout-mandate [] -> Bool
  :d "Verifies Scout archetype mandate properties and behavioral boundaries."
  (let [(m (tel/make-scout-mandate))
        (vals (.-values m))]
    (do
      (assert (= (.-archetype-id m) "scout"))
      (assert (string-contains? (.-purpose m) "perceptual"))
      (assert (>= (len (.-zone-of-responsibility m)) 4))
      (assert (>= (len (.-out-of-scope m)) 4))
      (assert (>= (len vals) 3))
      (assert (= (.-priority (get vals 0)) 1))
      (assert (= (.-value-name (get vals 0)) "Density & SNR > Verbose Dumps"))
      (assert (tel/validate-action-against-mandate m "extract compact AST outline via asl rpc"))
      (assert (not (tel/validate-action-against-mandate m "dump full file contents into prompt")))
      (assert (not (tel/validate-action-against-mandate m "dump entire file without outline")))
      (assert (not (tel/validate-action-against-mandate m "modify code in place")))
      true)))

(df test-planner-mandate [] -> Bool
  :d "Verifies Planner archetype mandate properties and behavioral boundaries."
  (let [(m (tel/make-planner-mandate))
        (vals (.-values m))]
    (do
      (assert (= (.-archetype-id m) "planner"))
      (assert (string-contains? (.-purpose m) "orchestrator"))
      (assert (>= (len (.-zone-of-responsibility m)) 4))
      (assert (>= (len (.-out-of-scope m)) 4))
      (assert (>= (len vals) 3))
      (assert (= (.-priority (get vals 0)) 1))
      (assert (= (.-value-name (get vals 0)) "Falsifiable Gates & Boundary Truth > Speculative Plans"))
      (assert (tel/validate-action-against-mandate m "decompose phase into atomic items with gate commands"))
      (assert (not (tel/validate-action-against-mandate m "speculative plan without verification gate")))
      (assert (not (tel/validate-action-against-mandate m "plan without gate verification")))
      (assert (not (tel/validate-action-against-mandate m "execute code directly in shell")))
      true)))

(df test-implementer-mandate [] -> Bool
  :d "Verifies Implementer archetype mandate properties and behavioral boundaries."
  (let [(m (tel/make-implementer-mandate))
        (vals (.-values m))]
    (do
      (assert (= (.-archetype-id m) "implementer"))
      (assert (string-contains? (.-purpose m) "atomic delta executor"))
      (assert (>= (len (.-zone-of-responsibility m)) 4))
      (assert (>= (len (.-out-of-scope m)) 4))
      (assert (>= (len vals) 3))
      (assert (= (.-priority (get vals 0)) 1))
      (assert (= (.-value-name (get vals 0)) "Gate Preservation & Zero Weakening > Speed"))
      (assert (tel/validate-action-against-mandate m "apply atomic diff and run item gate"))
      (assert (not (tel/validate-action-against-mandate m "weaken gate assertion to make it pass")))
      (assert (not (tel/validate-action-against-mandate m "skip test case that fails")))
      (assert (not (tel/validate-action-against-mandate m "remove test to pass gate")))
      (assert (not (tel/validate-action-against-mandate m "self-review and declare phase verified")))
      true)))

(df test-auditor-mandate [] -> Bool
  :d "Verifies Auditor archetype mandate properties and behavioral boundaries."
  (let [(m (tel/make-auditor-mandate))
        (vals (.-values m))]
    (do
      (assert (= (.-archetype-id m) "auditor"))
      (assert (string-contains? (.-purpose m) "truth"))
      (assert (>= (len (.-zone-of-responsibility m)) 4))
      (assert (>= (len (.-out-of-scope m)) 4))
      (assert (>= (len vals) 3))
      (assert (= (.-priority (get vals 0)) 1))
      (assert (= (.-value-name (get vals 0)) "Empirical Truth & Falsification > False Consensus"))
      (assert (tel/validate-action-against-mandate m "run verification gate and record receipts"))
      (assert (not (tel/validate-action-against-mandate m "rubber-stamp unverified assertion")))
      (assert (not (tel/validate-action-against-mandate m "approve without running verification gate")))
      (assert (not (tel/validate-action-against-mandate m "write code to fix bug directly")))
      true)))

(df test-arbiter-mandate [] -> Bool
  :d "Verifies Arbiter archetype mandate properties and behavioral boundaries."
  (let [(m (tel/make-arbiter-mandate))
        (vals (.-values m))]
    (do
      (assert (= (.-archetype-id m) "arbiter"))
      (assert (string-contains? (.-purpose m) "supervisor"))
      (assert (>= (len (.-zone-of-responsibility m)) 4))
      (assert (>= (len (.-out-of-scope m)) 4))
      (assert (>= (len vals) 3))
      (assert (= (.-priority (get vals 0)) 1))
      (assert (= (.-value-name (get vals 0)) "Disjoint Authority & Zero Contention"))
      (assert (tel/validate-action-against-mandate m "assign task sub-goal to specialized worker"))
      (assert (not (tel/validate-action-against-mandate m "monolithic execution without delegation")))
      (assert (not (tel/validate-action-against-mandate m "execute code directly in shell")))
      true)))

(df test-global-anti-tamper [] -> Bool
  :d "Verifies universal rejection of gate weakening across all archetypes."
  (let [(scout (tel/make-scout-mandate))
        (planner (tel/make-planner-mandate))
        (impl (tel/make-implementer-mandate))
        (auditor (tel/make-auditor-mandate))
        (arbiter (tel/make-arbiter-mandate))]
    (do
      (assert (not (tel/validate-action-against-mandate scout "loosen gate threshold")))
      (assert (not (tel/validate-action-against-mandate planner "bypass gate check")))
      (assert (not (tel/validate-action-against-mandate impl "silent pass on failure")))
      (assert (not (tel/validate-action-against-mandate auditor "unverified assertion approved")))
      (assert (not (tel/validate-action-against-mandate arbiter "weaken gate threshold")))
      (assert (not (tel/validate-action-against-mandate impl "skip gate execution")))
      true)))

(df test-custom-mandate [] -> Bool
  :d "Verifies custom agent mandate constructor and validation."
  (let [(v1 (tel/ValuePriority :priority 1 :value-name "Safety" :rationale "Prevent catastrophic state"))
        (custom (tel/make-agent-mandate
                  "sentinel"
                  "Continuous security invariant sentinel"
                  (list "audit" "guard")
                  (list "weaken" "bypass")
                  (list v1)
                  "Strictly vigilant and non-interactive"))]
    (do
      (assert (= (.-archetype-id custom) "sentinel"))
      (assert (= (len (.-values custom)) 1))
      (assert (= (.-value-name (get (.-values custom) 0)) "Safety"))
      (assert (tel/validate-action-against-mandate custom "monitor memory metrics"))
      (assert (not (tel/validate-action-against-mandate custom "weaken security rule")))
      true)))

(df test-prompt-formatting [] -> Bool
  :d "Verifies teleological prompt formatting produces compact guidance."
  (let [(scout-p (tel/format-mandate-prompt (tel/make-scout-mandate)))
        (plan-p (tel/format-mandate-prompt (tel/make-planner-mandate)))
        (impl-p (tel/format-mandate-prompt (tel/make-implementer-mandate)))
        (audit-p (tel/format-mandate-prompt (tel/make-auditor-mandate)))]
    (do
      (assert (string-contains? scout-p "Mandate [scout]"))
      (assert (string-contains? scout-p "Primary Invariant: Density & SNR > Verbose Dumps"))
      (assert (string-contains? plan-p "Mandate [planner]"))
      (assert (string-contains? impl-p "Mandate [implementer]"))
      (assert (string-contains? audit-p "Mandate [auditor]"))
      (assert (< (string-length scout-p) 500))
      (assert (< (string-length impl-p) 500))
      true)))

(df test-mandate-tuple [] -> Bool
  :d "Verifies mandate->tuple produces compact S-expression representation."
  (let [(impl-t (tel/mandate->tuple (tel/make-implementer-mandate)))
        (audit-t (tel/mandate->tuple (tel/make-auditor-mandate)))
        (scout-t (tel/mandate->tuple (tel/make-scout-mandate)))
        (plan-t (tel/mandate->tuple (tel/make-planner-mandate)))
        (arb-t (tel/mandate->tuple (tel/make-arbiter-mandate)))]
    (do
      (assert (string-contains? impl-t "(:mandate :id \"implementer\""))
      (assert (string-contains? impl-t ":primary-invariant \"Gate Preservation & Zero Weakening > Speed\""))
      (assert (string-contains? audit-t "(:mandate :id \"auditor\""))
      (assert (string-contains? audit-t ":primary-invariant \"Empirical Truth & Falsification > False Consensus\""))
      (assert (string-contains? scout-t "(:mandate :id \"scout\""))
      (assert (string-contains? plan-t "(:mandate :id \"planner\""))
      (assert (string-contains? arb-t "(:mandate :id \"arbiter\""))
      (assert (< (string-length impl-t) 300))
      (assert (< (string-length audit-t) 300))
      true)))

(df test-adaptive-dag-replanning [] -> Bool
  :d "Verifies dynamic adaptive replanning upon gate failure up to maximum recovery ceiling."
  (let [(cfg (sp/make-adaptive-dag-config 2 true))
        (pipe (sp/create-steps-pipeline "task-test-01" "Implement feature with adaptive fallback" "standard"))]
    (do
      (assert (= (.-max-replan-iterations cfg) 2))
      (assert (= (.-current-replan-count cfg) 0))
      (assert (not (sp/is-replan-exhausted? cfg)))
      (assert (= (.-final-status pipe) "pending"))
      (let [(replan-1 (sp/advance-pipeline-stage-adaptive pipe false "syntax error at line 42" cfg))]
        (assert (= (.-final-status replan-1) "replanning"))
        (assert (= (.-active-stage replan-1) "plan"))
        (assert (> (len (.-phases replan-1)) (len (.-phases pipe)))))
      (let [(exhausted-cfg (sp/AdaptiveDAGConfig :max-replan-iterations 2 :current-replan-count 2 :auto-diagnose true :allow-recovery true))]
        (assert (sp/is-replan-exhausted? exhausted-cfg))
        (let [(failed-pipe (sp/advance-pipeline-stage-adaptive pipe false "unresolvable failure" exhausted-cfg))]
          (assert (= (.-final-status failed-pipe) "failed"))
          (assert (not (.-is-completed failed-pipe)))))
      true)))

(df test-epistemic-primitives [] -> Bool
  :d "Verifies GroundFact, ContextBudget, AdversarialReflect, and ReconcileReality records."
  (let [(gf (sp/record-epistemic-primitive "ground-fact" "harness/src/steps-pipeline.asl" "AST verified"))
        (cb (sp/record-epistemic-primitive "context-budget" "tokens" "SNR 0.82"))
        (ar (sp/record-epistemic-primitive "adversarial-reflect" "diff" "zero gap detected"))
        (rr (sp/record-epistemic-primitive "reconcile-reality" "asl test" "exit 0 verified"))]
    (do
      (assert (= (.-step-type gf) "ground-fact"))
      (assert (.-executed gf))
      (assert (= (.-step-type cb) "context-budget"))
      (assert (= (.-step-type ar) "adversarial-reflect"))
      (assert (= (.-step-type rr) "reconcile-reality"))
      (assert (string-contains? (.-details rr) "exit 0"))
      true)))

(df run-tests [] -> Bool
  :d "Executes all teleology engine test assertions under strict falsification."
  (do
    (assert (test-scout-mandate))
    (assert (test-planner-mandate))
    (assert (test-implementer-mandate))
    (assert (test-auditor-mandate))
    (assert (test-arbiter-mandate))
    (assert (test-mandate-tuple))
    (assert (test-global-anti-tamper))
    (assert (test-custom-mandate))
    (assert (test-prompt-formatting))
    (assert (test-adaptive-dag-replanning))
    (assert (test-epistemic-primitives))
    true))
