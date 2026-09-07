(module asl-harness/budget-test
  :d "Unit tests for agent budget tracking and limit checks."
  :x [test-budget-tracking
      test-budget-limits
      run-tests]
  :i [(budget :a b)])

(df test-budget-tracking [] -> Bool
  (let [(bt0 (b/make-budget 1000 10 5000))
        (bt1 (b/record-turn bt0 250 120))]
    (and (= (.-used-tokens bt1) 250)
         (and (= (.-used-turns bt1) 1)
              (not (b/is-budget-exceeded? bt1))))))

(df test-budget-limits [] -> Bool
  (let [(bt0 (b/make-budget 100 2 1000))
        (bt1 (b/record-turn bt0 150 100))]
    (b/is-budget-exceeded? bt1)))

(df run-tests [] -> Bool
  (do
    (assert (test-budget-tracking))
    (assert (test-budget-limits))))
