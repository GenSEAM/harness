(module asl-harness/context-priority
  :d "Dynamic context prioritization and token budget ranking engine"
  :x [ContextPriorityRecord
      score-context-chunk
      rank-context-chunks
      apply-token-budget
      filter-retained-chunks
      total-retained-tokens]
  :i [])

(dfs ContextPriorityRecord
  (:f chunk-id Str "Unique identifier of context chunk outline or diff")
  (:f kind Str "Category kind: ast-outline, task-memory, or recent-diff")
  (:f raw-tokens I64 "Uncompressed token weight of the chunk")
  (:f relevance F64 "Task relevance score normalized between 0.0 and 1.0")
  (:f priority-score F64 "Calculated priority score based on relevance and token density")
  (:f retained Bool "Flag indicating whether chunk fits within target token budget"))

(df score-context-chunk [(chunk-id Str) (kind Str) (tokens I64) (relevance F64)] -> ContextPriorityRecord
  :d "Calculates dynamic priority score for context chunk based on relevance and token footprint"
  (let [(f-tok (int64-to-float64 tokens))
        (score (/ (* relevance 1000.0) (+ f-tok 10.0)))]
    (ContextPriorityRecord
      :chunk-id chunk-id
      :kind kind
      :raw-tokens tokens
      :relevance relevance
      :priority-score score
      :retained false)))

(df insert-chunk [(item ContextPriorityRecord) (sorted (List ContextPriorityRecord))] -> (List ContextPriorityRecord)
  :d "Inserts a context chunk into sorted list in descending priority-score order"
  (if (list-empty? sorted)
      (list item)
      (let [(default-chunk (ContextPriorityRecord :chunk-id "" :kind "" :raw-tokens 0 :relevance 0.0 :priority-score 0.0 :retained false))
            (head-c (option-or (list-head sorted) default-chunk))
            (tail-c (option-or (list-tail sorted) (list)))]
        (if (> (.-priority-score item) (.-priority-score head-c))
            (list-cons item sorted)
            (list-cons head-c (insert-chunk item tail-c))))))

(df sort-chunks-loop [(unsorted (List ContextPriorityRecord)) (sorted (List ContextPriorityRecord))] -> (List ContextPriorityRecord)
  :d "Tail-recursive helper sorting chunks in descending priority order"
  (if (list-empty? unsorted)
      sorted
      (let [(default-chunk (ContextPriorityRecord :chunk-id "" :kind "" :raw-tokens 0 :relevance 0.0 :priority-score 0.0 :retained false))
            (head-c (option-or (list-head unsorted) default-chunk))
            (tail-c (option-or (list-tail unsorted) (list)))]
        (sort-chunks-loop tail-c (insert-chunk head-c sorted)))))

(df rank-context-chunks [(chunks (List ContextPriorityRecord))] -> (List ContextPriorityRecord)
  :d "Orders context priority records in descending priority score order"
  (sort-chunks-loop chunks (list)))

(df apply-budget-loop [(chunks (List ContextPriorityRecord)) (budget I64) (accumulated I64) (acc (List ContextPriorityRecord))] -> (List ContextPriorityRecord)
  :d "Accumulates chunks within budget marking retained status"
  (if (list-empty? chunks)
      acc
      (let [(default-chunk (ContextPriorityRecord :chunk-id "" :kind "" :raw-tokens 0 :relevance 0.0 :priority-score 0.0 :retained false))
            (head-c (option-or (list-head chunks) default-chunk))
            (tail-c (option-or (list-tail chunks) (list)))
            (tok (.-raw-tokens head-c))]
        (if (<= (+ accumulated tok) budget)
            (let [(updated (ContextPriorityRecord
                             :chunk-id (.-chunk-id head-c)
                             :kind (.-kind head-c)
                             :raw-tokens tok
                             :relevance (.-relevance head-c)
                             :priority-score (.-priority-score head-c)
                             :retained true))]
              (apply-budget-loop tail-c budget (+ accumulated tok) (list-append acc (list updated))))
            (let [(updated (ContextPriorityRecord
                             :chunk-id (.-chunk-id head-c)
                             :kind (.-kind head-c)
                             :raw-tokens tok
                             :relevance (.-relevance head-c)
                             :priority-score (.-priority-score head-c)
                             :retained false))]
              (apply-budget-loop tail-c budget accumulated (list-append acc (list updated))))))))

(df apply-token-budget [(ranked (List ContextPriorityRecord)) (budget-tokens I64)] -> (List ContextPriorityRecord)
  :d "Applies token budget ceiling marking affordable chunks retained and trailing chunks evicted"
  (apply-budget-loop ranked budget-tokens 0 (list)))

(df filter-retained-chunks [(prioritized (List ContextPriorityRecord))] -> (List ContextPriorityRecord)
  :d "Filters context priority records to return only chunks marked retained"
  (filter (fn [(c ContextPriorityRecord)] -> Bool (.-retained c)) prioritized))

(df sum-retained-tokens-loop [(chunks (List ContextPriorityRecord)) (sum I64)] -> I64
  :d "Sums raw-tokens for retained chunks"
  (if (list-empty? chunks)
      sum
      (let [(default-chunk (ContextPriorityRecord :chunk-id "" :kind "" :raw-tokens 0 :relevance 0.0 :priority-score 0.0 :retained false))
            (head-c (option-or (list-head chunks) default-chunk))
            (tail-c (option-or (list-tail chunks) (list)))
            (next-sum (if (.-retained head-c) (+ sum (.-raw-tokens head-c)) sum))]
        (sum-retained-tokens-loop tail-c next-sum))))

(df total-retained-tokens [(chunks (List ContextPriorityRecord))] -> I64
  :d "Computes aggregate token weight across all retained context chunks"
  (sum-retained-tokens-loop chunks 0))
