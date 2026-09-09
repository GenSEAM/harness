(module asl-harness/tests/mcp-bridge-test
  :d "Unit tests for MCP Bridge configuration and connectivity verification."
  :x [test-standard-servers-count
      test-generate-claude-config
      test-verify-bridge-connectivity
      run-tests]
  :i [(mcp_bridge :a mcp)])

(df test-standard-servers-count [] -> Bool
  :d "Verifies standard GenSEAM MCP servers list."
  (let [(servers (mcp/standard-genseam-servers))]
    (do
      (assert (= (list-length servers) 3) "Must have 3 standard MCP servers")
      (let [(first-s (option-unwrap (list-head servers)))]
        (assert (= (.-name first-s) "asl-intel") "First server must be asl-intel")
        (assert (= (.-command first-s) "intel") "Command must be intel"))
      true)))

(df test-generate-claude-config [] -> Bool
  :d "Verifies Claude Code MCP config generation."
  (let [(servers (mcp/standard-genseam-servers))
        (cfg (mcp/generate-claude-mcp-config servers))]
    (do
      (assert (string-contains? cfg "mcpServers") "Config must contain mcpServers")
      (assert (string-contains? cfg "\"count\":3") "Config must contain count:3")
      true)))

(df test-verify-bridge-connectivity [] -> Bool
  :d "Verifies bridge connectivity check."
  (let [(ok (mcp/verify-bridge-connectivity))]
    (do
      (assert ok "Bridge connectivity must return true")
      (assert (not (= ok false)) "Bridge connectivity is not false")
      true)))

(df run-tests [] -> Bool
  :d "Executes MCP bridge test suite."
  (and (test-standard-servers-count)
       (and (test-generate-claude-config)
            (test-verify-bridge-connectivity))))
