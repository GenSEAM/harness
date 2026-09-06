(module asl-harness/tests/plugin-test
  :d "Unit tests for flexible pluggable harness extension system and registries."
  :x [run-tests]
  :i [(plugin :a plug)
      (config :a cfg)])

(df test-create-plugin [] -> Bool
  :d "Verifies construction of an individual AgentPlugin."
  (let [(cap (plug/PluginCapability
               :provided-tools (list "custom-tool-1")
               :system-prompts (list "Use custom tool 1")
               :hooks (list (cfg/hook-pre-call))
               :dependencies (list)
               :conflicts (list)))
        (p (plug/create-plugin "plug-alpha" "Alpha Plugin" "1.0.0" 1 cap))]
    (and (= (.-id p) "plug-alpha")
         (and (= (.-name p) "Alpha Plugin")
              (and (.-enabled p)
                   (= (.-priority p) 1))))))

(df test-registry-lifecycle [] -> Bool
  :d "Verifies registry creation, addition, lookup, and tool collection."
  (let [(cap (plug/PluginCapability
               :provided-tools (list "test-cmd-a" "test-cmd-b")
               :system-prompts (list)
               :hooks (list)
               :dependencies (list)
               :conflicts (list)))
        (p (plug/create-plugin "p1" "Plugin One" "1.0.0" 1 cap))
        (reg0 (plug/registry-create))
        (reg1 (plug/registry-add reg0 p))
        (found (plug/registry-find reg1 "p1"))
        (tools (plug/registry-get-tools reg1))]
    (and (= (.-active-count reg1) 1)
         (and (mt found
                ((none) false)
                ((some fp) (= (.-name fp) "Plugin One")))
              (and (= (list-length tools) 2)
                   (plug/contains-string? tools "test-cmd-a"))))))

(df test-standard-harness-plugins [] -> Bool
  :d "Verifies standard built-in harness plugins registry initialization."
  (let [(std (plug/build-standard-harness-plugins))
        (tools (plug/registry-get-tools std))]
    (and (>= (.-active-count std) 5)
         (and (plug/contains-string? tools "intel-preload")
              (and (plug/contains-string? tools "audit-ast-mutation")
                   (plug/contains-string? tools "scan-component-usages"))))))

(df run-tests [] -> Bool
  :d "Runs all plugin system tests."
  (and (test-create-plugin)
       (and (test-registry-lifecycle)
            (test-standard-harness-plugins))))
