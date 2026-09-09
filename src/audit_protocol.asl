(module asl-harness/audit-protocol
  :d "Formal epistemic audit protocol, incongruity and crutch taxonomy, and secondary meta-audit evaluation engine."
  :x [AuditFinding
      AuditVerdict
      MetaAuditReport
      make-audit-finding
      make-audit-verdict
      make-meta-audit-report
      is-crutch-finding?
      is-critical-finding?
      evaluate-audit-findings
      is-meta-audit-adequate?
      format-finding-asn
      format-verdict-asn]
  :i [])

(dfs AuditFinding
  (:f category Str "Incongruity classification: crutch-scaffolding, incomplete-feature, architectural-drift, orphaned-code, vacuous-verification, intent-misalignment")
  (:f file-path Str "Relative target file path")
  (:f line-num I64 "Exact 1-based source line number")
  (:f symbol Str "Target symbol or function identifier or empty string")
  (:f description Str "Actionable description of the discovered defect or crutch")
  (:f intent-rationale Str "Underlying architectural rationale and invariant violated e.g. c-0001, c-0003, d-0041")
  (:f remediation-gate Str "Falsifiable verification command or predicate proving remediation"))

(dfs AuditVerdict
  (:f passed Bool "True if zero critical or high severity findings exist")
  (:f verdict-tag Str "Verdict rating: approve, approve-with-amendments, reject")
  (:f total-findings I64 "Total number of findings discovered")
  (:f crutch-count I64 "Count of temporary crutches and scaffolding identified")
  (:f findings (List AuditFinding) "List of all evaluated audit findings"))

(dfs MetaAuditReport
  (:f primary-auditor Str "Identifier of primary audit author or agent role")
  (:f is-adequate Bool "True if primary audit satisfies grounding and taxonomy completeness criteria")
  (:f adequacy-score I64 "Normalized adequacy score between 0 and 100")
  (:f checked-categories (List Str) "List of taxonomy categories scrutinized")
  (:f missing-gaps (List Str) "List of gaps overlooked by the primary audit"))

(df make-audit-finding [(cat Str) (file Str) (line I64) (sym Str) (desc Str) (intent Str) (gate Str)] -> AuditFinding
  :d "Constructs an AuditFinding record with verified file location and falsifiable remediation gate."
  (AuditFinding
    :category cat
    :file-path file
    :line-num line
    :symbol sym
    :description desc
    :intent-rationale intent
    :remediation-gate gate))

(df make-audit-verdict [(passed Bool) (tag Str) (total I64) (crutches I64) (findings (List AuditFinding))] -> AuditVerdict
  :d "Constructs an AuditVerdict record summarizing evaluation outcomes."
  (AuditVerdict
    :passed passed
    :verdict-tag tag
    :total-findings total
    :crutch-count crutches
    :findings findings))

(df make-meta-audit-report [(auditor Str) (adequate Bool) (score I64) (cats (List Str)) (gaps (List Str))] -> MetaAuditReport
  :d "Constructs a MetaAuditReport evaluating the adequacy and rigor of a primary audit."
  (MetaAuditReport
    :primary-auditor auditor
    :is-adequate adequate
    :adequacy-score score
    :checked-categories cats
    :missing-gaps gaps))

(df is-crutch-finding? [(f AuditFinding)] -> Bool
  :d "Checks if an audit finding represents a temporary workaround or forgotten scaffolding."
  (= (.-category f) "crutch-scaffolding"))

(df is-critical-finding? [(f AuditFinding)] -> Bool
  :d "Checks if an audit finding represents a critical violation requiring immediate rejection."
  (or (= (.-category f) "architectural-drift")
      (= (.-category f) "vacuous-verification")))

(df evaluate-audit-findings [(findings (List AuditFinding))] -> AuditVerdict
  :d "Aggregates audit findings, calculates crutch frequency, and derives overall verdict."
  (let [(total (list-length findings))]
    (if (= total 0)
      (AuditVerdict
        :passed true
        :verdict-tag "approve"
        :total-findings 0
        :crutch-count 0
        :findings (list))
      (let [(crutches (filter (fn [(f AuditFinding)] -> Bool (is-crutch-finding? f)) findings))
            (criticals (filter (fn [(f AuditFinding)] -> Bool (is-critical-finding? f)) findings))
            (crutch-len (list-length crutches))
            (crit-len (list-length criticals))
            (has-critical (> crit-len 0))
            (has-crutch (> crutch-len 0))
            (verdict-tag (if has-critical "reject" (if has-crutch "approve-with-amendments" "approve-with-amendments")))
            (is-passed (not has-critical))]
        (AuditVerdict
          :passed is-passed
          :verdict-tag verdict-tag
          :total-findings total
          :crutch-count crutch-len
          :findings findings)))))

(df is-meta-audit-adequate? [(report MetaAuditReport)] -> Bool
  :d "Validates that a primary audit satisfies minimum adequacy score and covers required categories."
  (and (.-is-adequate report)
       (and (>= (.-adequacy-score report) 80)
            (= (list-length (.-missing-gaps report)) 0))))

(df format-finding-asn [(f AuditFinding)] -> Str
  :d "Serializes a single AuditFinding into compact canonical ASN frame."
  (str "(:finding"
       " :cat :" (.-category f)
       " :file \"" (.-file-path f) "\""
       " :line " (string-from-int64 (.-line-num f))
       " :sym \"" (.-symbol f) "\""
       " :desc \"" (.-description f) "\""
       " :why \"" (.-intent-rationale f) "\""
       " :gate \"" (.-remediation-gate f) "\")"))

(df format-verdict-asn [(v AuditVerdict)] -> Str
  :d "Serializes an AuditVerdict into compact canonical ASN representation."
  (let [(finding-strs (map (fn [(f AuditFinding)] -> Str (format-finding-asn f)) (.-findings v)))
        (findings-body (string-join finding-strs " "))
        (pass-str (if (.-passed v) "true" "false"))]
    (str "(:verdict"
         " :passed " pass-str
         " :tag :" (.-verdict-tag v)
         " :total " (string-from-int64 (.-total-findings v))
         " :crutches " (string-from-int64 (.-crutch-count v))
         " :findings [" findings-body "])")))
