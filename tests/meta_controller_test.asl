(module asl-harness/meta-controller-test
  :d "Unit verification test suite for Adaptive Harness Meta-Controller."
  :x [test-task-entropy-formula
      test-task-entropy-boundaries
      test-tier-routing-boundaries
      test-profile-alias
      run-tests]
  :i [(meta-controller :a mc)])

(df test-task-entropy-formula [] -> Bool
  :d "Verifies task entropy formula evaluation on zero and standard inputs."
  (let [(e-zero (mc/compute-task-entropy 0 0.0 0.0 0.0))
        (e-single (mc/compute-task-entropy 1 0.1 0.2 0.1))
        (e-large (mc/compute-task-entropy 10 1.0 1.0 1.0))]
    (do
      (assert (= e-zero 0.0))
      (assert (>= e-single 0.99))
      (assert (<= e-single 1.01))
      (assert (= e-large 9.0))
      true)))

(df test-task-entropy-boundaries [] -> Bool
  :d "Verifies boundary values 1.49, 1.50, 3.99, and 4.00."
  (let [(tier-below-15 (mc/select-execution-tier 1.49))
        (tier-exact-15 (mc/select-execution-tier 1.50))
        (tier-below-40 (mc/select-execution-tier 3.99))
        (tier-exact-40 (mc/select-execution-tier 4.00))]
    (do
      (assert (= tier-below-15 "fast-path"))
      (assert (= tier-exact-15 "balanced"))
      (assert (= tier-below-40 "balanced"))
      (assert (= tier-exact-40 "deep-reflex"))
      true)))

(df test-tier-routing-boundaries [] -> Bool
  :d "Verifies tier routing across the full spectrum."
  (let [(t-zero (mc/select-execution-tier 0.0))
        (t-low (mc/select-execution-tier 1.2))
        (t-mid (mc/select-execution-tier 2.5))
        (t-high (mc/select-execution-tier 5.5))]
    (do
      (assert (= t-zero "fast-path"))
      (assert (= t-low "fast-path"))
      (assert (= t-mid "balanced"))
      (assert (= t-high "deep-reflex"))
      true)))

(df test-profile-alias [] -> Bool
  :d "Verifies select-execution-profile acts as canonical alias."
  (let [(p-fast (mc/select-execution-profile 1.0))
        (p-bal (mc/select-execution-profile 2.0))
        (p-deep (mc/select-execution-profile 4.5))]
    (do
      (assert (= p-fast "fast-path"))
      (assert (= p-bal "balanced"))
      (assert (= p-deep "deep-reflex"))
      (assert (= (mc/select-execution-profile 1.2) (mc/select-execution-tier 1.2)))
      (assert (= (mc/select-execution-profile 2.5) (mc/select-execution-tier 2.5)))
      (assert (= (mc/select-execution-profile 6.0) (mc/select-execution-tier 6.0)))
      true)))

(df run-tests [] -> Bool
  :d "Executes meta-controller test suite under strict falsification."
  (do
    (assert (test-task-entropy-formula))
    (assert (test-task-entropy-boundaries))
    (assert (test-tier-routing-boundaries))
    (assert (test-profile-alias))
    true))
