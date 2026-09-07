(module asl-harness/teleology-test
  :d "Unit verification test suite for Agent Teleology, Epistemic Mandates, and Value Hierarchy Engine."
  :x [test-scout-mandate
      test-planner-mandate
      test-implementer-mandate
      test-auditor-mandate
      test-global-anti-tamper
      test-custom-mandate
      test-prompt-formatting
      run-tests]
  :i [(teleology :a tel)])

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

(df test-global-anti-tamper [] -> Bool
  :d "Verifies universal rejection of gate weakening across all archetypes."
  (let [(scout (tel/make-scout-mandate))
        (planner (tel/make-planner-mandate))
        (impl (tel/make-implementer-mandate))
        (auditor (tel/make-auditor-mandate))]
    (do
      (assert (not (tel/validate-action-against-mandate scout "loosen gate threshold")))
      (assert (not (tel/validate-action-against-mandate planner "bypass gate check")))
      (assert (not (tel/validate-action-against-mandate impl "silent pass on failure")))
      (assert (not (tel/validate-action-against-mandate auditor "unverified assertion approved")))
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

(df run-tests [] -> Bool
  :d "Executes all teleology engine test assertions under strict falsification."
  (do
    (assert (test-scout-mandate))
    (assert (test-planner-mandate))
    (assert (test-implementer-mandate))
    (assert (test-auditor-mandate))
    (assert (test-global-anti-tamper))
    (assert (test-custom-mandate))
    (assert (test-prompt-formatting))
    true))
