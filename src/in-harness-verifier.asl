(module asl-harness/in-harness-verifier
  :d "Native In-Harness Steps Verification & Execution Simulation Hallucination (ESH) Grounding"
  :x [PlanGateItem
      HarnessTurnState
      VerificationResult
      init-turn-state
      register-plan-item
      record-gate-execution
      validate-turn-completion
      audit-action-precondition
      format-verification-feedback]
  :i [(core/strings :a s)])

(dfs PlanGateItem
  (:f id Str "Unique plan item identifier e.g. item-1")
  (:f description Str "Summary of intended code mutation")
  (:f verification-command Str "Shell command or gate script that must pass")
  (:f executed Bool "True if verification command was executed in turn")
  (:f passed Bool "True if gate exited with returncode 0"))

(dfs HarnessTurnState
  (:f planned-items (List PlanGateItem) "Queue of declared plan items")
  (:f mutating-actions-count I64 "Number of state-mutating actions executed")
  (:f esh-violations (List Str) "Recorded simulated execution claims without execution")
  (:f is-turn-grounded Bool "True if all mutating actions are backed by plans and gates"))

(dfs VerificationResult
  (:f approved Bool "True if action or completion claim is verified and allowed")
  (:f reason Str "Diagnostic message explaining approval or rejection")
  (:f feedback Str "Actionable feedback for agent self-correction"))

(df init-turn-state [] -> HarnessTurnState
  :d "Initializes clean turn state for in-harness verification."
  (HarnessTurnState
    :planned-items (list)
    :mutating-actions-count 0
    :esh-violations (list)
    :is-turn-grounded true))

(df is-mutating-action? [(action-kind Str)] -> Bool
  :d "Classifies if an action mutates workspace state."
  (or (= action-kind "write_to_file")
      (or (= action-kind "replace_file_content")
          (or (= action-kind "apply_patch")
              (or (= action-kind "execute_bash")
                  (= action-kind "git_commit"))))))

(df register-plan-item [(state HarnessTurnState) (id Str) (desc Str) (gate-cmd Str)] -> HarnessTurnState
  :d "Registers an incremental plan item with an explicit verification gate."
  (let [(item (PlanGateItem
                :id id
                :description desc
                :verification-command gate-cmd
                :executed false
                :passed false))
        (updated-items (list-append (.-planned-items state) item))]
    (HarnessTurnState
      :planned-items updated-items
      :mutating-actions-count (.-mutating-actions-count state)
      :esh-violations (.-esh-violations state)
      :is-turn-grounded true)))

(df audit-action-precondition [(state HarnessTurnState) (action-kind Str)] -> VerificationResult
  :d "Enforces plan-before-act invariant on mutating actions."
  (if (not (is-mutating-action? action-kind))
      (VerificationResult :approved true :reason "Read-only action allowed without plan" :feedback "")
      (if (list-empty? (.-planned-items state))
          (VerificationResult
            :approved false
            :reason "Plan-before-act invariant violation"
            :feedback "You must declare an incremental plan item with a verification command before mutating files.")
          (VerificationResult :approved true :reason "Mutating action grounded in registered plan" :feedback ""))))

(df record-gate-execution [(state HarnessTurnState) (item-id Str) (exit-code I64)] -> HarnessTurnState
  :d "Records the real sandbox execution result of a plan item's gate command."
  (let [(updated-items
          (map (fn [(item PlanGateItem)] -> PlanGateItem
                 (if (= (.-id item) item-id)
                     (PlanGateItem
                       :id (.-id item)
                       :description (.-description item)
                       :verification-command (.-verification-command item)
                       :executed true
                       :passed (= exit-code 0))
                     item))
               (.-planned-items state)))]
    (HarnessTurnState
      :planned-items updated-items
      :mutating-actions-count (+ (.-mutating-actions-count state) 1)
      :esh-violations (.-esh-violations state)
      :is-turn-grounded true)))

(df validate-turn-completion [(state HarnessTurnState) (agent-claim-success Bool)] -> VerificationResult
  :d "Audits agent completion claim against real physical gate execution (ESH Guard)."
  (let [(items (.-planned-items state))]
    (if (not agent-claim-success)
        (VerificationResult :approved true :reason "Agent reported failure or incomplete turn" :feedback "")
        (if (list-empty? items)
            (if (> (.-mutating-actions-count state) 0)
                (VerificationResult
                  :approved false
                  :reason "ESH violation: State mutated without plan or verification gates"
                  :feedback "Mutations occurred without registered plan or gate. Declare plan and run verification.")
                (VerificationResult :approved true :reason "No mutations, read-only completion approved" :feedback ""))
            (let [(unexecuted (filter (fn [(it PlanGateItem)] -> Bool (not (.-executed it))) items))
                  (failed (filter (fn [(it PlanGateItem)] -> Bool (and (.-executed it) (not (.-passed it)))) items))]
              (cond
                ((not (list-empty? unexecuted))
                 (VerificationResult
                   :approved false
                   :reason "ESH violation: Claimed success but verification gate was never executed"
                   :feedback "You cannot claim task completion until all verification commands have executed."))
                ((not (list-empty? failed))
                 (VerificationResult
                   :approved false
                   :reason "ESH violation: Claimed success but verification gate failed (exit code != 0)"
                   :feedback "The verification gate failed. Inspect error output and repair the implementation."))
                (:else
                 (VerificationResult
                   :approved true
                   :reason "Turn verified: All plan items executed and all gates passed cleanly"
                   :feedback ""))))))))

(df format-verification-feedback [(res VerificationResult)] -> Str
  :d "Formats verification result into agent system message."
  (if (.-approved res)
      (s/concat "[VERIFIED] " (.-reason res))
      (s/concat "[GATE BLOCKED] " (.-reason res) " -> " (.-feedback res))))
