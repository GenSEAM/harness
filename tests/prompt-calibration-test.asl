(module asl-harness/prompt-calibration-test
  :d "Unit test verification for prompt calibration and anti-pattern distractor benchmark."
  :x [test-micro-affirmative-pass
      test-anti-pattern-contamination
      test-full-calibration-matrix
      test-format-calibration-asn
      run-calibration-tests
      run-tests]
  :i [(prompt-calibration :a pc)])

(df test-micro-affirmative-pass [] -> Bool
  :d "Verifies that Pure Affirmative Schema achieves >90% pass rate on Qwen 0.5B."
  (let [(score (pc/evaluate-strategy (pc/scale-micro) (pc/strat-affirmative)))]
    (assert (>= (.-schema-pass-rate score) 90.0) "schema pass rate >= 90")
    (assert (<= (.-contamination-rate score) 5.0) "contamination rate <= 5")
    (assert (.-recommended score) "is recommended")
    true))

(df test-anti-pattern-contamination [] -> Bool
  :d "Verifies that anti-patterns cause high contamination rate (>30%) on Qwen 0.5B."
  (let [(score (pc/evaluate-strategy (pc/scale-micro) (pc/strat-contrastive)))]
    (assert (> (.-contamination-rate score) 30.0) "contamination rate > 30")
    (assert (not (.-recommended score)) "not recommended")
    true))

(df test-full-calibration-matrix [] -> Bool
  :d "Verifies full calibration factorial matrix construction."
  (let [(m (pc/run-full-calibration))]
    (assert (= (list-length (.-scores m)) 12) "scores length is 12")
    (assert (= (.-optimal-strategy-micro m) "Pure Affirmative Schema") "optimal strategy matches")
    true))

(df test-format-calibration-asn [] -> Bool
  :d "Verifies serialization to canonical ASN format."
  (let [(m (pc/run-full-calibration))
        (asn-out (pc/format-calibration-asn m))]
    (assert (string-starts-with? asn-out "(:prompt-calibration") "starts with :prompt-calibration")
    (assert (string-contains? asn-out ":optimal-micro") "contains :optimal-micro")
    true))

(df run-calibration-tests [] -> Bool
  :d "Runs all prompt calibration tests."
  (do
    (test-micro-affirmative-pass)
    (test-anti-pattern-contamination)
    (test-full-calibration-matrix)
    (test-format-calibration-asn)
    true))

(df run-tests [] -> Bool
  :d "Alias for run-calibration-tests"
  (run-calibration-tests))
