(module asl-harness/tests/asn-protocol-agent-test
  :d "Unit verification suite for pure ASN prompt and completion protocol harness adapter."
  :x [test-agent-state-construction
      test-tool-definition-construction
      test-format-tool-schema
      test-format-agent-prompt
      test-format-tool-return
      test-parse-completion-basic
      test-parse-completion-tool-calls
      test-parse-completion-edge-cases
      run-tests]
  :i [(asn_protocol_agent :a apa)])

(df test-agent-state-construction [] -> Bool
  :d "Verifies AsnAgentState constructor, field accessors, and empty list behavior."
  (let [(st (apa/AsnAgentState
              :session-id "sess-test-1"
              :turns 5
              :context (list "goal: benchmark" "step: 1")
              :active-tools (list "run_command" "view_file")))
        (st-empty (apa/AsnAgentState
                    :session-id "sess-empty"
                    :turns 0
                    :context (list)
                    :active-tools (list)))]
    (do
      (assert (= (.-session-id st) "sess-test-1") "Session ID must match constructor value")
      (assert (= (.-turns st) 5) "Turn count must equal 5")
      (assert (= (list-length (.-context st)) 2) "Context lines count must equal 2")
      (assert (= (list-length (.-active-tools st)) 2) "Active tools count must equal 2")
      (assert (= (.-turns st-empty) 0) "Empty state turns must be zero")
      (assert (list-empty? (.-context st-empty)) "Empty context list must be empty")
      true)))

(df test-tool-definition-construction [] -> Bool
  :d "Verifies AsnToolDefinition construction and field values."
  (let [(t1 (apa/AsnToolDefinition
              :name "view_file"
              :desc "View file contents"
              :params (list "AbsolutePath" "StartLine" "EndLine")))
        (t-empty (apa/AsnToolDefinition
                   :name "noop"
                   :desc "No-op tool"
                   :params (list)))]
    (do
      (assert (= (.-name t1) "view_file") "Tool name must match constructor value")
      (assert (= (.-desc t1) "View file contents") "Tool desc must match constructor value")
      (assert (= (list-length (.-params t1)) 3) "Tool params count must equal 3")
      (assert (= (.-name t-empty) "noop") "Empty tool name must match")
      (assert (list-empty? (.-params t-empty)) "Empty tool params list must be empty")
      (assert (= (.-desc t-empty) "No-op tool") "Empty tool description must match")
      true)))

(df test-format-tool-schema [] -> Bool
  :d "Verifies ASN tool schema serialization across empty and populated tool sets."
  (let [(t1 (apa/AsnToolDefinition
              :name "grep_search"
              :desc "Search patterns"
              :params (list "Query" "SearchPath")))
        (t2 (apa/AsnToolDefinition
              :name "run_cmd"
              :desc "Execute command"
              :params (list "CommandLine")))
        (schema-empty (apa/format-asn-tool-schema (list)))
        (schema-single (apa/format-asn-tool-schema (list t1)))
        (schema-multi (apa/format-asn-tool-schema (list t1 t2)))]
    (do
      (assert (= schema-empty "(:tools [])") "Empty tool list must serialize as (:tools [])")
      (assert (string-contains? schema-single "(:tools [") "Single schema must begin with (:tools [")
      (assert (string-contains? schema-single ":name \"grep_search\"") "Single schema must contain tool name")
      (assert (string-contains? schema-single ":desc \"Search patterns\"") "Single schema must contain desc")
      (assert (string-contains? schema-multi ":name \"run_cmd\"") "Multi schema must contain second tool")
      (assert (string-contains? schema-multi ":params [\"CommandLine\"]") "Multi schema must format params vector")
      true)))

(df test-format-agent-prompt [] -> Bool
  :d "Verifies pure ASN agent prompt encoding includes state context and tool schemas."
  (let [(st (apa/AsnAgentState
              :session-id "sess-prompt-42"
              :turns 2
              :context (list "line 1" "line 2")
              :active-tools (list "grep_search")))
        (t1 (apa/AsnToolDefinition
              :name "grep_search"
              :desc "Search files"
              :params (list "Query")))
        (prompt (apa/format-asn-agent-prompt st (list t1)))
        (st-blank (apa/AsnAgentState
                    :session-id "sess-blank"
                    :turns 0
                    :context (list)
                    :active-tools (list)))
        (prompt-blank (apa/format-asn-agent-prompt st-blank (list)))]
    (do
      (assert (string-contains? prompt "(:asn-prompt") "Prompt must open with (:asn-prompt")
      (assert (string-contains? prompt ":session-id \"sess-prompt-42\"") "Prompt must contain session id")
      (assert (string-contains? prompt ":turns 2") "Prompt must contain turn count")
      (assert (string-contains? prompt ":ctx [\"line 1\" \"line 2\"]") "Prompt must format context vector")
      (assert (string-contains? prompt ":active-tools [\"grep_search\"]") "Prompt must format active tools vector")
      (assert (string-contains? prompt-blank "(:tools [])") "Blank prompt must include empty tool schema")
      true)))

(df test-format-tool-return [] -> Bool
  :d "Verifies ASN tool execution return formatting."
  (let [(ret-ok (apa/AsnToolReturn
                  :call-id "call-999"
                  :status "success"
                  :payload "total files: 42"))
        (ret-err (apa/AsnToolReturn
                   :call-id "call-1000"
                   :status "error"
                   :payload "command exited with code 1"))
        (formatted-ok (apa/format-asn-tool-return ret-ok))
        (formatted-err (apa/format-asn-tool-return ret-err))]
    (do
      (assert (string-contains? formatted-ok "(:return") "Return must open with (:return")
      (assert (string-contains? formatted-ok ":call-id \"call-999\"") "Return must contain call id")
      (assert (string-contains? formatted-ok ":status \"success\"") "Return must contain success status")
      (assert (string-contains? formatted-ok ":payload \"total files: 42\"") "Return must contain payload")
      (assert (string-contains? formatted-err ":status \"error\"") "Error return must contain error status")
      (assert (string-contains? formatted-err "command exited with code 1") "Error return must contain error message")
      true)))

(df test-parse-completion-basic [] -> Bool
  :d "Verifies parsing of structured ASN completion without tool calls."
  (let [(raw "(:completion :intent \"analyze-crash\" :reveal [\"examined log file\" \"stack overflow detected\"] :delta \"fixed buffer ceiling\" :summary \"crash resolved successfully\")")
        (parsed (apa/parse-asn-completion raw))]
    (do
      (assert (= (.-intent parsed) "analyze-crash") "Intent must equal analyze-crash")
      (assert (= (list-length (.-reveal parsed)) 2) "Reveal observations count must equal 2")
      (assert (= (option-or (list-head (.-reveal parsed)) "") "examined log file") "First reveal observation must match")
      (assert (= (.-delta parsed) "fixed buffer ceiling") "Delta must match parsed payload")
      (assert (= (.-summary parsed) "crash resolved successfully") "Summary must match parsed payload")
      (assert (list-empty? (.-tool-calls parsed)) "Tool calls list must be empty")
      true)))

(df test-parse-completion-tool-calls [] -> Bool
  :d "Verifies extraction of structured tool invocations from ASN completion."
  (let [(raw "(:completion :intent \"execute-plan\" :reveal [\"running step\"] :tool-calls [(:call :id \"c-1\" :tool \"view_file\" :args [\"/tmp/main.asl\"]) (:call :id \"c-2\" :tool \"run_cmd\" :args [\"asl check\" \"src\"])] :delta \"\" :summary \"tools dispatched\")")
        (parsed (apa/parse-asn-completion raw))
        (calls (.-tool-calls parsed))]
    (do
      (assert (= (list-length calls) 2) "Parsed tool calls count must equal 2")
      (let [(call-1 (option-or (list-head calls) (apa/AsnToolCall :id "" :tool "" :args (list))))
            (tail (option-or (list-tail calls) (list)))
            (call-2 (option-or (list-head tail) (apa/AsnToolCall :id "" :tool "" :args (list))))]
        (do
          (assert (= (.-id call-1) "c-1") "First call id must equal c-1")
          (assert (= (.-tool call-1) "view_file") "First call tool must equal view_file")
          (assert (= (list-length (.-args call-1)) 1) "First call args count must equal 1")
          (assert (= (.-id call-2) "c-2") "Second call id must equal c-2")
          (assert (= (.-tool call-2) "run_cmd") "Second call tool must equal run_cmd")
          true)))))

(df test-parse-completion-edge-cases [] -> Bool
  :d "Verifies completion parser resilience with empty input, fallback desc, and standalone tool calls."
  (let [(p-empty (apa/parse-asn-completion ""))
        (raw-desc "(:completion :intent \"inspect\" :desc \"fallback description used\")")
        (p-desc (apa/parse-asn-completion raw-desc))
        (raw-single "(:call :id \"call-solo\" :tool \"asl-gate\" :args [\"--all\"])")
        (p-single (apa/parse-asn-completion raw-single))]
    (do
      (assert (= (.-intent p-empty) "") "Empty completion intent must be empty string")
      (assert (list-empty? (.-tool-calls p-empty)) "Empty completion tool calls must be empty")
      (assert (= (.-summary p-desc) "fallback description used") "Fallback desc must populate summary")
      (assert (= (list-length (.-tool-calls p-single)) 1) "Standalone tool call must parse 1 call")
      (let [(solo-call (option-or (list-head (.-tool-calls p-single)) (apa/AsnToolCall :id "" :tool "" :args (list))))]
        (do
          (assert (= (.-id solo-call) "call-solo") "Solo call id must match")
          (assert (= (.-tool solo-call) "asl-gate") "Solo call tool must match")
          true)))))

(df run-tests [] -> Bool
  :d "Executes complete pure ASN protocol agent test battery."
  (and (test-agent-state-construction)
       (and (test-tool-definition-construction)
            (and (test-format-tool-schema)
                 (and (test-format-agent-prompt)
                      (and (test-format-tool-return)
                           (and (test-parse-completion-basic)
                                (and (test-parse-completion-tool-calls)
                                     (test-parse-completion-edge-cases)))))))))
