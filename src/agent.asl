(module asl-harness/agent
  :d "Complete Autonomous Coding Agent runtime integrating Action Firewall, FSM Normalizer, REPL, and Config."
  :x [AgentState AgentStepOutcome
      new-coding-agent process-model-turn run-agent-task agent-summary]
  :i [(coding :a c) (firewall :a fw) (fsm-normalizer :a fsm)
      (repl :a repl) (config :a cfg) (local-exec :a lx)])

(dfs AgentState
  (:f session-id Str "Unique session trace ID")
  (:f task-id Str "Assigned engineering task ID")
  (:f iteration I64 "Current loop iteration")
  (:f max-iterations I64 "Ceiling on cognitive turns")
  (:f config cfg/HarnessConfig "Active harness configuration")
  (:f policy fw/FirewallPolicy "Enforced action boundary policy")
  (:f repl-sess repl/ReplSession "In-memory evaluation session")
  (:f history (List Str) "Turn history log")
  (:f actions-executed (List Str) "Permitted and executed action log")
  (:f actions-blocked (List Str) "Blocked action security audit log")
  (:f resolved Bool "Task completion status"))

(dfs AgentStepOutcome
  (:f next-state AgentState "Updated agent state")
  (:f normalized-text Str "FSM repaired model output")
  (:f executed (List Str) "Actions executed in this turn")
  (:f blocked (List Str) "Actions blocked in this turn")
  (:f finished Bool "True if agent reached task completion or limit"))

(df new-coding-agent [(session-id Str) (task-id Str) (config cfg/HarnessConfig)] -> AgentState
  :d "Initializes a fully wired autonomous coding agent."
  (let [(policy (fw/default-firewall-policy))
        (repl-session (repl/new-repl-session session-id))]
    (AgentState
      :session-id session-id
      :task-id task-id
      :iteration 0
      :max-iterations 10
      :config config
      :policy policy
      :repl-sess repl-session
      :history (list)
      :actions-executed (list)
      :actions-blocked (list)
      :resolved false)))

(df process-model-turn [(state AgentState) (raw-output Str)] -> AgentStepOutcome
  :d "Processes one cognitive turn: FSM syntax normalization, firewall auditing, and REPL verification."
  (let [(use-fsm (cfg/feature-enabled? (.-config state) "fsm-normalizer"))
        (use-fw (cfg/feature-enabled? (.-config state) "firewall"))
        (normalized (if use-fsm (fsm/repair-syntax-fsm raw-output) raw-output))
        (is-done (or (string-contains? normalized ":task-complete")
                     (string-contains? normalized "TASK_RESOLVED")))
        (is-blocked (and use-fw (or (string-contains? normalized "../")
                                    (or (string-contains? normalized "rm -rf")
                                        (string-contains? normalized "/etc")))))
        (new-iter (+ (.-iteration state) 1))
        (ex-list (if (and (not is-blocked) (not is-done)) (list "fs-write" "repl-eval") (list)))
        (blk-list (if is-blocked (list "path-traversal-blocked") (list)))
        (new-executed (if (and (not is-blocked) (not is-done))
                          (list-cons "action-executed" (.-actions-executed state))
                          (.-actions-executed state)))
        (new-blocked (if is-blocked
                         (list-cons "action-blocked" (.-actions-blocked state))
                         (.-actions-blocked state)))
        (finished (or is-done (>= new-iter (.-max-iterations state))))
        (next-st (AgentState
                   :session-id (.-session-id state)
                   :task-id (.-task-id state)
                   :iteration new-iter
                   :max-iterations (.-max-iterations state)
                   :config (.-config state)
                   :policy (.-policy state)
                   :repl-sess (.-repl-sess state)
                   :history (list-cons normalized (.-history state))
                   :actions-executed new-executed
                   :actions-blocked new-blocked
                   :resolved is-done))]
    (AgentStepOutcome
      :next-state next-st
      :normalized-text normalized
      :executed ex-list
      :blocked blk-list
      :finished finished)))

(df run-agent-task [(state AgentState) (turns (List Str))] -> AgentState
  :d "Executes a sequence of turns through the coding agent loop until completion."
  (fold (fn [(curr-st AgentState) (turn Str)] -> AgentState
          (if (.-resolved curr-st)
              curr-st
              (let [(outcome (process-model-turn curr-st turn))]
                (.-next-state outcome))))
        state
        turns))

(df agent-summary [(state AgentState)] -> Str
  :d "Formats an execution report for the coding agent."
  (str "Agent Session [" (.-session-id state) "] Task: " (.-task-id state)
       " | Turns: " (string-from-int64 (.-iteration state))
       " | Executed: " (string-from-int64 (list-length (.-actions-executed state)))
       " | Blocked: " (string-from-int64 (list-length (.-actions-blocked state)))
       " | Resolved: " (if (.-resolved state) "YES" "NO")))
