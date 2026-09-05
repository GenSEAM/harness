# GAP Audit: Local Agentic Development & SWE-bench Suite (iter-01-local-agent-swe)

**Scope**: Changes in `harness/` and `asl/` across iteration `iter-01-local-agent-swe`.  
**Verdict**: **approve-with-amendments**

---

## 1. Omissions & Gaps (Completeness)

### GAP-01: Malformed JSON Trailing Commas in Payload Serializers
- **Evidence**: [harness/src/provider.asl:40](file:///Users/purplelephant/projects/asex/harness/src/provider.asl#L40) and [harness/src/toolcall.asl:34,48](file:///Users/purplelephant/projects/asex/harness/src/toolcall.asl#L34)
- **Problem**: Serializer loops fold elements appending `", "` after every item, leaving a trailing comma before closing brackets (`[...]` or `{...}`). Strict JSON parsers reject trailing commas.
- **Remedy**: Strip trailing comma before closing or format using delimiter-aware fold.

### GAP-02: Unclosed Return Type Delimiter on Declaration Line
- **Evidence**: [harness/src/coding.asl:31](file:///Users/purplelephant/projects/asex/harness/src/coding.asl#L31)
- **Problem**: Signature is written as `(df standard-coding-tools [] -> (List BuiltinTool` where the `(List BuiltinTool)` delimiter is left open and accidentally closed 41 lines down at line 72.
- **Remedy**: Close return type cleanly: `(df standard-coding-tools [] -> (List BuiltinTool)`.

### GAP-03: Redundant Branching in Local Tool Execution Router
- **Evidence**: [harness/src/local-exec.asl:42-44](file:///Users/purplelephant/projects/asex/harness/src/local-exec.asl#L42-L44)
- **Problem**:
  ```lisp
  (if (should-execute-locally name)
      (c/execute-builtin-tool call)
      (c/execute-builtin-tool call))
  ```
  Both arms of the conditional invoke the exact same expression.
- **Remedy**: Differentiate execution tier or return `c/ToolResult` error when non-local tool is routed to local runner without remote delegation.

### GAP-04: Provider Tool-Call Parser Stub
- **Evidence**: [harness/src/provider.asl:46-56](file:///Users/purplelephant/projects/asex/harness/src/provider.asl#L46-L56)
- **Problem**: `parse-model-response` ignores `has-tools` and always returns an empty `(list)` for `tool-calls`.
- **Remedy**: Integrate `tc/parse-openai-tool-call` or return structured indicator when tool-calling is detected.

---

## 2. Invariants & Consistency Analysis
- **Zero Foreign Code**: Enforced (100% pure ASL, zero `.py` / `.js`).
- **Delimiter Balance**: 100% verified across all modules and test suites.
- **Gate Integrity**: All 4 verification gates reproducible, fast, and offline-compatible (`--dry-run`).

---

## 3. Recommended Remediation Diffs

### Remediation for GAP-02 (`harness/src/coding.asl`):
```diff
--- a/harness/src/coding.asl
+++ b/harness/src/coding.asl
@@ -31,1 +31,1 @@
-(df standard-coding-tools [] -> (List BuiltinTool
+(df standard-coding-tools [] -> (List BuiltinTool)
@@ -72,1 +72,1 @@
-      :deterministic true)))
+      :deterministic true))
```

### Remediation for GAP-03 (`harness/src/local-exec.asl`):
```diff
--- a/harness/src/local-exec.asl
+++ b/harness/src/local-exec.asl
@@ -42,3 +42,3 @@
     (if (should-execute-locally name)
         (c/execute-builtin-tool call)
-        (c/execute-builtin-tool call))))
+        (c/ToolResult :call-id (.-id call) :tool-name name :success false :output "" :error-msg "Tool requires remote LLM execution tier")))
```
