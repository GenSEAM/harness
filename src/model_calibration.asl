(module asl-harness/model-calibration
  :d "Automated model calibration stand, parameter sweep engine, and Pareto multi-objective optimizer."
  :x [CanaryTask
      CalibrationCandidate
      CalibrationEvaluationResult
      CalibrationSweepConfig
      CtrfSummary
      ScalarLossMetric
      make-canary-task
      canonical-canary-tasks
      slm-calibration-tasks
      nano-calibration-tasks
      browser-calibration-tasks
      medium-calibration-tasks
      frontier-calibration-tasks
      super-hard-calibration-tasks
      full-spectrum-canary-tasks
      tasks-for-tier
      enforce-browser-model-ceiling
      compute-pareto-score
      compute-gradient-pareto-score
      compute-loss-progress
      compute-scalar-loss
      compute-ceiling-loss
      parse-ctrf-summary
      evaluate-ctrf-trial
      evaluate-scalar-loss-trial
      evaluate-candidate
      run-calibration-sweep
      find-optimal-candidate
      format-calibration-result-asn]
  :i [(context_assembler :a ca)
      (context_bench :a cb)])

(dfs CanaryTask
  (:f task-id Str "Unique micro-canary identifier")
  (:f name Str "Task title")
  (:f kind Str "Category kind: syntax, state-machine, or amnesia-probe")
  (:f total-steps I64 "Number of steps in canary task")
  (:f blocks (List ca/ContextBlock) "Seed context blocks")
  (:f required-facts (List Str) "Critical ground-truth invariants"))

(dfs CalibrationCandidate
  (:f model-name Str "Target model identifier")
  (:f strategy Str "Context strategy: baseline, receipts, jit-memory, agent-directed")
  (:f temperature F64 "Sampling temperature point")
  (:f budget-ceiling I64 "Maximum prompt token ceiling"))

(dfs CalibrationEvaluationResult
  (:f candidate CalibrationCandidate "Evaluated parameter candidate")
  (:f pass-rate F64 "Percentage of canary tasks resolved cleanly")
  (:f continuous-progress F64 "Continuous completion ratio in range 0.0 to 1.0")
  (:f avg-tokens I64 "Average prompt tokens consumed per canary")
  (:f latency-ms I64 "Average execution latency in milliseconds")
  (:f amnesia-detected Bool "True if critical facts were dropped")
  (:f pareto-score F64 "Calculated multi-objective efficiency score")
  (:f status Str "Execution outcome status :passed or :rejected"))

(dfs CalibrationSweepConfig
  (:f model-name Str "Target model to calibrate")
  (:f strategies (List Str) "List of candidate strategies to test")
  (:f temperatures (List F64) "List of temperature points to test")
  (:f budget-ceilings (List I64) "List of token budget ceilings")
  (:f dry-run Bool "True if executing offline synthetic sweep"))

(dfs CtrfSummary
  (:f total-tests I64 "Total number of tests executed")
  (:f passed-tests I64 "Number of passed tests")
  (:f failed-tests I64 "Number of failed tests")
  (:f progress-ratio F64 "Continuous ratio of passed to total in range 0.0 to 1.0"))

(dfs ScalarLossMetric
  (:f metric-name Str "Identifier of the scalar objective metric")
  (:f current-val F64 "Current evaluated numerical value")
  (:f target-val F64 "Target threshold or objective ceiling")
  (:f normalized-loss F64 "Continuous normalized loss where 0.0 is optimal"))

(df make-canary-task [(task-id Str) (name Str) (kind Str) (steps I64) (blocks (List ca/ContextBlock)) (facts (List Str))] -> CanaryTask
  :d "Constructs a CanaryTask record"
  (CanaryTask
    :task-id task-id
    :name name
    :kind kind
    :total-steps steps
    :blocks blocks
    :required-facts facts))

(df canonical-canary-tasks [] -> (List CanaryTask)
  :d "Constructs 3 canonical micro-canary tasks for calibration"
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 50 "You are Implementer"))
        (b-syn (ca/make-context-block "syn" "task-spec" 90 "Refactor syntax AST [fact: lexer-rule-42]"))
        (t1 (make-canary-task "CANARY-SYNTAX-01" "Syntax Refactoring" "syntax" 3 (list b-sys b-syn) (list "lexer-rule-42")))
        (b-fsm (ca/make-context-block "fsm" "task-spec" 110 "FSM state step [fact: state-id-beta]"))
        (t2 (make-canary-task "CANARY-STATE-02" "State Machine Step" "state-machine" 4 (list b-sys b-fsm) (list "state-id-beta")))
        (b-amn (ca/make-context-block "amn" "task-spec" 100 "Crypto seed probe [fact: seed-salt-888]"))
        (t3 (make-canary-task "CANARY-AMNESIA-03" "Amnesia Retention Probe" "amnesia-probe" 4 (list b-sys b-amn) (list "seed-salt-888")))]
    (list t1 t2 t3)))

(df slm-calibration-tasks [] -> (List CanaryTask)
  :d "Constructs 5 micro-canary calibration tasks designed for SLMs (0.5B-3B) with short token horizons"
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 40 "Affirmative ASL agent"))
        (b-delim (ca/make-context-block "delim" "syntax-spec" 60 "Balance delimiter [fact: token-parens-ok]"))
        (t1 (make-canary-task "SLM-DELIM-01" "Delimiter Balance" "syntax" 2 (list b-sys b-delim) (list "token-parens-ok")))
        (b-tool (ca/make-context-block "tool" "tool-spec" 50 "Invoke AST symbol [fact: sym-resolve-42]"))
        (t2 (make-canary-task "SLM-TOOL-02" "Affirmative Tool Call" "tool-schema" 2 (list b-sys b-tool) (list "sym-resolve-42")))
        (b-slice (ca/make-context-block "slice" "slice-spec" 55 "Targeted slice read [fact: line-slice-range]"))
        (t3 (make-canary-task "SLM-SLICE-03" "Narrow Slice Read" "context-slice" 3 (list b-sys b-slice) (list "line-slice-range")))
        (b-fact (ca/make-context-block "fact" "retention-spec" 45 "Retain state key [fact: salt-micro-777]"))
        (t4 (make-canary-task "SLM-FACT-04" "Short Horizon Fact Retention" "amnesia-probe" 3 (list b-sys b-fact) (list "salt-micro-777")))
        (b-exit (ca/make-context-block "exit" "recovery-spec" 50 "Catch error code [fact: exit-halt-0]"))
        (t5 (make-canary-task "SLM-EXIT-05" "Error Circuit Break" "error-recovery" 2 (list b-sys b-exit) (list "exit-halt-0")))]
    (list t1 t2 t3 t4 t5)))

(df frontier-calibration-tasks [] -> (List CanaryTask)
  :d "Constructs 5 heavy-reasoning challenge tasks designed for frontier models (Gemma 31B+)"
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 80 "Autonomous Systems Architect & Sovereign Implementer"))
        (b-heap (ca/make-context-block "heap" "crash-spec" 180 "Diagnose heap corruption in custom-memory-heap-crash [fact: alloc-header-guard]"))
        (t1 (make-canary-task "FRONT-HEAP-01" "Custom Memory Heap Crash" "memory-safety" 5 (list b-sys b-heap) (list "alloc-header-guard")))
        (b-blast (ca/make-context-block "blast" "refactor-spec" 160 "Execute blast-radius refactor across 4 callers [fact: caller-graph-acyclic]"))
        (t2 (make-canary-task "FRONT-BLAST-02" "Multi-Module Blast Radius" "ast-refactor" 5 (list b-sys b-blast) (list "caller-graph-acyclic")))
        (b-air (ca/make-context-block "air" "airgap-spec" 150 "Hermetic cross-compilation sysroot resolution [fact: target-triple-sysroot]"))
        (t3 (make-canary-task "FRONT-AIRGAP-03" "Hermetic Sysroot Resolution" "cross-compile" 4 (list b-sys b-air) (list "target-triple-sysroot")))
        (b-esh (ca/make-context-block "esh" "gate-spec" 140 "Reject unexecuted verbal assertion claims [fact: ctrf-physical-receipt]"))
        (t4 (make-canary-task "FRONT-ESH-04" "Verbal ESH Interception" "gate-audit" 4 (list b-sys b-esh) (list "ctrf-physical-receipt")))
        (b-work (ca/make-context-block "work" "worktree-spec" 170 "Multi-branch isolated git worktree lifecycle [fact: worktree-ref-head]"))
        (t5 (make-canary-task "FRONT-WORKTREE-05" "Worktree Scoping Invariant" "worktree" 5 (list b-sys b-work) (list "worktree-ref-head")))]
    (list t1 t2 t3 t4 t5)))

(df medium-calibration-tasks [] -> (List CanaryTask)
  :d "Constructs 5 medium challenge tasks calibrated for 7B-14B SLMs and Flash models (Gemini Flash, Qwen Flash)"
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 60 "Specialized Coding Subagent"))
        (b-patch (ca/make-context-block "patch" "multi-patch-spec" 120 "Perform atomic multi-hunk patch across two modules [fact: patch-atomic-hunk]"))
        (t1 (make-canary-task "MED-MULTI-PATCH-01" "Concurrent Multi-Hunk Form Patch" "ast-patch" 3 (list b-sys b-patch) (list "patch-atomic-hunk")))
        (b-roll (ca/make-context-block "roll" "rollback-spec" 110 "Roll back dirty buffer on compiler failure [fact: buffer-rollback-ok]"))
        (t2 (make-canary-task "MED-COMPILER-ROLLBACK-02" "In-Memory Error Rollback" "compiler-feedback" 3 (list b-sys b-roll) (list "buffer-rollback-ok")))
        (b-spool (ca/make-context-block "spool" "search-spec" 130 "Find deadlock line in 1000-line spool [fact: thread-deadlock-line]"))
        (t3 (make-canary-task "MED-LOG-BM25-SEARCH-03" "Okapi BM25 Spool Log Search" "spool-search" 4 (list b-sys b-spool) (list "thread-deadlock-line")))
        (b-conv (ca/make-context-block "conv" "codec-spec" 115 "Transpile JSON payload into ASN typed record [fact: codec-roundtrip-bitexact]"))
        (t4 (make-canary-task "MED-REPRESENTATION-CONVERT-04" "JSON to ASN Codec Transpilation" "asl-codec" 3 (list b-sys b-conv) (list "codec-roundtrip-bitexact")))
        (b-watch (ca/make-context-block "watch" "watchdog-spec" 125 "Recover from 10-second subprocess watchdog timeout [fact: watchdog-sigint-recover]"))
        (t5 (make-canary-task "MED-TIMEOUT-WATCHDOG-05" "Supervised Watchdog Recovery" "watchdog" 3 (list b-sys b-watch) (list "watchdog-sigint-recover")))]
    (list t1 t2 t3 t4 t5)))

(df super-hard-calibration-tasks [] -> (List CanaryTask)
  :d "Constructs 2 super-hard impossible horizon tasks that modern models fail to resolve (0.0% pass ceiling)"
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 100 "Principal Distributed Systems & Formal Verification Architect"))
        (b-paxos (ca/make-context-block "paxos" "consensus-spec" 240 "Synthesize split-brain recovery under asymmetric network partitions and monotonic clock drift [fact: byzantine-paxos-quorum]"))
        (t1 (make-canary-task "IMPOSSIBLE-DISTRIB-CONSENSUS-01" "Distributed Byzantine Paxos Under Dynamic Partitions" "formal-consensus" 6 (list b-sys b-paxos) (list "byzantine-paxos-quorum")))
        (b-arena (ca/make-context-block "arena" "allocator-spec" 250 "Zero-allocation generational compacting arena in 64KB Wasm Linear Memory with cyclic pointer relocation [fact: bitexact-arena-reloc]"))
        (t2 (make-canary-task "IMPOSSIBLE-ZERO-ALLOC-GC-02" "Wasm MicroVM Zero-Allocation Arena Compactor" "linear-memory-gc" 6 (list b-sys b-arena) (list "bitexact-arena-reloc")))]
    (list t1 t2)))

(df full-spectrum-canary-tasks [] -> (List CanaryTask)
  :d "Aggregates all 17 stratified canary tasks spanning micro-SLM, medium flash, frontier, and impossible tiers"
  (list-append (slm-calibration-tasks)
               (list-append (medium-calibration-tasks)
                            (list-append (frontier-calibration-tasks)
                                         (super-hard-calibration-tasks)))))

(df nano-calibration-tasks [] -> (List CanaryTask)
  :d "Constructs 3 ultra-lightweight canary tasks for 100MB nano models"
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 25 "Nano Classifier"))
        (b-tag (ca/make-context-block "tag" "tag-spec" 30 "Classify token [fact: tag-intent-read]"))
        (t1 (make-canary-task "NANO-TAG-01" "Single Token Classify" "classification" 2 (list b-sys b-tag) (list "tag-intent-read")))
        (b-mat (ca/make-context-block "mat" "match-spec" 35 "Match regex token [fact: match-sym-ident]"))
        (t2 (make-canary-task "NANO-MATCH-02" "Regex Token Match" "pattern-match" 2 (list b-sys b-mat) (list "match-sym-ident")))
        (b-cnt (ca/make-context-block "cnt" "count-spec" 30 "Count parens balance [fact: count-parens-1]"))
        (t3 (make-canary-task "NANO-COUNT-03" "Paren Delimiter Count" "delimiter" 2 (list b-sys b-cnt) (list "count-parens-1")))]
    (list t1 t2 t3)))

(df browser-calibration-tasks [] -> (List CanaryTask)
  :d "Constructs 4 specialized tasks targeting browser-runnable models under 3B parameter ceiling"
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 40 "Browser SLM Agent"))
        (b-dom (ca/make-context-block "dom" "dom-spec" 65 "Resolve DOM selector [fact: dom-selector-query]"))
        (t1 (make-canary-task "BROWSER-DOM-01" "DOM Selector Resolution" "dom-query" 2 (list b-sys b-dom) (list "dom-selector-query")))
        (b-act (ca/make-context-block "act" "act-spec" 55 "Affirmative 4-tool action dispatch [fact: affirm-action-valid]"))
        (t2 (make-canary-task "BROWSER-ACT-02" "Affirmative Action Dispatch" "affirmative-tool" 2 (list b-sys b-act) (list "affirm-action-valid")))
        (b-toy (ca/make-context-block "toy" "toy-spec" 70 "Simulate cellular automata grid step [fact: toy-life-step-ok]"))
        (t3 (make-canary-task "BROWSER-TOY-03" "Interactive Toy Simulation Step" "toy-sim" 3 (list b-sys b-toy) (list "toy-life-step-ok")))
        (b-vdom (ca/make-context-block "vdom" "vdom-spec" 75 "Emit reactive VDOM element form [fact: vdom-render-pure]"))
        (t4 (make-canary-task "BROWSER-VDOM-04" "Reactive VDOM Form Generation" "vdom-render" 3 (list b-sys b-vdom) (list "vdom-render-pure")))]
    (list t1 t2 t3 t4)))

(df enforce-browser-model-ceiling [(model-name Str)] -> Bool
  :d "Enforces strict 3-billion parameter ceiling rejecting 7B, 9B, and larger models for browser targets"
  (if (or (string-contains? model-name "7B")
      (or (string-contains? model-name "7b")
      (or (string-contains? model-name "8B")
      (or (string-contains? model-name "8b")
      (or (string-contains? model-name "9B")
      (or (string-contains? model-name "9b")
      (or (string-contains? model-name "14B")
      (or (string-contains? model-name "14b")
      (or (string-contains? model-name "31B")
      (or (string-contains? model-name "31b")
      (or (string-contains? model-name "70B")
          (string-contains? model-name "70b"))))))))))))
    false
    true))

(df tasks-for-tier [(tier Str)] -> (List CanaryTask)
  :d "Routes to specialized canary tasks based on model scale tier (nano, browser, slm, medium, frontier, impossible, all, or canonical)"
  (cond
    ((= tier "nano") (nano-calibration-tasks))
    ((= tier "browser") (browser-calibration-tasks))
    ((= tier "slm") (slm-calibration-tasks))
    ((= tier "medium") (medium-calibration-tasks))
    ((= tier "frontier") (frontier-calibration-tasks))
    ((= tier "impossible") (super-hard-calibration-tasks))
    ((= tier "all") (full-spectrum-canary-tasks))
    (:else (canonical-canary-tasks))))

(df extract-first-digits [(chars (List Str)) (acc Str)] -> Str
  :d "Extracts consecutive digits from character list"
  (if (list-empty? chars)
    acc
    (let [(c (option-or (list-head chars) ""))
          (rst (option-or (list-tail chars) (list)))]
      (if (string-contains? "0123456789" c)
        (extract-first-digits rst (str acc c))
        (if (string-empty? acc)
          (if (or (= c " ") (or (= c ":") (or (= c "\t") (= c "\n"))))
            (extract-first-digits rst "")
            acc)
          acc)))))

(df extract-int-kw [(raw Str) (kw Str)] -> I64
  :d "Extracts integer value associated with keyword in ASN or text"
  (let [(idx-opt (string-index-of raw kw))]
    (mt idx-opt
      ((some idx)
       (let [(tail-opt (string-slice raw (+ idx (string-length kw)) (string-length raw)))
             (tail (option-or tail-opt ""))
             (digits (extract-first-digits (string-chars tail) ""))]
         (option-or (string-to-int64 digits) 0)))
      ((none) 0))))

(df parse-ctrf-summary [(ctrf-content Str)] -> CtrfSummary
  :d "Parses CTRF execution summary extracting test counts and progress ratio"
  (let [(tests (extract-int-kw ctrf-content ":tests"))
        (passed (extract-int-kw ctrf-content ":passed"))
        (failed (extract-int-kw ctrf-content ":failed"))
        (eff-total (if (> tests 0) tests (+ passed failed)))
        (f-pass (int64-to-float64 passed))
        (f-total (int64-to-float64 (max 1 eff-total)))
        (ratio (if (> eff-total 0) (/ f-pass f-total) 0.0))]
    (CtrfSummary
      :total-tests eff-total
      :passed-tests passed
      :failed-tests failed
      :progress-ratio ratio)))

(df compute-loss-progress [(loss F64)] -> F64
  :d "Converts continuous normalized loss into bounded progress ratio in range 0.0 to 1.0"
  (if (<= loss 0.0)
    1.0
    (/ 1.0 (+ 1.0 loss))))

(df compute-scalar-loss [(name Str) (curr F64) (target F64)] -> ScalarLossMetric
  :d "Computes normalized continuous scalar distance to target objective"
  (let [(delta (- curr target))
        (abs-delta (if (< delta 0.0) (- 0.0 delta) delta))
        (denom (if (= target 0.0) 1.0 (if (< target 0.0) (- 0.0 target) target)))
        (norm-loss (/ abs-delta denom))]
    (ScalarLossMetric
      :metric-name name
      :current-val curr
      :target-val target
      :normalized-loss norm-loss)))

(df compute-ceiling-loss [(name Str) (curr F64) (ceiling F64)] -> ScalarLossMetric
  :d "Computes normalized scalar loss for upper-bound ceiling objectives"
  (let [(excess (- curr ceiling))
        (norm-loss (if (<= excess 0.0) 0.0 (/ excess (max 1.0 ceiling))))]
    (ScalarLossMetric
      :metric-name name
      :current-val curr
      :target-val ceiling
      :normalized-loss norm-loss)))

(df compute-gradient-pareto-score [(pass-rate F64) (continuous-progress F64) (tokens I64) (amnesia Bool) (lat-ms I64)] -> F64
  :d "Computes continuous-gradient Pareto score balancing progress against token cost and latency"
  (let [(f-tok (int64-to-float64 tokens))
        (f-lat (int64-to-float64 lat-ms))
        (effective-rate (max pass-rate (* continuous-progress 100.0)))
        (base-eff (/ (* effective-rate 1000.0) (+ f-tok 10.0)))
        (amnesia-pen (if amnesia 500.0 0.0))
        (lat-pen (/ f-lat 10.0))]
    (- (- base-eff amnesia-pen) lat-pen)))

(df compute-pareto-score [(pass-rate F64) (tokens I64) (amnesia Bool) (lat-ms I64)] -> F64
  :d "Computes multi-objective Pareto score balancing accuracy against token cost and latency"
  (compute-gradient-pareto-score pass-rate (if (> pass-rate 0.0) (/ pass-rate 100.0) 0.0) tokens amnesia lat-ms))

(df simulate-canary-step [(c-task CanaryTask) (strat Str) (ceiling I64)] -> cb/StrategyRunMetrics
  :d "Simulates canary execution delegating to context bench runner"
  (let [(bench-task (cb/make-bench-task
                      (.-task-id c-task)
                      (.-name c-task)
                      (.-total-steps c-task)
                      (.-blocks c-task)
                      (.-required-facts c-task)
                      false))]
    (cb/simulate-task-under-strategy bench-task strat ceiling)))

(dfs CanaryEvalAcc
  (:f passed-count I64 "Number of passed canary tasks")
  (:f token-sum I64 "Accumulated tokens across canaries")
  (:f amnesia-count I64 "Number of amnesia detections")
  (:f latency-sum I64 "Accumulated latency"))

(df evaluate-candidate [(cand CalibrationCandidate) (tasks (List CanaryTask)) (dry-run Bool)] -> CalibrationEvaluationResult
  :d "Evaluates calibration candidate across canary micro-suite"
  (let [(strat (.-strategy cand))
        (ceiling (.-budget-ceiling cand))
        (init-acc (CanaryEvalAcc :passed-count 0 :token-sum 0 :amnesia-count 0 :latency-sum 0))
        (final-acc (fold (fn [(acc CanaryEvalAcc) (t CanaryTask)] -> CanaryEvalAcc
                           (let [(res (simulate-canary-step t strat ceiling))
                                 (is-pass (.-passed res))
                                 (tok (.-prompt-tokens res))
                                 (is-amn (.-amnesia-detected res))
                                 (lat (.-duration-ms res))]
                             (CanaryEvalAcc
                               :passed-count (if is-pass (+ (.-passed-count acc) 1) (.-passed-count acc))
                               :token-sum (+ (.-token-sum acc) tok)
                               :amnesia-count (if is-amn (+ (.-amnesia-count acc) 1) (.-amnesia-count acc))
                               :latency-sum (+ (.-latency-sum acc) lat))))
                         init-acc
                         tasks))
        (total-tasks (list-length tasks))
        (f-total (int64-to-float64 (max 1 total-tasks)))
        (f-passed (int64-to-float64 (.-passed-count final-acc)))
        (pass-rate (* (/ f-passed f-total) 100.0))
        (continuous-progress (/ f-passed f-total))
        (avg-tok (/ (.-token-sum final-acc) (max 1 total-tasks)))
        (avg-lat (/ (.-latency-sum final-acc) (max 1 total-tasks)))
        (amnesia-detected (> (.-amnesia-count final-acc) 0))
        (pareto (compute-gradient-pareto-score pass-rate continuous-progress avg-tok amnesia-detected avg-lat))
        (status (if (and (>= pass-rate 90.0) (not amnesia-detected)) ":passed" ":rejected"))]
    (CalibrationEvaluationResult
      :candidate cand
      :pass-rate pass-rate
      :continuous-progress continuous-progress
      :avg-tokens avg-tok
      :latency-ms avg-lat
      :amnesia-detected amnesia-detected
      :pareto-score pareto
      :status status)))

(df evaluate-ctrf-trial [(cand CalibrationCandidate) (ctrf-text Str) (tokens I64) (lat-ms I64)] -> CalibrationEvaluationResult
  :d "Evaluates calibration candidate against a benchmark CTRF report"
  (let [(ctrf (parse-ctrf-summary ctrf-text))
        (cont-prog (.-progress-ratio ctrf))
        (pass-rate (if (= (.-total-tests ctrf) 0)
                     0.0
                     (if (= (.-failed-tests ctrf) 0) 100.0 0.0)))
        (pareto (compute-gradient-pareto-score pass-rate cont-prog tokens false lat-ms))
        (status (if (= pass-rate 100.0) ":passed" ":rejected"))]
    (CalibrationEvaluationResult
      :candidate cand
      :pass-rate pass-rate
      :continuous-progress cont-prog
      :avg-tokens tokens
      :latency-ms lat-ms
      :amnesia-detected false
      :pareto-score pareto
      :status status)))

(df evaluate-scalar-loss-trial [(cand CalibrationCandidate) (metric ScalarLossMetric) (tokens I64) (lat-ms I64)] -> CalibrationEvaluationResult
  :d "Evaluates calibration candidate against an optimization scalar objective"
  (let [(cont-prog (compute-loss-progress (.-normalized-loss metric)))
        (pass-rate (if (<= (.-normalized-loss metric) 0.0) 100.0 0.0))
        (pareto (compute-gradient-pareto-score pass-rate cont-prog tokens false lat-ms))
        (status (if (= pass-rate 100.0) ":passed" ":rejected"))]
    (CalibrationEvaluationResult
      :candidate cand
      :pass-rate pass-rate
      :continuous-progress cont-prog
      :avg-tokens tokens
      :latency-ms lat-ms
      :amnesia-detected false
      :pareto-score pareto
      :status status)))

(dfs SweepCandidateList
  (:f candidates (List CalibrationCandidate) "List of Cartesian candidates"))

(df generate-candidates-loop [(model Str) (strats (List Str)) (temps (List F64)) (budgets (List I64))] -> (List CalibrationCandidate)
  :d "Generates grid permutations of strategies, temperatures, and budgets"
  (fold (fn [(acc (List CalibrationCandidate)) (strat Str)] -> (List CalibrationCandidate)
          (let [(temp-cand (fold (fn [(acc2 (List CalibrationCandidate)) (temp F64)] -> (List CalibrationCandidate)
                                   (let [(b-cand (map (fn [(b I64)] -> CalibrationCandidate
                                                        (CalibrationCandidate
                                                          :model-name model
                                                          :strategy strat
                                                          :temperature temp
                                                          :budget-ceiling b))
                                                      budgets))]
                                     (list-append acc2 b-cand)))
                                 (list)
                                 temps))]
            (list-append acc temp-cand)))
        (list)
        strats))

(df insert-result [(item CalibrationEvaluationResult) (sorted (List CalibrationEvaluationResult))] -> (List CalibrationEvaluationResult)
  :d "Inserts result into sorted list in descending pareto-score order"
  (if (list-empty? sorted)
    (list item)
    (let [(default-r (CalibrationEvaluationResult
                       :candidate (CalibrationCandidate :model-name "" :strategy "" :temperature 0.0 :budget-ceiling 0)
                       :pass-rate 0.0 :continuous-progress 0.0 :avg-tokens 0 :latency-ms 0 :amnesia-detected false :pareto-score 0.0 :status ""))
          (head-r (option-or (list-head sorted) default-r))
          (tail-r (option-or (list-tail sorted) (list)))]
      (if (> (.-pareto-score item) (.-pareto-score head-r))
        (list-cons item sorted)
        (list-cons head-r (insert-result item tail-r))))))

(df sort-results-loop [(unsorted (List CalibrationEvaluationResult)) (sorted (List CalibrationEvaluationResult))] -> (List CalibrationEvaluationResult)
  :d "Tail-recursive loop sorting results in descending pareto-score order"
  (if (list-empty? unsorted)
    sorted
    (let [(default-r (CalibrationEvaluationResult
                       :candidate (CalibrationCandidate :model-name "" :strategy "" :temperature 0.0 :budget-ceiling 0)
                       :pass-rate 0.0 :continuous-progress 0.0 :avg-tokens 0 :latency-ms 0 :amnesia-detected false :pareto-score 0.0 :status ""))
          (head-r (option-or (list-head unsorted) default-r))
          (tail-r (option-or (list-tail unsorted) (list)))]
      (sort-results-loop tail-r (insert-result head-r sorted)))))

(df sort-results-by-score [(unsorted (List CalibrationEvaluationResult))] -> (List CalibrationEvaluationResult)
  :d "Sorts calibration evaluation results descending by pareto-score"
  (sort-results-loop unsorted (list)))

(df run-calibration-sweep [(cfg CalibrationSweepConfig)] -> (List CalibrationEvaluationResult)
  :d "Executes full parameter sweep across canary tasks and returns Pareto-ranked results"
  (let [(model (.-model-name cfg))
        (strats (.-strategies cfg))
        (temps (.-temperatures cfg))
        (budgets (.-budget-ceilings cfg))
        (dry-run (.-dry-run cfg))
        (candidates (generate-candidates-loop model strats temps budgets))
        (tasks (canonical-canary-tasks))
        (eval-results (map (fn [(cand CalibrationCandidate)] -> CalibrationEvaluationResult
                             (evaluate-candidate cand tasks dry-run))
                           candidates))]
    (sort-results-by-score eval-results)))

(df find-optimal-candidate [(results (List CalibrationEvaluationResult))] -> (Option CalibrationCandidate)
  :d "Finds the candidate with highest Pareto efficiency score"
  (if (list-empty? results)
    (none)
    (let [(best (option-or (list-head results)
                           (CalibrationEvaluationResult
                             :candidate (CalibrationCandidate :model-name "" :strategy "" :temperature 0.0 :budget-ceiling 0)
                             :pass-rate 0.0
                             :continuous-progress 0.0
                             :avg-tokens 0
                             :latency-ms 0
                             :amnesia-detected false
                             :pareto-score 0.0
                             :status "")))]
      (some (.-candidate best)))))

(df format-calibration-result-asn [(res CalibrationEvaluationResult)] -> Str
  :d "Formats calibration evaluation result into structured ASN representation"
  (let [(cand (.-candidate res))]
    (str "(:calibration-result\n"
         "  :model \"" (.-model-name cand) "\"\n"
         "  :strategy \"" (.-strategy cand) "\"\n"
         "  :temperature " (string-from-float64 (.-temperature cand)) "\n"
         "  :budget-ceiling " (string-from-int64 (.-budget-ceiling cand)) "\n"
         "  :pass-rate " (string-from-float64 (.-pass-rate res)) "\n"
         "  :continuous-progress " (string-from-float64 (.-continuous-progress res)) "\n"
         "  :avg-tokens " (string-from-int64 (.-avg-tokens res)) "\n"
         "  :latency-ms " (string-from-int64 (.-latency-ms res)) "\n"
         "  :amnesia-detected " (if (.-amnesia-detected res) "true" "false") "\n"
         "  :pareto-score " (string-from-float64 (.-pareto-score res)) "\n"
         "  :status " (.-status res) "\n"
         ")")))
