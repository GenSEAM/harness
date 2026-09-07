(module asl-harness/synthesis
  :d "Stage 7 Synthesis reasoning engine: formats the canonical 5-section delivery report and epistemic calibration scorecard."
  :x [EpistemicScorecard
      CanonicalDeliveryReport
      format-5-section-delivery]
  :i [(feedback :a fb)
      (pre-mortem :a pm)])

(dfs EpistemicScorecard
  (:f confidence-score F64 "Confidence rating [0.0 - 1.0] calibrated against AST grounding")
  (:f verified-assertion-count I64 "Number of passing falsifiable assertions recorded")
  (:f unverified-gap-count I64 "Count of admitted gaps / unverified constraints")
  (:f calibration-verdict Str "epistemic-calibration rating: calibrated | overconfident | underconfident"))

(dfs CanonicalDeliveryReport
  (:f section-1-findings Str "Section 1: Verified Findings & AST Grounding")
  (:f section-2-divergences Str "Section 2: Intent Divergences & Reality Anchors")
  (:f section-3-disclosures Str "Section 3: Transparent Disclosures & Omissions")
  (:f section-4-consequences Str "Section 4: Blast Radius & Downstream Consequences")
  (:f section-5-scorecard Str "Section 5: Epistemic Calibration Scorecard")
  (:f raw-markdown Str "Complete concatenated 5-section delivery report"))

(df format-5-section-delivery
  [(task-id Str)
   (findings (List Str))
   (divergences (List Str))
   (omissions (List Str))
   (consequences (List pm/ConsequenceRisk))
   (scorecard EpistemicScorecard)] -> CanonicalDeliveryReport
  :d "Assembles the canonical 5-section delivery report adhering to strict Markdown heading standards. Integrates fb/disclose-observed-gaps from (asl-harness/feedback :as fb) to render Section 3."
  (let [(s1-body (if (list-empty? findings)
                     "- No verified findings recorded."
                     (str "- " (string-join findings "\n- "))))
        (s1 (str "## 1. Verified Findings & AST Grounding\n\n" s1-body))
        (s2-body (if (list-empty? divergences)
                     "- No intent divergences detected. Implementation anchors directly to specification."
                     (str "- " (string-join divergences "\n- "))))
        (s2 (str "## 2. Intent Divergences & Reality Anchors\n\n" s2-body))
        (s3-body (fb/disclose-observed-gaps omissions))
        (s3 (str "## 3. Transparent Disclosures & Omissions\n\n" s3-body))
        (s4-body (if (list-empty? consequences)
                     "- No downstream consequence risks identified."
                     (string-join (map (fn [(r pm/ConsequenceRisk)] -> Str
                                         (str "- [" (.-severity r) "] (hops: " (string-from-int64 (.-hop-count r))
                                              ", grounded: " (if (.-is-grounded r) "true" "false")
                                              ") " (.-description r)
                                              "\n  Trigger: `" (.-falsification-trigger r) "`"))
                                       consequences)
                                  "\n")))
        (s4 (str "## 4. Blast Radius & Downstream Consequences\n\n" s4-body))
        (s5-body (str "- Confidence Score: " (string-from-float64 (.-confidence-score scorecard)) "\n"
                      "- Verified Assertions: " (string-from-int64 (.-verified-assertion-count scorecard)) "\n"
                      "- Unverified Gaps: " (string-from-int64 (.-unverified-gap-count scorecard)) "\n"
                      "- Calibration Verdict: " (.-calibration-verdict scorecard)))
        (s5 (str "## 5. Epistemic Calibration Scorecard\n\n" s5-body))
        (raw-md (str "# Canonical Delivery Report: " task-id "\n\n"
                     s1 "\n\n"
                     s2 "\n\n"
                     s3 "\n\n"
                     s4 "\n\n"
                     s5))]
    (CanonicalDeliveryReport
      :section-1-findings s1
      :section-2-divergences s2
      :section-3-disclosures s3
      :section-4-consequences s4
      :section-5-scorecard s5
      :raw-markdown raw-md)))
