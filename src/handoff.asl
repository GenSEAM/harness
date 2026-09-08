(module asl-harness/handoff
  :d "Single-token property economic handoff briefs and stateless clean-context audit envelopes"
  :x [HandoffBrief
      CleanAuditEnvelope
      make-handoff-brief
      format-brief-asn
      make-clean-audit
      format-audit-asn]
  :i [])

(dfs HandoffBrief
  (:f task-id Str "Task identifier")
  (:f lane Str "Trajectory lane e.g. alpha or beta")
  (:f role Str "Epistemic role identifier e.g. worker-conservative")
  (:f temp Float "Sampling temperature")
  (:f task-spec Str "Compact task requirement")
  (:f budget Int64 "Maximum token budget"))

(dfs CleanAuditEnvelope
  (:f task-id Str "Target task identifier")
  (:f contract-cmd Str "Physical verification command")
  (:f candidate-lane Str "Lane under review")
  (:f exit-code Int64 "Process return code")
  (:f stdout Str "Command standard output digest")
  (:f stderr Str "Command standard error digest")
  (:f diff-summary Str "Summary of mutated files"))

(df make-handoff-brief [(task-id Str) (lane Str) (role Str) (temp Float) (task-spec Str) (budget Int64)] -> HandoffBrief
  :d "Instantiates typed handoff brief"
  (HandoffBrief
    :task-id task-id
    :lane lane
    :role role
    :temp temp
    :task-spec task-spec
    :budget budget))

(df format-brief-asn [(brief HandoffBrief)] -> Str
  :d "Formats compact ASN handoff envelope strictly bounding tokens using single-token keys"
  (str "(:brief :task \""
       (.-task-id brief)
       "\" :lane \""
       (.-lane brief)
       "\" :role \""
       (.-role brief)
       "\" :temp "
       (string-from-float64 (.-temp brief))
       " :spec \""
       (.-task-spec brief)
       "\" :budget "
       (string-from-int64 (.-budget brief))
       ")"))

(df make-clean-audit [(task-id Str) (contract-cmd Str) (candidate-lane Str) (exit-code Int64) (stdout Str) (stderr Str) (diff-summary Str)] -> CleanAuditEnvelope
  :d "Instantiates clean audit envelope stripping conversational history"
  (CleanAuditEnvelope
    :task-id task-id
    :contract-cmd contract-cmd
    :candidate-lane candidate-lane
    :exit-code exit-code
    :stdout stdout
    :stderr stderr
    :diff-summary diff-summary))

(df format-audit-asn [(audit CleanAuditEnvelope)] -> Str
  :d "Formats stateless clean-context audit envelope using single-token keys"
  (str "(:audit :task \""
       (.-task-id audit)
       "\" :lane \""
       (.-candidate-lane audit)
       "\" :spec \""
       (.-contract-cmd audit)
       "\" :receipt \"exit="
       (string-from-int64 (.-exit-code audit))
       " out="
       (.-stdout audit)
       " err="
       (.-stderr audit)
       "\" :diff \""
       (.-diff-summary audit)
       "\" :pass "
       (if (= (.-exit-code audit) 0) "true" "false")
       " :fail "
       (if (= (.-exit-code audit) 0) "false" "true")
       ")"))
