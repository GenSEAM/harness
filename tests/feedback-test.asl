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
    (and (= (.-task-id f) "TASK-200")
         (and (= (list-length (.-completed-work f)) 0)
              (= (list-length (.-unverified-gaps f)) 0)))))

(df test-feedback-add-completed [] -> Bool
  :d "Verifies appending completed work items to feedback record."
  (let [(f0 (fb/new-task-feedback "TASK-201"))
        (f1 (fb/feedback-add-completed f0 "Fixed off-by-one error in parser"))
        (f2 (fb/feedback-add-completed f1 "Added unit test coverage"))]
    (and (= (list-length (.-completed-work f2)) 2)
         (string-contains? (fb/format-feedback-summary f2) "Fixed off-by-one"))))

(df test-feedback-add-gap [] -> Bool
  :d "Verifies appending transparent disclosures to feedback record."
  (let [(f0 (fb/new-task-feedback "TASK-202"))
        (f1 (fb/feedback-add-gap f0 "Optional IPv6 support omitted per YAGNI"))
        (summary (fb/format-feedback-summary f1))
        (disc (fb/disclose-observed-gaps (.-unverified-gaps f1)))]
    (and (= (list-length (.-unverified-gaps f1)) 1)
         (and (string-contains? summary "Optional IPv6 support")
              (string-contains? disc "Transparent Disclosures")))))

(df test-feedback-formatting [] -> Bool
  :d "Verifies empty disclosures render clean message."
  (let [(disc (fb/disclose-observed-gaps (list)))]
    (string-contains? disc "No unverified gaps")))

(df test-feedback-status-and-receipts [] -> Bool
  :d "Verifies FeedbackStatus variants, ExecutionReceipt recording, and status transitions."
  (let [(f0 (fb/new-task-feedback "TASK-203"))
        (r1 (fb/make-execution-receipt "asl test harness/tests/feedback-test.asl" 0 "PASS"))
        (f1 (fb/feedback-add-receipt f0 r1))
        (r2 (fb/make-execution-receipt "asl gate" 1 "FAIL: invariant violation"))
        (f2 (fb/feedback-add-receipt f1 r2))
        (f3 (fb/feedback-with-status f0 (fb/partially-verified)))]
    (and (= (list-length (.-receipts f2)) 2)
         (and (.-passed r1)
              (and (not (.-passed r2))
                   (and (= (.-status f2) (fb/blocked))
                        (= (.-status f3) (fb/partially-verified))))))))

(df run-tests [] -> Bool
  :d "Executes full feedback test suite."
  (do
    (assert (test-feedback-init))
    (assert (test-feedback-add-completed))
    (assert (test-feedback-add-gap))
    (assert (test-feedback-formatting))
    (assert (test-feedback-status-and-receipts))
    true))
