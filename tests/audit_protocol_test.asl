(module asl-harness/audit-protocol-test
  :d "Unit and falsifiable verification suite for epistemic audit protocol and crutch taxonomy."
  :x [test-finding-construction-and-accessors
      test-crutch-and-critical-detection
      test-audit-verdict-aggregation
      test-meta-audit-adequacy
      test-asn-serialization
      run-tests]
  :i [(audit_protocol :a ap)])

(df test-finding-construction-and-accessors [] -> Bool
  :d "Verifies construction and record field integrity of AuditFinding."
  (let [(f (ap/make-audit-finding
             "crutch-scaffolding"
             "harness/src/foo.asl"
             42
             "temp-shim"
             "Temporary workaround"
             "c-0003"
             "asl check harness/src/foo.asl"))]
    (do
      (assert (= (.-category f) "crutch-scaffolding") "Finding category must match")
      (assert (= (.-file-path f) "harness/src/foo.asl") "Finding file-path must match")
      (assert (= (.-line-num f) 42) "Finding line number must match")
      (assert (= (.-symbol f) "temp-shim") "Finding symbol identifier must match")
      (assert (= (.-intent-rationale f) "c-0003") "Finding intent rationale must match")
      (assert (= (.-remediation-gate f) "asl check harness/src/foo.asl") "Remediation gate must match")
      true)))

(df test-crutch-and-critical-detection [] -> Bool
  :d "Verifies predicate classification for crutches, critical violations, and standard features."
  (let [(f-crutch (ap/make-audit-finding "crutch-scaffolding" "src/a.asl" 10 "shim" "shim desc" "c-0003" "gate-cmd"))
        (f-drift (ap/make-audit-finding "architectural-drift" "src/b.asl" 20 "leak" "leak desc" "d-0034" "gate-cmd"))
        (f-vacuous (ap/make-audit-finding "vacuous-verification" "tests/c.asl" 30 "empty-test" "vacuous desc" "ground-truth" "gate-cmd"))
        (f-feature (ap/make-audit-finding "incomplete-feature" "src/d.asl" 40 "missing-branch" "feature desc" "intent" "gate-cmd"))]
    (do
      (assert (ap/is-crutch-finding? f-crutch) "Crutch finding must be identified as crutch")
      (assert (not (ap/is-crutch-finding? f-drift)) "Architectural drift is not a crutch")
      (assert (not (ap/is-crutch-finding? f-vacuous)) "Vacuous verification is not a crutch")
      (assert (not (ap/is-crutch-finding? f-feature)) "Incomplete feature is not a crutch")
      (assert (ap/is-critical-finding? f-drift) "Architectural drift must be classified as critical")
      (assert (ap/is-critical-finding? f-vacuous) "Vacuous verification must be classified as critical")
      (assert (not (ap/is-critical-finding? f-crutch)) "Crutch finding is not critical")
      (assert (not (ap/is-critical-finding? f-feature)) "Incomplete feature is not critical")
      true)))

(df test-audit-verdict-aggregation [] -> Bool
  :d "Verifies verdict calculation across empty, advisory, and critical finding sets."
  (let [(f-crutch (ap/make-audit-finding "crutch-scaffolding" "src/a.asl" 10 "shim" "desc" "c-0003" "gate"))
        (f-drift (ap/make-audit-finding "architectural-drift" "src/b.asl" 20 "leak" "desc" "d-0034" "gate"))
        (f-feature (ap/make-audit-finding "incomplete-feature" "src/c.asl" 30 "feat" "desc" "intent" "gate"))
        (v-empty (ap/evaluate-audit-findings (list)))
        (v-crutch (ap/evaluate-audit-findings (list f-crutch f-feature)))
        (v-crit (ap/evaluate-audit-findings (list f-crutch f-drift)))]
    (do
      (assert (.-passed v-empty) "Empty findings must pass")
      (assert (= (.-verdict-tag v-empty) "approve") "Empty findings verdict tag must be approve")
      (assert (= (.-total-findings v-empty) 0) "Empty findings total count must be 0")
      (assert (= (.-crutch-count v-empty) 0) "Empty findings crutch count must be 0")
      (assert (.-passed v-crutch) "Crutch-only findings must pass with amendments")
      (assert (= (.-verdict-tag v-crutch) "approve-with-amendments") "Verdict tag must be approve-with-amendments")
      (assert (= (.-total-findings v-crutch) 2) "Total findings count must be 2")
      (assert (= (.-crutch-count v-crutch) 1) "Crutch count must be 1")
      (assert (not (.-passed v-crit)) "Critical findings must fail verdict")
      (assert (= (.-verdict-tag v-crit) "reject") "Critical verdict tag must be reject")
      (assert (= (.-total-findings v-crit) 2) "Critical total findings count must be 2")
      (assert (= (.-crutch-count v-crit) 1) "Critical crutch count must be 1")
      true)))

(df test-meta-audit-adequacy [] -> Bool
  :d "Verifies secondary meta-audit adequacy evaluations and threshold rejection."
  (let [(r-pass (ap/make-meta-audit-report
                  "steps-impl-reviewer"
                  true
                  92
                  (list "crutch-scaffolding" "incomplete-feature")
                  (list)))
        (r-low-score (ap/make-meta-audit-report
                       "auditor"
                       true
                       75
                       (list "crutch-scaffolding")
                       (list)))
        (r-inadequate (ap/make-meta-audit-report
                        "auditor"
                        false
                        95
                        (list)
                        (list)))
        (r-gaps (ap/make-meta-audit-report
                  "auditor"
                  true
                  95
                  (list "crutch-scaffolding")
                  (list "missed-crutch-at-line-10")))]
    (do
      (assert (ap/is-meta-audit-adequate? r-pass) "High score with no gaps must be adequate")
      (assert (not (ap/is-meta-audit-adequate? r-low-score)) "Score below 80 must be inadequate")
      (assert (not (ap/is-meta-audit-adequate? r-inadequate)) "Flagged inadequate report must fail")
      (assert (not (ap/is-meta-audit-adequate? r-gaps)) "Report with missing gaps must fail")
      true)))

(df test-asn-serialization [] -> Bool
  :d "Verifies canonical ASN formatting of AuditFinding and AuditVerdict."
  (let [(f (ap/make-audit-finding "crutch-scaffolding" "harness/src/foo.asl" 42 "temp-shim" "Temporary workaround" "c-0003" "asl check"))
        (v (ap/make-audit-verdict true "approve-with-amendments" 1 1 (list f)))
        (s-finding (ap/format-finding-asn f))
        (s-verdict (ap/format-verdict-asn v))]
    (do
      (assert (string-contains? s-finding ":finding") "Finding ASN must contain :finding tag")
      (assert (string-contains? s-finding ":cat :crutch-scaffolding") "Finding ASN must contain :cat :crutch-scaffolding")
      (assert (string-contains? s-finding "harness/src/foo.asl") "Finding ASN must contain file path")
      (assert (string-contains? s-finding ":line 42") "Finding ASN must contain line number")
      (assert (string-contains? s-verdict ":verdict") "Verdict ASN must contain :verdict tag")
      (assert (string-contains? s-verdict ":passed true") "Verdict ASN must contain :passed true")
      (assert (string-contains? s-verdict ":tag :approve-with-amendments") "Verdict ASN must contain :tag")
      (assert (string-contains? s-verdict ":total 1") "Verdict ASN must contain :total 1")
      (assert (string-contains? s-verdict ":crutches 1") "Verdict ASN must contain :crutches 1")
      true)))

(df run-tests [] -> Bool
  :d "Executes all epistemic audit protocol assertion suites."
  (do
    (assert (test-finding-construction-and-accessors))
    (assert (test-crutch-and-critical-detection))
    (assert (test-audit-verdict-aggregation))
    (assert (test-meta-audit-adequacy))
    (assert (test-asn-serialization))
    true))
