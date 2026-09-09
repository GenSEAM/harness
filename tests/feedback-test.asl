(module asl-harness/feedback-test
  :d "Unit tests for portable feedback and interaction module."
  :x [test-feedback-init
      test-feedback-add-completed
      test-feedback-add-gap
      test-feedback-formatting
      test-feedback-status-and-receipts
      run-tests]
  :i [(feedback :a fb)])

(df test-feedback-init [] -> Bool
  :d "Verifies clean initialization of task feedback record."
  (let [(f (fb/new-task-feedback "TASK-200"))]
    (do
      (assert (= (.-task-id f) "TASK-200"))
      (assert (= (list-length (.-completed-work f)) 0))
      (assert (= (list-length (.-unverified-gaps f)) 0))
      (assert (not (string-empty? (.-task-id f))))
      true)))

(df test-feedback-add-completed [] -> Bool
  :d "Verifies appending completed work items to feedback record."
  (let [(f0 (fb/new-task-feedback "TASK-201"))
        (f1 (fb/feedback-add-completed f0 "Fixed off-by-one error in parser"))
        (f2 (fb/feedback-add-completed f1 "Added unit test coverage"))]
    (do
      (assert (= (list-length (.-completed-work f2)) 2))
      (assert (string-contains? (fb/format-feedback-summary f2) "Fixed off-by-one"))
      (assert (not (= (list-length (.-completed-work f2)) 0)))
      true)))

(df test-feedback-add-gap [] -> Bool
  :d "Verifies appending transparent disclosures to feedback record."
  (let [(f0 (fb/new-task-feedback "TASK-202"))
        (f1 (fb/feedback-add-gap f0 "Optional IPv6 support omitted per YAGNI"))
        (summary (fb/format-feedback-summary f1))
        (disc (fb/disclose-observed-gaps (.-unverified-gaps f1)))]
    (do
      (assert (= (list-length (.-unverified-gaps f1)) 1))
      (assert (string-contains? summary "Optional IPv6 support"))
      (assert (string-contains? disc "Transparent Disclosures"))
      (assert (not (= (list-length (.-unverified-gaps f1)) 0)))
      true)))

(df test-feedback-formatting [] -> Bool
  :d "Verifies empty disclosures render clean message."
  (let [(disc (fb/disclose-observed-gaps (list)))]
    (do
      (assert (string-contains? disc "No unverified gaps"))
      (assert (not (string-contains? disc "Transparent Disclosures:")))
      true)))

(df test-feedback-status-and-receipts [] -> Bool
  :d "Verifies FeedbackStatus variants, ExecutionReceipt recording, and status transitions."
  (let [(f0 (fb/new-task-feedback "TASK-203"))
        (r1 (fb/make-execution-receipt "asl test harness/tests/feedback-test.asl" 0 "PASS"))
        (f1 (fb/feedback-add-receipt f0 r1))
        (r2 (fb/make-execution-receipt "asl gate" 1 "FAIL: invariant violation"))
        (f2 (fb/feedback-add-receipt f1 r2))
        (f3 (fb/feedback-with-status f0 (fb/partially-verified)))]
    (do
      (assert (= (list-length (.-receipts f2)) 2))
      (assert (.-passed r1))
      (assert (not (.-passed r2)))
      (assert (= (.-status f2) (fb/blocked)))
      (assert (= (.-status f3) (fb/partially-verified)))
      true)))

(df run-tests [] -> Bool
  :d "Executes full feedback test suite."
  (do
    (assert (test-feedback-init))
    (assert (test-feedback-add-completed))
    (assert (test-feedback-add-gap))
    (assert (test-feedback-formatting))
    (assert (test-feedback-status-and-receipts))
    true))
