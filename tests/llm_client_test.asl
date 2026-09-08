(module asl-harness/tests/llm-client-test
  :d "Comprehensive unit verification suite for LLM client dispatcher, telemetry profiler, and eval ledger"
  :x [run-tests
      test-model-options-and-request
      test-response-parsing-and-metrics
      test-grammar-constraint-compilation
      test-trace-recording-and-serialization
      test-model-profiler-and-slow-provider
      test-eval-corpus-curation-and-export
      test-dynamic-temperature-scheduling]
  :i [(llm_client :a lc)
      (trace_recorder :a tr)
      (eval_corpus :a ec)])

(df test-model-options-and-request [] -> Bool
  :d "Verifies ModelOptions construction, defaults, grammar optionality, and request formatting"
  (let [(def-opts (lc/make-default-options "gemma-4-31b-it"))
        (custom-opts (lc/ModelOptions
                       :model "claude-3-7-sonnet"
                       :temperature 0.7
                       :max-tokens 8192
                       :system "You are an ASL engineer."
                       :grammar-constraint (some "root ::= [a-z]+")))
        (req-payload (lc/format-model-request def-opts "Hello model"))]
    (do
      (assert (and (= (.-model def-opts) "gemma-4-31b-it") (= (.-temperature def-opts) 0.2)) "Default options must initialize target model and temperature 0.2")
      (assert (= (.-max-tokens def-opts) 4096) "Default options must allocate 4096 max tokens")
      (assert (option-is-none? (.-grammar-constraint def-opts)) "Default options must initialize grammar constraint to none")
      (assert (option-is-some? (.-grammar-constraint custom-opts)) "Custom options with grammar constraint must hold some")
      (assert (and (string-contains? req-payload "gemma-4-31b-it") (string-contains? req-payload "\"system\": \"\"")) "Request payload must contain model identifier and system prompt")
      true)))

(df test-response-parsing-and-metrics [] -> Bool
  :d "Verifies CompletionResult parsing, token metrics, duration recording, and speed calculation"
  (let [(raw-json "{\"text\": \"AgentScript generated\", \"prompt_tokens\": 120, \"completion_tokens\": 60}")
        (res (lc/parse-model-response raw-json 2000))
        (speed (lc/calculate-tok-sec 100 2000))
        (zero-speed (lc/calculate-tok-sec 100 0))]
    (do
      (assert (= (.-text res) "AgentScript generated") "parse-model-response must construct typed CompletionResult with parsed text")
      (assert (and (= (.-input-tokens res) 120) (= (.-output-tokens res) 60)) "Parsed token metrics must match input and output tokens")
      (assert (= (.-duration-ms res) 2000) "Recorded duration must match execution duration argument")
      (assert (= speed 50.0) "calculate-tok-sec must accurately calculate throughput speed tokens per second")
      (assert (= zero-speed 0.0) "calculate-tok-sec must safely return zero for non-positive duration")
      true)))

(df test-grammar-constraint-compilation [] -> Bool
  :d "Verifies GBNF grammar constraint compilation from ASN schema definitions"
  (let [(compiled-opt (lc/compile-asn-grammar-constraint "(:record :name \"Task\")"))
        (empty-opt (lc/compile-asn-grammar-constraint "   "))
        (compiled-str (option-or compiled-opt ""))]
    (do
      (assert (option-is-some? compiled-opt) "Valid schema specification must compile to some GBNF string")
      (assert (string-contains? compiled-str "root ::=") "Compiled GBNF grammar must define root rule")
      (assert (option-is-none? empty-opt) "Empty schema specification must compile to none")
      (assert (> (string-length compiled-str) 20) "Compiled GBNF grammar must yield substantive rule definitions")
      (assert (and (not (string-contains? compiled-str ";")) (not (string-contains? compiled-str "//"))) "Compiled GBNF grammar must exclude foreign comment delimiters")
      true)))

(df test-trace-recording-and-serialization [] -> Bool
  :d "Verifies interaction trace envelope construction and canonical ASN serialization"
  (let [(opts (lc/make-default-options "gemma-4-31b-it"))
        (res (lc/CompletionResult
               :text "(:action :run-gate)"
               :input-tokens 50
               :output-tokens 25
               :duration-ms 500
               :tok-sec 50.0))
        (trace (tr/record-interaction-trace "trace-001" 1725800000000 opts res "success"))
        (asn-str (tr/format-trace-asn trace))]
    (do
      (assert (and (= (.-trace-id trace) "trace-001") (= (.-timestamp-ms trace) 1725800000000)) "Trace record must aggregate trace identifier and timestamp")
      (assert (= (.-status trace) "success") "Trace record status must record execution verdict")
      (assert (and (string-starts-with? asn-str "(") (string-ends-with? asn-str ")")) "format-trace-asn must generate valid balanced ASN S-expression string")
      (assert (and (string-contains? asn-str ":interaction-trace") (string-contains? asn-str ":trace-id \"trace-001\"")) "Serialized trace string must contain interaction-trace marker and trace-id")
      (assert (and (string-contains? asn-str ":tokens-out 25") (string-contains? asn-str ":tok-sec 50.0")) "Serialized trace string must embed output tokens and throughput metrics")
      true)))

(df test-model-profiler-and-slow-provider [] -> Bool
  :d "Verifies model telemetry profile recurrence and slow-provider anomaly detection"
  (let [(p0 (tr/make-model-profile "gemma-4-31b-it"))
        (r1 (lc/CompletionResult :text "r1" :input-tokens 100 :output-tokens 50 :duration-ms 1000 :tok-sec 50.0))
        (p1 (tr/update-model-profile p0 r1))
        (r2 (lc/CompletionResult :text "r2" :input-tokens 100 :output-tokens 50 :duration-ms 1500 :tok-sec 33.333333333333336))
        (p2 (tr/update-model-profile p1 r2))
        (r-slow (lc/CompletionResult :text "slow" :input-tokens 100 :output-tokens 10 :duration-ms 4000 :tok-sec 2.5))
        (p-slow (tr/update-model-profile p0 r-slow))]
    (do
      (assert (and (= (.-total-calls p0) 0) (not (.-slow-provider p0))) "Initial model profile must have 0 total calls and slow-provider false")
      (assert (and (= (.-total-calls p1) 1) (= (.-avg-duration-ms p1) 1000)) "update-model-profile must increment total calls to 1 and track initial duration")
      (assert (and (= (.-total-calls p2) 2) (= (.-avg-duration-ms p2) 1250)) "update-model-profile must update weighted average duration on subsequent calls")
      (assert (not (.-slow-provider p1)) "Fast provider exceeding 10 tok-sec within 3000ms duration must retain slow-provider false")
      (assert (.-slow-provider p-slow) "Slow provider with sub-10 tok-sec or duration exceeding 3000ms must trip slow-provider true")
      true)))

(df test-eval-corpus-curation-and-export [] -> Bool
  :d "Verifies evaluation corpus curation, rating threshold filtering, and SFT/DPO export"
  (let [(c0 (ec/make-eval-corpus "harness-benchmark"))
        (pair1 (ec/EvalInteractionPair
                 :pair-id "pair-1"
                 :prompt "Generate factorial"
                 :response "(:df fact [(n I64)] -> I64 ...)"
                 :model "gemma-4-31b-it"
                 :verdict "pass"
                 :rating 0.95))
        (pair2 (ec/EvalInteractionPair
                 :pair-id "pair-2"
                 :prompt "Generate factorial"
                 :response "syntax error: unclosed paren"
                 :model "gemma-4-31b-it"
                 :verdict "fail"
                 :rating 0.15))
        (c1 (ec/add-interaction-pair c0 pair1))
        (c2 (ec/add-interaction-pair c1 pair2))
        (curated (ec/curate-interaction-corpus c2 0.8))
        (benchmarks (ec/export-benchmark-dataset curated))
        (preferences (ec/export-preference-pairs c2))]
    (do
      (assert (and (= (.-corpus-name c0) "harness-benchmark") (= (.-total-pairs c0) 0)) "Empty corpus must initialize with target name and zero pairs")
      (assert (= (.-total-pairs c2) 2) "add-interaction-pair must increment total pairs count to 2")
      (assert (= (.-total-pairs curated) 1) "curate-interaction-corpus must filter out pairs below minimum rating")
      (assert (= (list-length benchmarks) 1) "export-benchmark-dataset must export curated pairs as benchmark fixtures")
      (assert (and (> (list-length preferences) 0) (string-contains? (option-or (list-head preferences) "") ":chosen")) "export-preference-pairs must generate contrastive SFT/DPO preference pairs with chosen and rejected completions")
      true)))

(df test-dynamic-temperature-scheduling [] -> Bool
  :d "Verifies dynamic temperature scheduling across retry attempts, ceilings, and boundary clamping"
  (let [(t0 (lc/compute-dynamic-temperature 0 4 0.2))
        (t1 (lc/compute-dynamic-temperature 1 4 0.2))
        (t2 (lc/compute-dynamic-temperature 2 4 0.2))
        (t4 (lc/compute-dynamic-temperature 4 4 0.2))
        (t-overflow (lc/compute-dynamic-temperature 6 4 0.2))
        (t-single (lc/compute-dynamic-temperature 1 1 0.2))
        (t-neg (lc/compute-dynamic-temperature 0 4 -0.5))]
    (do
      (assert (= t0 0.2) "Initial attempt 0 must preserve base temperature 0.2")
      (assert (= t1 0.4) "First retry attempt must dynamically escalate temperature to 0.4")
      (assert (= t2 0.6) "Second retry attempt must dynamically escalate temperature to 0.6")
      (assert (= t4 1.0) "Final attempt reaching max-attempts must reach ceiling temperature 1.0")
      (assert (= t-overflow 1.0) "Attempts exceeding max-attempts must saturate at ceiling 1.0")
      (assert (= t-single 0.2) "Single attempt limit must preserve base temperature without escalation")
      (assert (= t-neg 0.0) "Negative base temperature must clamp cleanly to 0.0")
      true)))

(df run-tests [] -> Bool
  :d "Aggregates and executes all unit test suites for Phase 325 and Phase 338"
  (and (test-model-options-and-request)
       (and (test-response-parsing-and-metrics)
            (and (test-grammar-constraint-compilation)
                 (and (test-trace-recording-and-serialization)
                      (and (test-model-profiler-and-slow-provider)
                           (and (test-eval-corpus-curation-and-export)
                                (test-dynamic-temperature-scheduling))))))))
