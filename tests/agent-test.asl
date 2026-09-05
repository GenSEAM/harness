(module asl-harness/agent-test
  :d "Unit tests for complete Autonomous Coding Agent runtime and Two-Tier Reflection."
  :x [test-agent-init test-agent-turn-fsm-normalization test-agent-turn-firewall-blocking test-agent-task-resolution test-agent-surgical-patch test-agent-phase-transitions test-agent-verification-gate-rejection test-micro-reflection test-macro-reflection-todo test-reflection-ceiling test-agent-reflection-cycle run-tests]
  :i [(agent :a ag) (config :a cfg)])

(df test-agent-init [] -> Bool
  :d "Verifies clean initialization of coding agent state."
  (let [(c (cfg/default-harness-config))
        (state (ag/new-coding-agent "sess-001" "TASK-100" c))]
    (and (= (.-session-id state) "sess-001")
         (= (.-task-id state) "TASK-100")
         (= (.-iteration state) 0)
         (not (.-resolved state)))))

(df test-agent-turn-fsm-normalization [] -> Bool
  :d "Verifies model output is normalized through FSM normalizer in cognitive turn."
  (let [(c (cfg/default-harness-config))
        (state (ag/new-coding-agent "sess-002" "TASK-101" c))
        (dirty "(defun compute [(x Int64)] (+ x 1")
        (outcome (ag/process-model-turn state dirty))
        (next-st (.-next-state outcome))]
    (and (= (.-iteration next-st) 1)
         (string-contains? (.-normalized-text outcome) "(df compute")
         (string-contains? (.-normalized-text outcome) ")"))))

(df test-agent-turn-firewall-blocking [] -> Bool
  :d "Verifies out-of-boundary actions are intercepted and blocked by firewall."
  (let [(c (cfg/default-harness-config))
        (state (ag/new-coding-agent "sess-003" "TASK-102" c))
        (malicious "Read secret file at ../../../etc/shadow")
        (outcome (ag/process-model-turn state malicious))
        (next-st (.-next-state outcome))]
    (and (= (list-length (.-blocked outcome)) 1)
         (= (list-length (.-actions-blocked next-st)) 1))))

(df test-agent-task-resolution [] -> Bool
  :d "Verifies multi-turn agent loop runs and detects task completion."
  (let [(c (cfg/default-harness-config))
        (state (ag/new-coding-agent "sess-004" "TASK-103" c))
        (turns (list "(df patch [] true)" "Testing patch with REPL" ":task-complete"))
        (final-st (ag/run-agent-task state turns))]
    (and (.-resolved final-st)
         (= (.-iteration final-st) 3)
         (string-contains? (ag/agent-summary final-st) "Resolved: YES"))))

(df test-agent-surgical-patch [] -> Bool
  :d "Verifies agent handles surgical ast-patch tool execution."
  (let [(c (cfg/default-harness-config))
        (state (ag/new-coding-agent "sess-005" "TASK-104" c))
        (patch-turn "(:call ast-patch :path \"src/paged.asl\" :symbol \"slice\" :replacement \"(df slice [] true)\")")
        (outcome (ag/process-model-turn state patch-turn))
        (next-st (.-next-state outcome))]
    (and (= (.-phase next-st) "patch")
         (string-contains? (ag/agent-summary next-st) "Phase: patch"))))

(df test-agent-phase-transitions [] -> Bool
  :d "Verifies agent progresses through inspect, plan, patch, and resolved phases."
  (let [(c (cfg/default-harness-config))
        (s0 (ag/new-coding-agent "sess-006" "TASK-105" c))
        (s1 (.-next-state (ag/process-model-turn s0 "(:call fs-read :path \"src/a.asl\")")))
        (s2 (.-next-state (ag/process-model-turn s1 "(:plan inspect bounds, then apply fix)")))
        (s3 (.-next-state (ag/process-model-turn s2 "(:call ast-patch :path \"src/a.asl\")")))
        (s4 (.-next-state (ag/process-model-turn s3 "Task verified cleanly :task-complete")))]
    (and (= (.-phase s0) "inspect")
         (and (= (.-phase s1) "inspect")
              (and (= (.-phase s2) "plan")
                   (and (= (.-phase s3) "patch")
                        (= (.-phase s4) "resolved")))))))

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
    (and (not (.-resolved next-st))
         (and (= (.-phase next-st) "patch")
              (string-contains? (.-last-error next-st) ":gate-rejected")))))

(df test-micro-reflection [] -> Bool
  :d "Verifies step-level micro-reflection detects errors and clean output."
  (let [(err-report (ag/micro-reflect-step "exec-cmd" "" "Command not found"))
        (clean-report (ag/micro-reflect-step "fs-read" "file content" ""))]
    (and (string-contains? err-report "failed with error")
         (string-contains? clean-report "executed cleanly"))))

(df test-macro-reflection-todo [] -> Bool
  :d "Verifies macro-reflection flags TODO stubs on turn 0."
  (let [(verdict (ag/macro-reflect-audit "Fix bug" "(df foo [] ; TODO fix" true 0))]
    (and (not (.-passed verdict))
         (.-needs-fix verdict)
         (not (.-halt-loop verdict))
         (string-contains? (.-reason verdict) "TODO"))))

(df test-reflection-ceiling [] -> Bool
  :d "Verifies strict 1-turn limit ceiling halts loop and proceeds with transparent disclosure."
  (let [(verdict (ag/macro-reflect-audit "Fix bug" "(df foo [] ; TODO fix" true 1))]
    (and (.-passed verdict)
         (not (.-needs-fix verdict))
         (.-halt-loop verdict)
         (string-contains? (.-reason verdict) "1-turn reflection limit"))))

(df test-agent-reflection-cycle [] -> Bool
  :d "Verifies agent transitions to reflect on turn 0 with TODO, then resolves on turn 1 under ceiling."
  (let [(c (cfg/default-harness-config))
        (s0 (ag/new-coding-agent "sess-008" "TASK-107" c))
        (o1 (ag/process-model-turn s0 "(df fix [] ; TODO finish) :task-complete"))
        (s1 (.-next-state o1))
        (o2 (ag/process-model-turn s1 "Completing remaining work :task-complete"))
        (s2 (.-next-state o2))]
    (and (= (.-phase s1) "reflect")
         (not (.-resolved s1))
         (= (.-reflection-turns s1) 1)
         (.-resolved s2)
         (= (.-phase s2) "resolved"))))

(df run-tests [] -> Bool
  :d "Executes full agent test suite including reflection tests."
  (and (test-agent-init)
       (and (test-agent-turn-fsm-normalization)
            (and (test-agent-turn-firewall-blocking)
                 (and (test-agent-task-resolution)
                      (and (test-agent-surgical-patch)
                           (and (test-agent-phase-transitions)
                                (and (test-agent-verification-gate-rejection)
                                     (and (test-micro-reflection)
                                          (and (test-macro-reflection-todo)
                                               (and (test-reflection-ceiling)
                                                    (test-agent-reflection-cycle))))))))))))
