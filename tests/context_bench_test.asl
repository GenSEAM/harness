(module asl-harness/tests/context-bench-test
  :d "Unit and falsifiable verification suite for variational context benchmark engine and amnesia degradation audit."
  :x [test-bench-task-creation
      test-strategy-simulation-tokens
      test-variational-comparison-and-savings
      test-amnesia-interception-across-strategies
      test-report-formatting-asn
      run-tests]
  :i [(context_bench :a cb)
      (context_assembler :a ca)])

(df test-bench-task-creation [] -> Bool
  :d "Verifies ContextBenchTask construction and canonical tasks generator."
  (let [(tasks (cb/standard-benchmark-tasks))
        (t1 (option-or (list-head tasks) (cb/make-bench-task "" "" 0 (list) (list) false)))]
    (do
      (assert (= (list-length tasks) 2) "Tasks list length must equal 2")
      (assert (= (.-task-id t1) "CTX-BENCH-01") "First task ID must match CTX-BENCH-01")
      (assert (= (.-total-steps t1) 4) "First task must have 4 steps")
      (assert (= (list-length (.-required-facts t1)) 2) "First task must have 2 required facts")
      (assert (not (.-hard-challenge t1)) "First task should not be hard challenge")
      true)))

(df test-strategy-simulation-tokens [] -> Bool
  :d "Verifies simulation under S1 Baseline, S2 Receipts, S3 JIT, and S4 Agent-Directed."
  (let [(tasks (cb/standard-benchmark-tasks))
        (t1 (option-or (list-head tasks) (cb/make-bench-task "" "" 0 (list) (list) false)))
        (m-base (cb/simulate-task-under-strategy t1 "baseline" 4096))
        (m-rcpt (cb/simulate-task-under-strategy t1 "receipts" 4096))
        (m-jit (cb/simulate-task-under-strategy t1 "jit-memory" 4096))
        (m-agent (cb/simulate-task-under-strategy t1 "agent-directed" 4096))]
    (do
      (assert (= (.-strategy m-base) "baseline") "m-base strategy must be baseline")
      (assert (= (.-strategy m-rcpt) "receipts") "m-rcpt strategy must be receipts")
      (assert (= (.-strategy m-agent) "agent-directed") "m-agent strategy must be agent-directed")
      (assert (.-passed m-base) "m-base must pass solvable task")
      (assert (.-passed m-rcpt) "m-rcpt must pass solvable task")
      (assert (.-passed m-agent) "m-agent must pass solvable task")
      (assert (< (.-prompt-tokens m-rcpt) (.-prompt-tokens m-base)) "Receipts tokens must be less than baseline")
      (assert (< (.-prompt-tokens m-agent) (.-prompt-tokens m-base)) "Agent-directed tokens must be less than baseline")
      (assert (not (.-amnesia-detected m-base)) "Baseline must not suffer amnesia")
      (assert (not (.-amnesia-detected m-rcpt)) "Receipts must retain facts without amnesia")
      (assert (not (.-amnesia-detected m-agent)) "Agent-directed must retain facts without amnesia")
      (assert (> (.-duration-ms m-base) 0) "Duration must be positive")
      (assert (string-contains? (.-receipt m-agent) ":strategy \"agent-directed\"") "Receipt must mention agent-directed")
      true)))

(df test-variational-comparison-and-savings [] -> Bool
  :d "Verifies comparison report computation and compaction percentages."
  (let [(tasks (cb/standard-benchmark-tasks))
        (t1 (option-or (list-head tasks) (cb/make-bench-task "" "" 0 (list) (list) false)))
        (rep (cb/compare-strategies-on-task t1 4096))]
    (do
      (assert (= (.-task-id rep) "CTX-BENCH-01") "Report task-id must match")
      (assert (> (.-receipts-savings-pct rep) 10.0) "Receipts savings must exceed 10%")
      (assert (> (.-agent-savings-pct rep) 15.0) "Agent savings must exceed 15%")
      (assert (.-amnesia-free rep) "Report must indicate amnesia-free status")
      (assert (or (= (.-winner rep) "agent-directed") (= (.-winner rep) "receipts")) "Winner must be agent-directed or receipts")
      (assert (string-contains? (.-summary rep) "CTX-BENCH-01") "Summary must reference task ID")
      true)))

(df test-amnesia-interception-across-strategies [] -> Bool
  :d "Audits fact retention and amnesia detection under constrained token ceilings."
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 50 "System"))
        (b-fact (ca/make-context-block "critical" "task-spec" 100 "Critical invariant [fact: crypto-seed-key-777]"))
        (task-amnesia (cb/make-bench-task
                        "AMNESIA-PROBE-01"
                        "Fact Retention Under Compaction"
                        5
                        (list b-sys b-fact)
                        (list "crypto-seed-key-777")
                        false))
        (res-rcpt (cb/simulate-task-under-strategy task-amnesia "receipts" 4096))
        (res-agent (cb/simulate-task-under-strategy task-amnesia "agent-directed" 4096))]
    (do
      (assert (not (.-amnesia-detected res-rcpt)) "Strategy 2 Receipts must preserve critical fact")
      (assert (not (.-amnesia-detected res-agent)) "Strategy 4 Agent-Directed must preserve critical fact")
      (assert (.-passed res-rcpt) "Receipts must pass amnesia probe")
      (assert (.-passed res-agent) "Agent-directed must pass amnesia probe")
      true)))

(df test-report-formatting-asn [] -> Bool
  :d "Verifies formatted ASN serialization for variational report."
  (let [(tasks (cb/standard-benchmark-tasks))
        (t1 (option-or (list-head tasks) (cb/make-bench-task "" "" 0 (list) (list) false)))
        (rep (cb/compare-strategies-on-task t1 4096))
        (asn-str (cb/format-variational-report rep))]
    (do
      (assert (string-starts-with? asn-str "(:context-variational-report") "Report must start with :context-variational-report")
      (assert (string-contains? asn-str ":baseline-tokens") "Report must include :baseline-tokens")
      (assert (string-contains? asn-str ":receipts-savings-pct") "Report must include :receipts-savings-pct")
      (assert (string-contains? asn-str ":agent-directed-tokens") "Report must include :agent-directed-tokens")
      (assert (string-ends-with? asn-str ")") "Report must end with closing paren")
      true)))

(df run-tests [] -> Bool
  :d "Executes full context bench test suite."
  (and (test-bench-task-creation)
       (and (test-strategy-simulation-tokens)
            (and (test-variational-comparison-and-savings)
                 (and (test-amnesia-interception-across-strategies)
                      (test-report-formatting-asn))))))
