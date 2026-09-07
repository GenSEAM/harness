(module asl-harness/steps-pipeline
  :d "Steps & GAP Cognitive Pipeline Engine for autonomous AI agents. Manages multi-stage phased execution: Scout -> Plan -> GAP Plan Review -> Phased Implementation -> Post-Implementation GAP Verification -> Gate Settle."
  :x [StepPhase GapAuditResult StepsPipeline EddieConfig
      PipelineStage ReflectionConfig ReflectionVerdict
      default-reflection-config evaluate-fidelity-gate
      evaluate-prompt-fidelity select-pipeline-profile
      compute-task-entropy make-epistemic-7-phases make-7-stage-pipeline
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

(dfe PipelineStage
  (:c s1-ingest      [] "Ingestion and boundary normalization of task instruction and invariants")
  (:c s2-reformulate [] "Operational self-reformulation: explicit restatement of goal and constraints")
  (:c s3-intent-gate [] "Intent-Fidelity Gate: validates reformulation against prompt before planning")
  (:c s4-plan        [] "Action DAG decomposition with falsifiable verification gates")
  (:c s5-plan-gate   [] "Pre-mortem plan gate: detects ungrounded assumptions and omissions")
  (:c s6-implement   [] "Phased implementation under staged buffer isolation")
  (:c s7-verify      [] "Post-execution verification against genuine execution receipts"))

(dfs ReflectionConfig
  (:f max-hops I64 "Speculative reasoning hop ceiling (max 2)")
  (:f quarantined-channel Bool "Whether thinking tokens are quarantined from context")
  (:f fidelity-threshold F64 "Minimum confidence threshold for stage gate passage (e.g. 0.95)")
  (:f echo-suppression Bool "True if duplicate / echo reasoning loops are suppressed"))

(dfs ReflectionVerdict
  (:f stage PipelineStage "Epistemic pipeline stage under evaluation")
  (:f fidelity-score F64 "Measured fidelity score in range [0.0, 1.0]")
  (:f omissions (List Str) "Identified domain invariant omissions")
  (:f unsupported-claims (List Str) "Unanchored or hallucinated claims")
  (:f passed Bool "True if stage fidelity gate satisfied"))

(df default-reflection-config [] -> ReflectionConfig
  :d "Constructs standard canonical ReflectionConfig."
  (ReflectionConfig
    :max-hops 2
    :quarantined-channel true
    :fidelity-threshold 0.95
    :echo-suppression true))

(df evaluate-fidelity-gate [(verdict ReflectionVerdict) (cfg ReflectionConfig)] -> Bool
  :d "Evaluates whether reflection verdict passes the configured fidelity threshold."
  (and (.-passed verdict)
       (>= (.-fidelity-score verdict) (.-fidelity-threshold cfg))))

(df evaluate-prompt-fidelity [(original-prompt Str) (agent-reformulation Str) (threshold F64)] -> ReflectionVerdict
  :d "Audits agent reformulation against original prompt to prevent scope hallucination and omitted constraints."
  (let [(norm-prompt (string-lower original-prompt))
        (norm-ref (string-lower agent-reformulation))
        (has-content (and (not (string-empty? norm-prompt)) (not (string-empty? norm-ref))))]
    (if (not has-content)
      (ReflectionVerdict
        :stage (s3-intent-gate)
        :fidelity-score 0.0
        :omissions (list "Empty prompt or reformulation provided")
        :unsupported-claims (list)
        :passed false)
      (let [(words (string-split norm-prompt " "))
            (matched-count (list-length (filter (fn [(w Str)] -> Bool (and (> (string-length w) 3) (string-contains? norm-ref w))) words)))
            (candidate-count (list-length (filter (fn [(w Str)] -> Bool (> (string-length w) 3)) words)))
            (score (if (> candidate-count 0)
                     (/ (float-from-int64 matched-count) (float-from-int64 candidate-count))
                     1.0))
            (is-passed (>= score threshold))
            (omissions (if is-passed (list) (list "Reformulation omitted critical constraint terms from original prompt")))]
        (ReflectionVerdict
          :stage (s3-intent-gate)
          :fidelity-score score
          :omissions omissions
          :unsupported-claims (list)
          :passed is-passed)))))

(dfs EddieConfig
  (:f model Str "Inference model identifier")
  (:f pipeline Str "Default pipeline: full | adaptive | standard | fast")
  (:f asl-first Bool "Use dense ASN tool calls and telemetry")
  (:f scout-polyglot Bool "Inspect polyglot runtimes in scout phase"))

(df default-eddie-config [] -> EddieConfig
  :d "Returns canonical default Eddie configuration."
  (EddieConfig
    :model "openai/gemma-4-31b-it"
    :pipeline "full"
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

(df compute-task-entropy [(n-files I64) (domain-score F64) (ambiguity F64) (security-crit F64)] -> F64
  :d "Computes continuous task entropy score H_task based on file count, domain depth, ambiguity, and security criticality."
  (let [(w1 0.5)
        (w2 1.5)
        (w3 1.0)
        (w4 1.5)
        (f-val (float-from-int64 n-files))]
    (+ (+ (* w1 f-val) (* w2 domain-score))
       (+ (* w3 ambiguity) (* w4 security-crit)))))

(df select-pipeline-profile [(entropy F64)] -> Str
  :d "Selects execution profile based on task entropy: fast (< 1.5), standard (1.5 - 4.0), full (>= 4.0)."
  (cond
    ((< entropy 1.5) "fast")
    ((< entropy 4.0) "standard")
    (:else "full")))

(df make-epistemic-7-phases [(task-id Str)] -> (List StepPhase)
  :d "Generates full 7-stage epistemic reflection pipeline execution phases."
  (list
    (StepPhase
      :id "stage-1-ingest"
      :name "Ingest Task & Parse Invariants"
      :stage "s1-ingest"
      :gate-command "test -n \"$TASK_INSTRUCTION\""
      :status "pending"
      :findings (list))
    (StepPhase
      :id "stage-2-reformulate"
      :name "Operational Self-Reformulation"
      :stage "s2-reformulate"
      :gate-command "test -f REFORMULATION.md"
      :status "pending"
      :findings (list))
    (StepPhase
      :id "stage-3-intent-gate"
      :name "Intent-Fidelity Gate Verification"
      :stage "s3-intent-gate"
      :gate-command "asl test --strict-falsify harness/tests/epistemic_pipeline_test.asl"
      :status "pending"
      :findings (list))
    (StepPhase
      :id "stage-4-plan"
      :name "Action DAG Decomposition & Gate Formulation"
      :stage "s4-plan"
      :gate-command "test -f PLAN.md"
      :status "pending"
      :findings (list))
    (StepPhase
      :id "stage-5-plan-gate"
      :name "Pre-Mortem Plan Verification"
      :stage "s5-plan-gate"
      :gate-command "test -f REVIEW.md"
      :status "pending"
      :findings (list))
    (StepPhase
      :id "stage-6-implement"
      :name "Phased Implementation"
      :stage "s6-implement"
      :gate-command "asl rpc '(:batch (:diff))'"
      :status "pending"
      :findings (list))
    (StepPhase
      :id "stage-7-verify"
      :name "Post-Execution Receipt Verification"
      :stage "s7-verify"
      :gate-command "asl gate"
      :status "pending"
      :findings (list))))

(df make-7-stage-pipeline [(task-id Str) (instruction Str)] -> StepsPipeline
  :d "Instantiates full 7-stage epistemic reflection pipeline."
  (StepsPipeline
    :task-id task-id
    :task-instruction instruction
    :active-stage "s1-ingest"
    :phases (make-epistemic-7-phases task-id)
    :current-phase-idx 0
    :gap-audits (list)
    :is-completed false
    :final-status "pending"))

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
