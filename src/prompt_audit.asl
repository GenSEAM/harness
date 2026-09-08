(module asl-harness/prompt-audit
  :d "Canonical ASN prompt token budget auditor and validation utility."
  :x [PromptDef
      TokenMetric
      PromptAuditResult
      BudgetAuditReport
      audit-prompt-tokens
      estimate-tokens-simple
      validate-prompt-budget
      audit-registry-string
      audit-prompt-budgets]
  :i [])

(dfs PromptDef
  (:f id Str "Prompt identifier")
  (:f role Str "Target agent role")
  (:f budget-tokens I64 "Configured maximum token budget")
  (:f system Str "System instruction template")
  (:f template Str "User instruction template"))

(dfs TokenMetric
  (:f estimated-tokens I64 "Estimated token count of prompt")
  (:f budget-tokens I64 "Configured budget ceiling")
  (:f headroom I64 "Remaining token headroom (budget - estimated)")
  (:f over-budget Bool "True if estimated tokens exceed budget ceiling"))

(dfs PromptAuditResult
  (:f prompt-id Str "Audited prompt identifier")
  (:f metric TokenMetric "Computed token metrics")
  (:f status Str "Audit verdict status ('pass' or 'budget_exceeded')"))

(df estimate-tokens-simple [(text Str)] -> I64
  :d "Deterministic token count heuristic: max(1, length / 4), or 0 if empty."
  (let [(len (string-length text))]
    (if (<= len 0)
      0
      (let [(q (/ len 4))]
        (if (< q 1) 1 q)))))

(df audit-prompt-tokens [(prompt PromptDef)] -> (Result TokenMetric Str)
  :d "Computes token metrics against budget ceiling returning TokenMetric."
  (let [(sys-tok (estimate-tokens-simple (.-system prompt)))
        (tpl-tok (estimate-tokens-simple (.-template prompt)))
        (total-tok (+ sys-tok tpl-tok))
        (budget (.-budget-tokens prompt))
        (headroom (- budget total-tok))
        (over-budget (> total-tok budget))
        (metric (TokenMetric
                  :estimated-tokens total-tok
                  :budget-tokens budget
                  :headroom headroom
                  :over-budget over-budget))]
    (ok metric)))

(dfs BudgetAuditReport
  (:f prompt-id Str "Audited prompt identifier")
  (:f static-tokens I64 "Tokens consumed by static system prefix")
  (:f static-budget I64 "Configured static prefix budget ceiling")
  (:f static-headroom I64 "Remaining headroom for static prefix")
  (:f payload-tokens I64 "Tokens consumed by dynamic payload")
  (:f payload-budget I64 "Configured payload budget ceiling")
  (:f payload-headroom I64 "Remaining headroom for dynamic payload")
  (:f valid Bool "True if both static and dynamic budgets are respected")
  (:f error-code Str "Diagnostic error code e.g. STATIC_PREFIX_OVERFLOW or PAYLOAD_BUDGET_OVERFLOW"))

(df audit-prompt-budgets [(prompt-id Str) (system-str Str) (payload-str Str) (static-budget I64) (payload-budget I64)] -> BudgetAuditReport
  :d "Audits static system prefix and dynamic turn payload against decoupled budgets."
  (let [(s-tok (estimate-tokens-simple system-str))
        (p-tok (estimate-tokens-simple payload-str))
        (s-headroom (- static-budget s-tok))
        (p-headroom (- payload-budget p-tok))
        (s-overflow (< s-headroom 0))
        (p-overflow (< p-headroom 0))
        (err (if s-overflow
               "STATIC_PREFIX_OVERFLOW"
               (if p-overflow
                 "PAYLOAD_BUDGET_OVERFLOW"
                 "")))
        (is-valid (and (not s-overflow) (not p-overflow)))]
    (BudgetAuditReport
      :prompt-id prompt-id
      :static-tokens s-tok
      :static-budget static-budget
      :static-headroom s-headroom
      :payload-tokens p-tok
      :payload-budget payload-budget
      :payload-headroom p-headroom
      :valid is-valid
      :error-code err)))

(df validate-prompt-budget [(prompt PromptDef)] -> Bool
  :d "Validates whether prompt is within its configured token budget."
  (let [(res (audit-prompt-tokens prompt))]
    (mt res
      ((ok m) (not (.-over-budget m)))
      ((err _) false))))

(df extract-field-str [(block Str) (key Str)] -> Str
  :d "Extracts quoted string value for a given key from an ASN form block."
  (let [(needle (str key " \""))
        (idx-opt (string-index-of block needle))]
    (mt idx-opt
      ((some start-idx)
       (let [(val-start (+ start-idx (string-length needle)))
             (tail-str (option-or (string-slice block val-start (string-length block)) ""))
             (quote-opt (string-index-of tail-str "\""))]
         (mt quote-opt
           ((some end-idx)
            (option-or (string-slice tail-str 0 end-idx) ""))
           ((none) ""))))
      ((none) ""))))

(df extract-field-int [(block Str) (key Str)] -> I64
  :d "Extracts integer value for a given key from an ASN form block."
  (let [(needle (str key " "))
        (idx-opt (string-index-of block needle))]
    (mt idx-opt
      ((some start-idx)
       (let [(val-start (+ start-idx (string-length needle)))
             (tail-str (option-or (string-slice block val-start (string-length block)) ""))
             (chars (string-chars tail-str))
             (digits-str (fold (fn [(acc Str) (c Str)] -> Str
                                 (if (and (string-contains? "0123456789" c) (not (string-contains? acc " ")))
                                   (str acc c)
                                   (if (string-empty? acc)
                                     (if (or (= c " ") (or (= c "\n") (= c "\t"))) "" acc)
                                     (str acc " "))))
                               ""
                               chars))
             (clean-digits (option-or (list-head (string-split digits-str " ")) ""))]
         (option-or (string-to-int64 clean-digits) 0)))
      ((none) 0))))

(df audit-registry-string [(registry-content Str)] -> (Result (List PromptAuditResult) Str)
  :d "Audits prompt definitions parsed from an ASN prompt registry text."
  (let [(blocks (string-split registry-content "(:prompt"))
        (prompt-blocks (option-or (list-tail blocks) (list)))
        (results (fold (fn [(acc (List PromptAuditResult)) (blk Str)] -> (List PromptAuditResult)
                         (let [(id (extract-field-str blk ":id"))
                               (role (extract-field-str blk ":role"))
                               (budget (extract-field-int blk ":budget-tokens"))
                               (system (extract-field-str blk ":system"))
                               (template (extract-field-str blk ":template"))]
                           (if (string-empty? id)
                             acc
                             (let [(pdef (PromptDef
                                           :id id
                                           :role role
                                           :budget-tokens budget
                                           :system system
                                           :template template))
                                   (audit-res (audit-prompt-tokens pdef))]
                               (mt audit-res
                                 ((ok metric)
                                  (let [(status (if (.-over-budget metric) "budget_exceeded" "pass"))
                                        (res (PromptAuditResult :prompt-id id :metric metric :status status))]
                                    (list-append acc (list res))))
                                 ((err _) acc))))))
                       (list)
                       prompt-blocks))]
    (if (list-empty? results)
      (err "No prompt definitions found in registry")
      (ok results))))
