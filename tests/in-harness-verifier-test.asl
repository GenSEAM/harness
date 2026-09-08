(module asl-harness/in-harness-verifier-test
  :d "Unit verification test suite for Native In-Harness Steps Verification"
  :x [test-read-only-action-allowed
      test-mutating-action-rejected-without-plan
      test-mutating-action-approved-with-plan
      test-esh-rejection-unexecuted-gate
      test-esh-rejection-failed-gate
      test-turn-completion-approved
      run-in-harness-tests
      run-tests]
  :i [(in-harness-verifier :a ver)])

(df test-read-only-action-allowed [] -> Bool
  :d "Tests that read-only actions are permitted without a pre-registered plan"
  (let [(st (ver/init-turn-state))
        (res (ver/audit-action-precondition st "view_file"))]
    (assert (.-approved res) "read-only action approved")
    true))

(df test-mutating-action-rejected-without-plan [] -> Bool
  :d "Tests that mutating actions are rejected if no plan item has been declared"
  (let [(st (ver/init-turn-state))
        (res (ver/audit-action-precondition st "write_to_file"))]
    (assert (not (.-approved res)) "mutating rejected without plan")
    (assert (string-contains? (.-reason res) "Plan-before-act") "reason contains Plan-before-act")
    true))

(df test-mutating-action-approved-with-plan [] -> Bool
  :d "Tests that mutating actions are allowed once a plan item is registered"
  (let [(st (ver/init-turn-state))
        (st2 (ver/register-plan-item st "item-1" "Add helper function" "asl test test.asl"))
        (res (ver/audit-action-precondition st2 "write_to_file"))]
    (assert (.-approved res) "mutating approved with plan")
    true))

(df test-esh-rejection-unexecuted-gate [] -> Bool
  :d "Tests ESH rejection when agent claims completion without executing verification command"
  (let [(st (ver/init-turn-state))
        (st2 (ver/register-plan-item st "item-1" "Refactor module" "asl test test.asl"))
        (res (ver/validate-turn-completion st2 true))]
    (assert (not (.-approved res)) "unexecuted gate rejected")
    (assert (string-contains? (.-reason res) "never executed") "reason contains never executed")
    true))

(df test-esh-rejection-failed-gate [] -> Bool
  :d "Tests ESH rejection when agent claims completion but gate execution failed"
  (let [(st (ver/init-turn-state))
        (st2 (ver/register-plan-item st "item-1" "Fix bug" "asl test test.asl"))
        (st3 (ver/record-gate-execution st2 "item-1" 1))
        (res (ver/validate-turn-completion st3 true))]
    (assert (not (.-approved res)) "failed gate rejected")
    (assert (string-contains? (.-reason res) "gate failed") "reason contains gate failed")
    true))

(df test-turn-completion-approved [] -> Bool
  :d "Tests approval when all planned items have passing gate execution"
  (let [(st (ver/init-turn-state))
        (st2 (ver/register-plan-item st "item-1" "Fix bug" "asl test test.asl"))
        (st3 (ver/record-gate-execution st2 "item-1" 0))
        (res (ver/validate-turn-completion st3 true))]
    (assert (.-approved res) "turn completion approved")
    (assert (string-contains? (.-reason res) "Turn verified") "reason contains Turn verified")
    true))

(df run-in-harness-tests [] -> Bool
  :d "Runs all in-harness verifier unit test cases"
  (do
    (test-read-only-action-allowed)
    (test-mutating-action-rejected-without-plan)
    (test-mutating-action-approved-with-plan)
    (test-esh-rejection-unexecuted-gate)
    (test-esh-rejection-failed-gate)
    (test-turn-completion-approved)
    true))

(df run-tests [] -> Bool
  :d "Alias for run-in-harness-tests"
  (run-in-harness-tests))
