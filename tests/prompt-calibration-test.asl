(module asl-harness/prompt-calibration-test
  :d "Unit test verification for prompt calibration and anti-pattern distractor benchmark."
  :x [test-micro-affirmative-pass
      test-anti-pattern-contamination
      test-full-calibration-matrix
      test-format-calibration-asn
      run-calibration-tests]
  :i [(prompt-calibration :a pc)])

(df test-micro-affirmative-pass [] -> Bool
  :d "Verifies that Pure Affirmative Schema achieves >90% pass rate on Qwen 0.5B."
  (let [(score (pc/evaluate-strategy (pc/scale-micro) (pc/strat-affirmative)))]
    (and (>= (.-schema-pass-rate score) 90.0)
         (and (<= (.-contamination-rate score) 5.0)
              (.-recommended score)))))

(df test-anti-pattern-contamination [] -> Bool
  :d "Verifies that anti-patterns cause high contamination rate (>30%) on Qwen 0.5B."
  (let [(score (pc/evaluate-strategy (pc/scale-micro) (pc/strat-contrastive)))]
    (and (> (.-contamination-rate score) 30.0)
         (not (.-recommended score)))))

(df test-full-calibration-matrix [] -> Bool
  :d "Verifies full calibration factorial matrix construction."
  (let [(m (pc/run-full-calibration))]
    (and (= (list-length (.-scores m)) 12)
         (= (.-optimal-strategy-micro m) "Pure Affirmative Schema"))))

(df test-format-calibration-asn [] -> Bool
  :d "Verifies serialization to canonical ASN format."
  (let [(m (pc/run-full-calibration))
        (asn-out (pc/format-calibration-asn m))]
    (and (string-starts-with? asn-out "(:prompt-calibration")
         (string-contains? asn-out ":optimal-micro"))))

(df run-calibration-tests [] -> Bool
  :d "Runs all prompt calibration tests."
  (and (test-micro-affirmative-pass)
       (and (test-anti-pattern-contamination)
            (and (test-full-calibration-matrix)
                 (test-format-calibration-asn)))))
