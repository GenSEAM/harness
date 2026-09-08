(module asl-harness/agent-test
  :d "Unit tests for complete Autonomous Coding Agent runtime and Two-Tier Reflection."
  :x [test-agent-init test-agent-turn-fsm-normalization test-agent-turn-firewall-blocking test-agent-task-resolution test-agent-surgical-patch test-agent-phase-transitions test-agent-verification-gate-rejection test-micro-reflection test-macro-reflection-todo test-reflection-ceiling test-agent-reflection-cycle run-tests]
  :i [(agent :a ag) (config :a cfg)])

(df test-agent-init [] -> Bool
  :d "Verifies clean initialization of coding agent state."
  (let [(c (cfg/default-harness-config))
        (state (ag/new-coding-agent "sess-001" "TASK-100" c))]
    (assert (= (.-session-id state) "sess-001") "session-id matches")
    (assert (= (.-task-id state) "TASK-100") "task-id matches")
    (assert (= (.-iteration state) 0) "iteration is 0")
    (assert (not (.-resolved state)) "not resolved on init")
    true))

(df test-agent-turn-fsm-normalization [] -> Bool
  :d "Verifies model output is normalized through FSM normalizer in cognitive turn."
  (let [(c (cfg/default-harness-config))
        (state (ag/new-coding-agent "sess-002" "TASK-101" c))
        (dirty "(defun compute [(x Int64)] (+ x 1")
        (outcome (ag/process-model-turn state dirty))
        (next-st (.-next-state outcome))]
    (assert (= (.-iteration next-st) 1) "iteration incremented")
    (assert (string-contains? (.-normalized-text outcome) "(df compute") "keyword normalized to df")
    (assert (string-contains? (.-normalized-text outcome) ")") "closing paren appended")
    true))

(df test-agent-turn-firewall-blocking [] -> Bool
  :d "Verifies out-of-boundary actions are intercepted and blocked by firewall."
  (let [(c (cfg/default-harness-config))
        (state (ag/new-coding-agent "sess-003" "TASK-102" c))
        (malicious "Read secret file at ../../../etc/shadow")
        (outcome (ag/process-model-turn state malicious))
        (next-st (.-next-state outcome))]
    (assert (= (list-length (.-blocked outcome)) 1) "outcome has 1 blocked action")
    (assert (= (list-length (.-actions-blocked next-st)) 1) "state records 1 blocked action")
    true))

(df test-agent-task-resolution [] -> Bool
  :d "Verifies multi-turn agent loop runs and detects task completion."
  (let [(c (cfg/default-harness-config))
        (state (ag/new-coding-agent "sess-004" "TASK-103" c))
        (turns (list "(df patch [] true)" "Testing patch with REPL" ":task-complete"))
        (final-st (ag/run-agent-task state turns))]
    (assert (.-resolved final-st) "task is resolved")
    (assert (= (.-iteration final-st) 3) "iteration count is 3")
    (assert (string-contains? (ag/agent-summary final-st) "Resolved: YES") "summary confirms resolution")
    true))

(df test-agent-surgical-patch [] -> Bool
  :d "Verifies agent handles surgical ast-patch tool execution."
  (let [(c (cfg/default-harness-config))
        (state (ag/new-coding-agent "sess-005" "TASK-104" c))
        (patch-turn "(:call ast-patch :path \"src/paged.asl\" :symbol \"slice\" :replacement \"(df slice [] true)\")")
        (outcome (ag/process-model-turn state patch-turn))
        (next-st (.-next-state outcome))]
    (assert (= (.-phase next-st) "patch") "phase transitioned to patch")
    (assert (string-contains? (ag/agent-summary next-st) "Phase: patch") "summary contains patch phase")
    true))

(df test-agent-phase-transitions [] -> Bool
  :d "Verifies agent progresses through inspect, plan, patch, and resolved phases."
  (let [(c (cfg/default-harness-config))
        (s0 (ag/new-coding-agent "sess-006" "TASK-105" c))
        (s1 (.-next-state (ag/process-model-turn s0 "(:call fs-read :path \"src/a.asl\")")))
        (s2 (.-next-state (ag/process-model-turn s1 "(:plan inspect bounds, then apply fix)")))
        (s3 (.-next-state (ag/process-model-turn s2 "(:call ast-patch :path \"src/a.asl\")")))
        (s4 (.-next-state (ag/process-model-turn s3 "Task verified cleanly :task-complete")))]
    (assert (= (.-phase s0) "inspect") "s0 phase inspect")
    (assert (= (.-phase s1) "inspect") "s1 phase inspect")
    (assert (= (.-phase s2) "plan") "s2 phase plan")
    (assert (= (.-phase s3) "patch") "s3 phase patch")
    (assert (= (.-phase s4) "resolved") "s4 phase resolved")
    true))

(df test-agent-verification-gate-rejection [] -> Bool
  :d "Verifies completion is rejected when verification gate has no test command, forcing model back to patch."
  (let [(c (cfg/default-harness-config))
        (s-init (ag/new-coding-agent "sess-007" "TASK-106" c))
        (s-no-gate (ag/AgentState
                     :session-id (.-session-id s-init)
                     :task-id (.-task-id s-init)
                     :iteration (.-iteration s-init)
                     :max-iterations (.-max-iterations s-init)
                     :phase (.-phase s-init)
                     :last-error (.-last-error s-init)
                     :config (.-config s-init)
                     :policy (.-policy s-init)
                     :repl-sess (.-repl-sess s-init)
                     :history (.-history s-init)
                     :actions-executed (.-actions-executed s-init)
                     :actions-blocked (.-actions-blocked s-init)
                     :resolved false
                     :test-command ""
                     :reflection-turns 0))
        (outcome (ag/process-model-turn s-no-gate "I claim victory! :task-complete"))
        (next-st (.-next-state outcome))]
    (assert (not (.-resolved next-st)) "not resolved when gate is missing")
    (assert (= (.-phase next-st) "patch") "pushed back to patch phase")
    (assert (string-contains? (.-last-error next-st) ":gate-rejected") "gate-rejected error recorded")
    true))

(df test-micro-reflection [] -> Bool
  :d "Verifies step-level micro-reflection detects errors and clean output."
  (let [(err-report (ag/micro-reflect-step "exec-cmd" "" "Command not found"))
        (clean-report (ag/micro-reflect-step "fs-read" "file content" ""))]
    (assert (string-contains? err-report "failed with error") "error report noted")
    (assert (string-contains? clean-report "executed cleanly") "clean report noted")
    true))

(df test-macro-reflection-todo [] -> Bool
  :d "Verifies macro-reflection flags TODO stubs on turn 0."
  (let [(verdict (ag/macro-reflect-audit "Fix bug" "(df foo [] ; TODO fix" true 0))]
    (assert (not (.-passed verdict)) "audit failed due to TODO")
    (assert (.-needs-fix verdict) "needs-fix flagged")
    (assert (not (.-halt-loop verdict)) "does not halt loop on turn 0")
    (assert (string-contains? (.-reason verdict) "TODO") "reason notes TODO")
    true))

(df test-reflection-ceiling [] -> Bool
  :d "Verifies strict 1-turn limit ceiling halts loop and proceeds with transparent disclosure."
  (let [(verdict (ag/macro-reflect-audit "Fix bug" "(df foo [] ; TODO fix" true 1))]
    (assert (.-passed verdict) "passes under ceiling")
    (assert (not (.-needs-fix verdict)) "needs-fix false under ceiling")
    (assert (.-halt-loop verdict) "halt-loop true under ceiling")
    (assert (string-contains? (.-reason verdict) "1-turn reflection limit") "reason notes limit")
    true))

(df test-agent-reflection-cycle [] -> Bool
  :d "Verifies agent transitions to reflect on turn 0 with TODO, then resolves on turn 1 under ceiling."
  (let [(c (cfg/default-harness-config))
        (s0 (ag/new-coding-agent "sess-008" "TASK-107" c))
        (o1 (ag/process-model-turn s0 "(df fix [] ; TODO finish) :task-complete"))
        (s1 (.-next-state o1))
        (o2 (ag/process-model-turn s1 "Completing remaining work :task-complete"))
        (s2 (.-next-state o2))]
    (assert (= (.-phase s1) "reflect") "s1 in reflect phase")
    (assert (not (.-resolved s1)) "s1 not resolved")
    (assert (= (.-reflection-turns s1) 1) "s1 reflection turns is 1")
    (assert (.-resolved s2) "s2 resolved")
    (assert (= (.-phase s2) "resolved") "s2 in resolved phase")
    true))

(df run-tests [] -> Bool
  :d "Executes full agent test suite including reflection tests."
  (do
    (test-agent-init)
    (test-agent-turn-fsm-normalization)
    (test-agent-turn-firewall-blocking)
    (test-agent-task-resolution)
    (test-agent-surgical-patch)
    (test-agent-phase-transitions)
    (test-agent-verification-gate-rejection)
    (test-micro-reflection)
    (test-macro-reflection-todo)
    (test-reflection-ceiling)
    (test-agent-reflection-cycle)
    true))
