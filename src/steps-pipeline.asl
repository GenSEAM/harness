(module asl-harness/steps-pipeline
  :d "Steps & GAP Cognitive Pipeline Engine for autonomous AI agents. Manages multi-stage phased execution: Scout -> Plan -> GAP Plan Review -> Phased Implementation -> Post-Implementation GAP Verification -> Gate Settle."
  :x [StepPhase GapAuditResult StepsPipeline AddieConfig
      PipelineStage ReflectionConfig ReflectionVerdict
      default-reflection-config evaluate-fidelity-gate
      evaluate-prompt-fidelity select-pipeline-profile
      compute-task-entropy make-epistemic-7-phases make-7-stage-pipeline
      create-steps-pipeline add-pipeline-phase
      audit-plan-gaps audit-impl-gaps
      advance-pipeline-stage pipeline-status-summary
      make-standard-phases classify-task-entropy
      make-pipeline-by-mode default-addie-config
      make-reflection-config execute-epistemic-pipeline
      evaluate-stage-teleology
      AdaptiveDAGConfig EpistemicStepRecord
      make-adaptive-dag-config is-replan-exhausted?
      trigger-adaptive-replan record-epistemic-primitive
      advance-pipeline-stage-adaptive]
  :i [(operational-model :a op)
      (teleology :a tel)])

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

(dfs AdaptiveDAGConfig
  (:f max-replan-iterations I64 "Maximum homeostatic replan attempts before fatal abort")
  (:f current-replan-count I64 "Current number of replan iterations executed")
  (:f auto-diagnose Bool "Automatically analyze failure output and insert diagnostic triage step")
  (:f allow-recovery Bool "True if adaptive recovery is enabled"))

(dfs EpistemicStepRecord
  (:f step-type Str "ground-fact | context-budget | adversarial-reflect | reconcile-reality")
  (:f target Str "Target path, symbol, or gate command")
  (:f executed Bool "True if physically executed")
  (:f details Str "Recorded observations or proof"))

(dfe PipelineStage
  (:c s1-ingest      [] "Ingestion and boundary normalization of task instruction and invariants")
  (:c s2-reformulate [] "Operational self-reformulation: explicit restatement of goal and constraints")
  (:c s3-intent-gate [] "Intent-Fidelity Gate: validates reformulation against prompt before planning")
  (:c s4-plan        [] "Action DAG decomposition with falsifiable verification gates")
  (:c s5-plan-gate   [] "Pre-mortem plan gate: detects ungrounded assumptions and omissions")
  (:c s6-implement   [] "Phased implementation under staged buffer isolation")
  (:c s7-verify      [] "Post-execution verification against genuine execution receipts"))

(dfs ReflectionConfig
  (:f enabled-stages (List PipelineStage) "Active pipeline stages enabled for epistemic verification")
  (:f min-fidelity-score F64 "Minimum confidence threshold for stage gate passage")
  (:f allow-fast-path Bool "Whether fast-path stage skipping is permitted")
  (:f strict-falsify Bool "Enforce strict falsifiability assertions on gate commands"))

(dfs ReflectionVerdict
  (:f stage PipelineStage "Epistemic pipeline stage under evaluation")
  (:f passed Bool "True if stage fidelity gate satisfied")
  (:f hallucinations (List Str) "Unanchored or hallucinated claims")
  (:f omitted-constraints (List Str) "Identified domain invariant omissions")
  (:f confidence-score F64 "Measured fidelity score in range 0.0 to 1.0"))

(df make-reflection-config [(stages (List PipelineStage)) (min-score F64) (fast-path Bool) (strict Bool)] -> ReflectionConfig
  :d "Constructs a ReflectionConfig with specified stages and fidelity threshold."
  (ReflectionConfig
    :enabled-stages stages
    :min-fidelity-score min-score
    :allow-fast-path fast-path
    :strict-falsify strict))

(df default-reflection-config [] -> ReflectionConfig
  :d "Constructs standard canonical ReflectionConfig enabling all 7 stages."
  (ReflectionConfig
    :enabled-stages [(s1-ingest) (s2-reformulate) (s3-intent-gate) (s4-plan) (s5-plan-gate) (s6-implement) (s7-verify)]
    :min-fidelity-score 0.95
    :allow-fast-path false
    :strict-falsify true))

(df evaluate-fidelity-gate [(verdict ReflectionVerdict) (cfg ReflectionConfig)] -> Bool
  :d "Evaluates whether reflection verdict passes the configured fidelity threshold."
  (and (.-passed verdict)
       (>= (.-confidence-score verdict) (.-min-fidelity-score cfg))))

(df evaluate-prompt-fidelity [(original-prompt Str) (agent-reformulation Str) (threshold F64)] -> ReflectionVerdict
  :d "Audits agent reformulation against original prompt to prevent scope hallucination and omitted constraints."
  (let [(norm-prompt (string-lower original-prompt))
        (norm-ref (string-lower agent-reformulation))
        (has-content (and (not (string-empty? norm-prompt)) (not (string-empty? norm-ref))))]
    (if (not has-content)
      (ReflectionVerdict
        :stage (s3-intent-gate)
        :passed false
        :hallucinations (list)
        :omitted-constraints (list "Empty prompt or reformulation provided")
        :confidence-score 0.0)
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
          :passed is-passed
          :hallucinations (list)
          :omitted-constraints omissions
          :confidence-score score)))))

(df clean-path-token [(tok Str)] -> Str
  :d "Strips common syntax delimiters from path or identifier tokens."
  (let [(t1 (string-replace tok "," ""))
        (t2 (string-replace t1 ";" ""))
        (t3 (string-replace t2 "\"" ""))
        (t4 (string-replace t3 "'" ""))
        (t5 (string-replace t4 "`" ""))
        (t6 (string-replace t5 "(" ""))
        (t7 (string-replace t6 ")" ""))]
    t7))

(df execute-epistemic-pipeline [(instruction Str) (model op/OperationalModel) (cfg ReflectionConfig)] -> ReflectionVerdict
  :d "Executes epistemic reflection verification against the operational model, detecting invariant omissions and hallucinations."
  (let [(norm-inst (string-lower instruction))
        (norm-exit (string-lower (.-expected-exit-behavior model)))
        (words (string-split instruction " "))
        (cleaned-words (map (fn [(w Str)] -> Str (clean-path-token w)) words))
        (candidate-paths (filter (fn [(w Str)] -> Bool
                                   (and (> (string-length w) 3)
                                        (or (string-contains? w "/")
                                            (or (string-ends-with? w ".asl")
                                                (or (string-ends-with? w ".asn")
                                                    (string-ends-with? w ".ts"))))))
                                 cleaned-words))
        (omitted-files (filter (fn [(cp Str)] -> Bool
                                 (= (list-length (filter (fn [(tf Str)] -> Bool
                                                           (or (= tf cp)
                                                               (string-contains? tf cp)))
                                                         (.-target-files model))) 0))
                               candidate-paths))
        (omitted-file-msgs (map (fn [(f Str)] -> Str (str "Missing target file in operational model: " f)) omitted-files))
        (flags-1 (if (and (string-contains? norm-inst "argv")
                          (not (string-contains? norm-exit "argv")))
                     (list "Missing command-line argument handling requirement (argv)")
                     (list)))
        (flags-2 (if (and (string-contains? norm-inst "exit")
                          (not (string-contains? norm-exit "exit")))
                     (list-concat flags-1 (list "Missing verification exit behavior expectation"))
                     flags-1))
        (flags-3 (if (and (string-contains? norm-inst "strict-falsify")
                          (not (string-contains? norm-exit "strict-falsify")))
                     (list-concat flags-2 (list "Missing strict-falsify verification expectation"))
                     flags-2))
        (has-neg (or (string-contains? norm-inst "forbidden")
                     (or (string-contains? norm-inst "do not")
                         (or (string-contains? norm-inst "never")
                             (or (string-contains? norm-inst "without")
                                 (or (string-contains? norm-inst "no foreign")
                                     (string-contains? norm-inst "zero foreign")))))))
        (omitted-flags (if (and has-neg (list-empty? (.-forbidden-side-effects model)))
                           (list-concat flags-3 (list "Omitted negative constraint preservation from instruction into forbidden side-effects"))
                           flags-3))
        (all-omissions (list-concat omitted-file-msgs omitted-flags))
        (hallucinated-files (filter (fn [(tf Str)] -> Bool
                                      (not (or (string-contains? instruction tf)
                                               (> (list-length (filter (fn [(cp Str)] -> Bool
                                                                         (or (string-contains? tf cp)
                                                                             (string-contains? cp tf)))
                                                                       candidate-paths))
                                                  0))))
                                    (.-target-files model)))
        (hallucinated-file-msgs (map (fn [(f Str)] -> Str (str "Hallucinated unanchored target file: " f)) hallucinated-files))
        (hallucinated-symbols (filter (fn [(sym Str)] -> Bool
                                        (not (string-contains? norm-inst (string-lower sym))))
                                      (.-required-symbols model)))
        (hallucinated-symbol-msgs (map (fn [(s Str)] -> Str (str "Hallucinated ungrounded required symbol or external dependency: " s)) hallucinated-symbols))
        (all-hallucinations (list-concat hallucinated-file-msgs hallucinated-symbol-msgs))
        (o-count (list-length all-omissions))
        (h-count (list-length all-hallucinations))
        (penalty (+ (* (float-from-int64 o-count) 0.3) (* (float-from-int64 h-count) 0.4)))
        (raw-score (- 1.0 penalty))
        (confidence-score (if (< raw-score 0.0) 0.0 raw-score))
        (is-passed (and (= o-count 0) (and (= h-count 0) (>= confidence-score (.-min-fidelity-score cfg)))))]
    (ReflectionVerdict
      :stage (s3-intent-gate)
      :passed is-passed
      :hallucinations all-hallucinations
      :omitted-constraints all-omissions
      :confidence-score confidence-score)))

(dfs AddieConfig
  (:f model Str "Inference model identifier")
  (:f pipeline Str "Default pipeline: full | adaptive | standard | fast")
  (:f asl-first Bool "Use dense ASN tool calls and telemetry")
  (:f scout-polyglot Bool "Inspect polyglot runtimes in scout phase"))

(df default-addie-config [] -> AddieConfig
  :d "Returns canonical default Addie configuration."
  (AddieConfig
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

(df evaluate-stage-teleology [(stage-name Str) (proposed-action Str)] -> Bool
  :d "Evaluates whether an action in the current pipeline stage adheres to the appropriate teleological mandate."
  (let ((lower-stage (string-lower stage-name)))
    (cond
      ((or (string-contains? lower-stage "scout") (= lower-stage "s1-ingest"))
       (tel/validate-action-against-mandate (tel/make-scout-mandate) proposed-action))
      ((or (string-contains? lower-stage "plan") (= lower-stage "s4-plan"))
       (tel/validate-action-against-mandate (tel/make-planner-mandate) proposed-action))
      ((or (string-contains? lower-stage "impl") (= lower-stage "s6-implement"))
       (tel/validate-action-against-mandate (tel/make-implementer-mandate) proposed-action))
      ((or (string-contains? lower-stage "gap") (string-contains? lower-stage "verify") (= lower-stage "s7-verify"))
       (tel/validate-action-against-mandate (tel/make-auditor-mandate) proposed-action))
      (:else true))))

(df audit-plan-gaps [(instruction Str) (planned-steps (List Str))] -> GapAuditResult
  :d "Audits a proposed plan against the original instruction to detect omissions and bloat."
  (let ((omissions [])
        (bloat []))
    (when (and (string-contains? instruction "argv")
               (not (string-contains? (join " " planned-steps) "arg")))
      (set! omissions (concat omissions ["Missing command-line argument handling (argv)"])))
    (when (and (string-contains? instruction "exit")
               (not (string-contains? (join " " planned-steps) "exit")))
      (set! omissions (concat omissions ["Missing exit code handling requirement"])))
    (when (and (string-contains? instruction "in-place")
               (not (string-contains? (join " " planned-steps) "in-place")))
      (set! omissions (concat omissions ["Missing in-place file modification check"])))
    (when (> (len planned-steps) 8)
      (set! bloat (concat bloat ["Excessive phase count: plan exceeds 8 steps, risk of over-engineering"])))
    (when (not (tel/validate-action-against-mandate (tel/make-planner-mandate) (join " " planned-steps)))
      (set! omissions (concat omissions ["Teleological mandate violation: plan contains ungrounded steps without verification gates"])))
    
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
    ((not (tel/validate-action-against-mandate (tel/make-implementer-mandate) diff))
     (GapAuditResult
       :verdict "reject"
       :omissions ["Teleological mandate violation: implementation attempted gate tampering or unauthorized modification"]
       :bloat-warnings []
       :invariants-preserved false
       :recommendations ["Preserve all verification gates without weakening or skipping."]))
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

(df make-adaptive-dag-config [(max-replan I64) (auto-diag Bool)] -> AdaptiveDAGConfig
  :d "Constructs canonical AdaptiveDAGConfig with homeostatic recovery ceiling."
  (AdaptiveDAGConfig
    :max-replan-iterations max-replan
    :current-replan-count 0
    :auto-diagnose auto-diag
    :allow-recovery true))

(df is-replan-exhausted? [(cfg AdaptiveDAGConfig)] -> Bool
  :d "Checks whether dynamic replan attempts have reached maximum ceiling."
  (>= (.-current-replan-count cfg) (.-max-replan-iterations cfg)))

(df trigger-adaptive-replan [(pipeline StepsPipeline) (cfg AdaptiveDAGConfig) (failure-reason Str)] -> StepsPipeline
  :d "Dynamically triggers homeostatic replanning upon gate failure if under recovery limit."
  (if (is-replan-exhausted? cfg)
    (StepsPipeline
      :task-id (.-task-id pipeline)
      :task-instruction (.-task-instruction pipeline)
      :active-stage (.-active-stage pipeline)
      :phases (.-phases pipeline)
      :current-phase-idx (.-current-phase-idx pipeline)
      :gap-audits (.-gap-audits pipeline)
      :is-completed false
      :final-status "failed")
    (let [(replan-idx (+ (.-current-replan-count cfg) 1))
          (triage-phase (StepPhase
                          :id (str "triage-" (to-string replan-idx))
                          :name "Adaptive Root-Cause Triage & Recovery DAG"
                          :stage "plan"
                          :gate-command "asl check .asl/mem/tasks/in_flight.asn"
                          :status "running"
                          :findings (list (str "Auto-diagnose: " failure-reason))))]
      (StepsPipeline
        :task-id (.-task-id pipeline)
        :task-instruction (.-task-instruction pipeline)
        :active-stage "plan"
        :phases (list-append (.-phases pipeline) (list triage-phase))
        :current-phase-idx (.-current-phase-idx pipeline)
        :gap-audits (.-gap-audits pipeline)
        :is-completed false
        :final-status "replanning"))))

(df record-epistemic-primitive [(step-type Str) (target Str) (details Str)] -> EpistemicStepRecord
  :d "Constructs an EpistemicStepRecord capturing verified operational discipline."
  (EpistemicStepRecord
    :step-type step-type
    :target target
    :executed true
    :details details))

(df advance-pipeline-stage-adaptive [(pipeline StepsPipeline) (gate-passed Bool) (output Str) (cfg AdaptiveDAGConfig)] -> StepsPipeline
  :d "Transitions pipeline stage with adaptive replan fallback upon gate failure."
  (if gate-passed
    (advance-pipeline-stage pipeline true output)
    (trigger-adaptive-replan pipeline cfg output)))
