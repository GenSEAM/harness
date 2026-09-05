(module asl-harness/agent-test
  :d "Unit tests for complete Autonomous Coding Agent runtime."
  :x [test-agent-init test-agent-turn-fsm-normalization test-agent-turn-firewall-blocking test-agent-task-resolution test-agent-surgical-patch test-agent-phase-transitions]
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
