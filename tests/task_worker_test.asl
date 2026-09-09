(module asl-harness/tests/task-worker-test
  :d "Unit verification test suite for speculative RAM-VFS task worker trajectories and physical receipts"
  :x [test-make-speculative-lane
      test-execute-speculative-lane-isolation
      test-race-lanes-completion
      test-prune-losing-lane
      test-lane-receipt-formatting
      test-guarded-speculative-lane
      run-tests]
  :i [(task_worker :a tw)
      (handoff :a hnd)
      (vfs_fork :a vf)])

(df test-make-speculative-lane [] -> Bool
  :d "Verifies speculative lane construction and initial active status"
  (let [(lane (tw/make-speculative-lane "alpha" 0.2 "fork-alpha-01"))]
    (do
      (assert (= (.-lane-id lane) "alpha") "Lane id must equal alpha")
      (assert (= (.-temp lane) 0.2) "Temperature must equal 0.2")
      (assert (= (.-fork-id lane) "fork-alpha-01") "Fork id must equal fork-alpha-01")
      (assert (.-active lane) "New speculative lane must be active")
      true)))

(df test-execute-speculative-lane-isolation [] -> Bool
  :d "Verifies isolated execution across conservative and exploratory speculative lanes"
  (let [(brief-c (hnd/make-handoff-brief "t-101" "alpha" "worker-conservative" 0.1 "fix leak" 1000))
        (res-c (tw/execute-speculative-lane brief-c "fork-alpha"))
        (brief-e (hnd/make-handoff-brief "t-101" "beta" "worker-exploratory" 0.7 "fix leak" 1000))
        (res-e (tw/execute-speculative-lane brief-e "fork-beta"))]
    (do
      (assert (tw/is-lane-successful? res-c) "Conservative lane must succeed")
      (assert (= (.-exit-code res-c) 0) "Conservative lane exit code must be 0")
      (assert (string-contains? (.-output res-c) "PASS") "Conservative lane output must indicate pass")
      (assert (string-contains? (.-output res-c) ":affirmative-envelope") "Conservative lane must incorporate affirmative envelope")
      (assert (not (tw/is-lane-successful? res-e)) "Exploratory lane must fail")
      (assert (= (.-exit-code res-e) 1) "Exploratory lane exit code must be 1")
      (assert (string-contains? (.-output res-e) "FAIL") "Exploratory lane output must indicate failure")
      true)))

(df test-race-lanes-completion [] -> Bool
  :d "Verifies decisive first-green race and tie-breaking policies"
  (let [(win-a (tw/WorkerLaneResult :lane "alpha" :temp 0.1 :exit-code 0 :output "pass" :mutated-paths (list) :passed true :duration-ms 100))
        (fail-b (tw/WorkerLaneResult :lane "beta" :temp 0.7 :exit-code 1 :output "fail" :mutated-paths (list) :passed false :duration-ms 200))
        (win-b (tw/WorkerLaneResult :lane "beta" :temp 0.7 :exit-code 0 :output "pass" :mutated-paths (list) :passed true :duration-ms 150))
        (fast-a (tw/WorkerLaneResult :lane "alpha" :temp 0.1 :exit-code 0 :output "pass" :mutated-paths (list) :passed true :duration-ms 80))
        (slow-b (tw/WorkerLaneResult :lane "beta" :temp 0.7 :exit-code 0 :output "pass" :mutated-paths (list) :passed true :duration-ms 300))
        (tie-a (tw/WorkerLaneResult :lane "alpha" :temp 0.1 :exit-code 0 :output "pass" :mutated-paths (list) :passed true :duration-ms 100))
        (tie-b (tw/WorkerLaneResult :lane "beta" :temp 0.7 :exit-code 0 :output "pass" :mutated-paths (list) :passed true :duration-ms 100))]
    (do
      (assert (= (.-lane (tw/race-lanes-completion win-a fail-b)) "alpha") "Passing alpha must defeat failing beta")
      (assert (= (.-lane (tw/race-lanes-completion fail-b win-b)) "beta") "Passing beta must defeat failing alpha")
      (assert (= (.-lane (tw/race-lanes-completion fast-a slow-b)) "alpha") "Faster passing lane must win")
      (assert (= (.-lane (tw/race-lanes-completion tie-a tie-b)) "alpha") "Tie breaking must prefer lower temperature")
      true)))

(df test-prune-losing-lane [] -> Bool
  :d "Verifies aborting losing lane VFS branch"
  (let [(branch (vf/VFSBranch :branch-id "branch-loser" :parent-id "root" :created-at-ms 1700000000000 :buffers (list) :status "active"))
        (pruned (tw/prune-losing-lane branch))]
    (do
      (assert (= (.-status pruned) "aborted") "Pruned branch status must be aborted")
      (assert (not (= (.-status pruned) "active")) "Pruned branch status must not be active")
      true)))

(df test-lane-receipt-formatting [] -> Bool
  :d "Verifies physical lane receipt serialization with all required telemetry fields"
  (let [(receipt (tw/LaneReceipt
                   :lane "alpha"
                   :temp 0.2
                   :exit 0
                   :ms 125
                   :rss 48
                   :delta "(:patch \"foo.asl\")"
                   :vfs "fork-alpha-01"))
        (formatted (tw/format-lane-receipt receipt))]
    (do
      (assert (string-contains? formatted ":receipt :lane \"alpha\"") "Receipt must contain lane identifier")
      (assert (string-contains? formatted ":temp 0.2") "Receipt must contain temperature")
      (assert (string-contains? formatted ":exit 0") "Receipt must contain exit code")
      (assert (string-contains? formatted ":ms 125") "Receipt must contain elapsed milliseconds")
      (assert (string-contains? formatted ":rss 48") "Receipt must contain RSS memory")
      (assert (string-contains? formatted ":delta \"(:patch \\\"foo.asl\\\")\"") "Receipt must contain applied delta")
      (assert (string-contains? formatted ":vfs \"fork-alpha-01\"") "Receipt must contain VFS fork identifier")
      true)))

(df test-guarded-speculative-lane [] -> Bool
  :d "Verifies that guarded speculative lane halts when token budget exceeds ceiling"
  (let [(guard (tw/make-default-worker-guardrail))
        (brief-ok (hnd/make-handoff-brief "t-102" "alpha" "worker-conservative" 0.1 "fix leak" 5000))
        (res-ok (tw/execute-guarded-speculative-lane brief-ok "fork-alpha" guard))
        (brief-over (hnd/make-handoff-brief "t-103" "alpha" "worker-conservative" 0.1 "fix leak" 50000))
        (res-over (tw/execute-guarded-speculative-lane brief-over "fork-alpha" guard))]
    (do
      (assert (tw/is-lane-successful? res-ok) "Under-budget guarded lane must succeed")
      (assert (= (.-exit-code res-ok) 0) "Under-budget guarded lane exit code must be 0")
      (assert (not (tw/is-lane-successful? res-over)) "Over-budget guarded lane must fail")
      (assert (= (.-exit-code res-over) 124) "Over-budget guarded lane exit code must be 124")
      (assert (string-contains? (.-output res-over) "exceeded guardrail ceiling") "Output must indicate guardrail ceiling exceeded")
      true)))

(df run-tests [] -> Bool
  :d "Executes all task worker test assertions under strict falsification"
  (do
    (assert (test-make-speculative-lane))
    (assert (test-execute-speculative-lane-isolation))
    (assert (test-race-lanes-completion))
    (assert (test-prune-losing-lane))
    (assert (test-lane-receipt-formatting))
    (assert (test-guarded-speculative-lane))
    true))
