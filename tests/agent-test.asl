(module asl-harness/agent-test
  :d "Unit tests for complete Autonomous Coding Agent runtime."
  :x [test-agent-init test-agent-turn-fsm-normalization test-agent-turn-firewall-blocking test-agent-task-resolution]
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
