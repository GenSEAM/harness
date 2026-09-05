(module asl-harness/feedback
  :d "Portable Feedback and Interaction Module: structured disclosure of completed work, tradeoffs, and gaps across agent harnesses."
  :x [TaskFeedback new-task-feedback feedback-add-completed feedback-add-gap format-feedback-summary disclose-observed-gaps]
  :i [])

(dfs TaskFeedback
  (:f task-id Str "Assigned engineering task ID")
  (:f completed-work (List Str) "List of verified completed items")
  (:f observed-tradeoffs (List Str) "List of architectural tradeoffs and decisions")
  (:f unverified-gaps (List Str) "List of unverified gaps or transparent disclosures")
  (:f user-prompt Str "Original user instructions or requirements"))

(df new-task-feedback [(task-id Str)] -> TaskFeedback
  :d "Constructs an initial empty task feedback record."
  (TaskFeedback
    :task-id task-id
    :completed-work (list)
    :observed-tradeoffs (list)
    :unverified-gaps (list)
    :user-prompt ""))

(df feedback-add-completed [(fb TaskFeedback) (item Str)] -> TaskFeedback
  :d "Appends a verified completed work item to feedback record."
  (TaskFeedback
    :task-id (.-task-id fb)
    :completed-work (list-concat (.-completed-work fb) (list item))
    :observed-tradeoffs (.-observed-tradeoffs fb)
    :unverified-gaps (.-unverified-gaps fb)
    :user-prompt (.-user-prompt fb)))

(df feedback-add-gap [(fb TaskFeedback) (gap Str)] -> TaskFeedback
  :d "Appends an observed gap or transparent disclosure to feedback record."
  (TaskFeedback
    :task-id (.-task-id fb)
    :completed-work (.-completed-work fb)
    :observed-tradeoffs (.-observed-tradeoffs fb)
    :unverified-gaps (list-concat (.-unverified-gaps fb) (list gap))
    :user-prompt (.-user-prompt fb)))

(df format-feedback-summary [(fb TaskFeedback)] -> Str
  :d "Renders human-readable summary of completed work, tradeoffs, and transparent gap disclosures."
  (let [(done-count (list-length (.-completed-work fb)))
        (gap-count (list-length (.-unverified-gaps fb)))
        (done-str (string-join "\n  - " (.-completed-work fb)))
        (gap-str (if (= gap-count 0)
                     "None (all requirements verified)"
                     (string-join "\n  - " (.-unverified-gaps fb))))]
    (str "Task Feedback [" (.-task-id fb) "]:\n"
         "Completed (" (string-from-int64 done-count) "):\n  - " done-str "\n"
         "Disclosed Gaps (" (string-from-int64 gap-count) "):\n  - " gap-str)))

(df disclose-observed-gaps [(gaps (List Str))] -> Str
  :d "Formats a list of gaps into a transparent disclosure block for user feedback."
  (if (list-empty? gaps)
      "✓ No unverified gaps or defects observed."
      (str "⚠ Transparent Disclosures:\n  - " (string-join "\n  - " gaps))))
