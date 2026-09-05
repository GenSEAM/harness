(module asl-harness/tool-transpiler-test
  :d "Unit verification test suite for Tool Calling ASN Transpiler"
  :x [test-compact-tool-schema test-json-tool-call-to-asn
      test-asn-to-tool-result test-measure-tool-compaction
      run-tests]
  :i [(tool-transpiler :a tt)])

(df test-compact-tool-schema [] -> Bool
  :d "Validates JSON schema compaction into ASN tool signature"
  (let [(sig (tt/compact-tool-schema "fs-read" (list "path Str" "line I64") "Str"))]
    (and (string-contains? sig "(tool fs-read")
         (string-contains? sig "[:path Str :line I64] -> Str)"))))

(df test-json-tool-call-to-asn [] -> Bool
  :d "Validates JSON tool call conversion into ASN invocation frame"
  (let [(asn (tt/json-tool-call-to-asn "fs-read" "{\"path\": \"src/main.asl\", \"line\": 42}"))]
    (and (string-contains? asn "(! fs-read")
         (string-contains? asn ":path src/main.asl"))))

(df test-asn-to-tool-result [] -> Bool
  :d "Validates formatting ASN tool output into Anthropic tool_result block"
  (let [(res (tt/asn-to-tool-result "call_99" "File read successfully" false))]
    (and (string-contains? res "\"type\": \"tool_result\"")
         (string-contains? res "\"tool_use_id\": \"call_99\""))))

(df test-measure-tool-compaction [] -> Bool
  :d "Validates token compaction measurement on tool calling payload"
  (let [(json-call "{\"role\": \"assistant\", \"tool_calls\": [{\"id\": \"call_123\", \"type\": \"function\", \"function\": {\"name\": \"fs-read\", \"arguments\": \"{\\\"path\\\": \\\"packages/asl-codec/src/transpile.asl\\\", \\\"start_line\\\": 1, \\\"end_line\\\": 100}\"}}]} ")
        (asn-call "(! fs-read :path \"packages/asl-codec/src/transpile.asl\" :start 1 :end 100)")
        (res (tt/measure-tool-compaction "fs-read" json-call asn-call))]
    (and (> (.-json-tokens res) (.-asn-tokens res))
         (>= (.-savings-percent res) 50.0))))

(df run-tests [] -> Bool
  :d "Runs all tool transpiler unit tests"
  (and (test-compact-tool-schema)
       (and (test-json-tool-call-to-asn)
            (and (test-asn-to-tool-result)
                 (test-measure-tool-compaction)))))
