(module asl-harness/slm-browser-profile
  :d "Browser SLM Compact Profile and FSM Delimiter Mask for 500M Models"
  :x [SlmBrowserTool
      SlmAffirmativeSchema
      FsmDelimiterMask
      SlmBrowserProfile
      make-browser-slm-tools
      calculate-schema-tokens
      make-browser-slm-schema
      init-fsm-delimiter-mask
      fsm-feed-char
      validate-slm-token-stream
      format-slm-browser-priming
      make-browser-slm-profile
      validate-browser-model-ceiling
      make-nano-slm-tools
      make-nano-slm-schema
      make-nano-browser-slm-profile]
  :i [])

(dfs SlmBrowserTool
  :d "Compact tool schema for browser SLM"
  (:f name Str "Tool action name e.g. click, type, eval, get_dom")
  (:f signature Str "Affirmative schema signature")
  (:f summary Str "Affirmative capability description")
  (:f token-cost I64 "Estimated token cost of this tool definition"))

(dfs SlmAffirmativeSchema
  :d "Minimal affirmative schema under 118 tokens"
  (:f tools (List SlmBrowserTool) "Allowed tools list")
  (:f total-tokens I64 "Total tokens consumed by schema")
  (:f max-tools I64 "Tool count limit strictly 4")
  (:f affirmative-rule Str "Strict single-action affirmative constraint"))

(dfs FsmDelimiterMask
  :d "Streaming FSM token delimiter mask for browser execution"
  (:f depth I64 "Current nested delimiter depth")
  (:f in-string Bool "String literal parsing state")
  (:f is-escaped Bool "Escape backslash state")
  (:f is-valid Bool "Stream structural validity flag")
  (:f char-count I64 "Total characters scanned")
  (:f max-depth I64 "Maximum allowed nesting depth")
  (:f error-reason Str "Reason for validation failure if any"))

(dfs SlmBrowserProfile
  :d "SLM execution profile for browser web-workers"
  (:f model-name Str "Target model identifier e.g. Qwen2.5-0.5B")
  (:f context-budget I64 "Token budget for context window")
  (:f priming-token-count I64 "Target priming token count 118")
  (:f priming-prompt Str "Compact 118-token priming prompt")
  (:f schema SlmAffirmativeSchema "Affirmative schema configuration")
  (:f fsm-mask FsmDelimiterMask "Default delimiter mask"))

(df make-browser-slm-tools [] -> (List SlmBrowserTool)
  :d "Returns the minimal 4-tool essential affirmative schema for browser SLMs"
  (let [(t-dom (SlmBrowserTool
                 :name "get_dom"
                 :signature "(:act :get_dom)"
                 :summary "Inspect active DOM outline"
                 :token-cost 14))
        (t-click (SlmBrowserTool
                   :name "click"
                   :signature "(:act :click :selector Str)"
                   :summary "Dispatch click to selector"
                   :token-cost 16))
        (t-type (SlmBrowserTool
                  :name "type"
                  :signature "(:act :type :selector Str :text Str)"
                  :summary "Input text into targeted field"
                  :token-cost 18))
        (t-eval (SlmBrowserTool
                  :name "eval"
                  :signature "(:act :eval :expression Str)"
                  :summary "Evaluate JS in isolated sandbox"
                  :token-cost 16))]
    (list t-dom t-click t-type t-eval)))

(df calculate-schema-tokens [(tools (List SlmBrowserTool))] -> I64
  :d "Sums the token costs across all registered browser SLM tools"
  (fold (fn [(acc I64) (t SlmBrowserTool)] -> I64
          (+ acc (.-token-cost t)))
        0
        tools))

(df make-browser-slm-schema [] -> SlmAffirmativeSchema
  :d "Instantiates the canonical 4-tool affirmative schema"
  (let [(tools (make-browser-slm-tools))
        (tokens (calculate-schema-tokens tools))]
    (SlmAffirmativeSchema
      :tools tools
      :total-tokens tokens
      :max-tools 4
      :affirmative-rule "Emit exactly one affirmative S-expression action. Never hallucinate non-existent tools.")))

(df init-fsm-delimiter-mask [(max-depth I64)] -> FsmDelimiterMask
  :d "Initializes an FSM delimiter mask for streaming validation"
  (FsmDelimiterMask
    :depth 0
    :in-string false
    :is-escaped false
    :is-valid true
    :char-count 0
    :max-depth max-depth
    :error-reason ""))

(df fsm-feed-char [(mask FsmDelimiterMask) (ch Str)] -> FsmDelimiterMask
  :d "Consumes a single character and updates the FSM delimiter state"
  (if (not (.-is-valid mask))
    mask
    (let [(depth (.-depth mask))
          (in-str (.-in-string mask))
          (escaped (.-is-escaped mask))
          (count (+ (.-char-count mask) 1))
          (max-d (.-max-depth mask))]
      (if in-str
        (if escaped
          (FsmDelimiterMask
            :depth depth
            :in-string true
            :is-escaped false
            :is-valid true
            :char-count count
            :max-depth max-d
            :error-reason "")
          (if (= ch "\\")
            (FsmDelimiterMask
              :depth depth
              :in-string true
              :is-escaped true
              :is-valid true
              :char-count count
              :max-depth max-d
              :error-reason "")
            (if (= ch "\"")
              (FsmDelimiterMask
                :depth depth
                :in-string false
                :is-escaped false
                :is-valid true
                :char-count count
                :max-depth max-d
                :error-reason "")
              (FsmDelimiterMask
                :depth depth
                :in-string true
                :is-escaped false
                :is-valid true
                :char-count count
                :max-depth max-d
                :error-reason ""))))
        (if (= ch "\"")
          (FsmDelimiterMask
            :depth depth
            :in-string true
            :is-escaped false
            :is-valid true
            :char-count count
            :max-depth max-d
            :error-reason "")
          (cond
            ((or (= ch "(") (= ch "["))
             (let [(next-depth (+ depth 1))]
               (if (> next-depth max-d)
                 (FsmDelimiterMask
                   :depth next-depth
                   :in-string false
                   :is-escaped false
                   :is-valid false
                   :char-count count
                   :max-depth max-d
                   :error-reason "Max nesting depth exceeded")
                 (FsmDelimiterMask
                   :depth next-depth
                   :in-string false
                   :is-escaped false
                   :is-valid true
                   :char-count count
                   :max-depth max-d
                   :error-reason ""))))
            ((or (= ch ")") (= ch "]"))
             (if (<= depth 0)
               (FsmDelimiterMask
                 :depth -1
                 :in-string false
                 :is-escaped false
                 :is-valid false
                 :char-count count
                 :max-depth max-d
                 :error-reason "Unmatched closing delimiter")
               (FsmDelimiterMask
                 :depth (- depth 1)
                 :in-string false
                 :is-escaped false
                 :is-valid true
                 :char-count count
                 :max-depth max-d
                 :error-reason "")))
            (:else
             (FsmDelimiterMask
               :depth depth
               :in-string false
               :is-escaped false
               :is-valid true
               :char-count count
               :max-depth max-d
               :error-reason ""))))))))

(df validate-slm-token-stream [(mask FsmDelimiterMask) (stream Str)] -> FsmDelimiterMask
  :d "Streams an input string through the FSM delimiter mask and audits final balance"
  (let [(chars (string-chars stream))
        (stepped (fold (fn [(acc FsmDelimiterMask) (c Str)] -> FsmDelimiterMask
                         (fsm-feed-char acc c))
                       mask
                       chars))]
    (if (not (.-is-valid stepped))
      stepped
      (if (.-in-string stepped)
        (FsmDelimiterMask
          :depth (.-depth stepped)
          :in-string true
          :is-escaped (.-is-escaped stepped)
          :is-valid false
          :char-count (.-char-count stepped)
          :max-depth (.-max-depth stepped)
          :error-reason "Unclosed string literal at end of stream")
        (if (> (.-depth stepped) 0)
          (FsmDelimiterMask
            :depth (.-depth stepped)
            :in-string false
            :is-escaped (.-is-escaped stepped)
            :is-valid false
            :char-count (.-char-count stepped)
            :max-depth (.-max-depth stepped)
            :error-reason "Unclosed delimiter at end of stream")
          stepped)))))

(df format-slm-browser-priming [(model Str) (schema SlmAffirmativeSchema)] -> Str
  :d "Formats the compact 118-token affirmative priming prompt"
  (str "(:slm-profile :model \"" model "\" :priming 118 :contract \"Addie Browser SLM Agent. Allowed actions: get_dom click type eval. Emit exactly one valid S-expression. Zero prose.\")"))

(df make-browser-slm-profile [(model-name Str) (context-budget I64)] -> SlmBrowserProfile
  :d "Builds a complete browser SLM profile configured for on-device inference"
  (let [(schema (make-browser-slm-schema))
        (priming (format-slm-browser-priming model-name schema))
        (mask (init-fsm-delimiter-mask 16))]
    (SlmBrowserProfile
      :model-name model-name
      :context-budget context-budget
      :priming-token-count 118
      :priming-prompt priming
      :schema schema
      :fsm-mask mask)))

(df validate-browser-model-ceiling [(model-name Str)] -> Bool
  :d "Enforces strict 3-billion parameter ceiling for browser deployment"
  (if (or (string-contains? model-name "7B")
      (or (string-contains? model-name "7b")
      (or (string-contains? model-name "8B")
      (or (string-contains? model-name "8b")
      (or (string-contains? model-name "9B")
      (or (string-contains? model-name "9b")
      (or (string-contains? model-name "14B")
      (or (string-contains? model-name "14b")
      (or (string-contains? model-name "31B")
      (or (string-contains? model-name "31b")
      (or (string-contains? model-name "70B")
          (string-contains? model-name "70b"))))))))))))
    false
    true))

(df make-nano-slm-tools [] -> (List SlmBrowserTool)
  :d "Returns the minimal 2-tool schema for 100MB nano SLMs"
  (let [(t-tag (SlmBrowserTool
                 :name "tag"
                 :signature "(:act :tag :text Str :label Str)"
                 :summary "Classify token or phrase"
                 :token-cost 14))
        (t-match (SlmBrowserTool
                   :name "match"
                   :signature "(:act :match :pattern Str :target Str)"
                   :summary "Extract regex or token match"
                   :token-cost 16))]
    (list t-tag t-match)))

(df make-nano-slm-schema [] -> SlmAffirmativeSchema
  :d "Instantiates the 2-tool affirmative schema for 100MB nano models"
  (let [(tools (make-nano-slm-tools))
        (tokens (calculate-schema-tokens tools))]
    (SlmAffirmativeSchema
      :tools tools
      :total-tokens tokens
      :max-tools 2
      :affirmative-rule "Emit single token classification or match action. Never emit nested forms.")))

(df make-nano-browser-slm-profile [(model-name Str) (context-budget I64)] -> SlmBrowserProfile
  :d "Builds a 100MB nano SLM profile for lightweight in-browser WASM inference"
  (let [(schema (make-nano-slm-schema))
        (priming (str "(:nano-profile :model \"" model-name "\" :weight \"100MB\" :priming 30 :contract \"Nano Agent. Allowed: tag match.\")"))
        (mask (init-fsm-delimiter-mask 4))]
    (SlmBrowserProfile
      :model-name model-name
      :context-budget context-budget
      :priming-token-count 30
      :priming-prompt priming
      :schema schema
      :fsm-mask mask)))
