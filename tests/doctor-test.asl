(module asl-harness/doctor-test
  :d "Unit verification test suite for Agent Doctor and Adaptive LLM-Chain Inspector"
  :x [test-plugin-registry-creation
      test-doctor-clean-baseline
      test-doctor-detect-tool-collision
      test-doctor-detect-missing-dependency
      test-doctor-detect-prompt-contradiction
      test-doctor-llm-chain-fast-path-skip
      test-doctor-llm-chain-activation-on-issues
      test-format-doctor-report
      run-doctor-tests]
  :i [(plugin :a pl)
      (doctor :a doc)
      (config :a cfg)])

(df test-plugin-registry-creation [] -> Bool
  :d "Tests assembly of standard built-in harness plugins"
  (let [(reg (pl/build-standard-harness-plugins))
        (tools (pl/registry-get-tools reg))]
    (and (= (.-active-count reg) 5)
         (pl/contains-string? tools "intel-preload")
         (pl/contains-string? tools "audit-ast-mutation")
         (pl/contains-string? tools "extract-css-variables")
         (pl/contains-string? tools "scan-component-usages")
         (pl/contains-string? tools "run-sandboxed-script"))))

(df test-doctor-clean-baseline [] -> Bool
  :d "Tests that default standard plugins pass doctor inspection with 100% health"
  (let [(reg (pl/build-standard-harness-plugins))
        (diag (doc/diagnose-agent-plugins reg))]
    (and (.-healthy diag)
         (= (.-health-score diag) 100)
         (= (list-length (.-collisions diag)) 0)
         (= (list-length (.-contradictions diag)) 0)
         (= (list-length (.-missing-deps diag)) 0))))

(df test-doctor-detect-tool-collision [] -> Bool
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
    (and (not (.-healthy diag))
         (< (.-health-score diag) 100)
         (= (list-length (.-collisions diag)) 1)
         (let [(c (option-or (list-head (.-collisions diag))
                             (doc/ToolCollision :tool-name "" :plugin-a "" :plugin-b "")))]
           (= (.-tool-name c) "intel-preload")))))

(df test-doctor-detect-missing-dependency [] -> Bool
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
    (and (not (.-healthy diag))
         (= (list-length (.-missing-deps diag)) 1))))

(df test-doctor-detect-prompt-contradiction [] -> Bool
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
    (and (not (.-healthy diag))
         (> (list-length (.-contradictions diag)) 0))))

(df test-doctor-llm-chain-fast-path-skip [] -> Bool
  :d "Tests that healthy setup skips LLM inspection (0 token cost)"
  (let [(reg (pl/build-standard-harness-plugins))
        (diag (doc/diagnose-agent-plugins reg))
        (after (doc/inspect-with-llm diag "gemma-31b"))]
    (and (.-healthy after)
         (not (.-llm-inspected after)))))

(df test-doctor-llm-chain-activation-on-issues [] -> Bool
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
    (and (not (.-healthy after))
         (.-llm-inspected after)
         (> (list-length (.-remediations after)) 0))))

(df test-format-doctor-report [] -> Bool
  :d "Tests markdown formatting of doctor diagnosis report"
  (let [(reg (pl/build-standard-harness-plugins))
        (diag (doc/diagnose-agent-plugins reg))
        (report (doc/format-doctor-report diag))]
    (and (string-contains? report "Agent Doctor Inspection Report")
         (string-contains? report "HEALTHY (100/100)"))))

(df run-doctor-tests [] -> Bool
  :d "Runs complete test suite for Agent Doctor and Plugin System"
  (and (test-plugin-registry-creation)
       (test-doctor-clean-baseline)
       (test-doctor-detect-tool-collision)
       (test-doctor-detect-missing-dependency)
       (test-doctor-detect-prompt-contradiction)
       (test-doctor-llm-chain-fast-path-skip)
       (test-doctor-llm-chain-activation-on-issues)
       (test-format-doctor-report)))
