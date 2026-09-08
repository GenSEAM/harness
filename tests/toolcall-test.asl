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
    (assert (string-contains? json "\"file_path\": {\"type\": \"string\"") "schema has file_path string")
    (assert (string-contains? json "\"line_count\": {\"type\": \"integer\"") "schema has line_count integer")
    (assert (string-contains? json "\"dry_run\": {\"type\": \"boolean\"") "schema has dry_run boolean")
    (assert (string-contains? json "\"required\": [\"file_path\", \"line_count\"]") "schema has required array")
    (assert (not (string-contains? json ", }")) "no trailing comma before }")
    (assert (not (string-contains? json ", ]")) "no trailing comma before ]")
    true))

(df test-parse-openai-tool-call [] -> Bool
  :d "Validates structured argument parsing from JSON into ASL key-value pairs."
  (let [(call (tc/OpenAiToolCall
                :id "call_001"
                :function-name "fs_read"
                :arguments-json "{\"path\": \"src/main.asl\", \"line_count\": 50}"))
        (parsed (tc/parse-openai-tool-call call))
        (args (.-arguments parsed))]
    (assert (= (.-id parsed) "call_001") "id is call_001")
    (assert (= (.-tool-name parsed) "fs-read") "tool-name is fs-read")
    (assert (= (list-length args) 2) "args length is 2")
    (assert (= (fst (list-head args)) "path") "first arg key is path")
    (assert (= (snd (list-head args)) "src/main.asl") "first arg val is src/main.asl")
    true))

(df test-asn-call-to-openai-json [] -> Bool
  :d "Validates translating internal ToolCall into valid OpenAI JSON payload."
  (let [(call (c/ToolCall
                :id "call_002"
                :tool-name "fs-write"
                :arguments (list (pair "path" "output.txt") (pair "content" "hello"))))
        (json (tc/asn-call-to-openai-json call))]
    (assert (string-contains? json "\"id\": \"call_002\"") "json has id call_002")
    (assert (string-contains? json "\"name\": \"fs_write\"") "json has name fs_write")
    (assert (string-contains? json "\"path\": \\\"output.txt\\\"") "json has path output.txt")
    (assert (not (string-contains? json ", }")) "no trailing comma before }")
    true))

(df test-tools-to-openai-json [] -> Bool
  :d "Validates generating valid OpenAI tools array without trailing commas."
  (let [(tools (c/standard-coding-tools))
        (json (tc/tools-to-openai-json tools))]
    (assert (string-starts-with? json "[") "starts with [")
    (assert (string-ends-with? json "]") "ends with ]")
    (assert (not (string-contains? json ", ]")) "no trailing comma before ]")
    (assert (string-contains? json "\"name\": \"fs_read\"") "contains fs_read")
    true))

(df test-toolcall [] -> Bool
  :d "Aggregate toolcall test runner for benchmark/grammar registry."
  (do
    (test-tool-schema-typing)
    (test-parse-openai-tool-call)
    (test-asn-call-to-openai-json)
    (test-tools-to-openai-json)
    true))

(df run-tests [] -> Bool
  :d "Executes all toolcall unit tests."
  (test-toolcall))
