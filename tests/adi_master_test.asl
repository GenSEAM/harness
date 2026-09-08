(module asl-harness/adi-master-test
  :d "End-to-end verification test suite for ADI master orchestrator, kernel execution, and event bus grounding"
  :x [test-adi-kernel-config
      test-adi-task-execution
      test-adi-speculative-race
      test-agent-bus-lifecycle
      test-adi-receipt-formatting
      run-tests]
  :i [(harness :a h)
      (bus :a bus)])

(df test-adi-kernel-config [] -> Bool
  :d "Verifies ADI kernel initialization, default configuration values, and custom configuration properties"
  (let [(cfg-default (h/make-kernel-config "gemini-pro" true))
        (cfg-custom (h/ADIKernelConfig
                      :model "agy"
                      :temperature 0.1
                      :speculative false
                      :gate-command "asl gate"
                      :max-turns 5
                      :timeout-ms 30000))]
    (do
      (assert (= (.-model cfg-default) "gemini-pro") "Default kernel model must match requested model")
      (assert (= (.-temperature cfg-default) 0.2) "Default sampling temperature must be 0.2")
      (assert (.-speculative cfg-default) "Speculative racing must be enabled in default config")
      (assert (= (.-gate-command cfg-default) "asl test") "Default gate command must be asl test")
      (assert (= (.-max-turns cfg-default) 3) "Default turn budget must be 3")
      (assert (= (.-timeout-ms cfg-default) 15000) "Default execution timeout must be 15000ms")
      (assert (= (.-model cfg-custom) "agy") "Custom kernel model must match agy")
      (assert (= (.-temperature cfg-custom) 0.1) "Custom sampling temperature must be 0.1")
      (assert (not (.-speculative cfg-custom)) "Custom config speculative flag must be false")
      (assert (= (.-gate-command cfg-custom) "asl gate") "Custom gate command must be asl gate")
      (assert (= (.-max-turns cfg-custom) 5) "Custom max turns must be 5")
      (assert (= (.-timeout-ms cfg-custom) 30000) "Custom timeout must be 30000ms")
      true)))

(df test-adi-task-execution [] -> Bool
  :d "Verifies end-to-end task execution across text and voice modalities with prompt context pool and worker lane"
  (let [(cfg (h/make-kernel-config "gemini-pro" true))
        (req-text (h/make-task-request "t-101" "text" "implement AST parser" "asl test" 2048))
        (req-voice (h/make-task-request "t-102" "voice" "run verification gate" "asl gate" 1024))
        (rec-text (h/run-adi-kernel cfg req-text))
        (rec-voice (h/run-adi-kernel cfg req-voice))]
    (do
      (assert (= (.-task-id req-text) "t-101") "Task request ID must match input")
      (assert (= (.-input-kind req-text) "text") "Text modality input kind must be preserved")
      (assert (= (.-token-budget req-text) 2048) "Token budget must be 2048")
      (assert (= (.-task-id req-voice) "t-102") "Voice task request ID must match input")
      (assert (= (.-input-kind req-voice) "voice") "Voice modality input kind must be preserved")
      (assert (= (.-token-budget req-voice) 1024) "Token budget must be 1024")
      (assert (= (.-task-id rec-text) "t-101") "Receipt task ID must match request ID")
      (assert (.-verified rec-text) "Text task execution receipt must be verified")
      (assert (= (.-status rec-text) "pass") "Text task adjudication status must be pass")
      (assert (= (.-exit-code rec-text) 0) "Text task exit code must be 0")
      (assert (= (.-gate-cmd rec-text) "asl test") "Text task receipt gate command must match contract")
      (assert (= (.-task-id rec-voice) "t-102") "Voice receipt task ID must match request ID")
      (assert (.-verified rec-voice) "Voice task execution receipt must be verified")
      (assert (= (.-status rec-voice) "pass") "Voice task adjudication status must be pass")
      (assert (= (.-exit-code rec-voice) 0) "Voice task exit code must be 0")
      (assert (= (.-gate-cmd rec-voice) "asl gate") "Voice task receipt gate command must match contract")
      true)))

(df test-adi-speculative-race [] -> Bool
  :d "Verifies dual-temperature racing, deterministic tie-breaking, and supervisor adjudication under failures"
  (let [(cfg-race (h/make-kernel-config "gemini-pro" true))
        (cfg-single (h/make-kernel-config "slm" false))
        (req-normal (h/make-task-request "t-201" "text" "optimize inner loop" "asl test" 1500))
        (req-syntax (h/make-task-request "t-202" "text" "syntax-error in code" "asl test" 1500))
        (req-fail (h/make-task-request "t-203" "text" "force-fail gate check" "asl test" 1500))
        (rec-race (h/run-adi-kernel cfg-race req-normal))
        (rec-single (h/run-adi-kernel cfg-single req-normal))
        (rec-syntax (h/run-adi-kernel cfg-race req-syntax))
        (rec-fail (h/run-adi-kernel cfg-race req-fail))]
    (do
      (assert (= (.-lane rec-race) "alpha") "Dual-temperature race must select conservative alpha lane")
      (assert (.-verified rec-race) "Speculative race winner must be verified")
      (assert (= (.-status rec-race) "pass") "Speculative race winner must receive pass status")
      (assert (= (.-exit-code rec-race) 0) "Speculative race winner exit code must be 0")
      (assert (> (.-duration-ms rec-race) 0) "Speculative race must record positive latency")
      (assert (= (.-lane rec-single) "alpha") "Single worker execution must execute on alpha lane")
      (assert (.-verified rec-single) "Single worker execution must be verified")
      (assert (= (.-status rec-syntax) "retry") "Syntax error must trigger supervisor retry verdict")
      (assert (not (.-verified rec-syntax)) "Syntax error must not be marked as verified")
      (assert (= (.-exit-code rec-syntax) 1) "Syntax error exit code must be 1")
      (assert (= (.-status rec-fail) "fail") "Gate failure must trigger supervisor fail verdict")
      (assert (not (.-verified rec-fail)) "Gate failure must not be marked as verified")
      (assert (= (.-exit-code rec-fail) 1) "Gate failure exit code must be 1")
      true)))

(df test-agent-bus-lifecycle [] -> Bool
  :d "Verifies pure ASL event bus channel dispatch, lifecycle state transitions, and SSE wire streaming"
  (let [(ch-life (bus/lifecycle))
        (ch-telem (bus/telemetry))
        (ch-ctrl (bus/control))
        (ch-aud (bus/audit))
        (st-q (bus/queued))
        (st-r (bus/routing))
        (st-e (bus/executing))
        (st-v (bus/verifying))
        (st-d (bus/done))
        (st-f (bus/failed))
        (msg-e (bus/make-lifecycle-event "t-301" st-e "alpha worker running"))
        (rcpt-e (bus/dispatch-bus-event ch-life msg-e))
        (msg-d (bus/make-lifecycle-event "t-301" st-d "gate passed cleanly"))
        (rcpt-d (bus/dispatch-bus-event ch-telem msg-d))
        (sse-e (bus/format-lifecycle-sse "t-301" st-e "alpha worker running"))
        (sse-v (bus/format-lifecycle-sse "t-301" st-v "verifying clean context"))]
    (do
      (assert (= (bus/channel-to-str ch-life) "lifecycle") "Lifecycle channel string representation must match")
      (assert (= (bus/channel-to-str ch-telem) "telemetry") "Telemetry channel string representation must match")
      (assert (= (bus/channel-to-str ch-ctrl) "control") "Control channel string representation must match")
      (assert (= (bus/channel-to-str ch-aud) "audit") "Audit channel string representation must match")
      (assert (= (bus/lifecycle-to-str st-q) "QUEUED") "Lifecycle state QUEUED token must match")
      (assert (= (bus/lifecycle-to-str st-r) "ROUTING") "Lifecycle state ROUTING token must match")
      (assert (= (bus/lifecycle-to-str st-e) "EXECUTING") "Lifecycle state EXECUTING token must match")
      (assert (= (bus/lifecycle-to-str st-v) "VERIFYING") "Lifecycle state VERIFYING token must match")
      (assert (= (bus/lifecycle-to-str st-d) "DONE") "Lifecycle state DONE token must match")
      (assert (= (bus/lifecycle-to-str st-f) "FAILED") "Lifecycle state FAILED token must match")
      (assert (= (.-channel rcpt-e) "lifecycle") "Dispatch receipt channel must match target channel")
      (assert (.-delivered rcpt-e) "Receipt delivered status must be true")
      (assert (= (.-sender rcpt-e) "kernel") "Receipt sender must be kernel")
      (assert (= (.-channel rcpt-d) "telemetry") "Telemetry dispatch receipt channel must match")
      (assert (.-delivered rcpt-d) "Telemetry delivery status must be true")
      (assert (string-contains? (.-payload msg-e) "EXECUTING") "Event payload must contain EXECUTING token")
      (assert (string-contains? (.-payload msg-e) "t-301") "Event payload must contain task ID")
      (assert (string-contains? (.-payload msg-d) "DONE") "Event payload must contain DONE token")
      (assert (string-contains? sse-e "event: lifecycle") "SSE payload must declare lifecycle event")
      (assert (string-contains? sse-e "EXECUTING") "SSE payload must include EXECUTING state")
      (assert (string-ends-with? sse-e "\n\n") "SSE wire format must terminate with double newline")
      (assert (string-contains? sse-v "VERIFYING") "SSE payload must include VERIFYING state")
      (assert (string-ends-with? sse-v "\n\n") "SSE wire format must terminate with double newline")
      true)))

(df test-adi-receipt-formatting [] -> Bool
  :d "Verifies ND-ASN receipt serialization, single-token property keys, and audit envelope structure"
  (let [(rec-pass (h/ADIExecutionReceipt
                    :task-id "t-401"
                    :lane "alpha"
                    :status "pass"
                    :exit-code 0
                    :gate-cmd "asl gate"
                    :output "all 7 gates green"
                    :verified true
                    :duration-ms 125))
        (rec-fail (h/ADIExecutionReceipt
                    :task-id "t-402"
                    :lane "beta"
                    :status "fail"
                    :exit-code 1
                    :gate-cmd "asl test"
                    :output "assertion failure"
                    :verified false
                    :duration-ms 350))
        (fmt-pass (h/format-adi-receipt rec-pass))
        (fmt-fail (h/format-adi-receipt rec-fail))]
    (do
      (assert (string-starts-with? fmt-pass "(:adi-receipt") "ND-ASN receipt must start with :adi-receipt header")
      (assert (string-contains? fmt-pass ":task \"t-401\"") "ND-ASN receipt must encode :task key")
      (assert (string-contains? fmt-pass ":lane \"alpha\"") "ND-ASN receipt must encode :lane key")
      (assert (string-contains? fmt-pass ":status \"pass\"") "ND-ASN receipt must encode :status key")
      (assert (string-contains? fmt-pass ":code 0") "ND-ASN receipt must encode :code 0 for pass")
      (assert (string-contains? fmt-pass ":cmd \"asl gate\"") "ND-ASN receipt must encode :cmd key")
      (assert (string-contains? fmt-pass ":output \"all 7 gates green\"") "ND-ASN receipt must encode :output key")
      (assert (string-contains? fmt-pass ":verified true") "ND-ASN receipt must encode :verified true")
      (assert (string-contains? fmt-pass ":duration 125") "ND-ASN receipt must encode :duration key")
      (assert (string-ends-with? fmt-pass ")") "ND-ASN receipt must terminate with closing parenthesis")
      (assert (string-contains? fmt-fail ":status \"fail\"") "ND-ASN failed receipt must encode :status fail")
      (assert (string-contains? fmt-fail ":code 1") "ND-ASN failed receipt must encode :code 1")
      (assert (string-contains? fmt-fail ":verified false") "ND-ASN failed receipt must encode :verified false")
      true)))

(df run-tests [] -> Bool
  :d "Sequentially executes all 5 ADI master integration and gate grounding test suites"
  (and (test-adi-kernel-config)
       (and (test-adi-task-execution)
            (and (test-adi-speculative-race)
                 (and (test-agent-bus-lifecycle)
                      (test-adi-receipt-formatting))))))
