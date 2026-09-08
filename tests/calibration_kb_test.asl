(module asl-harness/tests/calibration-kb-test
  :d "Unit and falsifiable verification suite for Calibration Knowledge Base query and auto-recommender."
  :x [test-standard-profiles-count-and-fields
      test-find-profile-by-id-exact-and-partial
      test-recommend-harness-setup-known-model
      test-recommend-harness-setup-unknown-fallback
      test-format-model-profile-asn
      test-calibration-registry-and-runs
      test-format-calibration-registry-asn
      run-tests]
  :i [(calibration_kb :a ckb)
      (context_assembler :a ca)])

(df test-standard-profiles-count-and-fields [] -> Bool
  :d "Verifies standard profiles registry has 5 canonical models."
  (let [(profiles (ckb/standard-model-profiles))
        (p-gemma (option-or (ckb/find-profile-by-id profiles "gemma-4-31b-it")
                            (ckb/make-model-profile "" "" "" 0.0 0 0 0 (list) "")))]
    (do
      (assert (= (list-length profiles) 5) "Must have 5 standard model profiles in Knowledge Base")
      (assert (= (.-model-id p-gemma) "gemma-4-31b-it") "Must locate gemma profile")
      (assert (= (.-tier p-gemma) "midweight") "Gemma tier must be midweight")
      (assert (= (.-optimal-strategy p-gemma) "agent-directed") "Gemma optimal strategy must be agent-directed")
      (assert (= (.-optimal-temperature p-gemma) 0.15) "Gemma optimal temperature must be 0.15")
      (assert (= (.-token-ceiling p-gemma) 4096) "Gemma token ceiling must be 4096")
      (assert (= (.-clamp-knowledge p-gemma) 350) "Gemma knowledge clamp must be 350")
      true)))

(df test-find-profile-by-id-exact-and-partial [] -> Bool
  :d "Verifies exact and substring profile lookup."
  (let [(profiles (ckb/standard-model-profiles))
        (exact-opt (ckb/find-profile-by-id profiles "qwen-2.5-0.5b"))
        (partial-opt (ckb/find-profile-by-id profiles "qwen-2.5-3b-instruct"))
        (unknown-opt (ckb/find-profile-by-id profiles "non-existent-model-xyz"))]
    (do
      (assert (option-some? exact-opt) "Exact match must be found")
      (assert (option-some? partial-opt) "Partial match must be found")
      (assert (option-none? unknown-opt) "Unknown model must return none")
      true)))

(df test-recommend-harness-setup-known-model [] -> Bool
  :d "Verifies recommendation for known model retrieves tuned profile."
  (let [(rec (ckb/recommend-harness-setup "qwen-2.5-0.5b"))
        (cfg (.-context-config rec))]
    (do
      (assert (.-known-profile rec) "Known profile flag must be true")
      (assert (= (.-strategy cfg) "jit-memory") "Qwen 0.5B strategy must be jit-memory")
      (assert (= (.-token-ceiling cfg) 1024) "Qwen 0.5B ceiling must be 1024")
      (assert (= (.-temperature rec) 0.1) "Qwen 0.5B temperature must be 0.1")
      (assert (= (.-clamp-knowledge rec) 200) "Qwen 0.5B clamp must be 200")
      (assert (string-contains? (.-rationale rec) "Matched verified profile") "Rationale must reference matched profile")
      true)))

(df test-recommend-harness-setup-unknown-fallback [] -> Bool
  :d "Verifies recommendation for unknown model safely applies Universal Golden Default."
  (let [(rec (ckb/recommend-harness-setup "llama-3-8b-custom"))
        (cfg (.-context-config rec))]
    (do
      (assert (not (.-known-profile rec)) "Known profile flag must be false for unknown model")
      (assert (= (.-strategy cfg) "receipts") "Universal Golden Default strategy must be receipts")
      (assert (= (.-token-ceiling cfg) 4096) "Universal Golden Default ceiling must be 4096")
      (assert (= (.-keep-recent cfg) 1) "Universal Golden Default keep-recent must be 1")
      (assert (= (.-temperature rec) 0.2) "Universal Golden Default temperature must be 0.2")
      (assert (= (.-clamp-knowledge rec) 350) "Universal Golden Default clamp-knowledge must be 350")
      (assert (string-contains? (.-rationale rec) "Universal Golden Default") "Rationale must reference Universal Golden Default")
      true)))

(df test-format-model-profile-asn [] -> Bool
  :d "Verifies structured ASN serialization of ModelProfile."
  (let [(prof (ckb/make-model-profile
                "gpt-5.6-luna"
                "frontier"
                "receipts"
                0.2
                8192
                2
                600
                (list "High cost on verbose dumps")
                "Use rolling receipts"))
        (asn-str (ckb/format-model-profile-asn prof))]
    (do
      (assert (string-starts-with? asn-str "(:model-profile") "ASN must start with :model-profile")
      (assert (string-contains? asn-str ":model-id \"gpt-5.6-luna\"") "ASN must contain model-id")
      (assert (string-contains? asn-str ":tier \"frontier\"") "ASN must contain tier")
      (assert (string-contains? asn-str ":optimal-strategy \"receipts\"") "ASN must contain optimal-strategy")
      (assert (string-ends-with? asn-str ")") "ASN must end with closing paren")
      true)))

(df test-calibration-registry-and-runs [] -> Bool
  :d "Verifies model calibration registry construction, invariants, and best-run query."
  (let [(reg (ckb/make-calibration-registry))
        (runs (.-runs reg))
        (invs (.-invariants reg))
        (best-front (ckb/find-best-run-by-tier runs "frontier"))
        (best-med (ckb/find-best-run-by-tier runs "medium"))
        (best-micro (ckb/find-best-run-by-tier runs "micro-slm"))
        (best-hard (ckb/find-best-run-by-tier runs "impossible"))
        (unknown (ckb/find-best-run-by-tier runs "non-existent-tier"))]
    (do
      (assert (= (.-version reg) "1.0.0") "Registry version must be 1.0.0")
      (assert (= (list-length runs) 6) "Must have 6 canonical model runs")
      (assert (= (list-length invs) 8) "Must have 8 canonical system invariants")
      (assert (option-some? best-front) "Frontier best run must be found")
      (let [(bf (option-unwrap best-front))]
        (assert (= (.-model-id bf) "gemma-4-31b-it") "Best frontier run must be Gemma 31B")
        (assert (= (.-pareto-score bf) 94.8) "Best frontier Pareto score must be 94.8"))
      (assert (option-some? best-med) "Medium best run must be found")
      (let [(bmed (option-unwrap best-med))]
        (assert (= (.-model-id bmed) "gemini-2.5-flash") "Best medium run must be Gemini Flash")
        (assert (= (.-pareto-score bmed) 82.1) "Best medium Pareto score must be 82.1"))
      (assert (option-some? best-micro) "Micro-SLM best run must be found")
      (let [(bm (option-unwrap best-micro))]
        (assert (= (.-model-id bm) "qwen2.5:0.5b") "Best micro run must be Qwen 0.5B")
        (assert (= (.-strategy bm) "S3-jit-memory") "Best micro strategy must be S3-jit-memory"))
      (assert (option-some? best-hard) "Impossible horizon run must be found")
      (let [(bhard (option-unwrap best-hard))]
        (assert (= (.-pass-rate bhard) 0.0) "Impossible run pass rate must be 0.0")
        (assert (= (.-pareto-score bhard) 0.0) "Impossible run Pareto score must be 0.0"))
      (assert (option-none? unknown) "Unknown tier must return none")
      true)))

(df test-format-calibration-registry-asn [] -> Bool
  :d "Verifies full calibration registry serialization into canonical ASN."
  (let [(reg (ckb/make-calibration-registry))
        (asn-str (ckb/format-calibration-registry-asn reg))]
    (do
      (assert (string-starts-with? asn-str "(:model-calibration-registry") "Must start with :model-calibration-registry")
      (assert (string-contains? asn-str ":schema-version \"1.0.0\"") "Must contain schema version")
      (assert (string-contains? asn-str "RUN-GEMMA-31B-S4") "Must contain Gemma run")
      (assert (string-contains? asn-str "RUN-GEMINI-FLASH-S4") "Must contain Gemini Flash run")
      (assert (string-contains? asn-str "RUN-IMPOSSIBLE-BASELINE") "Must contain impossible horizon run")
      (assert (string-ends-with? asn-str ")") "Must end with closing paren")
      true)))

(df run-tests [] -> Bool
  :d "Executes full calibration knowledge base test suite."
  (and (test-standard-profiles-count-and-fields)
       (and (test-find-profile-by-id-exact-and-partial)
            (and (test-recommend-harness-setup-known-model)
                 (and (test-recommend-harness-setup-unknown-fallback)
                      (and (test-format-model-profile-asn)
                           (and (test-calibration-registry-and-runs)
                                (test-format-calibration-registry-asn))))))))
