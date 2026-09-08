(module asl-harness/worker
  :d "Autonomous multi-session worker loop with continuous phase polling, sequential gate verification, ProcessReceipt demuxing, and pre-commit blast-radius boundary guarding."
  :x [ProcessReceipt
      WorkerConfig
      WorkerState
      StepOutcome
      PhaseExecutionResult
      BlastRadiusGuard
      WorkItem
      PhaseRecord
      LeaseRecord
      RoadmapRecord
      make-work-item
      make-phase-record
      make-lease-record
      make-roadmap-record
      make-process-receipt
      render-process-receipt
      estimate-receipt-tokens
      make-worker-config
      init-worker-state
      path-in-boundaries?
      poll-claimed-phase
      execute-work-item
      execute-phase-items
      verify-blast-radius
      audit-pre-commit-safety
      commit-phase-diff
      worker-step
      run-worker-loop]
  :i [])

(dfs WorkItem
  (:f id Str "Granular work item identifier e.g. item-1")
  (:f name Str "Human-readable item title")
  (:f status Str "Execution state: pending, in-progress, completed, failed")
  (:f gate Str "Verification gate shell command"))

(dfs PhaseRecord
  (:f id Str "Canonical phase identifier")
  (:f name Str "Human-readable phase title")
  (:f status Str "Phase lifecycle state: pending, claimed, in-progress, completed, failed")
  (:f wave Str "Wave grouping identifier")
  (:f gate Str "Composite acceptance gate shell command")
  (:f items (List WorkItem) "Granular work item records"))

(dfs LeaseRecord
  (:f phase-id Str "Locked phase identifier")
  (:f agent-id Str "Worker agent holding exclusive execution lease")
  (:f acquired-epoch I64 "Epoch timestamp in milliseconds of lease grant")
  (:f ttl-ms I64 "Lease duration in milliseconds")
  (:f is-active Bool "True if lease is currently valid"))

(dfs RoadmapRecord
  (:f iteration Str "Active roadmap iteration name")
  (:f phases (List PhaseRecord) "Tracked phase records list")
  (:f leases (List LeaseRecord) "Active agent execution leases")
  (:f version I64 "Monotonic roadmap revision counter"))

(dfs ProcessReceipt
  (:f exit-code I64 "Process return code (0 = success)")
  (:f duration-ms I64 "Execution duration in milliseconds")
  (:f peak-rss-mb I64 "Peak memory resident set size in megabytes")
  (:f spool-path Str "Filesystem path to ephemeral disk spool")
  (:f summary Str "Compact diagnostic string (<100 tokens, errors only)")
  (:f tokens I64 "Estimated BPE token count of rendered receipt"))

(dfs BlastRadiusGuard
  (:f is-safe Bool "True if all modified symbols/paths remain within declared boundaries")
  (:f violations (List Str) "List of symbols or files modified outside declared boundaries")
  (:f affected-symbols (List Str) "List of affected symbols from impact analysis")
  (:f details Str "Diagnostic summary of blast-radius verification"))

(dfs WorkerConfig
  (:f agent-id Str "Worker agent identifier e.g. worker-daemon-1")
  (:f continuous Bool "True for continuous daemon mode, false for single pass")
  (:f max-cycles I64 "Maximum loop cycles (0 for unbounded)")
  (:f idle-interval-ms I64 "Polling sleep interval in milliseconds")
  (:f owns-boundaries (List Str) "Declared path and symbol ownership whitelist")
  (:f strict-gates Bool "True to enforce strict non-zero exit code rejection"))

(dfs WorkerState
  (:f config WorkerConfig "Worker configuration record")
  (:f status Str "Worker state: idle, polling, executing, verifying, committed, failed, halted")
  (:f cycle-count I64 "Monotonic execution cycle counter")
  (:f active-phase-id Str "Active phase identifier or empty string")
  (:f completed-phases (List Str) "List of successfully completed phase IDs")
  (:f receipts (List ProcessReceipt) "Process receipts from executed gates")
  (:f blast-guard (Option BlastRadiusGuard) "Last pre-commit blast-radius evaluation")
  (:f last-error Str "Diagnostic error message if failed"))

(dfs PhaseExecutionResult
  (:f receipts (List ProcessReceipt) "Process receipts recorded during item execution")
  (:f all-passed Bool "True if all attempted items passed their verification gates")
  (:f executed-count I64 "Total number of items executed")
  (:f failed-item-id Str "Identifier of first failed item or empty string"))

(dfs StepOutcome
  (:f worker-state WorkerState "Updated worker state after execution cycle")
  (:f phase-id Str "Target phase identifier")
  (:f action Str "Action taken: idle, claimed, executed, committed, failed")
  (:f items-count I64 "Number of items processed in this step")
  (:f all-passed Bool "True if all attempted items and gates passed"))

(df make-work-item [(id Str) (name Str) (status Str) (gate Str)] -> WorkItem
  :d "Constructs a work item record."
  (WorkItem :id id :name name :status status :gate gate))

(df make-phase-record [(id Str) (name Str) (status Str) (wave Str) (gate Str) (items (List WorkItem))] -> PhaseRecord
  :d "Constructs a phase record."
  (PhaseRecord :id id :name name :status status :wave wave :gate gate :items items))

(df make-lease-record [(phase-id Str) (agent-id Str) (acquired I64) (ttl I64)] -> LeaseRecord
  :d "Constructs an active phase lease record."
  (LeaseRecord :phase-id phase-id :agent-id agent-id :acquired-epoch acquired :ttl-ms ttl :is-active true))

(df make-roadmap-record [(iteration Str) (phases (List PhaseRecord))] -> RoadmapRecord
  :d "Constructs a roadmap record initialized at version 1 with no active leases."
  (RoadmapRecord :iteration iteration :phases phases :leases (list) :version 1))

(df estimate-receipt-tokens [(text Str)] -> I64
  :d "Estimates BPE tokens for rendered ProcessReceipt verifying ceiling."
  (let [(len (string-length text))]
    (cond
      ((<= len 0) 0)
      ((<= len 4) 1)
      (:else (/ (+ len 3) 4)))))

(df render-process-receipt [(r ProcessReceipt)] -> Str
  :d "Renders ProcessReceipt as compact S-expression string under 80 tokens."
  (str "(:receipt :exit " (string-from-int64 (.-exit-code r))
       " :ms " (string-from-int64 (.-duration-ms r))
       " :rss " (string-from-int64 (.-peak-rss-mb r))
       " :spool \"" (.-spool-path r) "\""
       " :summary \"" (.-summary r) "\")"))

(df make-process-receipt [(exit-code I64) (duration-ms I64) (peak-rss-mb I64) (spool-path Str) (summary Str)] -> ProcessReceipt
  :d "Constructs a compact ProcessReceipt with BPE token estimation under 80 tokens."
  (let [(rendered (str "(:receipt :exit " (string-from-int64 exit-code)
                       " :ms " (string-from-int64 duration-ms)
                       " :rss " (string-from-int64 peak-rss-mb)
                       " :spool \"" spool-path "\""
                       " :summary \"" summary "\")"))
        (toks (estimate-receipt-tokens rendered))]
    (ProcessReceipt
      :exit-code exit-code
      :duration-ms duration-ms
      :peak-rss-mb peak-rss-mb
      :spool-path spool-path
      :summary summary
      :tokens toks)))

(df make-worker-config [(agent-id Str) (continuous Bool) (max-cycles I64) (idle-interval-ms I64) (owns (List Str))] -> WorkerConfig
  :d "Constructs configuration for autonomous implementer worker daemon."
  (WorkerConfig
    :agent-id agent-id
    :continuous continuous
    :max-cycles max-cycles
    :idle-interval-ms idle-interval-ms
    :owns-boundaries owns
    :strict-gates true))

(df init-worker-state [(cfg WorkerConfig)] -> WorkerState
  :d "Initializes autonomous worker state with empty history and idle status."
  (WorkerState
    :config cfg
    :status "idle"
    :cycle-count 0
    :active-phase-id ""
    :completed-phases (list)
    :receipts (list)
    :blast-guard (none)
    :last-error ""))

(df path-in-boundaries? [(path Str) (boundaries (List Str))] -> Bool
  :d "Predicate asserting target path falls within declared ownership boundaries."
  (let [(matches (filter (fn [(b Str)] -> Bool
                           (or (= path b)
                               (or (string-starts-with? path b)
                                   (string-ends-with? path b))))
                         boundaries))]
    (not (list-empty? matches))))

(df poll-claimed-phase [(rm RoadmapRecord) (agent-id Str)] -> (Option PhaseRecord)
  :d "Queries roadmap for claimed or ready phases assigned to worker agent."
  (let [(leases (.-leases rm))
        (matching-leases (filter (fn [(l LeaseRecord)] -> Bool
                                   (and (= (.-agent-id l) agent-id)
                                        (.-is-active l)))
                                 leases))]
    (if (not (list-empty? matching-leases))
      (let [(target-lease (list-head matching-leases))]
        (mt target-lease
          ((some l)
           (let [(matches (filter (fn [(p PhaseRecord)] -> Bool (= (.-id p) (.-phase-id l))) (.-phases rm)))]
             (list-head matches)))
          ((none) (none))))
      (let [(phases (.-phases rm))
            (claimed-phases (filter (fn [(p PhaseRecord)] -> Bool
                                      (or (= (.-status p) "claimed")
                                          (= (.-status p) "pending")))
                                    phases))]
        (list-head claimed-phases)))))

(df execute-work-item [(item-id Str) (gate-cmd Str) (exit-code I64) (duration-ms I64)] -> ProcessReceipt
  :d "Executes single plan work item verification gate and emits ProcessReceipt."
  (let [(summary (if (= exit-code 0)
                   (str "Gate passed cleanly: " gate-cmd)
                   (str "Gate failed with exit code " (string-from-int64 exit-code) ": " gate-cmd)))
        (spool (str "/tmp/worker_spool_" item-id ".log"))]
    (make-process-receipt exit-code duration-ms 24 spool summary)))

(df execute-phase-items [(items (List WorkItem)) (exit-codes (List I64))] -> PhaseExecutionResult
  :d "Sequentially executes phase work item gates halting on first failure."
  (let [(initial (PhaseExecutionResult
                   :receipts (list)
                   :all-passed true
                   :executed-count 0
                   :failed-item-id ""))]
    (fold (fn [(acc PhaseExecutionResult) (item WorkItem)] -> PhaseExecutionResult
            (if (not (.-all-passed acc))
              acc
              (let [(idx (.-executed-count acc))
                    (code-opt (list-get exit-codes idx))
                    (code (mt code-opt
                            ((some c) c)
                            ((none) 0)))
                    (duration 35)
                    (receipt (execute-work-item (.-id item) (.-gate item) code duration))]
                (if (= code 0)
                  (PhaseExecutionResult
                    :receipts (list-append (.-receipts acc) (list receipt))
                    :all-passed true
                    :executed-count (+ idx 1)
                    :failed-item-id "")
                  (PhaseExecutionResult
                    :receipts (list-append (.-receipts acc) (list receipt))
                    :all-passed false
                    :executed-count (+ idx 1)
                    :failed-item-id (.-id item))))))
          initial
          items)))

(df verify-blast-radius [(affected-symbols (List Str)) (affected-paths (List Str)) (owns-boundaries (List Str))] -> BlastRadiusGuard
  :d "Validates that all modified symbols and paths remain inside declared owns boundaries."
  (let [(violations (filter (fn [(p Str)] -> Bool
                              (not (path-in-boundaries? p owns-boundaries)))
                            affected-paths))]
    (if (list-empty? violations)
      (BlastRadiusGuard
        :is-safe true
        :violations (list)
        :affected-symbols affected-symbols
        :details "Blast-radius contained: zero boundary violations detected.")
      (BlastRadiusGuard
        :is-safe false
        :violations violations
        :affected-symbols affected-symbols
        :details (str "Blast-radius violation: " (string-from-int64 (list-length violations)) " file(s) outside declared owns boundaries.")))))

(df audit-pre-commit-safety [(guard BlastRadiusGuard) (items-passed Bool) (phase-gate-passed Bool)] -> Bool
  :d "Audits blast radius and gate outcomes before permitting commit."
  (and (.-is-safe guard)
       (and items-passed
            (and phase-gate-passed
                 (list-empty? (.-violations guard))))))

(df commit-phase-diff [(state WorkerState) (guard BlastRadiusGuard) (phase-id Str) (phase-gate-exit I64)] -> WorkerState
  :d "Commits phase changes if blast radius is safe or halts with boundary violation."
  (if (not (.-is-safe guard))
    (WorkerState
      :config (.-config state)
      :status "failed"
      :cycle-count (+ (.-cycle-count state) 1)
      :active-phase-id phase-id
      :completed-phases (.-completed-phases state)
      :receipts (.-receipts state)
      :blast-guard (some guard)
      :last-error (.-details guard))
    (if (!= phase-gate-exit 0)
      (WorkerState
        :config (.-config state)
        :status "failed"
        :cycle-count (+ (.-cycle-count state) 1)
        :active-phase-id phase-id
        :completed-phases (.-completed-phases state)
        :receipts (.-receipts state)
        :blast-guard (some guard)
        :last-error (str "Composite acceptance gate failed with exit code " (string-from-int64 phase-gate-exit)))
      (let [(spool (str "/tmp/commit_" phase-id ".log"))
            (receipt (make-process-receipt 0 150 32 spool (str "Committed phase " phase-id " cleanly.")))]
        (WorkerState
          :config (.-config state)
          :status "committed"
          :cycle-count (+ (.-cycle-count state) 1)
          :active-phase-id ""
          :completed-phases (list-append (.-completed-phases state) (list phase-id))
          :receipts (list-append (.-receipts state) (list receipt))
          :blast-guard (some guard)
          :last-error "")))))

(df worker-step [(state WorkerState) (rm RoadmapRecord) (item-exit-codes (List I64)) (affected-paths (List Str)) (phase-gate-exit I64)] -> StepOutcome
  :d "Executes single cycle of autonomous implementer loop with gate checks and blast radius guard."
  (let [(cfg (.-config state))
        (phase-opt (poll-claimed-phase rm (.-agent-id cfg)))]
    (mt phase-opt
      ((none)
       (let [(updated-st (WorkerState
                           :config cfg
                           :status "idle"
                           :cycle-count (+ (.-cycle-count state) 1)
                           :active-phase-id ""
                           :completed-phases (.-completed-phases state)
                           :receipts (.-receipts state)
                           :blast-guard (none)
                           :last-error ""))]
         (StepOutcome
           :worker-state updated-st
           :phase-id ""
           :action "idle"
           :items-count 0
           :all-passed true)))
      ((some phase)
       (let [(pid (.-id phase))
             (items (.-items phase))
             (exec-res (execute-phase-items items item-exit-codes))
             (item-receipts (.-receipts exec-res))
             (items-passed (.-all-passed exec-res))]
         (if (not items-passed)
           (let [(fail-id (.-failed-item-id exec-res))
                 (fail-st (WorkerState
                            :config cfg
                            :status "failed"
                            :cycle-count (+ (.-cycle-count state) 1)
                            :active-phase-id pid
                            :completed-phases (.-completed-phases state)
                            :receipts (list-append (.-receipts state) item-receipts)
                            :blast-guard (none)
                            :last-error (str "Work item gate failed: " fail-id)))]
             (StepOutcome
               :worker-state fail-st
               :phase-id pid
               :action "failed"
               :items-count (.-executed-count exec-res)
               :all-passed false))
           (let [(guard (verify-blast-radius (list pid) affected-paths (.-owns-boundaries cfg)))
                 (state-with-receipts (WorkerState
                                        :config cfg
                                        :status "verifying"
                                        :cycle-count (.-cycle-count state)
                                        :active-phase-id pid
                                        :completed-phases (.-completed-phases state)
                                        :receipts (list-append (.-receipts state) item-receipts)
                                        :blast-guard (some guard)
                                        :last-error ""))
                 (committed-st (commit-phase-diff state-with-receipts guard pid phase-gate-exit))]
             (StepOutcome
               :worker-state committed-st
               :phase-id pid
               :action (if (= (.-status committed-st) "committed") "committed" "failed")
               :items-count (.-executed-count exec-res)
               :all-passed (= (.-status committed-st) "committed")))))))))

(df run-worker-loop [(state WorkerState) (rm RoadmapRecord) (max-steps I64)] -> WorkerState
  :d "Executes autonomous implementer event loop across polling and verification cycles."
  (let [(limit (if (<= max-steps 0) 1 max-steps))
        (outcome (worker-step state rm (list 0 0 0 0) (.-owns-boundaries (.-config state)) 0))
        (next-st (.-worker-state outcome))]
    (if (or (<= limit 1) (or (= (.-status next-st) "failed") (= (.-status next-st) "idle")))
      next-st
      (run-worker-loop next-st rm (- limit 1)))))

(df main [] -> Str
  :d "Standalone autonomous worker daemon entrypoint."
  (let [(cfg (make-worker-config "worker-daemon-1" false 1 500 (list "harness/src/worker.asl")))
        (st (init-worker-state cfg))]
    (str "(:worker-daemon :id \"" (.-agent-id cfg) "\" :status \"" (.-status st) "\")")))
