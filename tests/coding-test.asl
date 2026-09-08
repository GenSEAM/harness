(module asl-harness/tests/coding-test
  :d "Unit tests for agent coding harness, normalizer, toolcall translator, provider, and local execution."
  :x [test-coding-tools test-normalizer test-toolcall test-provider test-local-exec test-intel-tools run-tests]
  :i [(coding :a c) (normalizer :a norm) (toolcall :a tc) (provider :a prov) (local-exec :a lx)])

(df test-coding-tools [] -> Bool
  :d "Verifies standard coding tools declaration and direct execution including ast-patch and str-replace."
  (let [(tools (c/standard-coding-tools))
        (found (c/find-tool "fs-read" tools))
        (found-patch (c/find-tool "ast-patch" tools))
        (found-replace (c/find-tool "str-replace" tools))
        (call (c/ToolCall :id "call-1" :tool-name "fs-read" :arguments (list (pair "path" "src/main.asl"))))
        (call-patch (c/ToolCall :id "call-2" :tool-name "ast-patch" :arguments (list (pair "path" "src/main.asl") (pair "symbol" "foo") (pair "replacement" "(df foo [] true)"))))
        (call-replace (c/ToolCall :id "call-3" :tool-name "str-replace" :arguments (list (pair "path" "src/main.py") (pair "old-chunk" "x = 1") (pair "new-chunk" "x = 2"))))
        (res (c/execute-builtin-tool call))
        (res-patch (c/execute-builtin-tool call-patch))
        (res-replace (c/execute-builtin-tool call-replace))]
    (assert (not (list-empty? tools)) "standard tools list is not empty")
    (assert (option-is-some? found) "fs-read tool found")
    (assert (option-is-some? found-patch) "ast-patch tool found")
    (assert (option-is-some? found-replace) "str-replace tool found")
    (assert (.-success res) "fs-read execution succeeded")
    (assert (.-success res-patch) "ast-patch execution succeeded")
    (assert (.-success res-replace) "str-replace execution succeeded")
    true))

(df test-normalizer [] -> Bool
  :d "Verifies hallucination normalizer repairs snake_case, keywords, types, and delimiter balance."
  (let [(id (norm/normalize-identifier "read_file_content"))
        (kw (norm/canonicalize-keyword "defun"))
        (ty (norm/canonicalize-type "string"))
        (balanced (norm/balance-delimiters "(df foo [] (println \"hi\""))
        (rep (norm/repair-hallucinations "(defun my-func [(x String)] -> Int64 x"))]
    (assert (= id "read-file-content") "snake_case normalized to kebab-case")
    (assert (= kw "df") "defun canonicalized to df")
    (assert (= ty "Str") "string canonicalized to Str")
    (assert (string-contains? balanced "))") "delimiters balanced")
    (assert (not (.-is-clean rep)) "hallucination detected and repaired")
    true))

(df test-toolcall [] -> Bool
  :d "Verifies ASN to OpenAI tool translation and back, including intel-preload and deps-resolve."
  (let [(tool (c/BuiltinTool
                :name "fs-read"
                :description "Reads file"
                :params (list (c/ToolParam :name "path" :param-type "Str" :required true :doc "File path"))
                :deterministic true))
        (schema (tc/tool-to-openai-schema tool))
        (preload-tool (c/BuiltinTool
                        :name "intel-preload"
                        :description "Preload graph"
                        :params (list (c/ToolParam :name "target" :param-type "Str" :required true :doc "Target"))
                        :deterministic true))
        (preload-schema (tc/tool-to-openai-schema preload-tool))
        (deps-tool (c/BuiltinTool
                     :name "deps-resolve"
                     :description "Resolve deps"
                     :params (list (c/ToolParam :name "package" :param-type "Str" :required true :doc "Package"))
                     :deterministic true))
        (deps-schema (tc/tool-to-openai-schema deps-tool))
        (call (c/ToolCall :id "c1" :tool-name "fs-read" :arguments (list (pair "path" "test.asl"))))
        (asn-str (tc/format-asn-tool-call "fs-read" (list (pair "path" "test.asl"))))]
    (assert (= (.-name schema) "fs_read") "schema name fs_read")
    (assert (= (.-name preload-schema) "intel_preload") "preload schema name intel_preload")
    (assert (= (.-name deps-schema) "deps_resolve") "deps schema name deps_resolve")
    (assert (string-contains? (.-parameters-json schema) "path") "schema params include path")
    (assert (string-contains? asn-str "(:call :tool \"fs-read\"") "asn format includes fs-read tool")
    true))

(df test-provider [] -> Bool
  :d "Verifies default OpenAI gateway configuration and payload generation."
  (let [(cfg (prov/default-gateway-config))
        (msgs (list (prov/make-message "user" "hello")))
        (tools (c/standard-coding-tools))
        (payload (prov/build-request-payload cfg msgs tools))]
    (assert (= (.-model cfg) "gemma-4-31b-it") "default model gemma-4-31b-it")
    (assert (= (.-base-url cfg) "http://127.0.0.1:8765/v1") "default base url match")
    (assert (string-contains? payload "gemma-4-31b-it") "payload contains model")
    true))

(df test-local-exec [] -> Bool
  :d "Verifies deterministic tools are routed to local execution tier without LLM round-trip."
  (let [(local-ok (lx/should-execute-locally "fs-read"))
        (remote-ok (not (lx/should-execute-locally "code-generation")))
        (call (c/ToolCall :id "c2" :tool-name "fs-read" :arguments (list (pair "path" "test.asl"))))
        (res (lx/route-and-execute call))
        (savings (lx/format-savings-report 10))]
    (assert local-ok "fs-read executes locally")
    (assert remote-ok "code-generation not local")
    (assert (.-success res) "route-and-execute succeeded")
    (assert (string-contains? savings "Saved ~6500 tokens") "savings reported")
    true))

(df test-intel-tools [] -> Bool
  :d "Verifies discovery, local routing, and in-memory execution of all 5 intelligence tools."
  (let [(tools (c/standard-coding-tools))
        (f-preload (c/find-tool "intel-preload" tools))
        (f-impact (c/find-tool "intel-impact" tools))
        (f-health (c/find-tool "intel-health" tools))
        (f-deps (c/find-tool "deps-resolve" tools))
        (f-patch (c/find-tool "ast-patch" tools))
        (c-preload (c/ToolCall :id "ip-1" :tool-name "intel-preload" :arguments (list (pair "target" "sym-a") (pair "depth" "1") (pair "token-budget" "2000"))))
        (c-impact (c/ToolCall :id "ii-1" :tool-name "intel-impact" :arguments (list (pair "symbol" "sym-b"))))
        (c-health (c/ToolCall :id "ih-1" :tool-name "intel-health" :arguments (list (pair "scope" "pkg/src"))))
        (c-deps (c/ToolCall :id "dr-1" :tool-name "deps-resolve" :arguments (list (pair "package" "pydantic") (pair "symbol" "model_dump"))))
        (res-preload (lx/route-and-execute c-preload))
        (res-impact (lx/route-and-execute c-impact))
        (res-health (lx/route-and-execute c-health))
        (res-deps (lx/route-and-execute c-deps))]
    (assert (option-is-some? f-preload) "intel-preload found")
    (assert (option-is-some? f-impact) "intel-impact found")
    (assert (option-is-some? f-health) "intel-health found")
    (assert (option-is-some? f-deps) "deps-resolve found")
    (assert (option-is-some? f-patch) "ast-patch found")
    (assert (lx/should-execute-locally "intel-preload") "preload executes locally")
    (assert (lx/should-execute-locally "intel-impact") "impact executes locally")
    (assert (lx/should-execute-locally "intel-health") "health executes locally")
    (assert (lx/should-execute-locally "deps-resolve") "deps executes locally")
    (assert (.-success res-preload) "preload succeeded")
    (assert (.-success res-impact) "impact succeeded")
    (assert (.-success res-health) "health succeeded")
    (assert (.-success res-deps) "deps succeeded")
    true))

(df test-bounded-lines [] -> Bool
  :d "Verifies bounded line extraction with line numbers and clamping."
  (let [(content "line 1\nline 2\nline 3\nline 4\nline 5")
        (normal (c/read-bounded-lines content 2 4))
        (clamped (c/read-bounded-lines content -1 100))
        (inverted (c/read-bounded-lines content 5 2))]
    (assert (string-contains? normal "2: line 2") "normal contains line 2")
    (assert (string-contains? normal "4: line 4") "normal contains line 4")
    (assert (not (string-contains? normal "1: line 1")) "normal does not contain line 1")
    (assert (string-contains? clamped "1: line 1") "clamped contains line 1")
    (assert (string-contains? clamped "5: line 5") "clamped contains line 5")
    (assert (= inverted "") "inverted returns empty string")
    true))

(df test-string-replacement [] -> Bool
  :d "Verifies contiguous substring replacement."
  (let [(source "val x = 10\nval y = 20")
        (ok-res (c/apply-string-replacement source "10" "99"))
        (err-res (c/apply-string-replacement source "nonexistent" "99"))]
    (assert (match ok-res
              ((ok updated) (= updated "val x = 99\nval y = 20"))
              ((err _) false)) "replacement succeeded")
    (assert (match err-res
              ((ok _) false)
              ((err msg) (string-contains? msg "not found"))) "nonexistent substring produces error")
    true))

(df test-format-result [] -> Bool
  :d "Verifies format-tool-result output for both success and failure cases."
  (let [(ok-res (c/ToolResult :call-id "c1" :tool-name "fs-read" :success true :output "content ok" :error-msg ""))
        (err-res (c/ToolResult :call-id "c2" :tool-name "exec-cmd" :success false :output "" :error-msg "command not found"))
        (s-ok (c/format-tool-result ok-res))
        (s-err (c/format-tool-result err-res))]
    (assert (string-contains? s-ok "✓ [fs-read] content ok") "formatted ok result contains checkmark")
    (assert (string-contains? s-err "✗ [exec-cmd] Error: command not found") "formatted err result contains cross")
    true))

(df test-all-builtin-tools [] -> Bool
  :d "Verifies all standard builtin tools execute and return appropriate results."
  (let [(call-write (c/ToolCall :id "w1" :tool-name "fs-write" :arguments (list (pair "path" "out.txt") (pair "content" "data"))))
        (call-list (c/ToolCall :id "l1" :tool-name "fs-list" :arguments (list (pair "path" "."))))
        (call-cmd (c/ToolCall :id "e1" :tool-name "exec-cmd" :arguments (list (pair "command" "echo ok"))))
        (call-git (c/ToolCall :id "g1" :tool-name "git-status" :arguments (list)))
        (call-ast (c/ToolCall :id "a1" :tool-name "ast-search" :arguments (list (pair "query" "foo"))))
        (call-bad (c/ToolCall :id "b1" :tool-name "unknown-tool" :arguments (list)))
        (r-write (c/execute-builtin-tool call-write))
        (r-list (c/execute-builtin-tool call-list))
        (r-cmd (c/execute-builtin-tool call-cmd))
        (r-git (c/execute-builtin-tool call-git))
        (r-ast (c/execute-builtin-tool call-ast))
        (r-bad (c/execute-builtin-tool call-bad))]
    (assert (.-success r-write) "fs-write succeeded")
    (assert (.-success r-list) "fs-list succeeded")
    (assert (.-success r-cmd) "exec-cmd succeeded")
    (assert (.-success r-git) "git-status succeeded")
    (assert (.-success r-ast) "ast-search succeeded")
    (assert (not (.-success r-bad)) "unknown-tool failed")
    (assert (string-contains? (.-error-msg r-bad) "Unknown tool") "unknown tool error message noted")
    true))

(df run-tests [] -> Bool
  :d "Executes full harness test suite."
  (do
    (test-coding-tools)
    (test-all-builtin-tools)
    (test-bounded-lines)
    (test-string-replacement)
    (test-format-result)
    (test-normalizer)
    (test-toolcall)
    (test-provider)
    (test-local-exec)
    (test-intel-tools)
    true))
