(module asl-harness/provider-test
  :d "Unit tests for LLM Gateway provider configuration, message construction, payload serialization, reasoning quarantine, and ESH interception."
  :x [run-tests]
  :i [(provider :a prov)
      (coding :a c)])

(df test-gateway-config [] -> Bool
  :d "Verifies default LLM Gateway configuration endpoint and parameters."
  (let [(cfg (prov/default-gateway-config))]
    (assert (= (.-model cfg) "gemma-4-31b-it") "model is gemma-4-31b-it")
    (assert (= (.-base-url cfg) "http://127.0.0.1:8765/v1") "base url matches")
    (assert (= (.-max-tokens cfg) 4096) "max tokens is 4096")
    true))

(df test-message-creation [] -> Bool
  :d "Verifies creation of typed chat messages."
  (let [(m1 (prov/make-message "user" "hello world"))
        (m2 (prov/make-message "system" "you are eddie"))]
    (assert (= (.-role m1) "user") "m1 role is user")
    (assert (= (.-content m1) "hello world") "m1 content matches")
    (assert (= (.-role m2) "system") "m2 role is system")
    (assert (= (.-content m2) "you are eddie") "m2 content matches")
    true))

(df test-payload-serialization [] -> Bool
  :d "Verifies JSON payload construction with messages and tools array."
  (let [(cfg (prov/default-gateway-config))
        (msgs (list (prov/make-message "user" "list files")))
        (tools (c/standard-coding-tools))
        (payload (prov/build-request-payload cfg msgs tools))]
    (assert (string-contains? payload "gemma-4-31b-it") "payload contains model")
    (assert (string-contains? payload "list files") "payload contains user message")
    true))

(df test-response-parsing [] -> Bool
  :d "Verifies model response payload normalization."
  (let [(r1 (prov/parse-model-response "Task resolved cleanly" false))
        (r2 (prov/parse-model-response "Calling tool" true))]
    (assert (= (.-text r1) "Task resolved cleanly") "r1 text matches")
    (assert (= (.-finish-reason r1) "stop") "r1 finish reason is stop")
    (assert (= (.-text r2) "Calling tool") "r2 text matches")
    (assert (= (.-finish-reason r2) "stop") "r2 finish reason is stop")
    true))

(df test-think-quarantine [] -> Bool
  :d "Verifies that <think> reasoning blocks are quarantined from response text."
  (let [(raw "<think>internal reasoning steps</think>Hello user")
        (r (prov/parse-model-response raw false))]
    (assert (= (.-text r) "Hello user") "think block quarantined")
    (assert (= (.-finish-reason r) "stop") "finish reason is stop")
    true))

(df test-esh-rejection [] -> Bool
  :d "Verifies that verbal claims of test passage without verified receipt are rejected."
  (let [(raw "I completed the work. All tests pass cleanly.")
        (r (prov/parse-model-response raw false))]
    (assert (= (.-finish-reason r) "esh_rejected") "verbal ESH flagged")
    true))

(df run-tests [] -> Bool
  :d "Executes all test cases in suite"
  (do
    (test-gateway-config)
    (test-message-creation)
    (test-payload-serialization)
    (test-response-parsing)
    (test-think-quarantine)
    (test-esh-rejection)
    true))

