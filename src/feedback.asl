(module asl-harness/feedback
  :d "Portable Feedback and Interaction Module: structured disclosure of completed work, tradeoffs, and gaps across agent harnesses."
  :x [FeedbackStatus ExecutionReceipt TaskFeedback
      new-task-feedback make-execution-receipt feedback-with-status feedback-add-receipt
      feedback-add-completed feedback-add-gap format-feedback-summary disclose-observed-gaps]
  :i [])

(dfe FeedbackStatus
  (:c verified           [] "All requirements and verification gates verified")
  (:c partially-verified [] "Core requirements verified but non-blocking gaps remain")
  (:c blocked            [] "Execution blocked by gate failure or invariant violation"))

(dfs ExecutionReceipt
  (:f command Str "Executed shell or RPC verification command")
  (:f exit-code I64 "Process exit code (0 for success)")
  (:f stdout-tail Str "Diagnostic trailing stdout or receipt summary")
  (:f passed Bool "True if exit-code is 0"))

(df make-execution-receipt [(command Str) (exit-code I64) (stdout-tail Str)] -> ExecutionReceipt
  :d "Constructs an execution receipt recording command outcome."
  (ExecutionReceipt
    :command command
    :exit-code exit-code
    :stdout-tail stdout-tail
    :passed (= exit-code 0)))

(dfs TaskFeedback
  (:f task-id Str "Assigned engineering task ID")
  (:f status FeedbackStatus "Execution verification status")
  (:f receipts (List ExecutionReceipt) "List of verified execution receipts")
  (:f completed-work (List Str) "List of verified completed items")
  (:f observed-tradeoffs (List Str) "List of architectural tradeoffs and decisions")
  (:f unverified-gaps (List Str) "List of unverified gaps or transparent disclosures")
  (:f user-prompt Str "Original user instructions or requirements"))

(df new-task-feedback [(task-id Str)] -> TaskFeedback
  :d "Constructs an initial empty task feedback record."
  (TaskFeedback
    :task-id task-id
    :status (verified)
    :receipts (list)
    :completed-work (list)
    :observed-tradeoffs (list)
    :unverified-gaps (list)
    :user-prompt ""))

(df feedback-with-status [(fb TaskFeedback) (status FeedbackStatus)] -> TaskFeedback
  :d "Updates the verification status of a task feedback record."
  (TaskFeedback
    :task-id (.-task-id fb)
    :status status
    :receipts (.-receipts fb)
    :completed-work (.-completed-work fb)
    :observed-tradeoffs (.-observed-tradeoffs fb)
    :unverified-gaps (.-unverified-gaps fb)
    :user-prompt (.-user-prompt fb)))

(df feedback-add-receipt [(fb TaskFeedback) (receipt ExecutionReceipt)] -> TaskFeedback
  :d "Appends an execution receipt, updating status to blocked if command failed."
  (let [(new-status (if (.-passed receipt) (.-status fb) (blocked)))]
    (TaskFeedback
      :task-id (.-task-id fb)
      :status new-status
      :receipts (list-concat (.-receipts fb) (list receipt))
      :completed-work (.-completed-work fb)
      :observed-tradeoffs (.-observed-tradeoffs fb)
      :unverified-gaps (.-unverified-gaps fb)
      :user-prompt (.-user-prompt fb))))

(df feedback-add-completed [(fb TaskFeedback) (item Str)] -> TaskFeedback
  :d "Appends a verified completed work item to feedback record."
  (TaskFeedback
    :task-id (.-task-id fb)
    :status (.-status fb)
    :receipts (.-receipts fb)
    :completed-work (list-concat (.-completed-work fb) (list item))
    :observed-tradeoffs (.-observed-tradeoffs fb)
    :unverified-gaps (.-unverified-gaps fb)
    :user-prompt (.-user-prompt fb)))

(df feedback-add-gap [(fb TaskFeedback) (gap Str)] -> TaskFeedback
  :d "Appends an observed gap or transparent disclosure to feedback record."
  (TaskFeedback
    :task-id (.-task-id fb)
    :status (.-status fb)
    :receipts (.-receipts fb)
    :completed-work (.-completed-work fb)
    :observed-tradeoffs (.-observed-tradeoffs fb)
    :unverified-gaps (list-concat (.-unverified-gaps fb) (list gap))
    :user-prompt (.-user-prompt fb)))

(df format-feedback-summary [(fb TaskFeedback)] -> Str
  :d "Renders human-readable summary of completed work, tradeoffs, and transparent gap disclosures."
  (let [(done-count (list-length (.-completed-work fb)))
        (receipt-count (list-length (.-receipts fb)))
        (gap-count (list-length (.-unverified-gaps fb)))
        (done-str (string-join (.-completed-work fb) "\n  - "))
        (gap-str (if (= gap-count 0)
                     "None (all requirements verified)"
                     (string-join (.-unverified-gaps fb) "\n  - ")))]
    (str "Task Feedback [" (.-task-id fb) "]:\n"
         "Receipts (" (string-from-int64 receipt-count) ")\n"
         "Completed (" (string-from-int64 done-count) "):\n  - " done-str "\n"
         "Disclosed Gaps (" (string-from-int64 gap-count) "):\n  - " gap-str)))

(df disclose-observed-gaps [(gaps (List Str))] -> Str
  :d "Formats a list of gaps into a transparent disclosure block for user feedback."
  (if (list-empty? gaps)
      "✓ No unverified gaps or defects observed."
      (str "⚠ Transparent Disclosures:\n  - " (string-join gaps "\n  - "))))
