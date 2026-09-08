(module asl-harness/calibration-kb
  :d "Git-native Model Calibration Knowledge Base query engine and automatic harness setup recommender."
  :x [ModelProfile
      HarnessSetupRecommendation
      ModelRunRecord
      InvariantCheckRecord
      CalibrationRegistry
      make-model-profile
      standard-model-profiles
      find-profile-by-id
      recommend-harness-setup
      format-model-profile-asn
      make-model-run
      canonical-invariants
      canonical-model-runs
      make-calibration-registry
      find-best-run-by-tier
      format-model-run-asn
      format-calibration-registry-asn]
  :i [(context_assembler :a ca)])

(dfs ModelProfile
  (:f model-id Str "Model unique identifier")
  (:f tier Str "Model scale tier e.g. micro-slm, small-slm, midweight, frontier, fast-classifier")
  (:f optimal-strategy Str "Recommended context strategy")
  (:f optimal-temperature F64 "Recommended sampling temperature")
  (:f token-ceiling I64 "Recommended token budget ceiling")
  (:f keep-recent I64 "Number of recent turns to preserve in receipts mode")
  (:f clamp-knowledge I64 "Token budget limit for mounted knowledge docs")
  (:f pathologies (List Str) "List of observed model pathologies")
  (:f recommendation Str "Executive deployment guideline"))

(dfs HarnessSetupRecommendation
  (:f model-id Str "Target model identifier")
  (:f known-profile Bool "True if matched against verified knowledge base entry")
  (:f context-config ca/ContextAssemblyConfig "Configured context assembly parameters")
  (:f temperature F64 "Optimal sampling temperature")
  (:f clamp-knowledge I64 "Mounted knowledge token ceiling")
  (:f rationale Str "Recommendation rationale"))

(dfs ModelRunRecord
  (:f run-id Str "Unique calibration run identifier")
  (:f model-id Str "Model unique identifier")
  (:f tier Str "Model scale tier: micro-slm, small-slm, midweight, frontier")
  (:f strategy Str "Context strategy evaluated")
  (:f temperature F64 "Sampling temperature")
  (:f budget-ceiling I64 "Token budget ceiling")
  (:f pass-rate F64 "Evaluated pass rate percentage")
  (:f ctrf-progress F64 "Continuous subtest completion ratio")
  (:f avg-tokens I64 "Average tokens consumed")
  (:f latency-ms I64 "Average latency in milliseconds")
  (:f amnesia-detected Bool "Whether fact amnesia occurred")
  (:f pareto-score F64 "Calculated Pareto score")
  (:f timestamp-ms I64 "Run timestamp"))

(dfs InvariantCheckRecord
  (:f invariant-id Str "Unique invariant identifier")
  (:f rule-name Str "Invariant rule name")
  (:f status Str "Verification status: verified, active, or pending")
  (:f evidence Str "Physical proof or test suite receipt"))

(dfs CalibrationRegistry
  (:f version Str "Registry schema version")
  (:f runs (List ModelRunRecord) "Empirical model run history")
  (:f invariants (List InvariantCheckRecord) "Active repository invariants")
  (:f profiles (List ModelProfile) "Calibrated model profiles"))

(df make-model-profile [(id Str) (tier Str) (strat Str) (temp F64) (ceiling I64) (recent I64) (clamp I64) (pathologies (List Str)) (rec Str)] -> ModelProfile
  :d "Constructs a ModelProfile record"
  (ModelProfile
    :model-id id
    :tier tier
    :optimal-strategy strat
    :optimal-temperature temp
    :token-ceiling ceiling
    :keep-recent recent
    :clamp-knowledge clamp
    :pathologies pathologies
    :recommendation rec))

(df standard-model-profiles [] -> (List ModelProfile)
  :d "Provides canonical empirical model profiles verified on benchmarks"
  (let [(p1 (make-model-profile
              "qwen-2.5-0.5b"
              "micro-slm"
              "jit-memory"
              0.1
              1024
              0
              200
              (list "Attention saturation on verbose conversational prose"
                    "Pass rate degrades from 94% down to 31% if multi-turn history uncompressed")
              "Use pure affirmative S-expression schema and zero conversational history"))
        (p2 (make-model-profile
              "qwen-2.5-3b"
              "small-slm"
              "agent-directed"
              0.2
              2048
              1
              300
              (list "Occasional unclosed markdown backticks on multi-file refactors")
              "Use agent self-directed context eviction (:ctx-op) to clear prior tool logs"))
        (p3 (make-model-profile
              "gemma-4-31b-it"
              "midweight"
              "agent-directed"
              0.15
              4096
              1
              350
              (list "Unclosed markdown code fences if prompted with raw prose"
                    "Overdumps bash stdout unless constrained by S-expression tools")
              "Use Eddie ASL cognitive harness with agent self-eviction and 350-token knowledge clamping"))
        (p4 (make-model-profile
              "gpt-5.6-luna"
              "frontier"
              "receipts"
              0.2
              8192
              2
              600
              (list "High per-token billing cost and latency on raw terminal dumps")
              "Use rolling 1-line receipts (S2) to cut prompt cost by ~50% with zero quality degradation"))
        (p5 (make-model-profile
              "ling-3.0-flash"
              "fast-classifier"
              "jit-memory"
              0.0
              1024
              0
              200
              (list "Not suited for long-horizon planning; designed for single-shot triage")
              "Use for live parameter normalization, gate validation, and sub-220ms dispatch"))]
    (list p1 p2 p3 p4 p5)))

(df find-profile-by-id [(profiles (List ModelProfile)) (model-id Str)] -> (Option ModelProfile)
  :d "Searches profiles list for matching model ID using exact or substring matching"
  (if (list-empty? profiles)
    (none)
    (let [(head-p (option-or (list-head profiles) (make-model-profile "" "" "" 0.0 0 0 0 (list) "")))
          (tail-p (option-or (list-tail profiles) (list)))]
      (if (or (= (.-model-id head-p) model-id)
              (or (string-contains? model-id (.-model-id head-p))
                  (string-contains? (.-model-id head-p) model-id)))
        (some head-p)
        (find-profile-by-id tail-p model-id)))))

(df recommend-harness-setup [(model-id Str)] -> HarnessSetupRecommendation
  :d "Looks up optimal harness setup for model or applies Universal Golden Default canvas"
  (let [(profiles (standard-model-profiles))
        (matched (find-profile-by-id profiles model-id))]
    (mt matched
      ((some prof)
       (let [(cfg (ca/ContextAssemblyConfig
                    :strategy (.-optimal-strategy prof)
                    :token-ceiling (.-token-ceiling prof)
                    :keep-recent (.-keep-recent prof)))]
         (HarnessSetupRecommendation
           :model-id model-id
           :known-profile true
           :context-config cfg
           :temperature (.-optimal-temperature prof)
           :clamp-knowledge (.-clamp-knowledge prof)
           :rationale (str "Matched verified profile in Knowledge Base: " (.-recommendation prof)))))
      ((none)
       (let [(cfg (ca/ContextAssemblyConfig
                    :strategy "receipts"
                    :token-ceiling 4096
                    :keep-recent 1))]
         (HarnessSetupRecommendation
           :model-id model-id
           :known-profile false
           :context-config cfg
           :temperature 0.2
           :clamp-knowledge 350
           :rationale "Unknown model fallback: applied Universal Golden Default Canvas (S2 Receipts + 350-token knowledge clamp, temp 0.2)"))))))

(df format-model-profile-asn [(profile ModelProfile)] -> Str
  :d "Formats a model profile record into canonical ASN representation"
  (str "(:model-profile\n"
       "  :model-id \"" (.-model-id profile) "\"\n"
       "  :tier \"" (.-tier profile) "\"\n"
       "  :optimal-strategy \"" (.-optimal-strategy profile) "\"\n"
       "  :optimal-temperature " (string-from-float64 (.-optimal-temperature profile)) "\n"
       "  :token-ceiling " (string-from-int64 (.-token-ceiling profile)) "\n"
       "  :keep-recent " (string-from-int64 (.-keep-recent profile)) "\n"
       "  :clamp-knowledge " (string-from-int64 (.-clamp-knowledge profile)) "\n"
       "  :recommendation \"" (.-recommendation profile) "\"\n"
       ")"))

(df make-model-run [(run-id Str) (model-id Str) (tier Str) (strat Str) (temp F64) (budget I64) (pass-rate F64) (progress F64) (tokens I64) (lat I64) (amnesia Bool) (pareto F64) (ts I64)] -> ModelRunRecord
  :d "Constructs a ModelRunRecord"
  (ModelRunRecord
    :run-id run-id
    :model-id model-id
    :tier tier
    :strategy strat
    :temperature temp
    :budget-ceiling budget
    :pass-rate pass-rate
    :ctrf-progress progress
    :avg-tokens tokens
    :latency-ms lat
    :amnesia-detected amnesia
    :pareto-score pareto
    :timestamp-ms ts))

(df canonical-invariants [] -> (List InvariantCheckRecord)
  :d "Provides canonical list of grounded system and gateway invariants"
  (list
    (InvariantCheckRecord :invariant-id "c-0001" :rule-name "pure-asl-zero-comment" :status "verified" :evidence "721 source files audited cleanly in gate 2")
    (InvariantCheckRecord :invariant-id "c-0002" :rule-name "machine-asn-zero-emoji" :status "verified" :evidence "3363 grammar symbols audited cleanly in gate 6")
    (InvariantCheckRecord :invariant-id "c-0003" :rule-name "boundary-universalism" :status "verified" :evidence "Canonical package separation enforced (d-0034)")
    (InvariantCheckRecord :invariant-id "l7-cot" :rule-name "reasoning-channel-quarantine" :status "verified" :evidence "Demux stream isolates think from user channel (d-0037)")
    (InvariantCheckRecord :invariant-id "l7-esh" :rule-name "verbal-esh-rejection" :status "verified" :evidence "Unverified test passage claims rejected with esh_rejected")
    (InvariantCheckRecord :invariant-id "l7-gateway" :rule-name "single-llm-nexus" :status "verified" :evidence "All inference routed to http://127.0.0.1:8765/v1")
    (InvariantCheckRecord :invariant-id "affirmative-priming" :rule-name "distractor-free-schema" :status "verified" :evidence "118-token schema reduces SLM syntax errors to 1.8%")
    (InvariantCheckRecord :invariant-id "dual-harness" :rule-name "hermetic-vs-production" :status "verified" :evidence "Benchmark profile airgapped, Production profile epistemic-dag")))

(df canonical-model-runs [] -> (List ModelRunRecord)
  :d "Provides canonical calibrated model runs from benchmark matrices"
  (let [(r1 (make-model-run "RUN-QWEN-05B-S3" "qwen2.5:0.5b" "micro-slm" "S3-jit-memory" 0.1 2048 80.0 0.88 420 42 false 48.5 1788880000000))
        (r2 (make-model-run "RUN-QWEN-3B-S4" "qwen2.5:3b-instruct" "small-slm" "S4-agent-directed" 0.2 4096 100.0 1.00 780 82 false 72.3 1788880100000))
        (r3 (make-model-run "RUN-QWEN-14B-S4" "qwen2.5:14b-instruct" "medium" "S4-agent-directed" 0.2 8192 60.0 0.65 2450 140 false 78.4 1788880300000))
        (r4 (make-model-run "RUN-GEMINI-FLASH-S4" "gemini-2.5-flash" "medium" "S4-agent-directed" 0.2 8192 60.0 0.70 2100 95 false 82.1 1788880400000))
        (r5 (make-model-run "RUN-GEMMA-31B-S4" "gemma-4-31b-it" "frontier" "S4-agent-directed" 0.2 35000 100.0 0.96 11420 310 false 94.8 1788880200000))
        (r6 (make-model-run "RUN-IMPOSSIBLE-BASELINE" "all-models-evaluated" "impossible" "S4-agent-directed" 0.2 35000 0.0 0.12 15000 900 false 0.0 1788880600000))]
    (list r1 r2 r3 r4 r5 r6)))

(df make-calibration-registry [] -> CalibrationRegistry
  :d "Constructs the master Model Calibration Registry with runs, invariants, and profiles"
  (CalibrationRegistry
    :version "1.0.0"
    :runs (canonical-model-runs)
    :invariants (canonical-invariants)
    :profiles (standard-model-profiles)))

(df find-best-run-by-tier [(runs (List ModelRunRecord)) (tier Str)] -> (Option ModelRunRecord)
  :d "Finds the model run with highest Pareto score within specified tier"
  (let [(filtered (filter (fn [(r ModelRunRecord)] -> Bool (= (.-tier r) tier)) runs))]
    (if (list-empty? filtered)
        (none)
        (let [(best (fold (fn [(curr ModelRunRecord) (cand ModelRunRecord)] -> ModelRunRecord
                            (if (> (.-pareto-score cand) (.-pareto-score curr))
                                cand
                                curr))
                          (option-or (list-head filtered) (make-model-run "" "" "" "" 0.0 0 0.0 0.0 0 0 false 0.0 0))
                          filtered))]
          (some best)))))

(df format-model-run-asn [(r ModelRunRecord)] -> Str
  :d "Formats an individual model run into canonical ASN representation"
  (str "    (:run\n"
       "      :run-id \"" (.-run-id r) "\"\n"
       "      :model-id \"" (.-model-id r) "\"\n"
       "      :tier \"" (.-tier r) "\"\n"
       "      :strategy \"" (.-strategy r) "\"\n"
       "      :temperature " (string-from-float64 (.-temperature r)) "\n"
       "      :budget-ceiling " (string-from-int64 (.-budget-ceiling r)) "\n"
       "      :pass-rate " (string-from-float64 (.-pass-rate r)) "\n"
       "      :ctrf-progress " (string-from-float64 (.-ctrf-progress r)) "\n"
       "      :avg-tokens " (string-from-int64 (.-avg-tokens r)) "\n"
       "      :latency-ms " (string-from-int64 (.-latency-ms r)) "\n"
       "      :amnesia-detected " (if (.-amnesia-detected r) "true" "false") "\n"
       "      :pareto-score " (string-from-float64 (.-pareto-score r)) "\n"
       "    )"))

(df format-calibration-registry-asn [(reg CalibrationRegistry)] -> Str
  :d "Formats entire master calibration registry into canonical machine-readable ASN"
  (let [(runs-str (fold (fn [(acc Str) (r ModelRunRecord)] -> Str
                          (str acc (format-model-run-asn r) "\n"))
                        ""
                        (.-runs reg)))]
    (str "(:model-calibration-registry\n"
         "  :schema-version \"" (.-version reg) "\"\n"
         "  :runs [\n"
         runs-str
         "  ]\n"
         ")")))
