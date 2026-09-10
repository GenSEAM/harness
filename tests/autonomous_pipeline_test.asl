(module asl-harness/autonomous-pipeline-test
  :d "Unit and falsifiable verification suite for autonomous agent pipeline selection, stage temperatures, and Hanas model stand calibration."
  :x [test-stage-temperature-config-defaults
      test-stage-temperature-resolution
      test-all-five-pipeline-profiles
      test-pipeline-profile-lookup
      test-autonomous-selection-creative
      test-autonomous-selection-security
      test-autonomous-selection-trivial
      test-autonomous-selection-architecture
      test-autonomous-selection-standard
      test-hanas-model-stand-implementation-calibration
      test-hanas-model-stand-reflection-calibration
      test-hanas-model-stand-planning-calibration
      test-hanas-model-stand-full-sweep
      test-asn-serialization
      run-tests]
  :i [(autonomous_pipeline :a ap)])

(df test-stage-temperature-config-defaults [] -> Bool
  :d "Verifies default stage temperature configuration values."
  (let [(cfg (ap/default-stage-temperatures))]
    (do
      (assert (= (.-planning-temp cfg) 0.70) "Default planning temperature must be 0.70")
      (assert (= (.-reflection-temp cfg) 0.20) "Default reflection temperature must be 0.20")
      (assert (= (.-implementation-temp cfg) 0.00) "Default implementation temperature must be strictly 0.00")
      (assert (= (.-verification-temp cfg) 0.00) "Default verification temperature must be strictly 0.00")
      (assert (= (.-scout-temp cfg) 0.10) "Default scout temperature must be 0.10")
      true)))

(df test-stage-temperature-resolution [] -> Bool
  :d "Verifies stage temperature resolution across cognitive aliases."
  (let [(cfg (ap/default-stage-temperatures))]
    (do
      (assert (= (ap/stage-temperature-for cfg "plan") 0.70) "Plan stage temperature must match")
      (assert (= (ap/stage-temperature-for cfg "planning") 0.70) "Planning alias temperature must match")
      (assert (= (ap/stage-temperature-for cfg "decomposition") 0.70) "Decomposition alias must match")
      (assert (= (ap/stage-temperature-for cfg "reflect") 0.20) "Reflect stage temperature must match")
      (assert (= (ap/stage-temperature-for cfg "gap-audit") 0.20) "Gap audit alias must match")
      (assert (= (ap/stage-temperature-for cfg "review") 0.20) "Review alias must match")
      (assert (= (ap/stage-temperature-for cfg "impl") 0.00) "Impl stage temperature must match 0.00")
      (assert (= (ap/stage-temperature-for cfg "codegen") 0.00) "Codegen alias must match 0.00")
      (assert (= (ap/stage-temperature-for cfg "verify") 0.00) "Verify stage temperature must match 0.00")
      (assert (= (ap/stage-temperature-for cfg "gate-check") 0.00) "Gate check alias must match 0.00")
      (assert (= (ap/stage-temperature-for cfg "scout") 0.10) "Scout stage temperature must match 0.10")
      (assert (= (ap/stage-temperature-for cfg "unknown-stage") 0.00) "Unknown stage defaults to 0.00")
      true)))

(df test-all-five-pipeline-profiles [] -> Bool
  :d "Verifies that all five registered pipeline profiles instantiate cleanly with valid stages."
  (let [(profs (ap/available-pipeline-profiles))
        (fast (ap/make-fast-pipeline))
        (std (ap/make-standard-pipeline))
        (deep (ap/make-deep-epistemic-pipeline))
        (crt (ap/make-creative-synthesis-pipeline))
        (sec (ap/make-adversarial-hardening-pipeline))]
    (do
      (assert (= (list-length profs) 5) "Must have exactly 5 autonomous pipeline profiles")
      (assert (= (.-id fast) "fast") "Fast pipeline ID must match")
      (assert (.-supports-fast-path fast) "Fast pipeline must support fast-path")
      (assert (= (list-length (.-stages fast)) 2) "Fast pipeline must have 2 stages")
      (assert (= (.-id std) "standard") "Standard pipeline ID must match")
      (assert (= (list-length (.-stages std)) 5) "Standard pipeline must have 5 stages")
      (assert (= (.-id deep) "deep-epistemic") "Deep epistemic pipeline ID must match")
      (assert (= (list-length (.-stages deep)) 7) "Deep epistemic pipeline must have 7 stages")
      (assert (= (.-id crt) "creative-synthesis") "Creative pipeline ID must match")
      (assert (= (.-planning-temp (.-temp-config crt)) 0.75) "Creative planning temp must be 0.75")
      (assert (= (.-reflection-temp (.-temp-config crt)) 0.30) "Creative reflection temp must be 0.30")
      (assert (= (.-id sec) "adversarial-hardening") "Security pipeline ID must match")
      (assert (= (.-planning-temp (.-temp-config sec)) 0.40) "Security planning temp must be 0.40")
      (assert (= (.-reflection-temp (.-temp-config sec)) 0.10) "Security reflection temp must be 0.10")
      (assert (= (.-implementation-temp (.-temp-config sec)) 0.00) "Security impl temp must be 0.00")
      true)))

(df test-pipeline-profile-lookup [] -> Bool
  :d "Verifies finding pipeline profile by identifier."
  (let [(profs (ap/available-pipeline-profiles))
        (found-fast (ap/find-pipeline-profile profs "fast"))
        (found-sec (ap/find-pipeline-profile profs "adversarial-hardening"))
        (found-none (ap/find-pipeline-profile profs "non-existent"))]
    (do
      (assert (not (option-none? found-fast)) "Should find fast pipeline")
      (assert (not (option-none? found-sec)) "Should find security pipeline")
      (assert (option-none? found-none) "Non-existent profile must be None")
      true)))

(df test-autonomous-selection-creative [] -> Bool
  :d "Verifies autonomous pipeline selection for creative / generative tasks."
  (let [(prompt "Generate scalable vector graphics SVG mascot and interactive 2D canvas game loop with neon palette")
        (dec (ap/autonomous-select-pipeline "TASK-CRT-01" prompt "" 3 0.1 0.3))]
    (do
      (assert (= (.-detected-domain dec) "creative") "Domain must be detected as creative")
      (assert (= (.-id (.-selected-profile dec)) "creative-synthesis") "Selected pipeline must be creative-synthesis")
      (assert (>= (.-confidence dec) 0.90) "Confidence must be at least 0.90")
      (assert (= (.-planning-temp (.-temp-config (.-selected-profile dec))) 0.75) "Planning temp must be 0.75")
      (assert (= (.-implementation-temp (.-temp-config (.-selected-profile dec))) 0.00) "Implementation temp must be 0.00")
      true)))

(df test-autonomous-selection-security [] -> Bool
  :d "Verifies autonomous pipeline selection for security and vulnerability remediation tasks."
  (let [(prompt "Patch critical XSS vulnerability and sanitize input in cryptographic auth session tokens")
        (dec (ap/autonomous-select-pipeline "TASK-SEC-01" prompt "" 4 0.95 0.2))]
    (do
      (assert (= (.-detected-domain dec) "security") "Domain must be detected as security")
      (assert (= (.-id (.-selected-profile dec)) "adversarial-hardening") "Selected pipeline must be adversarial-hardening")
      (assert (>= (.-confidence dec) 0.95) "Confidence must be at least 0.95")
      (assert (= (.-planning-temp (.-temp-config (.-selected-profile dec))) 0.40) "Defensive planning temp must be 0.40")
      (assert (= (.-reflection-temp (.-temp-config (.-selected-profile dec))) 0.10) "Adversarial reflection temp must be 0.10")
      (assert (= (.-implementation-temp (.-temp-config (.-selected-profile dec))) 0.00) "Strict zero-temp impl must hold")
      true)))

(df test-autonomous-selection-trivial [] -> Bool
  :d "Verifies autonomous pipeline selection for trivial docstring or typo fixes."
  (let [(prompt "Fix minor typo in docstring of helper module")
        (dec (ap/autonomous-select-pipeline "TASK-TRIV-01" prompt "" 1 0.0 0.0))]
    (do
      (assert (= (.-detected-domain dec) "trivial") "Domain must be detected as trivial")
      (assert (= (.-id (.-selected-profile dec)) "fast") "Selected pipeline must be fast")
      (assert (.-supports-fast-path (.-selected-profile dec)) "Fast-path must be enabled")
      (assert (< (.-computed-entropy dec) 1.5) "Entropy must be below 1.5 threshold")
      true)))

(df test-autonomous-selection-architecture [] -> Bool
  :d "Verifies autonomous pipeline selection for complex architectural cross-package tasks."
  (let [(prompt "Perform deep architectural refactoring of distributed state machine across all monorepo packages")
        (dec (ap/autonomous-select-pipeline "TASK-ARCH-01" prompt "" 10 0.2 0.8))]
    (do
      (assert (= (.-detected-domain dec) "architecture") "Domain must be detected as architecture")
      (assert (= (.-id (.-selected-profile dec)) "deep-epistemic") "Selected pipeline must be deep-epistemic")
      (assert (>= (.-computed-entropy dec) 4.0) "Entropy must be >= 4.0")
      (assert (= (list-length (.-stages (.-selected-profile dec))) 7) "Deep epistemic pipeline must have 7 stages")
      true)))

(df test-autonomous-selection-standard [] -> Bool
  :d "Verifies autonomous pipeline selection for standard feature tasks."
  (let [(prompt "Add pagination support and filter query parameters to user profile list endpoint")
        (dec (ap/autonomous-select-pipeline "TASK-STD-01" prompt "" 2 0.1 0.2))]
    (do
      (assert (= (.-detected-domain dec) "standard") "Domain must be standard")
      (assert (= (.-id (.-selected-profile dec)) "standard") "Selected pipeline must be standard")
      (assert (and (>= (.-computed-entropy dec) 1.5) (< (.-computed-entropy dec) 4.0)) "Entropy in standard bounds")
      true)))

(df test-hanas-model-stand-implementation-calibration [] -> Bool
  :d "Verifies empirical Pareto optimization on Hanas stand proves T=0.00 is strictly mandatory for implementation."
  (let [(pt-zero (ap/evaluate-stage-temperature-point "small" "impl" 0.00))
        (pt-low (ap/evaluate-stage-temperature-point "small" "impl" 0.10))
        (pt-mid (ap/evaluate-stage-temperature-point "small" "impl" 0.30))]
    (do
      (assert (.-is-pareto-optimal pt-zero) "T=0.00 must be strictly Pareto-optimal for implementation")
      (assert (= (.-syntax-integrity pt-zero) 100.0) "T=0.00 must yield 100% syntax integrity")
      (assert (= (.-hallucination-rate pt-zero) 0.0) "T=0.00 must yield 0% hallucination rate")
      (assert (> (.-pareto-score pt-zero) (.-pareto-score pt-low)) "T=0.00 Pareto score must exceed T=0.10")
      (assert (> (.-pareto-score pt-low) (.-pareto-score pt-mid)) "T=0.10 Pareto score must exceed T=0.30")
      (assert (not (.-is-pareto-optimal pt-low)) "T=0.10 is sub-optimal for implementation due to syntax drift")
      true)))

(df test-hanas-model-stand-reflection-calibration [] -> Bool
  :d "Verifies reflection calibration finds optimal Pareto balance at T=0.20 for Hanas small and mini models."
  (let [(pt-zero (ap/evaluate-stage-temperature-point "small" "reflect" 0.00))
        (pt-opt (ap/evaluate-stage-temperature-point "small" "reflect" 0.20))
        (pt-high (ap/evaluate-stage-temperature-point "small" "reflect" 0.50))]
    (do
      (assert (.-is-pareto-optimal pt-opt) "T=0.20 must be Pareto-optimal for reflection")
      (assert (> (.-coverage-score pt-opt) (.-coverage-score pt-zero)) "T=0.20 catches more edge cases than T=0.00")
      (assert (< (.-hallucination-rate pt-opt) 3.0) "T=0.20 maintains very low hallucination rate")
      (assert (> (.-pareto-score pt-opt) (.-pareto-score pt-high)) "T=0.20 Pareto score must exceed T=0.50")
      (assert (not (.-is-pareto-optimal pt-high)) "T=0.50 triggers false positive hallucinated rejections")
      true)))

(df test-hanas-model-stand-planning-calibration [] -> Bool
  :d "Verifies planning calibration finds optimal Pareto divergence at T=0.70 for Hanas small and mini models."
  (let [(pt-low (ap/evaluate-stage-temperature-point "small" "plan" 0.10))
        (pt-opt (ap/evaluate-stage-temperature-point "small" "plan" 0.70))
        (pt-high (ap/evaluate-stage-temperature-point "small" "plan" 0.90))]
    (do
      (assert (.-is-pareto-optimal pt-opt) "T=0.70 must be Pareto-optimal for planning on small tier")
      (assert (> (.-coverage-score pt-opt) (.-coverage-score pt-low)) "T=0.70 generates deeper multi-hypothesis plan")
      (assert (< (.-hallucination-rate pt-opt) 4.0) "T=0.70 maintains bounded hallucination rate under 4%")
      (assert (> (.-pareto-score pt-opt) (.-pareto-score pt-high)) "T=0.70 Pareto score must exceed T=0.90")
      (assert (not (.-is-pareto-optimal pt-high)) "T=0.90 suffers ungrounded symbol hallucination penalties")
      true)))

(df test-hanas-model-stand-full-sweep [] -> Bool
  :d "Verifies full multi-stage temperature sweep across all 4 Hanas model tiers."
  (let [(sweep-small (ap/run-hanas-stage-calibration "small"))
        (sweep-micro (ap/run-hanas-stage-calibration "micro"))]
    (do
      (assert (= (.-model-alias sweep-small) "small") "Small model alias matches")
      (assert (= (.-memory-limit-mb sweep-small) 2150) "Small model memory ceiling is 2150MB")
      (assert (= (list-length (.-stage-points sweep-small)) 12) "Must have 12 tested calibration points")
      (assert (= (.-planning-temp (.-optimal-temps sweep-small)) 0.70) "Small optimal planning temp is 0.70")
      (assert (= (.-reflection-temp (.-optimal-temps sweep-small)) 0.20) "Small optimal reflection temp is 0.20")
      (assert (= (.-implementation-temp (.-optimal-temps sweep-small)) 0.00) "Small optimal impl temp is strictly 0.00")
      (assert (= (.-model-alias sweep-micro) "micro") "Micro model alias matches")
      (assert (= (.-memory-limit-mb sweep-micro) 480) "Micro model memory ceiling is 480MB")
      (assert (= (.-planning-temp (.-optimal-temps sweep-micro)) 0.50) "Micro optimal planning temp is conservative 0.50")
      (assert (= (.-reflection-temp (.-optimal-temps sweep-micro)) 0.10) "Micro optimal reflection temp is conservative 0.10")
      (assert (= (.-implementation-temp (.-optimal-temps sweep-micro)) 0.00) "Micro optimal impl temp is strictly 0.00")
      true)))

(df test-asn-serialization [] -> Bool
  :d "Verifies S-expression serialization for temperature configs, pipelines, and decisions."
  (let [(temps (ap/default-stage-temperatures))
        (prof (ap/make-deep-epistemic-pipeline))
        (dec (ap/autonomous-select-pipeline "T-01" "Build SVG game" "" 2 0.0 0.0))
        (sweep (ap/run-hanas-stage-calibration "small"))
        (s-temps (ap/format-stage-temperature-asn temps))
        (s-prof (ap/format-pipeline-profile-asn prof))
        (s-dec (ap/format-selection-decision-asn dec))
        (s-sweep (ap/format-hanas-stand-sweep-asn sweep))]
    (do
      (assert (string-contains? s-temps ":planning") "Stage temp ASN contains planning")
      (assert (string-contains? s-temps ":implementation") "Stage temp ASN contains implementation")
      (assert (string-contains? s-prof "deep-epistemic") "Profile ASN contains pipeline ID")
      (assert (string-contains? s-dec ":selected-pipeline") "Decision ASN contains selected pipeline")
      (assert (string-contains? s-sweep "small") "Sweep ASN contains model alias")
      true)))

(df run-tests [] -> Bool
  :d "Runs all autonomous pipeline verification test cases."
  (do
    (assert (test-stage-temperature-config-defaults))
    (assert (test-stage-temperature-resolution))
    (assert (test-all-five-pipeline-profiles))
    (assert (test-pipeline-profile-lookup))
    (assert (test-autonomous-selection-creative))
    (assert (test-autonomous-selection-security))
    (assert (test-autonomous-selection-trivial))
    (assert (test-autonomous-selection-architecture))
    (assert (test-autonomous-selection-standard))
    (assert (test-hanas-model-stand-implementation-calibration))
    (assert (test-hanas-model-stand-reflection-calibration))
    (assert (test-hanas-model-stand-planning-calibration))
    (assert (test-hanas-model-stand-full-sweep))
    (assert (test-asn-serialization))
    true))
