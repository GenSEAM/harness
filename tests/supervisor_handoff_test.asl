(module asl-harness/supervisor-handoff-test
  :d "Unit verification test suite for multi-agent supervisor, speculative racing, and handoff briefs"
  :x [test-delegation-planning
      test-single-token-briefs
      test-speculative-dual-race
      test-clean-context-adjudication
      test-time-travel-rollback
      run-tests]
  :i [(delegate :a del)
      (handoff :a hnd)
      (task_worker :a tw)
      (supervisor :a sup)
      (vfs_fork :a vf)])

(df test-delegation-planning [] -> Bool
  :d "Verifies delegation mode construction, default temperature bindings, and context slice isolation"
  (let [(plan-race (del/make-delegation-plan "t-001" (del/speculative-race)))
        (plan-single (del/make-delegation-plan "t-002" (del/single)))
        (plan-sup (del/make-delegation-plan "t-003" (del/clean-supervisor)))
        (slices (del/multiplex-context-slices "contract: verify CAS" (list "alpha" "beta")))]
    (do
      (assert (= (.-task-id plan-race) "t-001") "Plan task-id must equal t-001")
      (assert (= (list-length (.-lanes plan-race)) 2) "Speculative race must have exactly 2 lanes")
      (assert (= (list-length (.-temperatures plan-race)) 2) "Speculative race must have 2 temperature bindings")
      (assert (= (list-length (.-lanes plan-single)) 1) "Single worker delegation must have 1 lane")
      (assert (= (list-length (.-lanes plan-sup)) 1) "Clean supervisor delegation must have 1 lane")
      (assert (= (list-length slices) 2) "Multiplexed context slices must produce 2 slices")
      (assert (string-contains? (option-or (list-head slices) "") ":lane \"alpha\"") "First slice must target alpha lane")
      true)))

(df test-single-token-briefs [] -> Bool
  :d "Verifies single-token property keys in handoff briefs, token bounding, and clean audit serialization"
  (let [(brief (hnd/make-handoff-brief "t-100" "alpha" "worker-conservative" 0.1 "optimize inner loop" 2000))
        (asn-brief (hnd/format-brief-asn brief))
        (audit (hnd/make-clean-audit "t-100" "asl check" "alpha" 0 "syntax ok" "" "no diff"))
        (asn-audit (hnd/format-audit-asn audit))]
    (do
      (assert (string-contains? asn-brief ":task \"t-100\"") "Brief ASN must encode single-token :task key")
      (assert (string-contains? asn-brief ":lane \"alpha\"") "Brief ASN must encode single-token :lane key")
      (assert (string-contains? asn-brief ":temp 0.1") "Brief ASN must encode single-token :temp key")
      (assert (string-contains? asn-brief ":budget 2000") "Brief ASN must encode single-token :budget key")
      (assert (<= (+ (/ (string-length asn-brief) 3) 1) 150) "Handoff brief must remain strictly bounded under 150 tokens")
      (assert (string-contains? asn-audit ":receipt \"exit=0") "Clean audit ASN must encode single-token :receipt key")
      (assert (string-contains? asn-audit ":pass true") "Clean audit ASN must encode single-token :pass key")
      true)))

(df test-speculative-dual-race [] -> Bool
  :d "Verifies simultaneous T=0.1 vs T=0.7 lane execution, first-green decisive win, and losing branch pruning"
  (let [(brief-a (hnd/make-handoff-brief "t-200" "alpha" "worker-conservative" 0.1 "fix leak" 1000))
        (res-a (tw/execute-speculative-lane brief-a "fork-alpha"))
        (brief-b (hnd/make-handoff-brief "t-200" "beta" "worker-exploratory" 0.7 "fix leak" 1000))
        (res-b (tw/execute-speculative-lane brief-b "fork-beta"))
        (res-fail (tw/WorkerLaneResult :lane "alpha" :temp 0.1 :exit-code 1 :output "err" :mutated-paths (list) :passed false :duration-ms 200))
        (res-win (tw/WorkerLaneResult :lane "beta" :temp 0.7 :exit-code 0 :output "ok" :mutated-paths (list) :passed true :duration-ms 150))
        (res-fast (tw/WorkerLaneResult :lane "alpha" :temp 0.1 :exit-code 0 :output "ok" :mutated-paths (list) :passed true :duration-ms 100))
        (res-slow (tw/WorkerLaneResult :lane "beta" :temp 0.7 :exit-code 0 :output "ok" :mutated-paths (list) :passed true :duration-ms 300))
        (res-tie-a (tw/WorkerLaneResult :lane "alpha" :temp 0.1 :exit-code 0 :output "ok" :mutated-paths (list) :passed true :duration-ms 100))
        (res-tie-b (tw/WorkerLaneResult :lane "beta" :temp 0.7 :exit-code 0 :output "ok" :mutated-paths (list) :passed true :duration-ms 100))
        (dummy-branch (vf/VFSBranch :branch-id "branch-beta" :parent-id "root" :created-at-ms 1725793200000 :buffers (list) :status "active"))
        (pruned (tw/prune-losing-lane dummy-branch))]
    (do
      (assert (tw/is-lane-successful? res-a) "Conservative lane T=0.1 must succeed cleanly")
      (assert (not (tw/is-lane-successful? res-b)) "Exploratory lane T=0.7 with errors must not pass")
      (assert (= (.-lane (tw/race-lanes-completion res-a res-b)) "alpha") "First-green decisive race must select passing alpha lane")
      (assert (= (.-lane (tw/race-lanes-completion res-fail res-win)) "beta") "First-green decisive race must select passing beta lane")
      (assert (= (.-lane (tw/race-lanes-completion res-fast res-slow)) "alpha") "Fastest passing trajectory must win latency race")
      (assert (= (.-lane (tw/race-lanes-completion res-tie-a res-tie-b)) "alpha") "Deterministic tie-breaking must favor conservative lower temperature")
      (assert (= (.-status pruned) "aborted") "Losing branch must be pruned to aborted status")
      true)))

(df test-clean-context-adjudication [] -> Bool
  :d "Verifies stateless supervisor audit evaluation, objective pass/fail determination, and hint generation"
  (let [(audit-pass (hnd/make-clean-audit "t-300" "asl check" "alpha" 0 "valid" "" "mutated src/foo.asl"))
        (verdict-pass (sup/adjudicate-clean-audit audit-pass))
        (audit-syntax (hnd/make-clean-audit "t-301" "asl check" "beta" 1 "" "syntax error at line 5" ""))
        (verdict-syntax (sup/adjudicate-clean-audit audit-syntax))
        (audit-fail (hnd/make-clean-audit "t-302" "asl test" "alpha" 2 "" "assertion failed: expected 4 got 5" ""))
        (verdict-fail (sup/adjudicate-clean-audit audit-fail))]
    (do
      (assert (= (.-status verdict-pass) "pass") "Passing physical audit must receive pass verdict")
      (assert (= (.-chosen-lane verdict-pass) "alpha") "Passing audit must select candidate lane")
      (assert (= (.-confidence verdict-pass) 1.0) "Clean passing audit must yield 1.0 confidence")
      (assert (= (.-status verdict-syntax) "retry") "Syntax error stderr must produce retry verdict")
      (assert (!= (.-hint verdict-syntax) "") "Retry verdict must supply steering hint")
      (assert (= (.-status verdict-fail) "fail") "Logical assertion failure must produce fail verdict")
      true)))

(df test-time-travel-rollback [] -> Bool
  :d "Verifies atomic CAS checkpoint restoration, state reversion, and prevention of apology loops"
  (let [(st0 (sup/make-supervisor-state))
        (st1 (sup/SupervisorState :active-tasks (list "t-400" "t-401") :checkpoints (.-checkpoints st0) :speculative-enabled true :clean-audit-enabled true))
        (st2 (sup/set-task-checkpoint st1 "t-400" "cas-hash-c0ffee"))
        (st-rolled (sup/rollback-task-state st2 "t-400"))
        (audit-err (hnd/make-clean-audit "t-401" "asl gate" "alpha" 1 "" "timeout after 10000ms" ""))
        (cycle-verdict (sup/run-supervisor-cycle st-rolled audit-err))
        (clean-envelope-str (hnd/format-audit-asn audit-err))]
    (do
      (assert (= (sup/get-task-checkpoint st2 "t-400") "cas-hash-c0ffee") "Registered CAS checkpoint must be recoverable")
      (assert (= (list-length (.-active-tasks st-rolled)) 1) "Rollback must remove failed task from active task list")
      (assert (= (option-or (list-head (.-active-tasks st-rolled)) "") "t-401") "Remaining active task must be preserved")
      (assert (= (.-status cycle-verdict) "retry") "Supervisor cycle must adjudicate timeout receipt into retry")
      (assert (not (string-contains? clean-envelope-str "sorry")) "Clean audit envelope must contain zero conversational apologies")
      (assert (not (string-contains? clean-envelope-str "apologize")) "Clean audit envelope must prevent apology loops")
      true)))

(df run-tests [] -> Bool
  :d "Sequentially executes all 5 supervisor and handoff test suites"
  (and (test-delegation-planning)
       (and (test-single-token-briefs)
            (and (test-speculative-dual-race)
                 (and (test-clean-context-adjudication)
                      (test-time-travel-rollback))))))
