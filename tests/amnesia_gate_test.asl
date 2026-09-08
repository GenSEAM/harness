(module asl-harness/amnesia-gate-test
  :d "Unit verification test suite for dynamic test harness suite runner and amnesia pipeline gate."
  :x [test-parse-harness-suite-structure
      test-suite-testcase-metadata-notation
      test-run-harness-suite-evaluator
      test-emulate-context-overflow
      test-intercept-amnesia-trigger
      test-verify-facts-retained-success-and-failure
      run-tests]
  :i [(suite_runner :a sr) (amnesia_gate :a ag)])

(df test-parse-harness-suite-structure [] -> Bool
  :d "Verifies dynamic S-expression harness suite parsing and structure extraction."
  (let [(form-str "(harness-suite amnesia-pipeline-gate :target agent-core :tests ((test :id tc_overflow_compression :input-tokens 4500 :threshold 3000 :notation cs-expr :asserts ((assert-compact-memory-emitted) (assert-max-tokens-below 1500) (assert-facts-retained (:hash-algo \"argon2id\"))))))")
        (suite (sr/parse-harness-suite (list form-str)))
        (empty-suite (sr/parse-harness-suite (list "")))]
    (do
      (assert (not (string-empty? (.-name suite))) "Suite name must not be empty")
      (assert (= (.-name suite) "amnesia-pipeline-gate") "Suite name must match declared symbol")
      (assert (= (.-target suite) "agent-core") "Suite target must match declared target package")
      (assert (= (list-length (.-tests suite)) 1) "Suite must contain exactly 1 parsed testcase")
      (assert (= (list-length (.-tests empty-suite)) 0) "Empty suite form must yield 0 testcases")
      true)))

(df test-suite-testcase-metadata-notation [] -> Bool
  :d "Verifies testcase metadata tags and target serialization notation keyword parsing."
  (let [(form-str "(harness-suite amnesia-pipeline-gate :target agent-core :tests ((test :id tc_overflow_compression :input-tokens 4500 :threshold 3000 :notation cs-expr :asserts ((assert-compact-memory-emitted) (assert-max-tokens-below 1500) (assert-facts-retained (:hash-algo \"argon2id\"))))))")
        (suite (sr/parse-harness-suite (list form-str)))
        (tests (.-tests suite))
        (t (option-or (list-head tests) (sr/SuiteTest :id "" :input-tokens 0 :threshold 0 :notation "" :asserts (list))))
        (alt-test (sr/parse-suite-test (list "(test :id tc_nd_asn :input-tokens 2000 :threshold 1000 :notation nd-asn :asserts ())")))]
    (do
      (assert (= (.-id t) "tc_overflow_compression") "Test id must match declared identifier")
      (assert (= (.-input-tokens t) 4500) "Input tokens must match parsed 4500")
      (assert (= (.-threshold t) 3000) "Threshold must match parsed 3000")
      (assert (= (.-notation t) "cs-expr") "Notation must match concise S-expression tag cs-expr")
      (assert (= (.-notation alt-test) "nd-asn") "Notation must match newline-delimited ASN tag nd-asn")
      true)))

(df test-run-harness-suite-evaluator [] -> Bool
  :d "Verifies end-to-end suite runner assertion evaluation and outcome aggregation."
  (let [(form-str "(harness-suite amnesia-pipeline-gate :target agent-core :tests ((test :id tc_overflow_compression :input-tokens 4500 :threshold 3000 :notation cs-expr :asserts ((assert-compact-memory-emitted) (assert-max-tokens-below 1500) (assert-facts-retained (:hash-algo \"argon2id\"))))))")
        (suite (sr/parse-harness-suite (list form-str)))
        (outcome (sr/run-harness-suite suite))
        (failing-suite (sr/HarnessSuite
                         :name "failing-suite"
                         :target "agent-core"
                         :tests (list (sr/SuiteTest
                                        :id "tc_fail"
                                        :input-tokens 5000
                                        :threshold 3000
                                        :notation "cs-expr"
                                        :asserts (list "(assert-max-tokens-below 500)")))))
        (fail-outcome (sr/run-harness-suite failing-suite))]
    (do
      (assert (= (.-suite-name outcome) "amnesia-pipeline-gate") "Outcome suite name must match executed suite")
      (assert (.-passed outcome) "All assertions in valid suite must pass")
      (assert (= (.-total-asserts outcome) 3) "Total assertion count must equal 3")
      (assert (= (.-failed-asserts outcome) 0) "Failed assertion count must equal 0 on clean pass")
      (assert (and (not (.-passed fail-outcome)) (= (.-failed-asserts fail-outcome) 1)) "Failing assertion must mark suite unpassed with failed count 1")
      true)))

(df test-emulate-context-overflow [] -> Bool
  :d "Verifies synthetic context overflow generation, message expansion, and fact seeding."
  (let [(facts (list "(:hash-algo \"argon2id\")" "(:key-len 32)"))
        (ctx (ag/emulate-context-overflow "buf_overflow_1" 4500 3000 facts))
        (exact-ctx (ag/emulate-context-overflow "buf_exact_boundary" 3000 3000 (list "(:boundary true)")))]
    (do
      (assert (>= (.-tokens ctx) (.-threshold ctx)) "Active tokens must exceed compression threshold")
      (assert (not (list-empty? (.-messages ctx))) "Emulated message backlog must not be empty")
      (assert (= (.-tokens ctx) 4500) "Token volume must match configured input tokens")
      (assert (list-contains? (.-facts ctx) "(:hash-algo \"argon2id\")") "Seeded facts must contain required hash algorithm")
      (assert (>= (.-tokens exact-ctx) (.-threshold exact-ctx)) "Exact boundary tokens == threshold must trigger overflow flag")
      true)))

(df test-intercept-amnesia-trigger [] -> Bool
  :d "Verifies amnesia cascade trigger interception, chunk emission, and eviction."
  (let [(facts (list "(:hash-algo \"argon2id\")"))
        (overflow-ctx (ag/emulate-context-overflow "buf_trigger_1" 4500 3000 facts))
        (res (ag/intercept-amnesia-trigger overflow-ctx))
        (non-overflow-ctx (ag/emulate-context-overflow "buf_safe_1" 1500 3000 facts))
        (non-ov-res (ag/intercept-amnesia-trigger non-overflow-ctx))]
    (do
      (assert (.-triggered res) "Amnesia cascade must trigger when tokens exceed threshold")
      (assert (not (string-empty? (.-chunk-id res))) "Emitted memory chunk identifier must be non-empty")
      (assert (< (.-post-tokens res) 1500) "Post-compression token volume must be strictly below 1500 ceiling")
      (assert (.-raw-evicted res) "Raw operational messages must be evicted from active memory")
      (assert (not (.-triggered non-ov-res)) "Sub-threshold token volume must bypass amnesia trigger")
      true)))

(df test-verify-facts-retained-success-and-failure [] -> Bool
  :d "Verifies scalar fact preservation audit across complete and degraded memory states."
  (let [(res1 (ag/verify-facts-retained (list "argon2id") (list "argon2id" "blake2b")))
        (res2 (ag/verify-facts-retained (list "argon2id" "salt-128") (list "argon2id" "salt-128" "iter-4")))
        (res3 (ag/verify-facts-retained (list "argon2id" "missing-fact") (list "argon2id")))
        (res4 (ag/verify-facts-retained (list "missing") (list "other")))
        (res5 (ag/verify-facts-retained (list) (list "any-fact")))
        (res6 (ag/verify-facts-retained (list "(:hash-algo \"argon2id\")") (list "(:hash-algo \"sha256\")")))]
    (do
      (assert (.-first res1) "Retained required fact must pass verification")
      (assert (.-first res2) "Multi-fact retention audit must pass when all facts preserved")
      (assert (not (.-first res3)) "Missing fact must cause audit failure")
      (assert (= (.-second res4) (ag/ERR_AMNESIA_DATA_LOSS)) "Missing fact must yield ERR_AMNESIA_DATA_LOSS error code")
      (assert (.-first res5) "Empty required facts list must pass vacuously")
      (assert (and (not (.-first res6)) (= (.-second res6) (ag/ERR_AMNESIA_DATA_LOSS))) "Mismatched fact value must trigger failure with ERR_AMNESIA_DATA_LOSS")
      true)))

(df run-tests [] -> Bool
  :d "Runs all amnesia gate and dynamic suite runner unit tests."
  (and (test-parse-harness-suite-structure)
       (and (test-suite-testcase-metadata-notation)
            (and (test-run-harness-suite-evaluator)
                 (and (test-emulate-context-overflow)
                      (and (test-intercept-amnesia-trigger)
                           (test-verify-facts-retained-success-and-failure)))))))
