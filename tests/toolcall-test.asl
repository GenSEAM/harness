(module asl-harness/toolcall-test
  :d "Unit verification test suite for bidirectional OpenAI tool-calling translation."
  :x [run-tests test-toolcall]
  :i [(coding :a c)
      (toolcall :a tc)])

(df test-tool-schema-typing [] -> Bool
  :d "Validates JSON schema type mapping, required fields, and absence of trailing commas."
  (let [(t (c/BuiltinTool
             :name "test-tool"
             :description "Test tool description"
             :params (list
                       (c/ToolParam :name "file-path" :param-type "Str" :required true :doc "Path to file")
                       (c/ToolParam :name "line-count" :param-type "I64" :required true :doc "Number of lines")
                       (c/ToolParam :name "dry-run" :param-type "Bool" :required false :doc "Dry run mode"))
             :deterministic true))
        (schema (tc/tool-to-openai-schema t))
        (json (.-parameters-json schema))]
    (and (string-contains? json "\"file_path\": {\"type\": \"string\"")
         (and (string-contains? json "\"line_count\": {\"type\": \"integer\"")
              (and (string-contains? json "\"dry_run\": {\"type\": \"boolean\"")
                   (and (string-contains? json "\"required\": [\"file_path\", \"line_count\"]")
                        (and (not (string-contains? json ", }"))
                             (not (string-contains? json ", ]")))))))))

(df test-parse-openai-tool-call [] -> Bool
  :d "Validates structured argument parsing from JSON into ASL key-value pairs."
  (let [(call (tc/OpenAiToolCall
                :id "call_001"
                :function-name "fs_read"
                :arguments-json "{\"path\": \"src/main.asl\", \"line_count\": 50}"))
        (parsed (tc/parse-openai-tool-call call))
        (args (.-arguments parsed))]
    (and (= (.-id parsed) "call_001")
         (and (= (.-tool-name parsed) "fs-read")
              (and (= (list-length args) 2)
                   (and (= (fst (list-head args)) "path")
                        (= (snd (list-head args)) "src/main.asl")))))))

(df test-asn-call-to-openai-json [] -> Bool
  :d "Validates translating internal ToolCall into valid OpenAI JSON payload."
  (let [(call (c/ToolCall
                :id "call_002"
                :tool-name "fs-write"
                :arguments (list (pair "path" "output.txt") (pair "content" "hello"))))
        (json (tc/asn-call-to-openai-json call))]
    (and (string-contains? json "\"id\": \"call_002\"")
         (and (string-contains? json "\"name\": \"fs_write\"")
              (and (string-contains? json "\"path\": \\\"output.txt\\\"")
                   (not (string-contains? json ", }")))))))

(df test-tools-to-openai-json [] -> Bool
  :d "Validates generating valid OpenAI tools array without trailing commas."
  (let [(tools (c/standard-coding-tools))
        (json (tc/tools-to-openai-json tools))]
    (and (string-starts-with? json "[")
         (and (string-ends-with? json "]")
              (and (not (string-contains? json ", ]"))
                   (string-contains? json "\"name\": \"fs_read\""))))))

(df test-toolcall [] -> Bool
  :d "Aggregate toolcall test runner for benchmark/grammar registry."
  (and (test-tool-schema-typing)
       (and (test-parse-openai-tool-call)
            (and (test-asn-call-to-openai-json)
                 (test-tools-to-openai-json)))))

(df run-tests [] -> Bool
  :d "Executes all toolcall unit tests."
  (test-toolcall))
