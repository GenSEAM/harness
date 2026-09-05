# Phase Plan: Harness Action Firewall (`harness-action-firewall`)

## Objective
Implement a deterministic AST-level Action Firewall that intercepts agent actions and tool calls BEFORE execution:
- Path boundary checking: Blocks path traversal (`../`, `/etc`, `~/.ssh`).
- Safe execution policy: Blocks dangerous shell patterns (`rm -rf`, curl pipes to sh, eval).
- Capability lease checking: Verifies that agent has explicitly been granted read/write capability.
- 100% pure AgentScript implementation in `harness/src/firewall.asl`.

## Work Items
1. **Firewall Core (`harness/src/firewall.asl`)**:
   - `FirewallPolicy` (allowed-roots, allow-write, allow-exec, max-file-bytes).
   - `FirewallVerdict` (allowed, reason, sanitized-target).
   - `evaluate-path-boundary`: Validates file paths stay inside allowed workspace root.
   - `evaluate-command-safety`: Validates shell commands against blacklisted tokens.
   - `audit-tool-call`: Evaluates complete `ToolCall` against active policy.
2. **Grammar Registration**:
   - Register all types and functions in `harness/grammar.asn` with rationales for $> 2$ tokens.
3. **Verification Suite (`harness/tests/firewall-test.asl`)**:
   - Test path traversal blocks (`../../secret`).
   - Test dangerous command blocks.
   - Test permitted reads and writes inside sandbox.
4. **Gate Command**:
   - `asl test harness/tests/firewall-test.asl`
