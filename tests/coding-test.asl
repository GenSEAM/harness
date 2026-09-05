(module asl-harness/tests/coding-test
  :d "Unit tests for agent coding harness, normalizer, toolcall translator, provider, and local execution."
  :x [test-coding-tools test-normalizer test-toolcall test-provider test-local-exec run-tests]
  :i [(coding :a c) (normalizer :a norm) (toolcall :a tc) (provider :a prov) (local-exec :a lx)])

(df test-coding-tools [] -> Bool
  :d "Verifies standard coding tools declaration and direct execution including ast-patch."
  (let [(tools (c/standard-coding-tools))
        (found (c/find-tool "fs-read" tools))
        (found-patch (c/find-tool "ast-patch" tools))
        (call (c/ToolCall :id "call-1" :tool-name "fs-read" :arguments (list (pair "path" "src/main.asl"))))
        (call-patch (c/ToolCall :id "call-2" :tool-name "ast-patch" :arguments (list (pair "path" "src/main.asl") (pair "symbol" "foo") (pair "replacement" "(df foo [] true)"))))
        (res (c/execute-builtin-tool call))
        (res-patch (c/execute-builtin-tool call-patch))]
    (and (not (list-empty? tools))
         (and (option-is-some? found)
              (and (option-is-some? found-patch)
                   (and (.-success res)
                        (.-success res-patch)))))))

(df test-normalizer [] -> Bool
  :d "Verifies hallucination normalizer repairs snake_case, keywords, types, and delimiter balance."
  (let [(id (norm/normalize-identifier "read_file_content"))
        (kw (norm/canonicalize-keyword "defun"))
        (ty (norm/canonicalize-type "string"))
        (balanced (norm/balance-delimiters "(df foo [] (println \"hi\""))
        (rep (norm/repair-hallucinations "(defun my-func [(x String)] -> Int64 x"))]
    (and (= id "read-file-content")
         (and (= kw "df")
              (and (= ty "Str")
                   (and (string-contains? balanced "))")
                        (not (.-is-clean rep))))))))

(df test-toolcall [] -> Bool
  :d "Verifies ASN to OpenAI tool translation and back."
  (let [(tool (c/BuiltinTool
                :name "fs-read"
                :description "Reads file"
                :params (list (c/ToolParam :name "path" :param-type "Str" :required true :doc "File path"))
                :deterministic true))
        (schema (tc/tool-to-openai-schema tool))
        (call (c/ToolCall :id "c1" :tool-name "fs-read" :arguments (list (pair "path" "test.asl"))))
        (asn-str (tc/format-asn-tool-call "fs-read" (list (pair "path" "test.asl"))))]
    (and (= (.-name schema) "fs_read")
         (and (string-contains? (.-parameters-json schema) "path")
              (string-contains? asn-str "(:call :tool \"fs-read\"")))))

(df test-provider [] -> Bool
  :d "Verifies default OpenAI gateway configuration and payload generation."
  (let [(cfg (prov/default-gateway-config))
        (msgs (list (prov/make-message "user" "hello")))
        (tools (c/standard-coding-tools))
        (payload (prov/build-request-payload cfg msgs tools))]
    (and (= (.-model cfg) "gemma-4-31b-it")
         (and (= (.-base-url cfg) "https://api.llmgateway.io/v1")
              (string-contains? payload "gemma-4-31b-it")))))

(df test-local-exec [] -> Bool
  :d "Verifies deterministic tools are routed to local execution tier without LLM round-trip."
  (let [(local-ok (lx/should-execute-locally "fs-read"))
        (remote-ok (not (lx/should-execute-locally "code-generation")))
        (call (c/ToolCall :id "c2" :tool-name "fs-read" :arguments (list (pair "path" "test.asl"))))
        (res (lx/route-and-execute call))
        (savings (lx/format-savings-report 10))]
    (and local-ok
         (and remote-ok
              (and (.-success res)
                   (string-contains? savings "Saved ~6500 tokens"))))))

(df run-tests [] -> Bool
  :d "Executes full harness test suite."
  (and (test-coding-tools)
       (and (test-normalizer)
            (and (test-toolcall)
                 (and (test-provider)
                      (test-local-exec))))))
