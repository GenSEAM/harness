(module asl-harness/config
  :d "Configurable constructor, model profiles, and pluggable extension registry for ASL Harness."
  :x [ModelProfile PluginHook HarnessPlugin HarnessConfig
      profile-gemma-31b profile-default default-harness-config
      toggle-feature feature-enabled? register-plugin
      enable-experimental experimental-enabled? make-plugin]
  :i [])

(dfs ModelProfile
  (:f name Str "Model profile identifier e.g. gemma-4-31b-it")
  (:f family Str "Model architecture family e.g. gemma, claude, deepseek")
  (:f strict-firewall Bool "Enable strict action boundary and lease firewall")
  (:f strict-normalizer Bool "Enable single-pass FSM syntax and delimiter normalizer")
  (:f in-memory-repl Bool "Enable sub-millisecond in-memory REPL inspector")
  (:f max-tokens I64 "Default context token ceiling"))

(dfe PluginHook
  (:c hook-pre-call [] "Hook executed before tool call dispatch")
  (:c hook-post-call [] "Hook executed after tool call completion")
  (:c hook-model-response [] "Hook executed on raw model output stream")
  (:c hook-error [] "Hook executed on execution boundary failure"))

(dfs HarnessPlugin
  (:f id Str "Unique plugin identifier e.g. plugin-sec-audit")
  (:f name Str "Human-readable plugin name")
  (:f version Str "Semantic version string")
  (:f enabled Bool "Activation flag")
  (:f description Str "Functional plugin description"))

(dfs HarnessConfig
  (:f profile ModelProfile "Active model optimization profile")
  (:f flags (Map Str Bool) "Granular feature flag toggles")
  (:f plugins (List HarnessPlugin) "Registered extension plugins")
  (:f experimental (List Str) "Active experimental feature identifiers")
  (:f custom-settings (Map Str Str) "Arbitrary string configuration key-values"))

(df profile-gemma-31b [] -> ModelProfile
  :d "Optimal out-of-the-box profile calibrated for Gemma 31B (gemma-4-31b-it)."
  (ModelProfile
    :name "gemma-4-31b-it"
    :family "gemma"
    :strict-firewall true
    :strict-normalizer true
    :in-memory-repl true
    :max-tokens 8192))

(df profile-default [] -> ModelProfile
  :d "Standard baseline model profile."
  (ModelProfile
    :name "generic-llm"
    :family "generic"
    :strict-firewall true
    :strict-normalizer false
    :in-memory-repl false
    :max-tokens 4096))

(df make-plugin [(id Str) (name Str) (version Str) (enabled Bool) (description Str)] -> HarnessPlugin
  :d "Constructs a new HarnessPlugin definition record."
  (HarnessPlugin
    :id id
    :name name
    :version version
    :enabled enabled
    :description description))

(df default-harness-config [] -> HarnessConfig
  :d "Constructs default harness configuration with optimal out-of-the-box settings for Gemma 31B."
  (let [(prof (profile-gemma-31b))
        (init-flags (map-set (map-set (map-set (map-empty)
                                               "firewall" true)
                                      "fsm-normalizer" true)
                             "repl-in-memory" true))]
    (HarnessConfig
      :profile prof
      :flags init-flags
      :plugins (list)
      :experimental (list)
      :custom-settings (map-empty))))

(df toggle-feature [(cfg HarnessConfig) (feature-name Str) (enable Bool)] -> HarnessConfig
  :d "Toggles a specific feature flag on or off in the harness configuration."
  (let [(updated-flags (map-set (.-flags cfg) feature-name enable))]
    (HarnessConfig
      :profile (.-profile cfg)
      :flags updated-flags
      :plugins (.-plugins cfg)
      :experimental (.-experimental cfg)
      :custom-settings (.-custom-settings cfg))))

(df feature-enabled? [(cfg HarnessConfig) (feature-name Str)] -> Bool
  :d "Checks if a specific feature flag is actively enabled."
  (let [(val (map-get (.-flags cfg) feature-name))]
    (option-or val false)))

(df register-plugin [(cfg HarnessConfig) (plugin HarnessPlugin)] -> HarnessConfig
  :d "Registers a user-defined or third-party plugin into the harness pipeline."
  (let [(updated-plugins (list-cons plugin (.-plugins cfg)))]
    (HarnessConfig
      :profile (.-profile cfg)
      :flags (.-flags cfg)
      :plugins updated-plugins
      :experimental (.-experimental cfg)
      :custom-settings (.-custom-settings cfg))))

(df enable-experimental [(cfg HarnessConfig) (flag Str)] -> HarnessConfig
  :d "Enables an experimental opt-in feature flag."
  (let [(existing (.-experimental cfg))
        (updated (list-cons flag existing))]
    (HarnessConfig
      :profile (.-profile cfg)
      :flags (.-flags cfg)
      :plugins (.-plugins cfg)
      :experimental updated
      :custom-settings (.-custom-settings cfg))))

(df experimental-enabled? [(cfg HarnessConfig) (flag Str)] -> Bool
  :d "Checks whether an experimental feature flag is active."
  (let [(active (filter (fn [(f Str)] -> Bool (= f flag)) (.-experimental cfg)))]
    (not (list-empty? active))))
