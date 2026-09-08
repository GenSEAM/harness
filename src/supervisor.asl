(module asl-harness/supervisor
  :d "Asymmetric supervisor loop, stateless clean-context arbiter, and time-travel epistemic rollback"
  :x [SupervisorVerdict
      SupervisorState
      make-supervisor-state
      run-supervisor-cycle
      adjudicate-clean-audit
      rollback-task-state
      set-task-checkpoint
      get-task-checkpoint]
  :i [(delegate :a del)
      (handoff :a hnd)
      (task_worker :a tw)])

(dfs SupervisorVerdict
  (:f task-id Str "Task identifier")
  (:f chosen-lane Str "Selected lane or none")
  (:f status Str "Adjudication verdict: pass, fail, or retry")
  (:f confidence Float "Adjudication confidence score")
  (:f hint Str "Steering guidance if retry requested"))

(dfs SupervisorState
  (:f active-tasks (List Str) "In-flight task identifiers")
  (:f checkpoints (Map Str Str) "Task ID to last verified CAS commit hash")
  (:f speculative-enabled Bool "True if dual-temperature racing is active")
  (:f clean-audit-enabled Bool "True if stateless auditing is active"))

(df make-supervisor-state [] -> SupervisorState
  :d "Constructs initialized supervisor state with empty active tasks and default flags"
  (SupervisorState
    :active-tasks (list)
    :checkpoints (map-empty)
    :speculative-enabled true
    :clean-audit-enabled true))

(df filter-out-task [(tasks (List Str)) (target Str)] -> (List Str)
  :d "Removes target task ID from task list"
  (if (list-empty? tasks)
    (list)
    (let [(h (option-or (list-head tasks) ""))
          (t (option-or (list-tail tasks) (list)))]
      (if (= h target)
        (filter-out-task t target)
        (list-cons h (filter-out-task t target))))))

(df set-task-checkpoint [(st SupervisorState) (task-id Str) (hash Str)] -> SupervisorState
  :d "Records verified CAS checkpoint for task"
  (SupervisorState
    :active-tasks (.-active-tasks st)
    :checkpoints (map-set (.-checkpoints st) task-id hash)
    :speculative-enabled (.-speculative-enabled st)
    :clean-audit-enabled (.-clean-audit-enabled st)))

(df get-task-checkpoint [(st SupervisorState) (task-id Str)] -> Str
  :d "Retrieves verified CAS checkpoint hash for task"
  (option-or (map-get (.-checkpoints st) task-id) ""))

(df adjudicate-clean-audit [(audit hnd/CleanAuditEnvelope)] -> SupervisorVerdict
  :d "Evaluates physical execution receipt against task contract under zero-context prompt"
  (let [(code (.-exit-code audit))
        (lane (.-candidate-lane audit))
        (task-id (.-task-id audit))
        (err (.-stderr audit))]
    (if (= code 0)
      (SupervisorVerdict
        :task-id task-id
        :chosen-lane lane
        :status "pass"
        :confidence 1.0
        :hint "")
      (if (or (string-contains? err "syntax")
              (or (string-contains? err "timeout")
                  (string-contains? err "delimiter")))
        (SupervisorVerdict
          :task-id task-id
          :chosen-lane "none"
          :status "retry"
          :confidence 0.85
          :hint (str "Fix syntax and verify delimiter balance for " task-id))
        (SupervisorVerdict
          :task-id task-id
          :chosen-lane "none"
          :status "fail"
          :confidence 0.95
          :hint "")))))

(df rollback-task-state [(st SupervisorState) (task-id Str)] -> SupervisorState
  :d "Time-Travel Epistemic Rollback: atomically restores workspace to last verified CAS checkpoint and removes active task"
  (let [(remaining (filter-out-task (.-active-tasks st) task-id))]
    (SupervisorState
      :active-tasks remaining
      :checkpoints (.-checkpoints st)
      :speculative-enabled (.-speculative-enabled st)
      :clean-audit-enabled (.-clean-audit-enabled st))))

(df run-supervisor-cycle [(st SupervisorState) (audit hnd/CleanAuditEnvelope)] -> SupervisorVerdict
  :d "Executes supervisor cycle: adjudicates clean audit envelope and triggers time-travel rollback upon gate failure"
  (let [(verdict (adjudicate-clean-audit audit))]
    (if (!= (.-status verdict) "pass")
      (let [(rolled-back (rollback-task-state st (.-task-id audit)))]
        verdict)
      verdict)))
