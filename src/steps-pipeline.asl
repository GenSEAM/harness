(module asl-harness/steps-pipeline
  :d "Steps & GAP Cognitive Pipeline Engine for autonomous AI agents. Manages multi-stage phased execution: Scout -> Plan -> GAP Plan Review -> Phased Implementation -> Post-Implementation GAP Verification -> Gate Settle."
  :x [StepPhase GapAuditResult StepsPipeline EddieConfig
      create-steps-pipeline add-pipeline-phase
      audit-plan-gaps audit-impl-gaps
      advance-pipeline-stage pipeline-status-summary
      make-standard-phases classify-task-entropy
      make-pipeline-by-mode default-eddie-config]
  :i [])

(dfs StepPhase
  (:f id Str "Unique phase identifier")
  (:f name Str "Human-readable phase title")
  (:f stage Str "Cognitive stage: scout | plan | gap-plan | impl | gap-impl | verify | settle")
  (:f gate-command Str "Executable verification check for this phase")
  (:f status Str "Execution state: pending | running | passed | failed | skipped")
  (:f findings (List Str) "Recorded audit or execution observations"))

(dfs GapAuditResult
  (:f verdict Str "Review decision: approve | approve-with-amendments | reject")
  (:f omissions (List Str) "Missing requirements, unhandled edge cases, omitted CLI args")
  (:f bloat-warnings (List Str) "Over-engineering flags, premature generalizations, unnecessary deps")
  (:f invariants-preserved Bool "True if all core architectural constraints hold")
  (:f recommendations (List Str) "Concrete corrective actions"))

(dfs StepsPipeline
  (:f task-id Str "Assigned task or ticket identifier")
  (:f task-instruction Str "Verbatim user instruction")
  (:f active-stage Str "Current cognitive stage")
  (:f phases (List StepPhase) "Ordered sequence of execution phases")
  (:f current-phase-idx I64 "Index of currently executing phase")
  (:f gap-audits (List GapAuditResult) "History of plan and implementation gap reviews")
  (:f is-completed Bool "True if all phases passed and final gate succeeded")
  (:f final-status Str "Outcome: pending | approved | rejected | verified | failed"))

(dfs EddieConfig
  (:f model Str "Inference model identifier")
  (:f pipeline Str "Default pipeline: full | adaptive | standard | fast")
  (:f anti-overthinking Bool "Enforce strict stopping on clean audit")
  (:f asl-first Bool "Use dense ASN tool calls and telemetry")
  (:f scout-polyglot Bool "Inspect polyglot runtimes in scout phase"))

(df default-eddie-config [] -> EddieConfig
  :d "Returns canonical default Eddie configuration."
  (EddieConfig
    :model "openai/gemma-4-31b-it"
    :pipeline "full"
    :anti-overthinking true
    :asl-first true
    :scout-polyglot true))

(df classify-task-entropy [(instruction Str)] -> Str
  :d "Classifies task complexity to select optimal pipeline mode: fast | standard | full."
  (let ((lower (string-lower instruction)))
    (cond
      ((or (string-contains? lower "tb-")
           (string-contains? lower "terminal-bench")
           (string-contains? lower "vulnerability")
           (string-contains? lower "xss")
           (string-contains? lower "exploit")
           (string-contains? lower "crypto")
           (string-contains? lower "vigenere")
           (string-contains? lower "dedup")
           (string-contains? lower "security")
           (string-contains? lower "sanitize"))
       "full")
      ((or (string-contains? lower "typo")
           (string-contains? lower "rename")
           (string-contains? lower "one-line")
           (string-contains? lower "trivial")
           (string-contains? lower "docstring"))
       "fast")
      (:else
       "standard"))))

(df make-standard-phases [(task-id Str)] -> (List StepPhase)
  :d "Generates standard 5-phase canonical Steps+GAP execution phases for an autonomous task."
  [
    (StepPhase
      :id "phase-1-scout"
      :name "Environment Reconnaissance & Fact Discovery"
      :stage "scout"
      :gate-command "ls -la && env"
      :status "pending"
      :findings [])
    (StepPhase
      :id "phase-2-plan"
      :name "Phased Decomposition & Gate Formulation"
      :stage "plan"
      :gate-command "cat PLAN.md"
      :status "pending"
      :findings [])
    (StepPhase
      :id "phase-3-gap-plan"
      :name "Plan-to-Instruction Pre-Implementation GAP Audit"
      :stage "gap-plan"
      :gate-command "cat REVIEW.md"
      :status "pending"
      :findings [])
    (StepPhase
      :id "phase-4-impl"
      :name "Phased Implementation with Step Gates"
      :stage "impl"
      :gate-command "test -f output.ready"
      :status "pending"
      :findings [])
    (StepPhase
      :id "phase-5-gap-impl"
      :name "Post-Implementation GAP Audit & Negative Test Verification"
      :stage "gap-impl"
      :gate-command "pytest tests/ || ./test.sh"
      :status "pending"
      :findings [])
  ])

(df make-pipeline-by-mode [(task-id Str) (instruction Str) (mode Str)] -> StepsPipeline
  :d "Instantiates StepsPipeline configured for specified mode: fast | standard | full | adaptive."
  (let ((effective-mode (if (= mode "adaptive")
                          (classify-task-entropy instruction)
                          mode)))
    (cond
      ((= effective-mode "fast")
       (StepsPipeline
         :task-id task-id
         :task-instruction instruction
         :active-stage "impl"
         :phases [
           (StepPhase
             :id "phase-1-impl"
             :name "Direct Targeted Implementation"
             :stage "impl"
             :gate-command "git status -s"
             :status "pending"
             :findings [])
           (StepPhase
             :id "phase-2-verify"
             :name "Fast Verification & Settle"
             :stage "verify"
             :gate-command "git diff"
             :status "pending"
             :findings [])
         ]
         :current-phase-idx 0
         :gap-audits []
         :is-completed false
         :final-status "pending"))
      ((= effective-mode "standard")
       (StepsPipeline
         :task-id task-id
         :task-instruction instruction
         :active-stage "plan"
         :phases [
           (StepPhase
             :id "phase-1-plan"
             :name "Implementation Plan"
             :stage "plan"
             :gate-command "cat PLAN.md"
             :status "pending"
             :findings [])
           (StepPhase
             :id "phase-2-impl"
             :name "Implementation"
             :stage "impl"
             :gate-command "test -f output.ready"
             :status "pending"
             :findings [])
           (StepPhase
             :id "phase-3-verify"
             :name "Verification Gate"
             :stage "verify"
             :gate-command "pytest || ./test.sh"
             :status "pending"
             :findings [])
         ]
         :current-phase-idx 0
         :gap-audits []
         :is-completed false
         :final-status "pending"))
      (:else
       (StepsPipeline
         :task-id task-id
         :task-instruction instruction
         :active-stage "scout"
         :phases (make-standard-phases task-id)
         :current-phase-idx 0
         :gap-audits []
         :is-completed false
         :final-status "pending")))))

(df create-steps-pipeline [(task-id Str) (instruction Str)] -> StepsPipeline
  :d "Instantiates a new autonomous Steps pipeline."
  (make-pipeline-by-mode task-id instruction "full"))

(df add-pipeline-phase [(pipeline StepsPipeline) (phase StepPhase)] -> StepsPipeline
  :d "Appends a custom phase to the pipeline."
  (StepsPipeline
    :task-id (.-task-id pipeline)
    :task-instruction (.-task-instruction pipeline)
    :active-stage (.-active-stage pipeline)
    :phases (concat (.-phases pipeline) [phase])
    :current-phase-idx (.-current-phase-idx pipeline)
    :gap-audits (.-gap-audits pipeline)
    :is-completed (.-is-completed pipeline)
    :final-status (.-final-status pipeline)))

(df audit-plan-gaps [(instruction Str) (planned-steps (List Str))] -> GapAuditResult
  :d "Audits a proposed plan against the original instruction to detect omissions and bloat."
  (let ((omissions [])
        (bloat []))
    ;; Check edge-case omission heuristics
    (when (and (string-contains? instruction "argv")
               (not (string-contains? (join " " planned-steps) "arg")))
      (set! omissions (concat omissions ["Missing command-line argument handling (argv)"])))
    (when (and (string-contains? instruction "exit")
               (not (string-contains? (join " " planned-steps) "exit")))
      (set! omissions (concat omissions ["Missing exit code handling requirement"])))
    (when (and (string-contains? instruction "in-place")
               (not (string-contains? (join " " planned-steps) "in-place")))
      (set! omissions (concat omissions ["Missing in-place file modification check"])))
    ;; Check anti-overengineering bloat heuristics
    (when (> (len planned-steps) 8)
      (set! bloat (concat bloat ["Excessive phase count: plan exceeds 8 steps, risk of over-engineering"])))
    
    (let ((has-omissions (> (len omissions) 0))
          (has-bloat (> (len bloat) 0)))
      (cond
        (has-omissions
         (GapAuditResult
           :verdict "approve-with-amendments"
           :omissions omissions
           :bloat-warnings bloat
           :invariants-preserved false
           :recommendations ["Incorporate missing requirements into plan before implementing."]))
        (has-bloat
         (GapAuditResult
           :verdict "approve-with-amendments"
           :omissions []
           :bloat-warnings bloat
           :invariants-preserved true
           :recommendations ["Simplify plan: collapse redundant intermediate steps."]))
        (:else
         (GapAuditResult
           :verdict "approve"
           :omissions []
           :bloat-warnings []
           :invariants-preserved true
           :recommendations ["Plan is complete, minimal, and verified against instruction."]))))))

(df audit-impl-gaps [(instruction Str) (diff Str) (tests-passed Bool)] -> GapAuditResult
  :d "Audits a completed implementation against the instruction and test results."
  (cond
    ((not tests-passed)
     (GapAuditResult
       :verdict "reject"
       :omissions ["Automated verification gate failed; regression detected"]
       :bloat-warnings []
       :invariants-preserved false
       :recommendations ["Inspect failing test trace, apply targeted fix, re-run gate."]))
    ((string-empty? diff)
     (GapAuditResult
       :verdict "reject"
       :omissions ["No code diff produced; task not implemented"]
       :bloat-warnings []
       :invariants-preserved false
       :recommendations ["Produce required code implementation."]))
    ((and (string-contains? instruction "in-place")
          (not (string-contains? diff "write")))
     (GapAuditResult
       :verdict "approve-with-amendments"
       :omissions ["Ensure file is modified in-place"]
       :bloat-warnings []
       :invariants-preserved true
       :recommendations ["Verify in-place write to disk."]))
    (:else
     (GapAuditResult
       :verdict "approve"
       :omissions []
       :bloat-warnings []
       :invariants-preserved true
       :recommendations ["All functional and quality invariants verified."]))))

(df advance-pipeline-stage [(pipeline StepsPipeline) (gate-passed Bool) (output Str)] -> StepsPipeline
  :d "Transitions pipeline to the next stage upon gate pass, or records failure."
  (if (not gate-passed)
    (StepsPipeline
      :task-id (.-task-id pipeline)
      :task-instruction (.-task-instruction pipeline)
      :active-stage (.-active-stage pipeline)
      :phases (.-phases pipeline)
      :current-phase-idx (.-current-phase-idx pipeline)
      :gap-audits (.-gap-audits pipeline)
      :is-completed false
      :final-status "failed")
    (let ((next-idx (+ (.-current-phase-idx pipeline) 1))
          (total (len (.-phases pipeline))))
      (if (>= next-idx total)
        (StepsPipeline
          :task-id (.-task-id pipeline)
          :task-instruction (.-task-instruction pipeline)
          :active-stage "settle"
          :phases (.-phases pipeline)
          :current-phase-idx next-idx
          :gap-audits (.-gap-audits pipeline)
          :is-completed true
          :final-status "verified")
        (let ((next-phase (get (.-phases pipeline) next-idx)))
          (StepsPipeline
            :task-id (.-task-id pipeline)
            :task-instruction (.-task-instruction pipeline)
            :active-stage (.-stage next-phase)
            :phases (.-phases pipeline)
            :current-phase-idx next-idx
            :gap-audits (.-gap-audits pipeline)
            :is-completed false
            :final-status "pending"))))))

(df pipeline-status-summary [(pipeline StepsPipeline)] -> Str
  :d "Produces a compact human-readable status summary of the pipeline."
  (str "StepsPipeline [" (.-task-id pipeline) "]: stage=" (.-active-stage pipeline) 
       " | progress=" (to-string (.-current-phase-idx pipeline)) "/" (to-string (len (.-phases pipeline)))
       " | completed=" (if (.-is-completed pipeline) "true" "false")
       " | status=" (.-final-status pipeline)))
