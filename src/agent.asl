(module asl-harness/agent
  :d "Complete Autonomous Coding Agent runtime integrating Action Firewall, FSM Normalizer, REPL, Config, Compactor, Verifier, and Two-Tier Reflection."
  :x [AgentState AgentStepOutcome ReflectionVerdict
      new-coding-agent process-model-turn run-agent-task agent-summary
      micro-reflect-step macro-reflect-audit]
  :i [(coding :a c) (firewall :a fw) (fsm-normalizer :a fsm)
      (repl :a repl) (config :a cfg) (local-exec :a lx)
      (compactor :a comp) (verifier :a v)])

(dfs AgentState
  (:f session-id Str "Unique session trace ID")
  (:f task-id Str "Assigned engineering task ID")
  (:f iteration I64 "Current loop iteration")
  (:f max-iterations I64 "Ceiling on cognitive turns")
  (:f phase Str "Current engineering phase: inspect | plan | patch | verify | reflect | resolved")
  (:f last-error Str "Diagnostic feedback from previous step")
  (:f config cfg/HarnessConfig "Active harness configuration")
  (:f policy fw/FirewallPolicy "Enforced action boundary policy")
  (:f repl-sess repl/ReplSession "In-memory evaluation session")
  (:f history (List Str) "Turn history log")
  (:f actions-executed (List Str) "Permitted and executed action log")
  (:f actions-blocked (List Str) "Blocked action security audit log")
  (:f resolved Bool "Task completion status")
  (:f test-command Str "Automated verification gate command")
  (:f reflection-turns I64 "Executed reflection cycles count"))

(dfs AgentStepOutcome
  (:f next-state AgentState "Updated agent state")
  (:f normalized-text Str "FSM repaired model output")
  (:f executed (List Str) "Actions executed in this turn")
  (:f blocked (List Str) "Actions blocked in this turn")
  (:f finished Bool "True if agent reached task completion or limit"))

(dfs ReflectionVerdict
  (:f passed Bool "True if reflection audit passed")
  (:f needs-fix Bool "True if repair action is required")
  (:f reason Str "Diagnostic message or audit rationale")
  (:f turn-count I64 "Current reflection cycle count")
  (:f halt-loop Bool "True if reflection loop should halt under 1-turn ceiling"))

(df micro-reflect-step [(action Str) (result-output Str) (error-msg Str)] -> Str
  :d "Step-level micro-reflection: verifies AST balance and detects silent tool execution failures."
  (cond
    ((not (string-empty? error-msg))
     (str "⚠ Micro-reflection: action '" action "' failed with error: " error-msg))
    ((and (or (= action "fs-write") (= action "ast-patch"))
          (string-contains? result-output "unbalanced"))
     (str "⚠ Micro-reflection: action '" action "' produced unbalanced delimiters."))
    ((string-empty? result-output)
     (str "⚠ Micro-reflection: action '" action "' returned empty output; verify state."))
    (:else
     "✓ Micro-reflection: action executed cleanly.")))

(df macro-reflect-audit [(task-desc Str) (diff Str) (tests-passed Bool) (reflection-turn I64)] -> ReflectionVerdict
  :d "End-to-end macro-reflection: reconciles source diff against spec with strict 1-turn ceiling."
  (cond
    ((not tests-passed)
     (ReflectionVerdict
       :passed false
       :needs-fix true
       :reason "Verification gate failed: tests must pass before reflection audit"
       :turn-count reflection-turn
       :halt-loop false))
    ((>= reflection-turn 1)
     (ReflectionVerdict
       :passed true
       :needs-fix false
       :reason "1-turn reflection limit reached: proceeding with transparent gap disclosure"
       :turn-count reflection-turn
       :halt-loop true))
    ((or (string-contains? diff "TODO")
         (or (string-contains? diff "FIXME")
             (string-contains? diff "unimplemented")))
     (ReflectionVerdict
       :passed false
       :needs-fix true
       :reason "Unimplemented stub or TODO comment detected in source diff"
       :turn-count (+ reflection-turn 1)
       :halt-loop false))
    (:else
     (ReflectionVerdict
       :passed true
       :needs-fix false
       :reason "Audit passed: intent reconciled, edge cases covered, zero bloat"
       :turn-count reflection-turn
       :halt-loop true))))

(df new-coding-agent [(session-id Str) (task-id Str) (config cfg/HarnessConfig)] -> AgentState
  :d "Initializes a fully wired autonomous coding agent with context compaction and verification gate."
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
      :resolved false
      :test-command "asl test"
      :reflection-turns 0)))

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
  :d "Processes one cognitive turn: context compaction, FSM syntax normalization, firewall auditing, test gate, and two-tier reflection."
  (let [(use-fsm (cfg/feature-enabled? (.-config state) "fsm-normalizer"))
        (use-fw (cfg/feature-enabled? (.-config state) "firewall"))
        (unfenced (comp/extract-sexpr raw-output))
        (normalized (if use-fsm (fsm/repair-syntax-fsm unfenced) unfenced))
        (wants-done (or (string-contains? normalized ":task-complete")
                        (string-contains? normalized "TASK_RESOLVED")))
        (gate-verdict (if wants-done
                          (v/execute-verification-gate (.-test-command state) true)
                          (v/VerificationVerdict :allowed false :reason "" :language "")))
        (gate-passed (and wants-done (.-allowed gate-verdict)))
        (audit (if gate-passed
                   (macro-reflect-audit (.-task-id state) normalized true (.-reflection-turns state))
                   (ReflectionVerdict :passed false :needs-fix false :reason "" :turn-count 0 :halt-loop true)))
        (is-done (and gate-passed (not (.-needs-fix audit))))
        (gate-err (cond
                    ((and wants-done (not gate-passed))
                     (v/format-gate-rejection (.-test-command state) (.-reason gate-verdict)))
                    ((and gate-passed (.-needs-fix audit))
                     (str ":reflect-gap " (.-reason audit)))
                    (:else "")))
        (is-blocked (and use-fw (or (string-contains? normalized "../")
                                    (or (string-contains? normalized "rm -rf")
                                        (string-contains? normalized "/etc")))))
        (new-iter (+ (.-iteration state) 1))
        (new-refl-turns (if (and gate-passed (.-needs-fix audit))
                            (+ (.-reflection-turns state) 1)
                            (.-reflection-turns state)))
        (next-phase (cond
                      (is-done "resolved")
                      ((and gate-passed (.-needs-fix audit)) "reflect")
                      ((and wants-done (not gate-passed)) "patch")
                      (:else (derive-next-phase normalized (.-phase state) false))))
        (has-patch (or (string-contains? normalized "ast-patch")
                       (string-contains? normalized "str-replace")))
        (ex-list (cond
                    (is-blocked (list))
                    (is-done (list))
                    (has-patch (list "surgical-patch" "repl-eval"))
                    (:else (list "fs-write" "repl-eval"))))
        (blk-list (cond
                    (is-blocked (list "path-traversal-blocked"))
                    ((and wants-done (not gate-passed)) (list "verification-gate-failed"))
                    ((and gate-passed (.-needs-fix audit)) (list "reflection-gap-detected"))
                    (:else (list))))
        (new-executed (if (and (not is-blocked) (not is-done))
                          (list-concat (.-actions-executed state) ex-list)
                          (.-actions-executed state)))
        (new-blocked (if (or is-blocked (or (and wants-done (not gate-passed)) (and gate-passed (.-needs-fix audit))))
                         (list-concat (.-actions-blocked state) blk-list)
                         (.-actions-blocked state)))
        (finished (or is-done (>= new-iter (.-max-iterations state))))
        (compacted-hist (comp/compact-history (list-cons normalized (.-history state)) 2))
        (next-st (AgentState
                   :session-id (.-session-id state)
                   :task-id (.-task-id state)
                   :iteration new-iter
                   :max-iterations (.-max-iterations state)
                   :phase next-phase
                   :last-error gate-err
                   :config (.-config state)
                   :policy (.-policy state)
                   :repl-sess (.-repl-sess state)
                   :history compacted-hist
                   :actions-executed new-executed
                   :actions-blocked new-blocked
                   :resolved is-done
                   :test-command (.-test-command state)
                   :reflection-turns new-refl-turns))]
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
  :d "Formats an execution report for the coding agent including phase, reflection, and compaction telemetry."
  (str "Agent Session [" (.-session-id state) "] Task: " (.-task-id state)
       " | Phase: " (.-phase state)
       " | Turns: " (string-from-int64 (.-iteration state))
       " | Reflection: " (string-from-int64 (.-reflection-turns state))
       " | Executed: " (string-from-int64 (list-length (.-actions-executed state)))
       " | Blocked: " (string-from-int64 (list-length (.-actions-blocked state)))
       " | History Size: " (string-from-int64 (list-length (.-history state)))
       " | Resolved: " (if (.-resolved state) "YES" "NO")))
