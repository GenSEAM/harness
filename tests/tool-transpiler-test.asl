(module asl-harness/tool-transpiler-test
  :d "Unit verification test suite for Tool Calling ASN Transpiler"
  :x [test-compact-tool-schema test-json-tool-call-to-asn
      test-asn-to-tool-result test-measure-tool-compaction
      run-tests]
  :i [(tool-transpiler :a tt)])

(df test-compact-tool-schema [] -> Bool
  :d "Validates JSON schema compaction into ASN tool signature"
  (let [(sig (tt/compact-tool-schema "fs-read" (list "path Str" "line I64") "Str"))]
    (assert (string-contains? sig "(tool fs-read") "contains tool fs-read")
    (assert (string-contains? sig "[:path Str :line I64] -> Str)") "contains signature")
    true))

(df test-json-tool-call-to-asn [] -> Bool
  :d "Validates JSON tool call conversion into ASN invocation frame"
  (let [(asn (tt/json-tool-call-to-asn "fs-read" "{\"path\": \"src/main.asl\", \"line\": 42}"))]
    (assert (string-contains? asn "(! fs-read") "contains invocation frame")
    (assert (string-contains? asn ":path src/main.asl") "contains :path argument")
    true))

(df test-asn-to-tool-result [] -> Bool
  :d "Validates formatting ASN tool output into Anthropic tool_result block"
  (let [(res (tt/asn-to-tool-result "call_99" "File read successfully" false))]
    (assert (string-contains? res "\"type\": \"tool_result\"") "contains tool_result type")
    (assert (string-contains? res "\"tool_use_id\": \"call_99\"") "contains tool_use_id")
    true))

(df test-measure-tool-compaction [] -> Bool
  :d "Validates token compaction measurement on tool calling payload"
  (let [(json-call "{\"role\": \"assistant\", \"tool_calls\": [{\"id\": \"call_123\", \"type\": \"function\", \"function\": {\"name\": \"fs-read\", \"arguments\": \"{\\\"path\\\": \\\"packages/asl-codec/src/transpile.asl\\\", \\\"start_line\\\": 1, \\\"end_line\\\": 100}\"}}]} ")
        (asn-call "(! fs-read :path \"packages/asl-codec/src/transpile.asl\" :start 1 :end 100)")
        (res (tt/measure-tool-compaction "fs-read" json-call asn-call))]
    (assert (> (.-json-tokens res) (.-asn-tokens res)) "json tokens > asn tokens")
    (assert (>= (.-savings-percent res) 50.0) "savings percent >= 50")
    true))

(df run-tests [] -> Bool
  :d "Runs all tool transpiler unit tests"
  (do
    (test-compact-tool-schema)
    (test-json-tool-call-to-asn)
    (test-asn-to-tool-result)
    (test-measure-tool-compaction)
    true))
