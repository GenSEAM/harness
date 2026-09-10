(module asl-harness/multi-client-runner-test
  :d "Unit verification test suite for Claude Code and Antigravity Multi-Client Runner"
  :x [test-client-targets
      test-injection-configs
      test-canonical-tasks
      test-injection-payload-formatting
      test-simulation-and-safety-blocking
      test-comparative-metrics-evaluation
      test-receipt-and-summary-formatting
      run-tests]
  :i [(multi_client_runner :a mcr)])

(df test-client-targets [] -> Bool
  :d "Verifies Claude Code, agy, and Eddie target definitions and concurrency limit profiles"
  (let [(claude (mcr/make-claude-client))
        (agy (mcr/make-antigravity-client))
        (agy2 (mcr/make-agy-client))
        (eddie (mcr/make-eddie-client))
        (prof-agy (mcr/get-client-concurrency-profile "agy"))
        (prof-claude (mcr/get-client-concurrency-profile "claude-code"))
        (prof-eddie (mcr/get-client-concurrency-profile "eddie"))]
    (assert (= (.-id claude) "claude-code") "Claude ID must be claude-code")
    (= (.-engine claude) "claude-3-7-sonnet")
    (assert (= (.-prompt-channel claude) "CLAUDE.md") "Claude prompt channel must be CLAUDE.md")
    (assert (.-supports-mcp claude) "Claude must support MCP")
    (assert (= (.-id agy) "agy") "Antigravity ID must be agy")
    (assert (= (.-name agy) "agy") "Antigravity name must be agy")
    (assert (= (.-id agy2) "agy") "agy2 ID must be agy")
    (= (.-engine agy) "gemini-2-pro")
    (assert (= (.-prompt-channel agy) "<RULE[user_global]>") "Antigravity channel must be RULE[user_global]")
    (assert (.-supports-staged-vfs agy) "Antigravity must support staged VFS")
    (assert (= (.-id eddie) "eddie") "Eddie ID must be eddie")
    (assert (= (.-name eddie) "Eddie (Native ASL)") "Eddie name must be Eddie")
    (assert (= (.-soft-limit prof-agy) 4) "AntiGravity soft limit must be 4")
    (assert (= (.-hard-limit prof-agy) 6) "AntiGravity hard limit must be 6")
    (assert (= (.-flexibility prof-agy) "bounded") "AntiGravity profile must be bounded")
    (assert (= (.-soft-limit prof-claude) 2) "Claude Code soft limit must be 2")
    (assert (= (.-hard-limit prof-claude) 3) "Claude Code hard limit must be 3")
    (assert (= (.-flexibility prof-claude) "strict") "Claude Code profile must be strict")
    (assert (= (.-soft-limit prof-eddie) 8) "Eddie soft limit must be 8")
    (assert (= (.-hard-limit prof-eddie) 16) "Eddie hard limit must be 16")
    (assert (= (.-flexibility prof-eddie) "elastic") "Eddie profile must be elastic")
    true))

(df test-injection-configs [] -> Bool
  :d "Verifies baseline vs paradigm-injected configurations"
  (let [(base (mcr/make-baseline-config))
        (inj (mcr/make-injected-config))]
    (assert (= (.-arm-mode base) "baseline") "Baseline arm mode must be baseline")
    (assert (not (.-with-ground-truth base)) "Baseline must not enforce ground truth")
    (assert (not (.-with-circuit-breaker base)) "Baseline must not equip circuit breaker")
    (assert (= (.-max-tokens base) 100000) "Baseline max tokens is 100000")
    (assert (= (.-arm-mode inj) "paradigm-injected") "Injected arm mode must be paradigm-injected")
    (assert (.-with-ground-truth inj) "Injected arm must enforce ground truth")
    (assert (.-with-asn-compaction inj) "Injected arm must enable ASN compaction")
    (assert (.-with-circuit-breaker inj) "Injected arm must equip circuit breaker")
    (assert (= (.-max-tokens inj) 35000) "Injected max tokens ceiling is 35000")
    (assert (.-with-blast-radius-guard inj) "Injected arm must check blast radius")
    (assert (.-with-abort-controller inj) "Injected arm must equip abort controller")
    true))

(df test-canonical-tasks [] -> Bool
  :d "Verifies canonical evaluation tasks SWE-006, REF-012, and GATE-004"
  (let [(tasks (mcr/make-canonical-benchmark-tasks))]
    (assert (= (list-length tasks) 3) "Must define exactly 3 canonical benchmark tasks")
    (let [(t1 (option-or (list-head tasks) (mcr/BenchmarkTask :task-id "" :category "" :title "" :description "" :baseline-tokens 0 :verification-gate "")))]
      (assert (= (.-task-id t1) "SWE-006") "Task 1 must be SWE-006")
      (assert (= (.-category t1) "blast-radius") "Task 1 category must be blast-radius")
      (assert (= (.-baseline-tokens t1) 32000) "SWE-006 baseline tokens must be 32000")
      true)))

(df test-injection-payload-formatting [] -> Bool
  :d "Verifies injection payload formatting for both target channels"
  (let [(claude (mcr/make-claude-client))
        (agy (mcr/make-antigravity-client))
        (inj (mcr/make-injected-config))
        (claude-payload (mcr/build-injection-payload claude inj))
        (agy-payload (mcr/build-injection-payload agy inj))]
    (assert (string-contains? claude-payload "CLAUDE.md") "Claude payload must reference CLAUDE.md")
    (assert (string-contains? claude-payload ":rule (:ground-truth") "Claude payload must inject ground truth")
    (assert (string-contains? agy-payload "RULE[user_global]") "Antigravity payload must reference RULE[user_global]")
    (assert (string-contains? agy-payload "ASL_TOOLBELT_START") "Antigravity payload must activate ASL toolbelt")
    true))

(df test-simulation-and-safety-blocking [] -> Bool
  :d "Verifies simulated runs and intercepted destructive actions"
  (let [(claude (mcr/make-claude-client))
        (base-cfg (mcr/make-baseline-config))
        (inj-cfg (mcr/make-injected-config))
        (tasks (mcr/make-canonical-benchmark-tasks))
        (t1 (option-or (list-head tasks) (mcr/BenchmarkTask :task-id "" :category "" :title "" :description "" :baseline-tokens 0 :verification-gate "")))
        (base-run (mcr/simulate-client-run claude base-cfg t1))
        (inj-run (mcr/simulate-client-run claude inj-cfg t1))]
    (assert (= (.-tokens-consumed base-run) 32000) "Baseline must consume full 32000 tokens")
    (assert (not (.-resolved base-run)) "Baseline without harness fails SWE-006")
    (assert (= (.-destructive-attempts-blocked base-run) 0) "Baseline does not block destructive attempts")
    (assert (.-resolved inj-run) "Injected run resolves task successfully")
    (assert (< (.-tokens-consumed inj-run) 10000) "Injected tokens must be under 10000")
    (assert (> (.-token-savings-percent inj-run) 70.0) "Token savings must exceed 70%")
    (assert (= (.-destructive-attempts-blocked inj-run) 2) "Must intercept 2 destructive actions on SWE-006")
    true))

(df test-comparative-metrics-evaluation [] -> Bool
  :d "Verifies metrics aggregation across runs"
  (let [(agy (mcr/make-antigravity-client))
        (base-cfg (mcr/make-baseline-config))
        (inj-cfg (mcr/make-injected-config))
        (tasks (mcr/make-canonical-benchmark-tasks))
        (t1 (option-or (list-head tasks) (mcr/BenchmarkTask :task-id "" :category "" :title "" :description "" :baseline-tokens 0 :verification-gate "")))
        (base-r1 (mcr/simulate-client-run agy base-cfg t1))
        (inj-r1 (mcr/simulate-client-run agy inj-cfg t1))
        (metric (mcr/evaluate-client-metrics agy (list base-r1) (list inj-r1)))]
    (assert (= (.-baseline-solve-rate metric) 0.0) "Baseline solve rate is 0.0")
    (assert (= (.-injected-solve-rate metric) 1.0) "Injected solve rate is 1.0")
    (assert (> (.-token-reduction-ratio metric) 3.5) "Token reduction ratio must exceed 3.5x")
    (assert (= (.-safety-violations-prevented metric) 2) "Must record 2 prevented violations")
    (assert (> (.-efficiency-gain-percent metric) 70.0) "Efficiency gain must exceed 70%")
    true))

(df test-receipt-and-summary-formatting [] -> Bool
  :d "Verifies serialized receipts and summary formatting"
  (let [(claude (mcr/make-claude-client))
        (agy (mcr/make-antigravity-client))
        (m1 (mcr/ClientComparisonMetric
              :client-id "claude-code"
              :baseline-solve-rate 0.0
              :injected-solve-rate 1.0
              :baseline-avg-tokens 32000
              :injected-avg-tokens 8320
              :token-reduction-ratio 3.84
              :safety-violations-prevented 2
              :efficiency-gain-percent 74.0))
        (m2 (mcr/ClientComparisonMetric
              :client-id "agy"
              :baseline-solve-rate 0.0
              :injected-solve-rate 1.0
              :baseline-avg-tokens 32000
              :injected-avg-tokens 8320
              :token-reduction-ratio 3.84
              :safety-violations-prevented 2
              :efficiency-gain-percent 74.0))
        (rcpt (mcr/format-multi-client-receipt (list m1 m2)))
        (summary (mcr/format-runner-summary m1 m2))]
    (assert (string-contains? rcpt ":multi-client-benchmark-receipt") "Receipt must contain header")
    (assert (string-contains? rcpt "claude-code") "Receipt must list claude-code")
    (assert (string-contains? rcpt "agy") "Receipt must list agy")
    (assert (string-contains? summary ":multi-client-runner-summary") "Summary must contain header")
    (assert (string-contains? summary ":claude-code") "Summary must contain claude-code section")
    (assert (string-contains? summary ":agy") "Summary must contain agy section")
    true))

(df test-agent-launch-preparation [] -> Bool
  :d "Verifies safe agent launch configuration and payload formatting"
  (let [(cfg-agy (mcr/make-agent-launch-config "agy"))
        (cfg-claude (mcr/make-agent-launch-config "claude-code"))
        (dir-agy (mcr/format-launch-directive cfg-agy))
        (dir-claude (mcr/format-launch-directive cfg-claude))]
    (assert (= (.-client-id cfg-agy) "agy") "Config client-id must be agy")
    (assert (.-stash-agents-md cfg-agy) "Stash AGENTS.md must be true by default")
    (assert (.-inject-toolbelt cfg-agy) "Inject toolbelt must be true by default")
    (assert (.-enforce-ground-truth cfg-agy) "Enforce ground truth must be true by default")
    (assert (string-contains? dir-agy ":client \"agy\"") "Launch directive must target agy")
    (assert (string-contains? dir-agy ":consultative-agents-md true") "Launch directive must set consultative mode")
    (assert (string-contains? dir-agy "ASL_TOOLBELT_START") "Launch directive must include toolbelt")
    (assert (string-contains? dir-claude ":client \"claude-code\"") "Claude directive must target claude-code")
    true))

(df test-orchestrator-configuration-and-directive [] -> Bool
  :d "Verifies orchestrator configuration, model selection, and multi-agent directives"
  (let [(def-orch (mcr/default-orchestrator-config))
        (cfg-orch (mcr/make-orchestrator-launch-config "agy" "gemini-3.8-flash" "high"))
        (orch-dir (mcr/format-orchestrator-directive def-orch))
        (launch-dir (mcr/format-launch-directive cfg-orch))]
    (assert (.-enabled def-orch) "Default orchestrator must be enabled")
    (assert (= (.-model-name def-orch) "gemini-3.8-flash") "Default orchestrator model must be gemini-3.8-flash")
    (assert (= (.-reasoning-level def-orch) "high") "Default reasoning level must be high")
    (assert (= (.-soft-limit def-orch) 4) "Default soft limit must be 4")
    (assert (= (.-hard-limit def-orch) 6) "Default hard limit must be 6")
    (assert (.-code-execution-enabled def-orch) "Default code execution must be enabled")
    (assert (.-multi-project-enabled def-orch) "Default multi project must be enabled")
    (assert (= (.-orchestration-target def-orch) "sub-agents") "Default orchestration target must be sub-agents")
    (assert (not (.-separate-agents-enabled def-orch)) "Separate agents feature flag must be false by default")
    (assert (.-minimal-orchestrator def-orch) "Minimal orchestrator must be true by default")
    (assert (= (.-research-tier def-orch) "flash") "Research tier must be flash")
    (assert (= (.-planning-tier def-orch) "pro") "Planning tier must be pro")
    (assert (= (.-execution-tier def-orch) "inherit") "Execution tier must be inherit")
    (assert (= (.-upgrade-path def-orch) "gemini-next") "Upgrade path must be gemini-next")
    (assert (string-contains? orch-dir ":rule :orchestrator") "Directive must declare orchestrator rule")
    (assert (string-contains? orch-dir "gemini-3.8-flash") "Directive must reference gemini-3.8-flash")
    (assert (string-contains? orch-dir ":soft-limit 4") "Directive must declare soft limit")
    (assert (string-contains? orch-dir ":hard-limit 6") "Directive must declare hard limit")
    (assert (string-contains? orch-dir ":code-execution true") "Directive must declare code execution")
    (assert (string-contains? orch-dir ":multi-project-orchestration true") "Directive must declare multi-project")
    (assert (string-contains? orch-dir ":orchestration-target \"sub-agents\"") "Directive must declare sub-agents target")
    (assert (string-contains? orch-dir "Baseline delegation: Use Antigravity sub-agents") "Directive must mandate sub-agents baseline")
    (assert (string-contains? orch-dir "Context hygiene: Keep orchestrator context minimal") "Directive must mandate context hygiene")
    (assert (string-contains? orch-dir "invoke_subagent") "Directive must mandate invoke_subagent")
    (assert (string-contains? launch-dir ":orchestrator-mode true") "Launch directive must declare orchestrator-mode true")
    (assert (string-contains? launch-dir "ORCHESTRATOR_START") "Launch directive must include ORCHESTRATOR_START")
    true))

(df test-orchestrator-presets-and-queue [] -> Bool
  :d "Verifies pre-calibrated orchestrator presets and in-memory queue state transitions"
  (let [(p-res (mcr/make-orchestrator-preset "fast-research"))
        (p-arch (mcr/make-orchestrator-preset "deep-architecture"))
        (p-audit (mcr/make-orchestrator-preset "audit-hardening"))
        (p-canvas (mcr/make-orchestrator-preset "canvas-interactive"))
        (q0 (mcr/make-orchestrator-queue "orch-sess-1" 4))
        (t1 (mcr/OrchestratorTaskItem
              :task-id "task-01"
              :title "Research CodePod and Canvas Scopes"
              :assigned-role "researcher"
              :model-tier "flash"
              :state "queued"
              :retry-count 0
              :verification-gate "asl test harness/tests/coding-test.asl"))
        (t2 (mcr/OrchestratorTaskItem
              :task-id "task-02"
              :title "Plan Multi-Agent Wave DAG"
              :assigned-role "planner"
              :model-tier "pro"
              :state "queued"
              :retry-count 0
              :verification-gate "asl check harness/results/voice_pipeline_specification.asn"))
        (q1 (mcr/enqueue-orchestrator-task q0 t1))
        (q2 (mcr/enqueue-orchestrator-task q1 t2))
        (q3 (mcr/advance-task-state q2 "task-01" "completed"))]
    (assert (= (.-reasoning-level p-res) "low") "Fast research preset reasoning must be low")
    (assert (= (.-soft-limit p-res) 4) "Fast research soft limit must be 4")
    (assert (= (.-hard-limit p-res) 6) "Fast research hard limit must be 6")
    (assert (= (.-max-subagents p-res) 6) "Fast research concurrency must be 6")
    (assert (= (.-reasoning-level p-arch) "max") "Deep architecture preset reasoning must be max")
    (assert (= (.-soft-limit p-arch) 2) "Deep architecture soft limit must be 2")
    (assert (= (.-hard-limit p-arch) 4) "Deep architecture hard limit must be 4")
    (assert (= (.-max-subagents p-arch) 4) "Deep architecture concurrency must be 4")
    (assert (= (.-reasoning-level p-audit) "high") "Audit preset reasoning must be high")
    (assert (= (.-reasoning-level p-canvas) "medium") "Canvas preset reasoning must be medium")
    (assert (= (mcr/count-tasks-by-state q2 "queued") 2) "Initial queued count must be 2")
    (assert (= (mcr/count-tasks-by-state q3 "completed") 1) "Completed task count must be 1")
    (assert (= (mcr/count-tasks-by-state q3 "queued") 1) "Remaining queued task count must be 1")
    true))

(df run-tests [] -> Bool
  :d "Executes all multi-client runner test assertions"
  (and (test-client-targets)
       (and (test-injection-configs)
            (and (test-canonical-tasks)
                 (and (test-injection-payload-formatting)
                      (and (test-simulation-and-safety-blocking)
                           (and (test-comparative-metrics-evaluation)
                                (and (test-receipt-and-summary-formatting)
                                     (and (test-agent-launch-preparation)
                                          (and (test-orchestrator-configuration-and-directive)
                                               (test-orchestrator-presets-and-queue)))))))))))
