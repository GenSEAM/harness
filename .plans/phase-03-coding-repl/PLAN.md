# Phase Plan: In-Memory REPL & AST Diff Inspector (`coding-repl-inspector`)

## Objective
Implement a sub-0.05ms in-memory REPL and AST diff inspector for autonomous coding agents:
- Microsecond evaluation: Evaluates S-expression fragments without spawning external processes or waiting for rustc/node.
- Structured semantic traceback: Returns error diagnostics as structured AST nodes with exact line, column, and form references.
- AST node patching: Supports granular node replacement (`patch-ast-node`) avoiding full-file rewrites and context degradation.
- 100% pure AgentScript implementation in `harness/src/repl.asl`.

## Work Items
1. **In-Memory REPL & Inspector (`harness/src/repl.asl`)**:
   - `ReplSession`: In-memory environment binding table and evaluation history.
   - `EvalOutcome`: Status (success, error), result payload, latency-microseconds.
   - `eval-expression`: In-memory pure evaluation of basic S-expressions.
   - `patch-ast-node`: Granular S-expression substitution at target symbol/node ID.
   - `format-repl-error`: Structured semantic traceback generator.
2. **Grammar Registration**:
   - Register all types and functions in `harness/grammar.asn` with rationales for $> 2$ tokens.
3. **Verification Suite (`harness/tests/repl-test.asl`)**:
   - Test microsecond expression evaluation.
   - Test granular AST node patching without touching surrounding code.
   - Test structured error diagnostics.
4. **Gate Command**:
   - `asl test harness/tests/repl-test.asl`
