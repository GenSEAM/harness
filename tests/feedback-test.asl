(module asl-harness/feedback-test
  :d "Unit tests for portable feedback and interaction module."
  :x [test-feedback-init test-feedback-add-completed test-feedback-add-gap test-feedback-formatting run-tests]
  :i [(feedback :a fb)])

(df test-feedback-init [] -> Bool
  :d "Verifies clean initialization of task feedback record."
  (let [(f (fb/new-task-feedback "TASK-200"))]
    (and (= (.-task-id f) "TASK-200")
         (= (list-length (.-completed-work f)) 0)
         (= (list-length (.-unverified-gaps f)) 0))))

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
         (string-contains? summary "Optional IPv6 support")
         (string-contains? disc "Transparent Disclosures"))))

(df test-feedback-formatting [] -> Bool
  :d "Verifies empty disclosures render clean message."
  (let [(disc (fb/disclose-observed-gaps (list)))]
    (string-contains? disc "No unverified gaps")))

(df run-tests [] -> Bool
  :d "Executes full feedback test suite."
  (and (test-feedback-init)
       (and (test-feedback-add-completed)
            (and (test-feedback-add-gap)
                 (test-feedback-formatting)))))
