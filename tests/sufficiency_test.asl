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
    (and (= (.-completed-count rep) 2)
         (s/is-sufficient? rep))))

(df test-sufficiency-partial [] -> Bool
  (let [(tasks (list "task1" "task2"))
        (done (list "task1"))
        (rep (s/evaluate-sufficiency tasks done))]
    (and (= (.-completed-count rep) 1)
         (not (s/is-sufficient? rep)))))

(df run-tests [] -> Bool
  (do
    (assert (test-sufficiency-complete))
    (assert (test-sufficiency-partial))))
