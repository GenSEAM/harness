(module asl-harness/sufficiency
  :d "Autonomous task sufficiency evaluation and completion verification."
  :x [SufficiencyState SufficiencyReport
      evaluate-sufficiency is-sufficient?]
  :i [])

(dfe SufficiencyState
  (:c suff-complete [] "All required criteria verified and complete")
  (:c suff-partial [] "Substantial portion complete but gaps remain")
  (:c suff-insufficient [] "Core criteria unfulfilled or failing"))

(dfs SufficiencyReport
  (:f target-count I64 "Total required target tasks")
  (:f completed-count I64 "Number of successfully verified tasks")
  (:f state SufficiencyState "Overall sufficiency classification")
  (:f summary Str "Human-readable sufficiency summary"))

(df evaluate-sufficiency [(targets (List Str)) (completed (List Str))] -> SufficiencyReport
  :d "Evaluates completion ratio and classifies sufficiency state."
  (let [(total (list-length targets))
        (done (list-length completed))
        (st (cond
              ((= total 0) (suff-complete))
              ((>= done total) (suff-complete))
              ((> done 0) (suff-partial))
              (true (suff-insufficient))))
        (msg (if (>= done total)
               "All acceptance criteria verified."
               "Gaps remaining in verification criteria."))]
    (SufficiencyReport
      :target-count total
      :completed-count done
      :state st
      :summary msg)))

(df is-sufficient? [(rep SufficiencyReport)] -> Bool
  :d "Returns true if the report indicates complete sufficiency."
  (mt (.-state rep)
    ((suff-complete) true)
    ((suff-partial) false)
    ((suff-insufficient) false)))
