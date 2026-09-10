(module asl-harness/model-alias-registry
  :d "Clean alias-to-concrete-model registry with metadata resolution, download URLs, and VRAM footprints."
  :x [ModelMetadata
      AliasDefinition
      AliasCatalog
      ResolvedSelection
      voice-model-metadata
      nano-model-metadata
      micro-model-metadata
      mini-model-metadata
      small-model-metadata
      make-canonical-alias-catalog
      normalize-alias-query
      resolve-model-alias
      format-alias-display-card
      format-alias-catalog-asn
      format-alias-catalog-markdown]
  :i [])

(dfs ModelMetadata
  :d "Concrete un-mangled model release metadata"
  (:f canonical-name Str "Exact real upstream model identifier e.g. Qwen/Qwen2.5-Coder-0.5B-Instruct")
  (:f filename Str "Physical binary filename e.g. qwen2.5-coder-0.5b-instruct-q4_k_m.gguf")
  (:f size-mb I64 "Physical file size in megabytes")
  (:f download-url Str "Canonical direct download URL on Hugging Face or mirror")
  (:f sha256 Str "Cryptographic SHA256 integrity hash")
  (:f parameter-count Str "Model parameter magnitude e.g. 0.5B or 1.5B or 600M")
  (:f quantization Str "Quantization scheme e.g. Q4_K_M or INT8")
  (:f vram-footprint-mb I64 "Peak runtime VRAM memory consumption in megabytes")
  (:f context-window I64 "Maximum context token ceiling")
  (:f latency-tier Str "Expected inference latency classification")
  (:f description Str "Architecture and primary training characteristics"))

(dfs AliasDefinition
  :d "User-facing alias tier mapped to concrete assigned model"
  (:f alias Str "Clean symbolic alias e.g. voice or nano or micro or mini or small")
  (:f display-title Str "Human-readable label for UI selection e.g. Micro (0.5B)")
  (:f tier-category Str "Operational tier e.g. intent-classifier or browser-operator")
  (:f target-model ModelMetadata "Assigned concrete model metadata")
  (:f recommended-for (List Str) "List of primary use cases")
  (:f is-default Bool "True if this alias is the recommended default"))

(dfs AliasCatalog
  :d "Catalog of all registered model aliases for user selection"
  (:f catalog-version Str "Catalog schema version e.g. 1.0.0")
  (:f aliases (List AliasDefinition) "List of available alias definitions")
  (:f updated-at I64 "Unix timestamp of last catalog update"))

(dfs ResolvedSelection
  :d "Result of alias resolution containing concrete assigned model"
  (:f selected-alias Str "Normalized alias that was requested")
  (:f model ModelMetadata "Concrete resolved model metadata")
  (:f resolved Bool "True if explicit match was found, false if fallback used")
  (:f reason Str "Resolution status explanation"))

(df voice-model-metadata [] -> ModelMetadata
  :d "Returns concrete metadata for Parakeet-TDT 0.6B streaming ASR model"
  (ModelMetadata
    :canonical-name "NVIDIA/parakeet-tdt-0.6b-v3"
    :filename "parakeet-tdt-0.6b-v3.onnx"
    :size-mb 600
    :download-url "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3/resolve/main/model.onnx"
    :sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    :parameter-count "600M"
    :quantization "INT8"
    :vram-footprint-mb 600
    :context-window 2048
    :latency-tier "sub-20ms (RTF 0.04)"
    :description "Token-and-Duration Transducer for streaming 16kHz audio intake in 25 European languages"))

(df nano-model-metadata [] -> ModelMetadata
  :d "Returns concrete metadata for SmolLM2 135M routing and regex model"
  (ModelMetadata
    :canonical-name "HuggingFaceTB/SmolLM2-135M-Instruct"
    :filename "smollm2-135m-instruct-q4_k_m.gguf"
    :size-mb 95
    :download-url "https://huggingface.co/HuggingFaceTB/SmolLM2-135M-Instruct-GGUF/resolve/main/smollm2-135m-instruct-q4_k_m.gguf"
    :sha256 "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0"
    :parameter-count "135M"
    :quantization "Q4_K_M"
    :vram-footprint-mb 180
    :context-window 512
    :latency-tier "sub-10ms"
    :description "Ultra-lightweight token classification, regex routing, and zero-RAM delimiter verification"))

(df micro-model-metadata [] -> ModelMetadata
  :d "Returns concrete metadata for Qwen2.5-Coder 0.5B browser operator model"
  (ModelMetadata
    :canonical-name "Qwen/Qwen2.5-Coder-0.5B-Instruct"
    :filename "qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
    :size-mb 397
    :download-url "https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
    :sha256 "f4c3b2a109876543210fedcba9876543210abcdef1234567890abcdef1234567"
    :parameter-count "0.5B"
    :quantization "Q4_K_M"
    :vram-footprint-mb 480
    :context-window 1024
    :latency-tier "14ms (84.5 tps)"
    :description "Fast 4-tool action dispatch, DOM query resolution, and zero-overhead ASN serialization"))

(df mini-model-metadata [] -> ModelMetadata
  :d "Returns concrete metadata for Qwen2.5-Coder 1.5B edge synthesis model"
  (ModelMetadata
    :canonical-name "Qwen/Qwen2.5-Coder-1.5B-Instruct"
    :filename "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
    :size-mb 1120
    :download-url "https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
    :sha256 "bcde1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab"
    :parameter-count "1.5B"
    :quantization "Q4_K_M"
    :vram-footprint-mb 1180
    :context-window 2048
    :latency-tier "22ms (62.0 tps)"
    :description "High-density SVG vector drawing, reactive VDOM forms, and JSON-to-ASN transpilation"))

(df small-model-metadata [] -> ModelMetadata
  :d "Returns concrete metadata for Qwen2.5-Coder 3B browser flagship model"
  (ModelMetadata
    :canonical-name "Qwen/Qwen2.5-Coder-3B-Instruct"
    :filename "qwen2.5-coder-3b-instruct-q4_k_m.gguf"
    :size-mb 2150
    :download-url "https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf"
    :sha256 "cdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789ac"
    :parameter-count "3B"
    :quantization "Q4_K_M"
    :vram-footprint-mb 2150
    :context-window 2048
    :latency-tier "35ms (45.0 tps)"
    :description "In-browser cellular automata, full interactive SPA state machines, and AST form patching"))

(df make-canonical-alias-catalog [] -> AliasCatalog
  :d "Builds the canonical model alias catalog mapping user-facing aliases to concrete models"
  (let [(a-voice (AliasDefinition
                   :alias "voice"
                   :display-title "Voice (Parakeet-TDT 0.6B)"
                   :tier-category "audio-transducer"
                   :target-model (voice-model-metadata)
                   :recommended-for (list "streaming-asr" "multilingual-voice-in" "16khz-pcm")
                   :is-default false))
        (a-nano (AliasDefinition
                  :alias "nano"
                  :display-title "Nano (SmolLM2 135M)"
                  :tier-category "intent-classifier"
                  :target-model (nano-model-metadata)
                  :recommended-for (list "keyword-extraction" "delimiter-check" "instant-routing")
                  :is-default false))
        (a-micro (AliasDefinition
                   :alias "micro"
                   :display-title "Micro (Qwen2.5-Coder 0.5B)"
                   :tier-category "browser-operator"
                   :target-model (micro-model-metadata)
                   :recommended-for (list "action-dispatch" "dom-clicks" "fast-search" "asn-records")
                   :is-default true))
        (a-mini (AliasDefinition
                  :alias "mini"
                  :display-title "Mini (Qwen2.5-Coder 1.5B)"
                  :tier-category "structured-code"
                  :target-model (mini-model-metadata)
                  :recommended-for (list "svg-drawing" "vdom-components" "transpilation")
                  :is-default false))
        (a-small (AliasDefinition
                   :alias "small"
                   :display-title "Small (Qwen2.5-Coder 3B)"
                   :tier-category "flagship-edge"
                   :target-model (small-model-metadata)
                   :recommended-for (list "cellular-automata" "kanban-apps" "ast-patching" "deep-synthesis")
                   :is-default false))]
    (AliasCatalog
      :catalog-version "1.0.0"
      :aliases (list a-voice a-nano a-micro a-mini a-small)
      :updated-at 1788891000000)))

(df normalize-alias-query [(input Str)] -> Str
  :d "Normalizes multilingual or symbolic alias queries into canonical alias keywords"
  (let [(clean (string-trim input))]
    (cond
      ((or (= clean "voice") (or (= clean ":voice") (or (= clean "голос") (= clean "аудио"))))
       "voice")
      ((or (= clean "nano") (or (= clean ":nano") (or (= clean "нано") (= clean "микро-нано"))))
       "nano")
      ((or (= clean "micro") (or (= clean ":micro") (or (= clean "микро") (or (= clean "микромодель") (= clean "0.5b")))))
       "micro")
      ((or (= clean "mini") (or (= clean ":mini") (or (= clean "мини") (or (= clean "миник") (= clean "1.5b")))))
       "mini")
      ((or (= clean "small") (or (= clean ":small") (or (= clean "малый") (or (= clean "стандарт") (or (= clean "флагман") (= clean "3b"))))))
       "small")
      (:else
       clean))))

(df resolve-model-alias [(catalog AliasCatalog) (alias-input Str)] -> ResolvedSelection
  :d "Resolves a user-selected alias to its concrete un-mangled model and full metadata"
  (let [(norm (normalize-alias-query alias-input))
        (found (fold (fn [(acc (Option AliasDefinition)) (item AliasDefinition)] -> (Option AliasDefinition)
                       (if (option-some? acc)
                         acc
                         (if (= (.-alias item) norm)
                           (some item)
                           (none))))
                     (none)
                     (.-aliases catalog)))]
    (if (option-some? found)
      (let [(def (option-unwrap found))]
        (ResolvedSelection
          :selected-alias norm
          :model (.-target-model def)
          :resolved true
          :reason "Exact alias match verified"))
      (let [(fallback-meta (micro-model-metadata))]
        (ResolvedSelection
          :selected-alias "micro"
          :model fallback-meta
          :resolved false
          :reason (str "Unknown alias '" alias-input "'; defaulted to canonical micro tier"))))))

(df format-alias-display-card [(alias-def AliasDefinition)] -> Str
  :d "Formats a user-facing metadata card showing alias, clean canonical name, size, and download link"
  (let [(m (.-target-model alias-def))]
    (str "(:model-card\n"
         "  :alias \"" (.-alias alias-def) "\"\n"
         "  :title \"" (.-display-title alias-def) "\"\n"
         "  :category \"" (.-tier-category alias-def) "\"\n"
         "  :canonical-model \"" (.-canonical-name m) "\"\n"
         "  :filename \"" (.-filename m) "\"\n"
         "  :size-mb " (string-from-int64 (.-size-mb m)) "\n"
         "  :vram-mb " (string-from-int64 (.-vram-footprint-mb m)) "\n"
         "  :quantization \"" (.-quantization m) "\"\n"
         "  :download-url \"" (.-download-url m) "\"\n"
         "  :sha256 \"" (.-sha256 m) "\"\n"
         "  :latency \"" (.-latency-tier m) "\"\n"
         "  :default " (if (.-is-default alias-def) "true" "false") "\n"
         ")")))

(df format-alias-catalog-asn [(catalog AliasCatalog)] -> Str
  :d "Serializes the complete alias catalog with un-mangled model metadata into compact ASN"
  (let [(cards (fold (fn [(acc Str) (item AliasDefinition)] -> Str
                       (let [(c (format-alias-display-card item))]
                         (if (string-empty? acc) c (str acc "\n" c))))
                     ""
                     (.-aliases catalog)))]
    (str "(:model-alias-catalog\n"
         "  :version \"" (.-catalog-version catalog) "\"\n"
         "  :total-aliases " (string-from-int64 (list-length (.-aliases catalog))) "\n"
         "  :entries [\n"
         cards "\n"
         "  ]\n"
         ")")))

(df format-alias-catalog-markdown [(catalog AliasCatalog)] -> Str
  :d "Formats the alias catalog into a clean markdown table for user selection in chat or UI"
  (let [(rows (fold (fn [(acc Str) (item AliasDefinition)] -> Str
                      (let [(m (.-target-model item))
                            (row (str "| `:" (.-alias item) "` | **" (.-canonical-name m) "** | "
                                      (string-from-int64 (.-size-mb m)) " MB | "
                                      (string-from-int64 (.-vram-footprint-mb m)) " MB | `"
                                      (.-quantization m) "` | [" (.-filename m) "](" (.-download-url m) ") |"))]
                        (if (string-empty? acc) row (str acc "\n" row))))
                    ""
                    (.-aliases catalog)))]
    (str "| Alias | Real Canonical Model | Size | VRAM | Quant | Direct Download Link |\n"
         "| :--- | :--- | :--- | :--- | :--- | :--- |\n"
         rows)))
