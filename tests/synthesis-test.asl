(module asl-harness/synthesis-test
  :d "Unit verification tests for Stage 7 synthesis reasoning engine and 5-section canonical delivery."
  :x [test-synthesis-5-canonical-sections
      test-synthesis-disclose-gaps
      run-tests]
  :i [(synthesis :a syn)
      (feedback :a fb)
      (pre-mortem :a pm)])

(df test-synthesis-5-canonical-sections [] -> Bool
  :d "Verifies that format-5-section-delivery renders all 5 mandatory canonical section headers."
  (let [(r-risk (pm/ConsequenceRisk
                  :description "Potential schema drift in downstream cache"
                  :hop-count 1
                  :falsification-trigger "asl test --strict-falsify harness/tests/feedback-test.asl"
                  :severity "low"
                  :is-grounded true))
        (scorecard (syn/EpistemicScorecard
                     :confidence-score 0.98
                     :verified-assertion-count 12
                     :unverified-gap-count 0
                     :calibration-verdict "calibrated"))
        (report (syn/format-5-section-delivery
                  "TASK-258"
                  (list "Stage 4 pre-mortem reasoning engine verified" "Strict 2-hop speculation ceiling enforced")
                  (list)
                  (list)
                  (list r-risk)
                  scorecard))
        (md (.-raw-markdown report))]
    (and (string-contains? md "## 1. Verified Findings & AST Grounding")
         (and (string-contains? md "## 2. Intent Divergences & Reality Anchors")
              (and (string-contains? md "## 3. Transparent Disclosures & Omissions")
                   (and (string-contains? md "## 4. Blast Radius & Downstream Consequences")
                        (and (string-contains? md "## 5. Epistemic Calibration Scorecard")
                             (and (string-contains? (.-section-1-findings report) "Verified Findings & AST Grounding")
                                  (and (string-contains? (.-section-4-consequences report) "schema drift")
                                       (and (string-contains? (.-section-5-scorecard report) "calibrated")
                                            (string-contains? (.-section-5-scorecard report) "0.98")))))))))))

(df test-synthesis-disclose-gaps [] -> Bool
  :d "Verifies Section 3 integration with fb/disclose-observed-gaps for both empty and populated omissions."
  (let [(scorecard (syn/EpistemicScorecard
                     :confidence-score 0.85
                     :verified-assertion-count 8
                     :unverified-gap-count 2
                     :calibration-verdict "calibrated"))
        (report-with-gaps (syn/format-5-section-delivery
                            "TASK-258-GAPS"
                            (list "Verified core AST structure")
                            (list)
                            (list "ARM64 micro-benchmarking deferred to bench wave" "Optional JSON pretty-printing omitted per YAGNI")
                            (list)
                            scorecard))
        (report-clean (syn/format-5-section-delivery
                        "TASK-258-CLEAN"
                        (list "All items green")
                        (list)
                        (list)
                        (list)
                        scorecard))
        (s3-gaps (.-section-3-disclosures report-with-gaps))
        (s3-clean (.-section-3-disclosures report-clean))]
    (and (string-contains? s3-gaps "Transparent Disclosures")
         (and (string-contains? s3-gaps "ARM64 micro-benchmarking")
              (and (string-contains? s3-gaps "Optional JSON pretty-printing")
                   (string-contains? s3-clean "No unverified gaps or defects observed"))))))

(df run-tests [] -> Bool
  :d "Executes full synthesis delivery test suite."
  (do
    (assert (test-synthesis-5-canonical-sections))
    (assert (test-synthesis-disclose-gaps))
    true))
