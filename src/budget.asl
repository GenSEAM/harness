(module asl-harness/budget
  :d "Turn and token budget tracking for autonomous agent execution."
  :x [BudgetLimits BudgetTracker
      make-budget record-turn is-budget-exceeded?]
  :i [])

(dfs BudgetLimits
  (:f max-tokens I64 "Maximum allowable token ceiling")
  (:f max-turns I64 "Maximum allowable execution turns")
  (:f max-ms I64 "Maximum execution timeout in milliseconds"))

(dfs BudgetTracker
  (:f used-tokens I64 "Total tokens consumed so far")
  (:f used-turns I64 "Total turns executed so far")
  (:f elapsed-ms I64 "Elapsed execution wall-clock time in milliseconds")
  (:f limits BudgetLimits "Configured budget limits"))

(df make-budget [(tokens I64) (turns I64) (ms I64)] -> BudgetTracker
  :d "Initializes a clean budget tracker with target ceilings."
  (BudgetTracker
    :used-tokens 0
    :used-turns 0
    :elapsed-ms 0
    :limits (BudgetLimits :max-tokens tokens :max-turns turns :max-ms ms)))

(df record-turn [(bt BudgetTracker) (tokens I64) (duration I64)] -> BudgetTracker
  :d "Records token and time consumption of an executed agent turn."
  (BudgetTracker
    :used-tokens (+ (.-used-tokens bt) tokens)
    :used-turns (+ (.-used-turns bt) 1)
    :elapsed-ms (+ (.-elapsed-ms bt) duration)
    :limits (.-limits bt)))

(df is-budget-exceeded? [(bt BudgetTracker)] -> Bool
  :d "Determines if any configured budget ceiling has been surpassed."
  (let [(lim (.-limits bt))]
    (or (> (.-used-tokens bt) (.-max-tokens lim))
        (or (> (.-used-turns bt) (.-max-turns lim))
            (> (.-elapsed-ms bt) (.-max-ms lim))))))
