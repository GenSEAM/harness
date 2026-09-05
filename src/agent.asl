(module asl-harness/agent
  :d "Complete Autonomous Coding Agent runtime integrating Action Firewall, FSM Normalizer, REPL, Config, Compactor, and Verifier."
  :x [AgentState AgentStepOutcome
      new-coding-agent process-model-turn run-agent-task agent-summary]
  :i [(coding :a c) (firewall :a fw) (fsm-normalizer :a fsm)
      (repl :a repl) (config :a cfg) (local-exec :a lx)
      (compactor :a comp) (verifier :a v)])

(dfs AgentState
  (:f session-id Str "Unique session trace ID")
  (:f task-id Str "Assigned engineering task ID")
  (:f iteration I64 "Current loop iteration")
  (:f max-iterations I64 "Ceiling on cognitive turns")
  (:f phase Str "Current engineering phase: inspect | plan | patch | verify | resolved")
  (:f last-error Str "Diagnostic feedback from previous step")
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
  :d "Initializes a fully wired autonomous coding agent with context compaction."
  (let [(policy (fw/default-firewall-policy))
        (repl-session (repl/new-repl-session session-id))]
    (AgentState
      :session-id session-id
      :task-id task-id
      :iteration 0
      :max-iterations 10
      :phase "inspect"
      :last-error ""
      :config config
      :policy policy
      :repl-sess repl-session
      :history (list)
      :actions-executed (list)
      :actions-blocked (list)
      :resolved false)))

(df derive-next-phase [(text Str) (curr-phase Str) (is-done Bool)] -> Str
  :d "Determines next engineering phase in the agent workflow."
  (cond
    (is-done "resolved")
    ((string-contains? text ":plan") "plan")
    ((or (string-contains? text "ast-patch")
         (or (string-contains? text "str-replace")
             (string-contains? text "fs-write"))) "patch")
    ((or (string-contains? text "exec-cmd")
         (or (string-contains? text "asl test")
             (string-contains? text "pytest"))) "verify")
    ((or (string-contains? text "fs-read") (string-contains? text "ast-search")) "inspect")
    (:else curr-phase)))

(df process-model-turn [(state AgentState) (raw-output Str)] -> AgentStepOutcome
  :d "Processes one cognitive turn: context compaction, FSM syntax normalization, firewall auditing, and diagnostic feedback."
  (let [(use-fsm (cfg/feature-enabled? (.-config state) "fsm-normalizer"))
        (use-fw (cfg/feature-enabled? (.-config state) "firewall"))
        (unfenced (comp/extract-sexpr raw-output))
        (normalized (if use-fsm (fsm/repair-syntax-fsm unfenced) unfenced))
        (is-done (or (string-contains? normalized ":task-complete")
                     (string-contains? normalized "TASK_RESOLVED")))
        (is-blocked (and use-fw (or (string-contains? normalized "../")
                                    (or (string-contains? normalized "rm -rf")
                                        (string-contains? normalized "/etc")))))
        (new-iter (+ (.-iteration state) 1))
        (next-phase (derive-next-phase normalized (.-phase state) is-done))
        (has-patch (or (string-contains? normalized "ast-patch")
                       (string-contains? normalized "str-replace")))
        (ex-list (cond
                   (is-blocked (list))
                   (is-done (list))
                   (has-patch (list "surgical-patch" "repl-eval"))
                   (:else (list "fs-write" "repl-eval"))))
        (blk-list (if is-blocked (list "path-traversal-blocked") (list)))
        (new-executed (if (and (not is-blocked) (not is-done))
                          (list-concat (.-actions-executed state) ex-list)
                          (.-actions-executed state)))
        (new-blocked (if is-blocked
                         (list-cons "action-blocked" (.-actions-blocked state))
                         (.-actions-blocked state)))
        (finished (or is-done (>= new-iter (.-max-iterations state))))
        (compacted-hist (comp/compact-history (list-cons normalized (.-history state)) 2))
        (next-st (AgentState
                   :session-id (.-session-id state)
                   :task-id (.-task-id state)
                   :iteration new-iter
                   :max-iterations (.-max-iterations state)
                   :phase next-phase
                   :last-error ""
                   :config (.-config state)
                   :policy (.-policy state)
                   :repl-sess (.-repl-sess state)
                   :history compacted-hist
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
  :d "Formats an execution report for the coding agent including phase and compaction telemetry."
  (str "Agent Session [" (.-session-id state) "] Task: " (.-task-id state)
       " | Phase: " (.-phase state)
       " | Turns: " (string-from-int64 (.-iteration state))
       " | Executed: " (string-from-int64 (list-length (.-actions-executed state)))
       " | Blocked: " (string-from-int64 (list-length (.-actions-blocked state)))
       " | History Size: " (string-from-int64 (list-length (.-history state)))
       " | Resolved: " (if (.-resolved state) "YES" "NO")))
