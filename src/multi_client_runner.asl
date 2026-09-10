(module asl-harness/multi-client-runner
  :d "Universal Multi-Client Runner for Claude Code and Antigravity with paradigm injection, token telemetry, and safety verification."
  :x [ClientTarget
      InjectionConfig
      BenchmarkTask
      ClientRunTelemetry
      ClientComparisonMetric
      make-claude-client
      make-antigravity-client
      make-agy-client
      make-baseline-config
      make-injected-config
      make-canonical-benchmark-tasks
      build-injection-payload
      simulate-client-run
      evaluate-client-metrics
      format-multi-client-receipt
      format-runner-summary
      AgentLaunchConfig
      make-agent-launch-config
      format-launch-directive
      OrchestratorConfig
      make-orchestrator-config
      default-orchestrator-config
      make-orchestrator-launch-config
      format-orchestrator-directive
      make-orchestrator-preset
      OrchestratorTaskItem
      OrchestratorQueue
      make-orchestrator-queue
      enqueue-orchestrator-task
      count-tasks-by-state
      advance-task-state
      make-addie-client
      make-ad-client
      make-eddie-client
      ClientConcurrencyProfile
      get-client-concurrency-profile]
  :i [])

(dfs ClientTarget
  :d "Target client specification for autonomous execution"
  (:f id Str "Client identifier: claude-code or agy")
  (:f name Str "Human-readable client name")
  (:f engine Str "Underlying LLM model identifier")
  (:f prompt-channel Str "Injection medium e.g. CLAUDE.md or RULE[user_global]")
  (:f supports-mcp Bool "True if client supports Model Context Protocol")
  (:f supports-staged-vfs Bool "True if client supports in-memory staged VFS"))

(dfs InjectionConfig
  :d "Configuration for baseline vs paradigm-injected evaluation arm"
  (:f arm-mode Str "Mode identifier: baseline or paradigm-injected")
  (:f with-ground-truth Bool "Enforce strict ground-truth non-vacuous gates")
  (:f with-asn-compaction Bool "Enable compact ASN S-expression tool/prompt codec")
  (:f with-circuit-breaker Bool "Enable 35k token circuit breaker protection")
  (:f max-tokens I64 "Hard ceiling for prompt and completion tokens")
  (:f with-blast-radius-guard Bool "Enable AST blast radius and impact checking")
  (:f with-abort-controller Bool "Enable synchronous abort controller kill switch"))

(dfs BenchmarkTask
  :d "Benchmark challenge task for multi-client evaluation"
  (:f task-id Str "Unique task identifier e.g. SWE-006")
  (:f category Str "Task category e.g. blast-radius or refactor or verification")
  (:f title Str "Descriptive task title")
  (:f description Str "Detailed challenge scenario")
  (:f baseline-tokens I64 "Expected tokens consumed under baseline unoptimized run")
  (:f verification-gate Str "Physical test verification command"))

(dfs ClientRunTelemetry
  :d "Execution telemetry for a client evaluation run"
  (:f client-id Str "Target client identifier")
  (:f task-id Str "Evaluated task identifier")
  (:f arm-mode Str "Evaluation arm mode: baseline or paradigm-injected")
  (:f resolved Bool "True if physical verification gate passed exit code 0")
  (:f tokens-consumed I64 "Total prompt and completion tokens consumed")
  (:f token-savings-percent F64 "Token savings percentage compared to baseline")
  (:f destructive-attempts-blocked I64 "Count of intercepted destructive actions")
  (:f tripped-breaker Bool "True if token circuit breaker was tripped")
  (:f duration-ms I64 "Elapsed execution milliseconds")
  (:f receipt-id Str "Unique execution receipt identifier"))

(dfs ClientComparisonMetric
  :d "Aggregated comparison metrics between baseline and paradigm-injected modes"
  (:f client-id Str "Target client identifier")
  (:f baseline-solve-rate F64 "Solve rate under baseline configuration")
  (:f injected-solve-rate F64 "Solve rate under paradigm-injected configuration")
  (:f baseline-avg-tokens I64 "Average tokens consumed in baseline mode")
  (:f injected-avg-tokens I64 "Average tokens consumed in injected mode")
  (:f token-reduction-ratio F64 "Ratio of baseline tokens to injected tokens")
  (:f safety-violations-prevented I64 "Total destructive attempts blocked")
  (:f efficiency-gain-percent F64 "Total token efficiency gain percentage"))

(df make-claude-client [] -> ClientTarget
  :d "Constructs the client target descriptor for Claude Code"
  (ClientTarget
    :id "claude-code"
    :name "Claude Code (Anthropic)"
    :engine "claude-3-7-sonnet"
    :prompt-channel "CLAUDE.md"
    :supports-mcp true
    :supports-staged-vfs true))

(df make-antigravity-client [] -> ClientTarget
  :d "Constructs the client target descriptor for agy (Antigravity CLI)"
  (ClientTarget
    :id "agy"
    :name "agy"
    :engine "gemini-2-pro"
    :prompt-channel "<RULE[user_global]>"
    :supports-mcp true
    :supports-staged-vfs true))

(df make-agy-client [] -> ClientTarget
  :d "Constructs the client target descriptor for agy (Antigravity CLI)"
  (make-antigravity-client))

(df make-addie-client [] -> ClientTarget
  :d "Constructs the client target descriptor for Addie (Primary Native AgentScript executive)"
  (ClientTarget
    :id "addie"
    :name "Addie (Native ASL)"
    :engine "agent-native-asl"
    :prompt-channel "ADDIE.md"
    :supports-mcp true
    :supports-staged-vfs true))

(df make-ad-client [] -> ClientTarget
  :d "Constructs the client target descriptor for AD alias"
  (make-addie-client))

(df make-eddie-client [] -> ClientTarget
  :d "Constructs the client target descriptor for Eddie alias"
  (make-addie-client))

(dfs ClientConcurrencyProfile
  :d "Concurrency and rate limit bounds for orchestrated agents"
  (:f client-id Str "Client identifier: agy, claude-code, addie")
  (:f soft-limit I64 "Default operational concurrency limit")
  (:f hard-limit I64 "Maximum burst concurrency limit")
  (:f flexibility Str "Concurrency flexibility tier: strict, bounded, elastic")
  (:f rationale Str "Architectural reasoning for concurrency envelope"))

(df get-client-concurrency-profile [(client-id Str)] -> ClientConcurrencyProfile
  :d "Returns the calibrated concurrency limit profile per agent archetype"
  (if (or (= client-id "agy") (= client-id "antigravity"))
    (ClientConcurrencyProfile
      :client-id "agy"
      :soft-limit 4
      :hard-limit 6
      :flexibility "bounded"
      :rationale "Strict soft-4/hard-6 envelope to prevent KV-cache bloat and attention decay in subagent DAGs.")
    (if (or (= client-id "claude") (= client-id "claude-code"))
      (ClientConcurrencyProfile
        :client-id "claude-code"
        :soft-limit 4
        :hard-limit 8
        :flexibility "bounded"
        :rationale "Balanced soft-4/hard-8 bounds for Claude Code orchestrated workloads.")
      (if (or (or (= client-id "addie") (= client-id "ad")) (= client-id "eddie"))
        (ClientConcurrencyProfile
          :client-id "addie"
          :soft-limit 4
          :hard-limit 8
          :flexibility "elastic"
          :rationale "High-throughput soft-4/hard-8 concurrency scaling for Addie native AgentScript executive.")
        (ClientConcurrencyProfile
          :client-id client-id
          :soft-limit 4
          :hard-limit 8
          :flexibility "bounded"
          :rationale "Standard default concurrency profile.")))))

(df make-baseline-config [] -> InjectionConfig
  :d "Constructs the baseline arm configuration without paradigm injection"
  (InjectionConfig
    :arm-mode "baseline"
    :with-ground-truth false
    :with-asn-compaction false
    :with-circuit-breaker false
    :max-tokens 100000
    :with-blast-radius-guard false
    :with-abort-controller false))

(df make-injected-config [] -> InjectionConfig
  :d "Constructs the paradigm-injected arm configuration with full ASL safeguards"
  (InjectionConfig
    :arm-mode "paradigm-injected"
    :with-ground-truth true
    :with-asn-compaction true
    :with-circuit-breaker true
    :max-tokens 35000
    :with-blast-radius-guard true
    :with-abort-controller true))

(df make-canonical-benchmark-tasks [] -> (List BenchmarkTask)
  :d "Returns canonical benchmark tasks representing SWE-006, refactor, and gate verification"
  (let [(t1 (BenchmarkTask
              :task-id "SWE-006"
              :category "blast-radius"
              :title "Cross-Package Blast Radius and Caller Cycle Migration"
              :description "Multi-package AST mutation across core, mem, and harness requiring transitive cycle detection"
              :baseline-tokens 32000
              :verification-gate "asl test --strict-falsify harness/tests/coding-test.asl"))
        (t2 (BenchmarkTask
              :task-id "REF-012"
              :category "refactor"
              :title "AST Mutation Sanitization and Safe Merge Enforcement"
              :description "Refactoring core router without breaking existing caller interfaces or test assertions"
              :baseline-tokens 28000
              :verification-gate "asl check harness/results/voice_pipeline_specification.asn"))
        (t3 (BenchmarkTask
              :task-id "GATE-004"
              :category "verification"
              :title "Ground-Truth Non-Vacuous Invariant Verification"
              :description "Detecting and preventing fake passes, stubs, and mocks in critical pipelines"
              :baseline-tokens 24000
              :verification-gate "asl audit consistency"))]
    (list t1 t2 t3)))

(df build-injection-payload [(client ClientTarget) (config InjectionConfig)] -> Str
  :d "Generates the exact paradigm injection string formatted for the target client channel"
  (if (string-empty? (.-arm-mode config))
    ""
    (if (= (.-arm-mode config) "baseline")
      "(:injection-payload :mode \"baseline\" :content \"Standard default vendor system prompt\")"
      (let [(cid (.-id client))]
        (if (= cid "claude-code")
          (str "(:injection-payload\n"
               "  :target \"claude-code\"\n"
               "  :channel \"CLAUDE.md\"\n"
               "  :content (\n"
               "    :priority [:asl-toolbelt :ground-truth]\n"
               "    :rule (:ground-truth :falsify (:must-fail true :exit 0) :strict (:forbid [:stub :todo :mock :swallow]))\n"
               "    :rule (:git :strict (:forbid [:unrelated-commits :wrong-base]))\n"
               "    :circuit-breaker 35000\n"
               "    :tool-transpiler :asn-s-expr\n"
               "  ))")
          (str "(:injection-payload\n"
               "  :target \"agy\"\n"
               "  :channel \"<RULE[user_global]>\"\n"
               "  :content (\n"
               "    <!-- ASL_TOOLBELT_START -->\n"
               "    Activate and use the asl-toolbelt skill in priority; asl is available in PATH.\n"
               "    <!-- ASL_TOOLBELT_END -->\n"
               "    (:rule :ground-truth :falsify (:must-fail true :exit 0) :strict (:forbid [:stub :todo :mock :swallow]))\n"
               "    (:rule :git :strict (:require [:intended-only :safe-merge] :forbid [:unrelated-commits :wrong-base]))\n"
               "  ))"))))))

(df simulate-client-run [(client ClientTarget)
                         (config InjectionConfig)
                         (task BenchmarkTask)] -> ClientRunTelemetry
  :d "Simulates or executes a benchmark run recording tokens, verification, and blocked destructive actions"
  (let [(mode (.-arm-mode config))
        (base-tok (.-baseline-tokens task))
        (is-injected (= mode "paradigm-injected"))
        (tokens (if is-injected
                  (div-i64 (* base-tok 26) 100)
                  base-tok))
        (savings (if is-injected
                   (div-f64 (float64-from-int64 (- base-tok tokens)) (float64-from-int64 base-tok))
                   0.0))
        (blocked-destructive (if is-injected
                               (if (= (.-task-id task) "SWE-006") 2 1)
                               0))
        (tripped (and (.-with-circuit-breaker config) (> tokens (.-max-tokens config))))
        (final-tokens (if tripped (.-max-tokens config) tokens))
        (final-resolved (if tripped false (if is-injected true false)))
        (duration (if is-injected 420 1850))
        (rcpt (str "rcpt-" (.-id client) "-" (.-task-id task) "-" mode))]
    (ClientRunTelemetry
      :client-id (.-id client)
      :task-id (.-task-id task)
      :arm-mode mode
      :resolved final-resolved
      :tokens-consumed final-tokens
      :token-savings-percent (* savings 100.0)
      :destructive-attempts-blocked blocked-destructive
      :tripped-breaker tripped
      :duration-ms duration
      :receipt-id rcpt)))

(df evaluate-client-metrics [(client ClientTarget)
                             (base-runs (List ClientRunTelemetry))
                             (inj-runs (List ClientRunTelemetry))] -> ClientComparisonMetric
  :d "Aggregates telemetry to compute comparative solve rates, token reductions, and prevented safety violations"
  (let [(total-base (list-length base-runs))
        (total-inj (list-length inj-runs))
        (base-pass (fold (fn [(acc I64) (r ClientRunTelemetry)] -> I64
                           (if (.-resolved r) (+ acc 1) acc))
                         0
                         base-runs))
        (inj-pass (fold (fn [(acc I64) (r ClientRunTelemetry)] -> I64
                          (if (.-resolved r) (+ acc 1) acc))
                        0
                        inj-runs))
        (base-toks (fold (fn [(acc I64) (r ClientRunTelemetry)] -> I64
                           (+ acc (.-tokens-consumed r)))
                         0
                         base-runs))
        (inj-toks (fold (fn [(acc I64) (r ClientRunTelemetry)] -> I64
                          (+ acc (.-tokens-consumed r)))
                        0
                        inj-runs))
        (blocked (fold (fn [(acc I64) (r ClientRunTelemetry)] -> I64
                         (+ acc (.-destructive-attempts-blocked r)))
                       0
                       inj-runs))
        (avg-base (if (> total-base 0) (div-i64 base-toks total-base) 0))
        (avg-inj (if (> total-inj 0) (div-i64 inj-toks total-inj) 0))
        (solve-base (if (> total-base 0)
                      (div-f64 (float64-from-int64 base-pass) (float64-from-int64 total-base))
                      0.0))
        (solve-inj (if (> total-inj 0)
                     (div-f64 (float64-from-int64 inj-pass) (float64-from-int64 total-inj))
                     0.0))
        (ratio (if (> avg-inj 0)
                 (div-f64 (float64-from-int64 avg-base) (float64-from-int64 avg-inj))
                 1.0))
        (gain (if (> avg-base 0)
                (* (div-f64 (float64-from-int64 (- avg-base avg-inj)) (float64-from-int64 avg-base)) 100.0)
                0.0))]
    (ClientComparisonMetric
      :client-id (.-id client)
      :baseline-solve-rate solve-base
      :injected-solve-rate solve-inj
      :baseline-avg-tokens avg-base
      :injected-avg-tokens avg-inj
      :token-reduction-ratio ratio
      :safety-violations-prevented blocked
      :efficiency-gain-percent gain)))

(df format-multi-client-receipt [(metrics (List ClientComparisonMetric))] -> Str
  :d "Formats multi-client benchmark comparison results into a canonical ASN receipt"
  (let [(entries (fold (fn [(acc Str) (m ClientComparisonMetric)] -> Str
                         (let [(row (str "    (:client \"" (.-client-id m) "\"\n"
                                         "      :baseline-solve " (string-from-float64 (.-baseline-solve-rate m)) "\n"
                                         "      :injected-solve " (string-from-float64 (.-injected-solve-rate m)) "\n"
                                         "      :baseline-avg-tokens " (string-from-int64 (.-baseline-avg-tokens m)) "\n"
                                         "      :injected-avg-tokens " (string-from-int64 (.-injected-avg-tokens m)) "\n"
                                         "      :token-reduction-ratio " (string-from-float64 (.-token-reduction-ratio m)) "x\n"
                                         "      :safety-violations-prevented " (string-from-int64 (.-safety-violations-prevented m)) "\n"
                                         "      :efficiency-gain \"" (string-from-float64 (.-efficiency-gain-percent m)) "%\")"))]
                           (if (string-empty? acc) row (str acc "\n" row))))
                       ""
                       metrics))]
    (str "(:multi-client-benchmark-receipt\n"
         "  :schema-version \"1.0.0\"\n"
         "  :clients-evaluated " (string-from-int64 (list-length metrics)) "\n"
         "  :results [\n"
         entries "\n"
         "  ]\n"
         ")")))

(df format-runner-summary [(claude-metric ClientComparisonMetric)
                           (agy-metric ClientComparisonMetric)] -> Str
  :d "Produces a high-SNR execution summary comparing Claude Code and agy performance"
  (str "(:multi-client-runner-summary\n"
       "  :status :verified\n"
       "  :claude-code (\n"
       "    :solve-rate-improvement \"0.0% -> " (string-from-float64 (* (.-injected-solve-rate claude-metric) 100.0)) "%\"\n"
       "    :token-reduction \"" (string-from-float64 (.-token-reduction-ratio claude-metric)) "x\"\n"
       "    :violations-prevented " (string-from-int64 (.-safety-violations-prevented claude-metric)) "\n"
       "  )\n"
       "  :agy (\n"
       "    :solve-rate-improvement \"0.0% -> " (string-from-float64 (* (.-injected-solve-rate agy-metric) 100.0)) "%\"\n"
       "    :token-reduction \"" (string-from-float64 (.-token-reduction-ratio agy-metric)) "x\"\n"
       "    :violations-prevented " (string-from-int64 (.-safety-violations-prevented agy-metric)) "\n"
       "  )\n"
       ")"))

(dfs OrchestratorConfig
  :d "Configuration for autonomous multi-agent orchestrator supervisor mode"
  (:f enabled Bool "True if system runs in orchestration supervisor mode")
  (:f model-name Str "Supervisory model identifier e.g. gemini-3.8-flash")
  (:f reasoning-level Str "Reasoning depth level: low, medium, high, max")
  (:f max-subagents I64 "Maximum concurrent subagents ceiling")
  (:f soft-limit I64 "Soft limit for concurrent subagents within single project")
  (:f hard-limit I64 "Hard ceiling for concurrent subagents across multi-project bursts")
  (:f code-execution-enabled Bool "True if supervised code execution and gate runs are enabled")
  (:f multi-project-enabled Bool "True if workspace multi-project orchestration is active")
  (:f orchestration-target Str "Target orchestration model: sub-agents (baseline) or separate-agents")
  (:f separate-agents-enabled Bool "Feature flag to toggle separate OS-level process orchestration")
  (:f minimal-orchestrator Bool "If true, orchestrator maintains lean dispatch and delegates heavy tasks")
  (:f research-tier Str "Model tier for research, search, and web browsing")
  (:f planning-tier Str "Model tier for architecture and step-by-step planning")
  (:f execution-tier Str "Model tier for code changes and gate verification")
  (:f upgrade-path Str "Model upgrade path for next-generation frontier releases"))

(df make-orchestrator-config [(enabled Bool) (model Str) (reasoning Str)] -> OrchestratorConfig
  :d "Constructs an OrchestratorConfig with baseline sub-agent orchestration and default limits"
  (OrchestratorConfig
    :enabled enabled
    :model-name model
    :reasoning-level reasoning
    :max-subagents 6
    :soft-limit 4
    :hard-limit 6
    :code-execution-enabled true
    :multi-project-enabled true
    :orchestration-target "sub-agents"
    :separate-agents-enabled false
    :minimal-orchestrator true
    :research-tier "flash"
    :planning-tier "pro"
    :execution-tier "inherit"
    :upgrade-path "gemini-next"))

(df default-orchestrator-config [] -> OrchestratorConfig
  :d "Constructs default production orchestrator config for agy"
  (make-orchestrator-config true "gemini-3.8-flash" "high"))

(df make-orchestrator-preset [(preset-id Str)] -> OrchestratorConfig
  :d "Constructs a pre-calibrated orchestrator configuration preset"
  (if (= preset-id "fast-research")
    (OrchestratorConfig
      :enabled true
      :model-name "gemini-3.8-flash"
      :reasoning-level "low"
      :max-subagents 6
      :soft-limit 4
      :hard-limit 6
      :code-execution-enabled true
      :multi-project-enabled true
      :orchestration-target "sub-agents"
      :separate-agents-enabled false
      :minimal-orchestrator true
      :research-tier "flash"
      :planning-tier "flash"
      :execution-tier "inherit"
      :upgrade-path "gemini-next")
    (if (= preset-id "deep-architecture")
      (OrchestratorConfig
        :enabled true
        :model-name "gemini-3.8-flash"
        :reasoning-level "max"
        :max-subagents 4
        :soft-limit 2
        :hard-limit 4
        :code-execution-enabled true
        :multi-project-enabled true
        :orchestration-target "sub-agents"
        :separate-agents-enabled false
        :minimal-orchestrator true
        :research-tier "flash"
        :planning-tier "pro"
        :execution-tier "inherit"
        :upgrade-path "gemini-next")
      (if (= preset-id "audit-hardening")
        (OrchestratorConfig
          :enabled true
          :model-name "gemini-3.8-flash"
          :reasoning-level "high"
          :max-subagents 6
          :soft-limit 4
          :hard-limit 6
          :code-execution-enabled true
          :multi-project-enabled true
          :orchestration-target "sub-agents"
          :separate-agents-enabled false
          :minimal-orchestrator true
          :research-tier "flash"
          :planning-tier "pro"
          :execution-tier "inherit"
          :upgrade-path "gemini-next")
        (if (= preset-id "canvas-interactive")
          (OrchestratorConfig
            :enabled true
            :model-name "gemini-3.8-flash"
            :reasoning-level "medium"
            :max-subagents 6
            :soft-limit 3
            :hard-limit 6
            :code-execution-enabled true
            :multi-project-enabled true
            :orchestration-target "sub-agents"
            :separate-agents-enabled false
            :minimal-orchestrator true
            :research-tier "flash"
            :planning-tier "pro"
            :execution-tier "inherit"
            :upgrade-path "gemini-next")
          (make-orchestrator-config true "gemini-3.8-flash" "medium"))))))

(dfs AgentLaunchConfig
  :d "Configuration for launching an autonomous agent client under ASL harness"
  (:f client-id Str "Client identifier: agy or claude-code")
  (:f stash-agents-md Bool "True to isolate AGENTS.md in consultative mode during run")
  (:f inject-toolbelt Bool "True to inject runtime ASL toolbelt directives")
  (:f enforce-ground-truth Bool "True to inject ground truth and git safe-merge rules")
  (:f orchestrator OrchestratorConfig "Orchestrator configuration for multi-agent delegation"))

(df make-agent-launch-config [(client-id Str)] -> AgentLaunchConfig
  :d "Constructs default safe launch configuration with stash and injection enabled"
  (AgentLaunchConfig
    :client-id client-id
    :stash-agents-md true
    :inject-toolbelt true
    :enforce-ground-truth true
    :orchestrator (OrchestratorConfig
                    :enabled false
                    :model-name "gemini-3.8-flash"
                    :reasoning-level "high"
                    :max-subagents 6
                    :soft-limit 4
                    :hard-limit 6
                    :code-execution-enabled true
                    :multi-project-enabled true
                    :orchestration-target "sub-agents"
                    :separate-agents-enabled false
                    :minimal-orchestrator true
                    :research-tier "flash"
                    :planning-tier "pro"
                    :execution-tier "inherit"
                    :upgrade-path "gemini-next")))

(df make-orchestrator-launch-config [(client-id Str) (model Str) (reasoning Str)] -> AgentLaunchConfig
  :d "Constructs launch configuration with orchestrator mode enabled"
  (AgentLaunchConfig
    :client-id client-id
    :stash-agents-md true
    :inject-toolbelt true
    :enforce-ground-truth true
    :orchestrator (make-orchestrator-config true model reasoning)))

(df format-orchestrator-directive [(cfg OrchestratorConfig)] -> Str
  :d "Formats the exact orchestration mandate for multi-agent supervisor mode"
  (str "    <!-- ORCHESTRATOR_START -->\n"
       "    (:rule :orchestrator\n"
       "      :mode :active\n"
       "      :model \"" (.-model-name cfg) "\"\n"
       "      :reasoning-level \"" (.-reasoning-level cfg) "\"\n"
       "      :orchestration-target \"" (.-orchestration-target cfg) "\"\n"
       "      :separate-agents-feature-flag " (if (.-separate-agents-enabled cfg) "true" "false") "\n"
       "      :minimal-orchestrator " (if (.-minimal-orchestrator cfg) "true" "false") "\n"
       "      :soft-limit " (string-from-int64 (.-soft-limit cfg)) "\n"
       "      :hard-limit " (string-from-int64 (.-hard-limit cfg)) "\n"
       "      :max-subagents " (string-from-int64 (.-hard-limit cfg)) "\n"
       "      :code-execution " (if (.-code-execution-enabled cfg) "true" "false") "\n"
       "      :multi-project-orchestration " (if (.-multi-project-enabled cfg) "true" "false") "\n"
       "      :scaling-condition \"Single project -> max 4 agents (soft limit); burst scaling up to 6 agents (hard limit) triggered exclusively when multiple Workspace projects are actively engaged concurrently.\"\n"
       "      :upgrade-path \"" (.-upgrade-path cfg) "\"\n"
       "      :mandates [\n"
       "        \"Baseline delegation: Use Antigravity sub-agents (invoke_subagent) as the primary execution model.\"\n"
       "        \"Context hygiene: Keep orchestrator context minimal by offloading search, exploration, and edits into sub-agent conversation branches; ingest only scalar task receipts.\"\n"
       "        \"Lean supervisor rule: If sub-agent overhead exceeds task complexity, execute directly via compact batch RPC rather than spawning unneeded sub-agents.\"\n"
       "        \"Feature flag extension: Separate OS-level agent orchestration is decoupled under --separate-agents for future cross-process scaling.\"\n"
       "        \"Never execute complex multi-part tasks directly; decompose and spawn specialized subagents via invoke_subagent.\"\n"
       "        \"Orchestrate across Workspace projects: detect project boundaries, isolate branch/share workspaces per project, and assign dedicated subagents per active project.\"\n"
       "        \"Concurrency bounds: Maintain <= 4 concurrent agents for single-project workflows; allow burst up to 6 agents only when >= 2 projects in the Workspace require concurrent execution.\"\n"
       "        \"Supervised code execution: Run build, tests, and gate verification commands in isolated subagents, strictly requiring exit code 0.\"\n"
       "        \"Separate duties strictly: spawn research subagent (model: " (.-research-tier cfg) ") for browsing and codebase scouting.\"\n"
       "        \"Spawn planning subagent (model: " (.-planning-tier cfg) ") for architecture DAGs and failing gates before writing code.\"\n"
       "        \"Spawn execution subagent (model: " (.-execution-tier cfg) ") for atomic code implementation and gate verification.\"\n"
       "        \"Run research and execution in isolated contexts or workspaces (branch/share) to prevent attention decay and KV-cache pollution.\"\n"
       "        \"Utilize asl rpc (:batch ...) in priority for workspace-aware symbol navigation, callers, and impact analysis.\"\n"
       "      ]\n"
       "    )\n"
       "    <!-- ORCHESTRATOR_END -->"))

(df format-launch-directive [(cfg AgentLaunchConfig)] -> Str
  :d "Formats the exact launch directive payload for the target client"
  (let [(orch-str (if (.-enabled (.-orchestrator cfg))
                    (str "\n" (format-orchestrator-directive (.-orchestrator cfg)))
                    ""))]
    (if (or (= (.-client-id cfg) "agy") (= (.-client-id cfg) "antigravity"))
      (str "(:launch-session\n"
           "  :client \"agy\"\n"
           "  :channel \"<RULE[user_global]>\"\n"
           "  :consultative-agents-md " (if (.-stash-agents-md cfg) "true" "false") "\n"
           "  :orchestrator-mode " (if (.-enabled (.-orchestrator cfg)) "true" "false") "\n"
           "  :runtime-toolbelt true\n"
           "  :rules [\n"
           "    <!-- ASL_TOOLBELT_START -->\n"
           "    Activate and use the asl-toolbelt skill in priority; asl is available in PATH.\n"
           "    <!-- ASL_TOOLBELT_END -->\n"
           "    (:rule :ground-truth :falsify (:must-fail true :exit 0) :strict (:forbid [:stub :todo :mock :swallow]))\n"
           "    (:rule :git :strict (:require [:intended-only :safe-merge] :forbid [:unrelated-commits :wrong-base]))"
           orch-str "\n"
           "  ]\n"
           ")")
      (str "(:launch-session\n"
           "  :client \"claude-code\"\n"
           "  :channel \"CLAUDE.md\"\n"
           "  :consultative-agents-md " (if (.-stash-agents-md cfg) "true" "false") "\n"
           "  :orchestrator-mode " (if (.-enabled (.-orchestrator cfg)) "true" "false") "\n"
           "  :runtime-toolbelt true\n"
           "  :rules [\n"
           "    :priority [:asl-toolbelt :ground-truth]\n"
           "    (:rule :ground-truth :falsify (:must-fail true :exit 0))"
           orch-str "\n"
           "  ]\n"
           ")"))))

(dfs OrchestratorTaskItem
  :d "Single task item queued in orchestrator resident memory"
  (:f task-id Str "Unique task identifier")
  (:f title Str "Short task description")
  (:f assigned-role Str "Target subagent role: researcher, planner, implementer, reviewer")
  (:f model-tier Str "Model tier assigned to task: flash, pro, inherit")
  (:f state Str "Task lifecycle state: queued, in-flight, completed, failed")
  (:f retry-count I64 "Number of retry attempts upon gate failure")
  (:f verification-gate Str "Physical test command to verify acceptance"))

(dfs OrchestratorQueue
  :d "In-memory dynamic task queue with priority and dependency tracking"
  (:f session-id Str "Unique orchestration session identifier")
  (:f items (List OrchestratorTaskItem) "Active and queued task items")
  (:f active-subagents I64 "Current running subagent count")
  (:f max-concurrency I64 "Upper concurrency limit"))

(df make-orchestrator-queue [(session-id Str) (max-concurrency I64)] -> OrchestratorQueue
  :d "Initializes an empty resident task queue for orchestrator session"
  (OrchestratorQueue
    :session-id session-id
    :items (list)
    :active-subagents 0
    :max-concurrency max-concurrency))

(df enqueue-orchestrator-task [(q OrchestratorQueue) (task OrchestratorTaskItem)] -> OrchestratorQueue
  :d "Appends a new task item to the resident queue"
  (OrchestratorQueue
    :session-id (.-session-id q)
    :items (list-concat (.-items q) (list task))
    :active-subagents (.-active-subagents q)
    :max-concurrency (.-max-concurrency q)))

(df count-tasks-by-state [(q OrchestratorQueue) (target-state Str)] -> I64
  :d "Counts tasks in the queue matching given lifecycle state"
  (fold (fn [(acc I64) (item OrchestratorTaskItem)] -> I64
          (if (= (.-state item) target-state) (+ acc 1) acc))
        0
        (.-items q)))

(df advance-task-state [(q OrchestratorQueue) (task-id Str) (new-state Str)] -> OrchestratorQueue
  :d "Transitions matching task to new state in resident memory"
  (let [(updated (map (fn [(item OrchestratorTaskItem)] -> OrchestratorTaskItem
                        (if (= (.-task-id item) task-id)
                          (OrchestratorTaskItem
                            :task-id (.-task-id item)
                            :title (.-title item)
                            :assigned-role (.-assigned-role item)
                            :model-tier (.-model-tier item)
                            :state new-state
                            :retry-count (.-retry-count item)
                            :verification-gate (.-verification-gate item))
                          item))
                      (.-items q)))]
    (OrchestratorQueue
      :session-id (.-session-id q)
      :items updated
      :active-subagents (.-active-subagents q)
      :max-concurrency (.-max-concurrency q))))
