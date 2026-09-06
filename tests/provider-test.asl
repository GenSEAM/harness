(module asl-harness/provider-test
  :d "Unit tests for LLM Gateway provider configuration, message construction, payload serialization, and response parsing."
  :x [run-tests]
  :i [(provider :a prov)])

(df test-gateway-config [] -> Bool
  :d "Verifies default LLM Gateway configuration endpoint and parameters."
  (let [(cfg (prov/default-gateway-config))]
    (and (= (.-model cfg) "gemma-4-31b-it")
         (= (.-base-url cfg) "https://api.llmgateway.io/v1")
         (= (.-max-tokens cfg) 4096))))

(df test-message-creation [] -> Bool
  :d "Verifies creation of typed chat messages."
  (let [(m1 (prov/make-message "user" "hello world"))
        (m2 (prov/make-message "system" "you are eddie"))]
    (and (= (.-role m1) "user")
         (= (.-content m1) "hello world")
         (= (.-role m2) "system")
         (= (.-content m2) "you are eddie"))))

(df test-payload-serialization [] -> Bool
  :d "Verifies JSON payload construction with messages and tools array."
  (let [(cfg (prov/default-gateway-config))
        (msgs (list (prov/make-message "user" "list files")))
        (tools (list "file_view" "edit_file"))
        (payload (prov/build-chat-payload cfg msgs tools))]
    (and (= (.-model payload) "gemma-4-31b-it")
         (> (.-max-tokens payload) 0))))

(df test-response-parsing [] -> Bool
  :d "Verifies model response payload normalization."
  (let [(r1 (prov/parse-model-response "Task resolved cleanly" false))
        (r2 (prov/parse-model-response "Calling tool" true))]
    (and (= (.-text r1) "Task resolved cleanly")
         (= (.-finish-reason r1) "stop")
         (= (.-text r2) "Calling tool")
         (= (.-finish-reason r2) "stop"))))

(df run-tests [] -> Bool
  :d "Executes all test cases in suite"
  (and (test-gateway-config)
       (and (test-message-creation)
            (and (test-payload-serialization)
                 (test-response-parsing)))))
