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
    (assert (= (.-id p) "plug-alpha") "plugin id matches")
    (assert (= (.-name p) "Alpha Plugin") "plugin name matches")
    (assert (.-enabled p) "plugin is enabled")
    (assert (= (.-priority p) 1) "plugin priority is 1")
    true))

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
    (assert (= (.-active-count reg1) 1) "active count is 1")
    (assert (match found
              ((none) false)
              ((some fp) (= (.-name fp) "Plugin One"))) "found plugin name matches")
    (assert (= (list-length tools) 2) "tool count is 2")
    (assert (plug/contains-string? tools "test-cmd-a") "contains test-cmd-a")
    true))

(df test-standard-harness-plugins [] -> Bool
  :d "Verifies standard built-in harness plugins registry initialization."
  (let [(std (plug/build-standard-harness-plugins))
        (tools (plug/registry-get-tools std))]
    (assert (>= (.-active-count std) 5) "standard count >= 5")
    (assert (plug/contains-string? tools "intel-preload") "has intel-preload")
    (assert (plug/contains-string? tools "audit-ast-mutation") "has audit-ast-mutation")
    (assert (plug/contains-string? tools "scan-component-usages") "has scan-component-usages")
    true))

(df run-tests [] -> Bool
  :d "Runs all plugin system tests."
  (do
    (test-create-plugin)
    (test-registry-lifecycle)
    (test-standard-harness-plugins)
    true))
