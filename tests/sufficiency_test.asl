(module asl-harness/sufficiency-test
  :d "Unit tests for task sufficiency evaluation and completion verification."
  :x [test-sufficiency-complete
      test-sufficiency-partial
      run-tests]
  :i [(sufficiency :a s)])

(df test-sufficiency-complete [] -> Bool
  (let [(tasks (list "task1" "task2"))
        (done (list "task1" "task2"))
        (rep (s/evaluate-sufficiency tasks done))]
    (do
      (assert (= (.-completed-count rep) 2))
      (assert (s/is-sufficient? rep))
      (assert (not (= (.-completed-count rep) 0)))
      true)))

(df test-sufficiency-partial [] -> Bool
  (let [(tasks (list "task1" "task2"))
        (done (list "task1"))
        (rep (s/evaluate-sufficiency tasks done))]
    (do
      (assert (= (.-completed-count rep) 1))
      (assert (not (s/is-sufficient? rep)))
      (assert (> (.-completed-count rep) 0))
      true)))

(df run-tests [] -> Bool
  (do
    (assert (test-sufficiency-complete))
    (assert (test-sufficiency-partial))))
