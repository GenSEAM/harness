(module asl-harness/circuit-breaker-test
  :d "Unit tests for anti-thrash circuit breaker and two-tier operator escalation."
  :x [test-circuit-breaker-lifecycle
      test-escalation-tiers
      run-tests]
  :i [(circuit-breaker :a cb)])

(df test-circuit-breaker-lifecycle [] -> Bool
  (let [(c0 (cb/make-circuit-breaker 3))]
    (assert (not (cb/is-tripped? c0)) "New breaker must be closed")
    (let [(c1 (cb/record-failure c0 "Error 1"))]
      (assert (not (cb/is-tripped? c1)) "1 failure must not trip threshold 3")
      (let [(c2 (cb/record-failure c1 "Error 2"))]
        (assert (not (cb/is-tripped? c2)) "2 failures must not trip threshold 3")
        (let [(c3 (cb/record-failure c2 "Error 3"))]
          (assert (cb/is-tripped? c3) "3 failures must trip circuit")
          (assert (= (cb/resolve-escalation c3) "approver") "Tier 1 must escalate to approver")
          (let [(c-clean (cb/record-success c3))]
            (assert (not (cb/is-tripped? c-clean)) "Success must reset circuit")
            true))))))

(df test-escalation-tiers [] -> Bool
  (let [(c0 (cb/make-circuit-breaker 2))
        (c1 (cb/record-failure c0 "Err 1"))
        (c2 (cb/record-failure c1 "Err 2"))
        (c3 (cb/record-failure c2 "Err 3"))
        (c4 (cb/record-failure c3 "Err 4"))]
    (assert (cb/is-tripped? c2) "Breaker tripped at count 2")
    (assert (= (cb/resolve-escalation c2) "approver") "Count 2 escalates to approver")
    (assert (= (cb/resolve-escalation c4) "human-operator") "Count 4 escalates to human operator")
    true))

(df run-tests [] -> Bool
  (and (test-circuit-breaker-lifecycle)
       (test-escalation-tiers)))
