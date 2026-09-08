(module asl-harness/worker-test
  :d "Unit verification test suite for Autonomous Multi-Session Implementer Loop."
  :x [test-process-receipt-structure
      test-process-receipt-token-ceiling
      test-process-receipt-error-summary
      test-worker-config-init
      test-worker-state-lifecycle
      test-path-in-boundaries-matching
      test-path-in-boundaries-prefix
      test-path-in-boundaries-rejected
      test-work-item-creation
      test-phase-record-creation
      test-phase-polling-claimed-lease
      test-phase-polling-claimed-status
      test-phase-polling-empty
      test-sequential-execution-all-pass
      test-sequential-execution-early-halt
      test-blast-radius-within-boundaries
      test-blast-radius-external-violation
      test-pre-commit-safety-audit
      test-pre-commit-safety-blocked-by-blast
      test-pre-commit-safety-blocked-by-gate
      test-commit-phase-diff-success
      test-commit-phase-diff-rejected
      test-worker-step-complete-success
      test-worker-step-item-failure
      test-worker-step-idle
      test-run-worker-loop-bounded
      test-diagnostic-receipt
      run-tests]
  :i [(worker :a w)])

(df test-process-receipt-structure [] -> Bool
  :d "Verifies ProcessReceipt record construction, field access, and initialization."
  (let [(r (w/make-process-receipt 0 42 16 "/tmp/spool_1.log" "Gate passed cleanly"))]
    (do
      (assert (= (.-exit-code r) 0))
      (assert (= (.-duration-ms r) 42))
      (assert (= (.-peak-rss-mb r) 16))
      (assert (= (.-spool-path r) "/tmp/spool_1.log"))
      (assert (= (.-summary r) "Gate passed cleanly"))
      (assert (> (.-tokens r) 0))
      true)))

(df test-process-receipt-token-ceiling [] -> Bool
  :d "Verifies that rendered ProcessReceipt stays strictly under 80 BPE tokens (ADR d-0005)."
  (let [(r (w/make-process-receipt 0 85 24 "/tmp/spool_gate.log" "All 4 plan item gates evaluated and passed cleanly"))
        (rendered (w/render-process-receipt r))
        (toks (w/estimate-receipt-tokens rendered))]
    (do
      (assert (< toks 80))
      (assert (> toks 0))
      (assert (string-contains? rendered ":receipt"))
      (assert (string-contains? rendered ":exit 0"))
      (assert (string-contains? rendered ":ms 85"))
      true)))

(df test-process-receipt-error-summary [] -> Bool
  :d "Verifies ProcessReceipt with non-zero exit code stays compact and records failure."
  (let [(r (w/make-process-receipt 1 120 30 "/tmp/fail.log" "Gate failed with exit code 1: asl test"))]
    (do
      (assert (= (.-exit-code r) 1))
      (assert (< (.-tokens r) 80))
      (assert (string-contains? (.-summary r) "Gate failed"))
      true)))

(df test-worker-config-init [] -> Bool
  :d "Verifies WorkerConfig constructor and parameter bindings."
  (let [(owns (list "harness/src/worker.asl" "harness/tests/worker_test.asl"))
        (cfg (w/make-worker-config "worker-daemon-test" true 5 250 owns))]
    (do
      (assert (= (.-agent-id cfg) "worker-daemon-test"))
      (assert (.-continuous cfg))
      (assert (= (.-max-cycles cfg) 5))
      (assert (= (.-idle-interval-ms cfg) 250))
      (assert (.-strict-gates cfg))
      (assert (= (list-length (.-owns-boundaries cfg)) 2))
      true)))

(df test-worker-state-lifecycle [] -> Bool
  :d "Verifies initial clean WorkerState lifecycle state."
  (let [(cfg (w/make-worker-config "worker-daemon-1" false 1 500 (list "harness/src/worker.asl")))
        (st (w/init-worker-state cfg))]
    (do
      (assert (= (.-status st) "idle"))
      (assert (= (.-cycle-count st) 0))
      (assert (= (.-active-phase-id st) ""))
      (assert (list-empty? (.-completed-phases st)))
      (assert (list-empty? (.-receipts st)))
      (assert (= (.-last-error st) ""))
      true)))

(df test-path-in-boundaries-matching [] -> Bool
  :d "Verifies exact match path boundary check."
  (let [(bounds (list "harness/src/worker.asl" "harness/grammar.asn"))]
    (do
      (assert (w/path-in-boundaries? "harness/src/worker.asl" bounds))
      (assert (w/path-in-boundaries? "harness/grammar.asn" bounds))
      true)))

(df test-path-in-boundaries-prefix [] -> Bool
  :d "Verifies prefix path boundary check."
  (let [(bounds (list "harness/src/" "harness/tests/"))]
    (do
      (assert (w/path-in-boundaries? "harness/src/worker.asl" bounds))
      (assert (w/path-in-boundaries? "harness/tests/worker_test.asl" bounds))
      true)))

(df test-path-in-boundaries-rejected [] -> Bool
  :d "Verifies rejection of paths outside declared boundaries."
  (let [(bounds (list "harness/src/worker.asl"))]
    (do
      (assert (not (w/path-in-boundaries? "agent-bus/src/ambient.asl" bounds)))
      (assert (not (w/path-in-boundaries? "mem/src/engine.asl" bounds)))
      true)))

(df test-work-item-creation [] -> Bool
  :d "Verifies WorkItem record constructor."
  (let [(item (w/make-work-item "item-1" "Worker Loop" "pending" "asl test worker_test.asl"))]
    (do
      (assert (= (.-id item) "item-1"))
      (assert (= (.-name item) "Worker Loop"))
      (assert (= (.-status item) "pending"))
      (assert (= (.-gate item) "asl test worker_test.asl"))
      true)))

(df test-phase-record-creation [] -> Bool
  :d "Verifies PhaseRecord constructor and work item aggregation."
  (let [(it1 (w/make-work-item "item-1" "Item 1" "pending" "asl test"))
        (it2 (w/make-work-item "item-2" "Item 2" "pending" "asl gate"))
        (phase (w/make-phase-record "phase-298" "Autonomous Worker" "pending" "Wave E" "asl gate" (list it1 it2)))]
    (do
      (assert (= (.-id phase) "phase-298"))
      (assert (= (.-name phase) "Autonomous Worker"))
      (assert (= (.-status phase) "pending"))
      (assert (= (.-wave phase) "Wave E"))
      (assert (= (list-length (.-items phase)) 2))
      true)))

(df test-phase-polling-claimed-lease [] -> Bool
  :d "Verifies polling returns phase locked by active worker lease."
  (let [(it (w/make-work-item "item-1" "Loop" "pending" "asl test"))
        (phase (w/make-phase-record "phase-298" "Worker" "claimed" "Wave E" "asl gate" (list it)))
        (lease (w/make-lease-record "phase-298" "worker-daemon-1" 1000 60000))
        (rm (w/RoadmapRecord :iteration "iter-42" :phases (list phase) :leases (list lease) :version 1))
        (polled (w/poll-claimed-phase rm "worker-daemon-1"))]
    (mt polled
      ((some p) (do (assert (= (.-id p) "phase-298")) true))
      ((none) (do (assert false) false)))))

(df test-phase-polling-claimed-status [] -> Bool
  :d "Verifies polling returns phase in claimed or pending status without explicit lease."
  (let [(it (w/make-work-item "item-1" "Loop" "pending" "asl test"))
        (phase (w/make-phase-record "phase-298" "Worker" "claimed" "Wave E" "asl gate" (list it)))
        (rm (w/RoadmapRecord :iteration "iter-42" :phases (list phase) :leases (list) :version 1))
        (polled (w/poll-claimed-phase rm "worker-daemon-2"))]
    (mt polled
      ((some p) (do (assert (= (.-id p) "phase-298")) true))
      ((none) (do (assert false) false)))))

(df test-phase-polling-empty [] -> Bool
  :d "Verifies polling returns none when roadmap has zero ready or claimed phases."
  (let [(it (w/make-work-item "item-1" "Loop" "completed" "asl test"))
        (phase (w/make-phase-record "phase-297" "Prior" "completed" "Wave E" "asl gate" (list it)))
        (rm (w/RoadmapRecord :iteration "iter-42" :phases (list phase) :leases (list) :version 1))
        (polled (w/poll-claimed-phase rm "worker-daemon-1"))]
    (mt polled
      ((some _) (do (assert false) false))
      ((none) true))))

(df test-sequential-execution-all-pass [] -> Bool
  :d "Verifies that sequential execution processes all items when gates pass."
  (let [(it1 (w/make-work-item "item-1" "Step 1" "pending" "gate-1"))
        (it2 (w/make-work-item "item-2" "Step 2" "pending" "gate-2"))
        (it3 (w/make-work-item "item-3" "Step 3" "pending" "gate-3"))
        (res (w/execute-phase-items (list it1 it2 it3) (list 0 0 0)))]
    (do
      (assert (.-all-passed res))
      (assert (= (.-executed-count res) 3))
      (assert (= (.-failed-item-id res) ""))
      (assert (= (list-length (.-receipts res)) 3))
      true)))

(df test-sequential-execution-early-halt [] -> Bool
  :d "Verifies that sequential execution halts immediately on first gate failure."
  (let [(it1 (w/make-work-item "item-1" "Step 1" "pending" "gate-1"))
        (it2 (w/make-work-item "item-2" "Step 2" "pending" "gate-2"))
        (it3 (w/make-work-item "item-3" "Step 3" "pending" "gate-3"))
        (res (w/execute-phase-items (list it1 it2 it3) (list 0 1 0)))]
    (do
      (assert (not (.-all-passed res)))
      (assert (= (.-executed-count res) 2))
      (assert (= (.-failed-item-id res) "item-2"))
      (assert (= (list-length (.-receipts res)) 2))
      true)))

(df test-blast-radius-within-boundaries [] -> Bool
  :d "Verifies blast-radius guard approves changes strictly within declared owns."
  (let [(affected (list "harness/src/worker.asl" "harness/tests/worker_test.asl"))
        (owns (list "harness/src/worker.asl" "harness/tests/worker_test.asl" "asl/asl"))
        (guard (w/verify-blast-radius (list "worker") affected owns))]
    (do
      (assert (.-is-safe guard))
      (assert (list-empty? (.-violations guard)))
      (assert (string-contains? (.-details guard) "zero boundary violations"))
      true)))

(df test-blast-radius-external-violation [] -> Bool
  :d "Verifies blast-radius guard intercepts mutations outside declared owns boundaries."
  (let [(affected (list "harness/src/worker.asl" "mem/src/engine.asl"))
        (owns (list "harness/src/worker.asl" "harness/tests/worker_test.asl"))
        (guard (w/verify-blast-radius (list "worker") affected owns))]
    (do
      (assert (not (.-is-safe guard)))
      (assert (= (list-length (.-violations guard)) 1))
      (assert (string-contains? (.-details guard) "Blast-radius violation"))
      true)))

(df test-pre-commit-safety-audit [] -> Bool
  :d "Verifies pre-commit safety audit approves when blast-radius is clean and gates passed."
  (let [(guard (w/BlastRadiusGuard :is-safe true :violations (list) :affected-symbols (list) :details "Clean"))]
    (do
      (assert (w/audit-pre-commit-safety guard true true))
      true)))

(df test-pre-commit-safety-blocked-by-blast [] -> Bool
  :d "Verifies pre-commit safety audit blocks commit when blast-radius violations exist."
  (let [(guard (w/BlastRadiusGuard :is-safe false :violations (list "mem/engine.asl") :affected-symbols (list) :details "Violation"))]
    (do
      (assert (not (w/audit-pre-commit-safety guard true true)))
      true)))

(df test-pre-commit-safety-blocked-by-gate [] -> Bool
  :d "Verifies pre-commit safety audit blocks commit when phase gate failed."
  (let [(guard (w/BlastRadiusGuard :is-safe true :violations (list) :affected-symbols (list) :details "Clean"))]
    (do
      (assert (not (w/audit-pre-commit-safety guard true false)))
      (assert (not (w/audit-pre-commit-safety guard false true)))
      true)))

(df test-commit-phase-diff-success [] -> Bool
  :d "Verifies clean phase commit records receipts and marks phase completed."
  (let [(cfg (w/make-worker-config "worker-1" false 1 500 (list "harness/src/worker.asl")))
        (st (w/init-worker-state cfg))
        (guard (w/BlastRadiusGuard :is-safe true :violations (list) :affected-symbols (list) :details "Clean"))
        (res (w/commit-phase-diff st guard "phase-298" 0))]
    (do
      (assert (= (.-status res) "committed"))
      (assert (= (list-length (.-completed-phases res)) 1))
      (assert (= (list-length (.-receipts res)) 1))
      (assert (= (.-last-error res) ""))
      true)))

(df test-commit-phase-diff-rejected [] -> Bool
  :d "Verifies phase commit rejects with failure status on boundary violation."
  (let [(cfg (w/make-worker-config "worker-1" false 1 500 (list "harness/src/worker.asl")))
        (st (w/init-worker-state cfg))
        (guard (w/BlastRadiusGuard :is-safe false :violations (list "intel/src/intel.asl") :affected-symbols (list) :details "Boundary violation"))
        (res (w/commit-phase-diff st guard "phase-298" 0))]
    (do
      (assert (= (.-status res) "failed"))
      (assert (list-empty? (.-completed-phases res)))
      (assert (string-contains? (.-last-error res) "Boundary violation"))
      true)))

(df test-worker-step-complete-success [] -> Bool
  :d "Verifies single worker step end-to-end execution resulting in committed phase."
  (let [(cfg (w/make-worker-config "worker-1" false 1 500 (list "harness/src/worker.asl")))
        (st (w/init-worker-state cfg))
        (it (w/make-work-item "item-1" "Step 1" "pending" "gate-1"))
        (phase (w/make-phase-record "phase-298" "Autonomous" "claimed" "Wave E" "asl gate" (list it)))
        (rm (w/RoadmapRecord :iteration "iter-1" :phases (list phase) :leases (list) :version 1))
        (outcome (w/worker-step st rm (list 0) (list "harness/src/worker.asl") 0))]
    (do
      (assert (.-all-passed outcome))
      (assert (= (.-action outcome) "committed"))
      (assert (= (.-phase-id outcome) "phase-298"))
      (assert (= (.-status (.-worker-state outcome)) "committed"))
      true)))

(df test-worker-step-item-failure [] -> Bool
  :d "Verifies worker step transitions to failed state when an item gate fails."
  (let [(cfg (w/make-worker-config "worker-1" false 1 500 (list "harness/src/worker.asl")))
        (st (w/init-worker-state cfg))
        (it (w/make-work-item "item-1" "Step 1" "pending" "gate-1"))
        (phase (w/make-phase-record "phase-298" "Autonomous" "claimed" "Wave E" "asl gate" (list it)))
        (rm (w/RoadmapRecord :iteration "iter-1" :phases (list phase) :leases (list) :version 1))
        (outcome (w/worker-step st rm (list 1) (list "harness/src/worker.asl") 0))]
    (do
      (assert (not (.-all-passed outcome)))
      (assert (= (.-action outcome) "failed"))
      (assert (= (.-status (.-worker-state outcome)) "failed"))
      (assert (string-contains? (.-last-error (.-worker-state outcome)) "item-1"))
      true)))

(df test-worker-step-idle [] -> Bool
  :d "Verifies worker step remains idle when no phases are claimed."
  (let [(cfg (w/make-worker-config "worker-1" false 1 500 (list "harness/src/worker.asl")))
        (st (w/init-worker-state cfg))
        (rm (w/RoadmapRecord :iteration "iter-1" :phases (list) :leases (list) :version 1))
        (outcome (w/worker-step st rm (list) (list) 0))]
    (do
      (assert (.-all-passed outcome))
      (assert (= (.-action outcome) "idle"))
      (assert (= (.-status (.-worker-state outcome)) "idle"))
      true)))

(df test-run-worker-loop-bounded [] -> Bool
  :d "Verifies run-worker-loop terminates safely when bounded."
  (let [(cfg (w/make-worker-config "worker-1" false 2 500 (list "harness/src/worker.asl")))
        (st (w/init-worker-state cfg))
        (rm (w/RoadmapRecord :iteration "iter-1" :phases (list) :leases (list) :version 1))
        (final-st (w/run-worker-loop st rm 3))]
    (do
      (assert (= (.-status final-st) "idle"))
      (assert (> (.-cycle-count final-st) 0))
      true)))

(df test-diagnostic-receipt [] -> Bool
  :d "Verifies ERR_STRING_NOT_FOUND structured diagnostic receipt formatting and fields"
  (let [(diag (w/emit-string-not-found-receipt "(:old-fn)" "(:old-fn-def)" "src/main.asl"))
        (rendered (w/format-diagnostic-receipt diag))]
    (do
      (assert (= (.-code diag) "ERR_STRING_NOT_FOUND") "Diagnostic code must be ERR_STRING_NOT_FOUND")
      (assert (= (.-failed-seek diag) "(:old-fn)") "Failed seek must match")
      (assert (= (.-hint diag) "(:old-fn-def)") "Hint must match")
      (assert (string-contains? (.-action diag) ":read") "Action must recommend targeted read")
      (assert (string-contains? rendered ":diagnostic :code :ERR_STRING_NOT_FOUND") "Rendered must have diagnostic code")
      (assert (string-contains? rendered ":failed-seek \"(:old-fn)\"") "Rendered must have failed-seek")
      (assert (string-contains? rendered ":hint \"(:old-fn-def)\"") "Rendered must have hint")
      true)))

(df run-tests [] -> Bool
  :d "Executes all worker engine and blast-radius guard test assertions under strict falsification."
  (do
    (assert (test-process-receipt-structure) "t1: receipt structure")
    (assert (test-process-receipt-token-ceiling) "t2: token ceiling")
    (assert (test-process-receipt-error-summary) "t3: error summary")
    (assert (test-worker-config-init) "t4: config init")
    (assert (test-worker-state-lifecycle) "t5: state lifecycle")
    (assert (test-path-in-boundaries-matching) "t6: boundaries match")
    (assert (test-path-in-boundaries-prefix) "t7: boundaries prefix")
    (assert (test-path-in-boundaries-rejected) "t8: boundaries rejected")
    (assert (test-work-item-creation) "t9: work item")
    (assert (test-phase-record-creation) "t10: phase record")
    (assert (test-phase-polling-claimed-lease) "t11: poll lease")
    (assert (test-phase-polling-claimed-status) "t12: poll status")
    (assert (test-phase-polling-empty) "t13: poll empty")
    (assert (test-sequential-execution-all-pass) "t14: seq all pass")
    (assert (test-sequential-execution-early-halt) "t15: seq early halt")
    (assert (test-blast-radius-within-boundaries) "t16: blast safe")
    (assert (test-blast-radius-external-violation) "t17: blast violation")
    (assert (test-pre-commit-safety-audit) "t18: precommit audit")
    (assert (test-pre-commit-safety-blocked-by-blast) "t19: audit blast block")
    (assert (test-pre-commit-safety-blocked-by-gate) "t20: audit gate block")
    (assert (test-commit-phase-diff-success) "t21: commit success")
    (assert (test-commit-phase-diff-rejected) "t22: commit rejected")
    (assert (test-worker-step-complete-success) "t23: worker step success")
    (assert (test-worker-step-item-failure) "t24: worker step failure")
    (assert (test-worker-step-idle) "t25: worker step idle")
    (assert (test-run-worker-loop-bounded) "t26: worker loop")
    (assert (test-diagnostic-receipt) "t27: diagnostic receipt")
    true))
