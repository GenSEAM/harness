(module asl-harness/model-alias-registry-test
  :d "Unit test suite verifying alias-to-model mapping, metadata preservation, and multilingual query resolution."
  :x [test-canonical-metadata-preservation
      test-alias-catalog-tiers
      test-alias-query-normalization
      test-alias-resolution-exact
      test-alias-resolution-fallback
      test-format-cards-and-markdown
      run-tests]
  :i [(model_alias_registry :a mar)])

(df test-canonical-metadata-preservation [] -> Bool
  :d "Verifies real upstream model names and physical metadata are preserved un-mangled"
  (let [(v (mar/voice-model-metadata))
        (n (mar/nano-model-metadata))
        (m (mar/micro-model-metadata))
        (mini (mar/mini-model-metadata))
        (s (mar/small-model-metadata))]
    (assert (= (.-canonical-name v) "NVIDIA/parakeet-tdt-0.6b-v3") "Voice model name must be un-mangled")
    (assert (= (.-size-mb v) 600) "Voice model size must be 600MB")
    (assert (= (.-canonical-name n) "HuggingFaceTB/SmolLM2-135M-Instruct") "Nano model name must be un-mangled")
    (assert (= (.-size-mb n) 95) "Nano model size must be 95MB")
    (assert (= (.-canonical-name m) "Qwen/Qwen2.5-Coder-0.5B-Instruct") "Micro model name must be un-mangled")
    (assert (= (.-size-mb m) 397) "Micro model size must be 397MB")
    (assert (= (.-vram-footprint-mb m) 480) "Micro VRAM must be 480MB")
    (assert (= (.-canonical-name mini) "Qwen/Qwen2.5-Coder-1.5B-Instruct") "Mini model name must be un-mangled")
    (assert (= (.-size-mb mini) 1120) "Mini model size must be 1120MB")
    (assert (= (.-canonical-name s) "Qwen/Qwen2.5-Coder-3B-Instruct") "Small model name must be un-mangled")
    (assert (= (.-size-mb s) 2150) "Small model size must be 2150MB")
    (assert (string-contains? (.-download-url m) "huggingface.co") "Download URL must be a valid Hugging Face link")
    true))

(df test-alias-catalog-tiers [] -> Bool
  :d "Verifies the 5 canonical alias tiers in the catalog"
  (let [(cat (mar/make-canonical-alias-catalog))
        (aliases (.-aliases cat))]
    (assert (= (list-length aliases) 5) "Catalog must define exactly 5 alias tiers")
    (assert (= (.-catalog-version cat) "1.0.0") "Catalog version must be 1.0.0")
    (let [(micro-def (option-or (list-head (option-or (list-tail (option-or (list-tail aliases) (list))) (list)))
                                (mar/AliasDefinition :alias "" :display-title "" :tier-category "" :target-model (mar/micro-model-metadata) :recommended-for (list) :is-default false)))]
      (assert (= (.-alias micro-def) "micro") "Third alias must be micro")
      (assert (.-is-default micro-def) "Micro tier must be marked as default")
      true)))

(df test-alias-query-normalization [] -> Bool
  :d "Verifies multilingual and symbolic aliases normalize cleanly"
  (assert (= (mar/normalize-alias-query ":micro") "micro") ":micro normalizes to micro")
  (assert (= (mar/normalize-alias-query "микро") "micro") "микро normalizes to micro")
  (assert (= (mar/normalize-alias-query "0.5b") "micro") "0.5b normalizes to micro")
  (assert (= (mar/normalize-alias-query ":mini") "mini") ":mini normalizes to mini")
  (assert (= (mar/normalize-alias-query "мини") "mini") "мини normalizes to mini")
  (assert (= (mar/normalize-alias-query ":voice") "voice") ":voice normalizes to voice")
  (assert (= (mar/normalize-alias-query "голос") "voice") "голос normalizes to voice")
  (assert (= (mar/normalize-alias-query ":nano") "nano") ":nano normalizes to nano")
  (assert (= (mar/normalize-alias-query "нано") "nano") "нано normalizes to nano")
  (assert (= (mar/normalize-alias-query ":small") "small") ":small normalizes to small")
  (assert (= (mar/normalize-alias-query "флагман") "small") "флагман normalizes to small")
  true)

(df test-alias-resolution-exact [] -> Bool
  :d "Verifies user selecting an alias resolves to the exact assigned model with full metadata"
  (let [(cat (mar/make-canonical-alias-catalog))
        (res-micro (mar/resolve-model-alias cat "микро"))
        (res-mini (mar/resolve-model-alias cat ":mini"))
        (res-voice (mar/resolve-model-alias cat "voice"))]
    (assert (.-resolved res-micro) "Micro must resolve successfully")
    (assert (= (.-selected-alias res-micro) "micro") "Selected alias is micro")
    (assert (= (.-canonical-name (.-model res-micro)) "Qwen/Qwen2.5-Coder-0.5B-Instruct") "Resolves to Qwen 0.5B")
    (assert (= (.-size-mb (.-model res-micro)) 397) "Micro size is 397MB")
    (assert (.-resolved res-mini) "Mini must resolve successfully")
    (assert (= (.-canonical-name (.-model res-mini)) "Qwen/Qwen2.5-Coder-1.5B-Instruct") "Resolves to Qwen 1.5B")
    (assert (= (.-size-mb (.-model res-mini)) 1120) "Mini size is 1120MB")
    (assert (.-resolved res-voice) "Voice must resolve successfully")
    (assert (= (.-canonical-name (.-model res-voice)) "NVIDIA/parakeet-tdt-0.6b-v3") "Resolves to Parakeet TDT")
    true))

(df test-alias-resolution-fallback [] -> Bool
  :d "Verifies unknown alias query falls back gracefully to default micro model"
  (let [(cat (mar/make-canonical-alias-catalog))
        (res-unknown (mar/resolve-model-alias cat "unknown-model-xyz"))]
    (assert (not (.-resolved res-unknown)) "Unknown alias must be flagged as fallback")
    (assert (= (.-selected-alias res-unknown) "micro") "Fallback alias is micro")
    (assert (= (.-canonical-name (.-model res-unknown)) "Qwen/Qwen2.5-Coder-0.5B-Instruct") "Fallback model is Qwen 0.5B")
    (assert (string-contains? (.-reason res-unknown) "defaulted to canonical micro tier") "Reason must indicate fallback")
    true))

(df test-format-cards-and-markdown [] -> Bool
  :d "Verifies ASN cards and markdown table generation for UI display"
  (let [(cat (mar/make-canonical-alias-catalog))
        (asn-catalog (mar/format-alias-catalog-asn cat))
        (md-table (mar/format-alias-catalog-markdown cat))]
    (assert (string-contains? asn-catalog ":model-alias-catalog") "ASN catalog has root header")
    (assert (string-contains? asn-catalog ":canonical-model \"Qwen/Qwen2.5-Coder-0.5B-Instruct\"") "ASN has canonical model")
    (assert (string-contains? asn-catalog ":download-url") "ASN includes download URLs")
    (assert (string-contains? md-table "| Alias | Real Canonical Model | Size | VRAM | Quant | Direct Download Link |") "Markdown includes header")
    (assert (string-contains? md-table "`:micro`") "Markdown includes :micro alias")
    (assert (string-contains? md-table "**Qwen/Qwen2.5-Coder-0.5B-Instruct**") "Markdown includes un-mangled model")
    (assert (string-contains? md-table "397 MB") "Markdown includes size in MB")
    true))

(df run-tests [] -> Bool
  :d "Executes all alias registry test assertions"
  (and (test-canonical-metadata-preservation)
       (and (test-alias-catalog-tiers)
            (and (test-alias-query-normalization)
                 (and (test-alias-resolution-exact)
                      (and (test-alias-resolution-fallback)
                           (test-format-cards-and-markdown)))))))
