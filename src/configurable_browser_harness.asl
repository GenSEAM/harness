(module asl-harness/configurable-browser-harness
  :d "Configurable Browser Harness and Preset Engine for Sub-3B Models"
  :x [BrowserExecutionContext
      DynamicHarnessRoute
      SpecializedHarnessPreset
      PresetExecutionPlan
      TranspiledOutput
      ThreadProfileMetrics
      make-browser-execution-context
      make-dynamic-harness-route
      route-dynamic-harness
      make-specialized-harness-preset
      generate-preset-execution-plan
      evaluate-execution-thread-profile
      transpile-preset-to-browser
      format-dynamic-route-asn
      format-preset-plan-asn
      format-thread-profile-asn]
  :i [])

(dfs BrowserExecutionContext
  :d "Browser execution context profile"
  (:f mode Str "Execution threading mode single-thread or multi-thread")
  (:f thread-id Str "Worker thread identifier")
  (:f worker-count I64 "Number of active WebWorker threads")
  (:f shared-buffer-supported Bool "SharedArrayBuffer support"))

(dfs DynamicHarnessRoute
  :d "Dynamic capability routing decision"
  (:f capability Str "Target capability category")
  (:f model-id Str "Target model identifier")
  (:f tier Str "Calibrated model tier")
  (:f execution-mode Str "Recommended execution mode")
  (:f schema-tokens I64 "Overhead schema tokens")
  (:f fsm-depth I64 "Max FSM delimiter nesting depth"))

(dfs SpecializedHarnessPreset
  :d "Preconfigured specialized affirmative harness profile"
  (:f preset-id Str "Unique preset identifier")
  (:f category Str "Category grouping")
  (:f target-tier Str "Model tier required")
  (:f recommended-model Str "Specific recommended model")
  (:f execution-context Str "Required execution context")
  (:f affirmative-schema Str "Affirmative system prompt")
  (:f fsm-mask-depth I64 "Delimiter mask depth bound"))

(dfs PresetExecutionPlan
  :d "Execution plan for browser demonstration preset"
  (:f plan-id Str "Unique execution plan ID")
  (:f preset-id Str "Target preset ID")
  (:f route DynamicHarnessRoute "Dynamic harness route")
  (:f input-prompt Str "Standardized input stimulus")
  (:f expected-format Str "Expected output MIME format")
  (:f max-tokens I64 "Generation token ceiling"))

(dfs TranspiledOutput
  :d "Transpiled client-side output for browser rendering"
  (:f output-id Str "Output identifier")
  (:f preset-kind Str "Kind of preset")
  (:f raw-asn Str "Raw generated ASN payload")
  (:f target-format Str "MIME target format")
  (:f rendered-output Str "Compiled browser-consumable markup")
  (:f success Bool "Transpilation success flag"))

(dfs ThreadProfileMetrics
  :d "Execution thread context performance telemetry"
  (:f mode Str "Thread mode")
  (:f estimated-latency-ms I64 "Estimated TTFT latency")
  (:f ui-frame-drop-risk Str "Frame drop risk assessment")
  (:f memory-overhead-mb I64 "RAM overhead in MB")
  (:f fps60-guaranteed Bool "UI frame rate lock guarantee"))

(df make-browser-execution-context [(mode Str) (thread-id Str) (worker-count I64) (shared-buffer-supported Bool)] -> BrowserExecutionContext
  :d "Constructs a browser execution context"
  (BrowserExecutionContext
    :mode mode
    :thread-id thread-id
    :worker-count worker-count
    :shared-buffer-supported shared-buffer-supported))

(df make-dynamic-harness-route [(capability Str) (model-id Str) (tier Str) (execution-mode Str) (schema-tokens I64) (fsm-depth I64)] -> DynamicHarnessRoute
  :d "Constructs a dynamic harness route record"
  (DynamicHarnessRoute
    :capability capability
    :model-id model-id
    :tier tier
    :execution-mode execution-mode
    :schema-tokens schema-tokens
    :fsm-depth fsm-depth))

(df route-dynamic-harness [(capability Str)] -> DynamicHarnessRoute
  :d "Routes a capability requirement to calibrated model tier and harness configuration"
  (if (= capability "toys")
    (make-dynamic-harness-route "toys" "qwen2.5:3b-instruct" "browser-ceiling-slm" "multi-thread" 140 16)
    (if (= capability "websites")
      (make-dynamic-harness-route "websites" "qwen2.5:1.5b" "small-slm-edge" "multi-thread" 118 12)
      (if (= capability "svgs")
        (make-dynamic-harness-route "svgs" "qwen2.5:1.5b" "small-slm-edge" "single-thread" 118 8)
        (if (= capability "nano")
          (make-dynamic-harness-route "nano" "hanse-nano:100m" "nano-slm" "single-thread" 30 4)
          (make-dynamic-harness-route "micro" "qwen2.5:0.5b" "micro-slm" "single-thread" 118 8))))))

(df make-specialized-harness-preset [(preset-id Str) (category Str) (target-tier Str) (recommended-model Str) (execution-context Str) (affirmative-schema Str) (fsm-mask-depth I64)] -> SpecializedHarnessPreset
  :d "Constructs a specialized harness preset specification"
  (SpecializedHarnessPreset
    :preset-id preset-id
    :category category
    :target-tier target-tier
    :recommended-model recommended-model
    :execution-context execution-context
    :affirmative-schema affirmative-schema
    :fsm-mask-depth fsm-mask-depth))

(df generate-preset-execution-plan [(plan-id Str) (preset-id Str) (category Str) (input-prompt Str) (expected-format Str)] -> PresetExecutionPlan
  :d "Generates an execution plan with calibrated route for a preset"
  (let [(route (route-dynamic-harness category))
        (max-toks (if (= category "toys") 512 (if (= category "websites") 384 256)))]
    (PresetExecutionPlan
      :plan-id plan-id
      :preset-id preset-id
      :route route
      :input-prompt input-prompt
      :expected-format expected-format
      :max-tokens max-toks)))

(df evaluate-execution-thread-profile [(mode Str) (tier Str)] -> ThreadProfileMetrics
  :d "Evaluates thread context performance characteristics"
  (if (= mode "multi-thread")
    (ThreadProfileMetrics
      :mode "multi-thread"
      :estimated-latency-ms (if (= tier "browser-ceiling-slm") 35 22)
      :ui-frame-drop-risk "none"
      :memory-overhead-mb 32
      :fps60-guaranteed true)
    (if (= tier "browser-ceiling-slm")
      (ThreadProfileMetrics
        :mode "single-thread"
        :estimated-latency-ms 35
        :ui-frame-drop-risk "high"
        :memory-overhead-mb 0
        :fps60-guaranteed false)
      (if (= tier "nano-slm")
        (ThreadProfileMetrics
          :mode "single-thread"
          :estimated-latency-ms 12
          :ui-frame-drop-risk "none"
          :memory-overhead-mb 0
          :fps60-guaranteed true)
        (ThreadProfileMetrics
          :mode "single-thread"
          :estimated-latency-ms 18
          :ui-frame-drop-risk "low"
          :memory-overhead-mb 0
          :fps60-guaranteed true)))))

(df transpile-preset-to-browser [(output-id Str) (preset-kind Str) (raw-asn Str)] -> TranspiledOutput
  :d "Transpiles raw ASN model output into browser-consumable markup"
  (let [(is-svg (string-contains? preset-kind "vector"))
        (is-vdom (string-contains? preset-kind "vdom"))]
    (if is-svg
      (TranspiledOutput
        :output-id output-id
        :preset-kind preset-kind
        :raw-asn raw-asn
        :target-format "image/svg+xml"
        :rendered-output (str "<svg xmlns=\"http://www.w3.org/2000/svg\" " raw-asn "</svg>")
        :success true)
      (if is-vdom
        (TranspiledOutput
          :output-id output-id
          :preset-kind preset-kind
          :raw-asn raw-asn
          :target-format "text/html"
          :rendered-output (str "<div class=\"vdom-container\">" raw-asn "</div>")
          :success true)
        (TranspiledOutput
          :output-id output-id
          :preset-kind preset-kind
          :raw-asn raw-asn
          :target-format "application/json"
          :rendered-output (str "{\"simulation\": \"" raw-asn "\"}")
          :success true)))))

(df format-dynamic-route-asn [(route DynamicHarnessRoute)] -> Str
  :d "Formats dynamic route as canonical ASN"
  (str "(:route :capability \"" (.-capability route) "\" :model-id \"" (.-model-id route) "\" :tier \"" (.-tier route) "\" :execution-mode \"" (.-execution-mode route) "\" :schema-tokens " (string-from-int64 (.-schema-tokens route)) " :fsm-depth " (string-from-int64 (.-fsm-depth route)) ")"))

(df format-preset-plan-asn [(plan PresetExecutionPlan)] -> Str
  :d "Formats preset execution plan as canonical ASN"
  (str "(:plan :plan-id \"" (.-plan-id plan) "\" :preset-id \"" (.-preset-id plan) "\" :max-tokens " (string-from-int64 (.-max-tokens plan)) " :format \"" (.-expected-format plan) "\")"))

(df format-thread-profile-asn [(profile ThreadProfileMetrics)] -> Str
  :d "Formats thread profile telemetry as canonical ASN"
  (str "(:thread-profile :mode \"" (.-mode profile) "\" :latency-ms " (string-from-int64 (.-estimated-latency-ms profile)) " :frame-drop-risk \"" (.-ui-frame-drop-risk profile) "\" :fps60-guaranteed " (if (.-fps60-guaranteed profile) "true" "false") ")"))
