(module asl-harness/doctor-test
  :d "Unit verification test suite for Agent Doctor and Adaptive LLM-Chain Inspector"
  :x [test-plugin-registry-creation
      TestDoctorCleanBaseline
      TestDoctorDetectToolCollision
      TestDoctorDetectMissingDependency
      TestDoctorDetectPromptContradiction
      TestDoctorLlmChainFastPathSkip
      TestDoctorLlmChainActivationOnIssues
      test-format-doctor-report
      run-doctor-tests
      run-tests]
  :i [(plugin :a pl)
      (doctor :a doc)
      (config :a cfg)])

(df test-plugin-registry-creation [] -> Bool
  :d "Tests assembly of standard built-in harness plugins"
  (let [(reg (pl/build-standard-harness-plugins))
        (tools (pl/registry-get-tools reg))]
    (assert (= (.-active-count reg) 5) "reg count is 5")
    (assert (pl/contains-string? tools "intel-preload") "has intel-preload")
    (assert (pl/contains-string? tools "audit-ast-mutation") "has audit-ast-mutation")
    (assert (pl/contains-string? tools "extract-css-variables") "has extract-css-variables")
    (assert (pl/contains-string? tools "scan-component-usages") "has scan-component-usages")
    (assert (pl/contains-string? tools "run-sandboxed-script") "has run-sandboxed-script")
    true))

(df TestDoctorCleanBaseline [] -> Bool
  :d "Tests that default standard plugins pass doctor inspection with 100% health"
  (let [(reg (pl/build-standard-harness-plugins))
        (diag (doc/diagnose-agent-plugins reg))]
    (assert (.-healthy diag) "clean is healthy")
    (assert (= (.-health-score diag) 100) "health score is 100")
    (assert (= (list-length (.-collisions diag)) 0) "0 collisions")
    (assert (= (list-length (.-contradictions diag)) 0) "0 contradictions")
    (assert (= (list-length (.-missing-deps diag)) 0) "0 missing deps")
    true))

(df TestDoctorDetectToolCollision [] -> Bool
  :d "Tests detection of duplicate tool names across plugins"
  (let [(reg (pl/build-standard-harness-plugins))
        (bad-plugin (pl/create-plugin
                      "custom-plugin"
                      "Custom Duplicating Plugin"
                      "1.0"
                      1
                      (pl/PluginCapability
                        :provided-tools (list "intel-preload")
                        :system-prompts (list)
                        :hooks (list)
                        :dependencies (list)
                        :conflicts (list))))
        (reg-with-collision (pl/registry-add reg bad-plugin))
        (diag (doc/diagnose-agent-plugins reg-with-collision))]
    (assert (not (.-healthy diag)) "collision is not healthy")
    (assert (< (.-health-score diag) 100) "health score < 100")
    (assert (= (list-length (.-collisions diag)) 1) "1 collision found")
    (let [(c (option-or (list-head (.-collisions diag))
                        (doc/ToolCollision :tool-name "" :plugin-a "" :plugin-b "")))]
      (assert (= (.-tool-name c) "intel-preload") "collision tool is intel-preload"))
    true))

(df TestDoctorDetectMissingDependency [] -> Bool
  :d "Tests detection of unfulfilled plugin dependencies"
  (let [(reg (pl/registry-create))
        (p (pl/create-plugin
             "consumer-plugin"
             "Needs Auth"
             "1.0"
             1
             (pl/PluginCapability
               :provided-tools (list "do-something")
               :system-prompts (list)
               :hooks (list)
               :dependencies (list "missing-auth-plugin")
               :conflicts (list))))
        (reg-unmet (pl/registry-add reg p))
        (diag (doc/diagnose-agent-plugins reg-unmet))]
    (assert (not (.-healthy diag)) "missing dep is not healthy")
    (assert (= (list-length (.-missing-deps diag)) 1) "1 missing dep found")
    true))

(df TestDoctorDetectPromptContradiction [] -> Bool
  :d "Tests detection of contradictory prompt directives"
  (let [(reg (pl/registry-create))
        (p1 (pl/create-plugin
              "strict-planner"
              "Strict Planner"
              "1.0"
              1
              (pl/PluginCapability
                :provided-tools (list "tool1")
                :system-prompts (list "Never mutate files without plan registered.")
                :hooks (list)
                :dependencies (list)
                :conflicts (list))))
        (p2 (pl/create-plugin
              "auto-patcher"
              "Auto Patcher"
              "1.0"
              2
              (pl/PluginCapability
                :provided-tools (list "tool2")
                :system-prompts (list "Auto-apply patches silently without waiting.")
                :hooks (list)
                :dependencies (list)
                :conflicts (list))))
        (reg-conflict (pl/registry-add (pl/registry-add reg p1) p2))
        (diag (doc/diagnose-agent-plugins reg-conflict))]
    (assert (not (.-healthy diag)) "contradiction is not healthy")
    (assert (> (list-length (.-contradictions diag)) 0) "contradictions found")
    true))

(df TestDoctorLlmChainFastPathSkip [] -> Bool
  :d "Tests that healthy setup skips LLM inspection (0 token cost)"
  (let [(reg (pl/build-standard-harness-plugins))
        (diag (doc/diagnose-agent-plugins reg))
        (after (doc/inspect-with-llm diag "gemma-31b"))]
    (assert (.-healthy after) "fast path is healthy")
    (assert (not (.-llm-inspected after)) "llm was not inspected")
    true))

(df TestDoctorLlmChainActivationOnIssues [] -> Bool
  :d "Tests that LLM chain inspector is triggered when issues exist"
  (let [(reg (pl/registry-create))
        (p1 (pl/create-plugin "p1" "P1" "1.0" 1
              (pl/PluginCapability :provided-tools (list "t1")
                :system-prompts (list "Never mutate files without plan.")
                :hooks (list) :dependencies (list) :conflicts (list))))
        (p2 (pl/create-plugin "p2" "P2" "1.0" 2
              (pl/PluginCapability :provided-tools (list "t1")
                :system-prompts (list "Auto-apply patches silently.")
                :hooks (list) :dependencies (list) :conflicts (list))))
        (reg-bad (pl/registry-add (pl/registry-add reg p1) p2))
        (diag (doc/diagnose-agent-plugins reg-bad))
        (after (doc/inspect-with-llm diag "qwen-2.5-coder"))]
    (assert (not (.-healthy after)) "issues not healthy")
    (assert (.-llm-inspected after) "llm was inspected")
    (assert (> (list-length (.-remediations after)) 0) "remediations exist")
    true))

(df test-format-doctor-report [] -> Bool
  :d "Tests markdown formatting of doctor diagnosis report"
  (let [(reg (pl/build-standard-harness-plugins))
        (diag (doc/diagnose-agent-plugins reg))
        (report (doc/format-doctor-report diag))]
    (assert (string-contains? report "Agent Doctor Inspection Report") "report header present")
    (assert (string-contains? report "HEALTHY (100/100)") "healthy text present")
    true))

(df run-doctor-tests [] -> Bool
  :d "Runs complete test suite for Agent Doctor and Plugin System"
  (do
    (test-plugin-registry-creation)
    (TestDoctorCleanBaseline)
    (TestDoctorDetectToolCollision)
    (TestDoctorDetectMissingDependency)
    (TestDoctorDetectPromptContradiction)
    (TestDoctorLlmChainFastPathSkip)
    (TestDoctorLlmChainActivationOnIssues)
    (test-format-doctor-report)
    true))

(df run-tests [] -> Bool
  :d "Alias for run-doctor-tests"
  (run-doctor-tests))
