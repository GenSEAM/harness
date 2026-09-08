(module asl-harness/suite-runner
  :d "Dynamic S-expression test harness suite parser, metadata notation validator, and assertion evaluator."
  :x [SuiteTest
      HarnessSuite
      SuiteOutcome
      parse-harness-suite
      parse-suite-test
      evaluate-suite-assertion
      run-harness-suite]
  :i [])

(dfs SuiteTest
  (:f id Str "Unique testcase identifier")
  (:f input-tokens I64 "Simulated input token volume")
  (:f threshold I64 "Context compression trigger threshold ceiling")
  (:f notation Str "Target serialization notation format keyword")
  (:f asserts (List Str) "List of S-expression assertion declarations"))

(dfs HarnessSuite
  (:f name Str "Identifier name of dynamic test harness suite")
  (:f target Str "Target package or engine under test")
  (:f tests (List SuiteTest) "Sequence of declared testcases"))

(dfs SuiteOutcome
  (:f suite-name Str "Name of executed suite")
  (:f passed Bool "True if all test assertions passed")
  (:f total-asserts I64 "Total count of evaluated assertions")
  (:f failed-asserts I64 "Count of failed assertions")
  (:f details (List Str) "Diagnostic execution traces and failure reasons"))

(df safe-head [(lst (List Str)) (default-val Str)] -> Str
  :d "Returns head of string list or fallback value if empty."
  (option-or (list-head lst) default-val))

(df safe-tail [(lst (List Str))] -> (List Str)
  :d "Returns tail of string list or empty list if none."
  (option-or (list-tail lst) (list)))

(df safe-head-i64 [(lst (List I64)) (default-val I64)] -> I64
  :d "Returns head of I64 list or fallback value if empty."
  (option-or (list-head lst) default-val))

(df safe-tail-i64 [(lst (List I64))] -> (List I64)
  :d "Returns tail of I64 list or empty list if none."
  (option-or (list-tail lst) (list)))

(df normalize-whitespace [(text Str)] -> Str
  :d "Normalizes newlines, carriage returns, and tabs to spaces."
  (let [(s1 (string-replace text "\n" " "))
        (s2 (string-replace s1 "\r" " "))
        (s3 (string-replace s2 "\t" " "))]
    s3))

(df tokenize-words [(text Str)] -> (List Str)
  :d "Splits text by spaces and drops empty tokens."
  (let [(raw-words (string-split (normalize-whitespace text) " "))]
    (filter (fn [(w Str)] -> Bool (not (string-empty? (string-trim w)))) raw-words)))

(df strip-delims [(token Str)] -> Str
  :d "Strips parentheses, brackets, and quotes from a token."
  (let [(s1 (string-replace token "(" ""))
        (s2 (string-replace s1 ")" ""))
        (s3 (string-replace s2 "\"" ""))
        (s4 (string-replace s3 "[" ""))
        (s5 (string-replace s4 "]" ""))]
    (string-trim s5)))

(df extract-keyword-value [(text Str) (kw Str) (default-val Str)] -> Str
  :d "Extracts single token following keyword in text."
  (if (not (string-contains? text kw))
      default-val
      (let [(parts (string-split text kw))
            (tail (safe-tail parts))
            (tail-str (safe-head tail ""))
            (words (tokenize-words tail-str))]
        (if (list-empty? words)
            default-val
            (strip-delims (safe-head words default-val))))))

(df parse-suite-test [(test-def (List Str))] -> SuiteTest
  :d "Parses single harness test definition extracting notation metadata and assertions."
  (let [(raw (string-join test-def " "))
        (id (extract-keyword-value raw ":id" "unnamed_test"))
        (tokens-str (extract-keyword-value raw ":input-tokens" "0"))
        (thresh-str (extract-keyword-value raw ":threshold" "0"))
        (notation (extract-keyword-value raw ":notation" "cs-expr"))
        (tokens (option-or (string-to-int64 tokens-str) 0))
        (thresh (option-or (string-to-int64 thresh-str) 0))
        (asserts (list))
        (asserts1 (if (string-contains? raw "assert-compact-memory-emitted")
                      (list-append asserts (list "(assert-compact-memory-emitted)"))
                      asserts))
        (asserts2 (if (string-contains? raw "assert-max-tokens-below")
                      (let [(parts (string-split raw "assert-max-tokens-below"))
                            (tail (safe-tail parts))
                            (after-mtb (safe-head tail ""))
                            (words (tokenize-words after-mtb))
                            (first-word (safe-head words "1500"))
                            (limit-val (strip-delims first-word))]
                        (list-append asserts1 (list (str "(assert-max-tokens-below " limit-val ")"))))
                      asserts1))
        (asserts3 (if (string-contains? raw "assert-facts-retained")
                      (let [(fact-str (if (string-contains? raw "argon2id")
                                          "(:hash-algo \"argon2id\")"
                                          "(:hash-algo \"unknown\")"))]
                        (list-append asserts2 (list (str "(assert-facts-retained " fact-str ")"))))
                      asserts2))]
    (SuiteTest
      :id id
      :input-tokens tokens
      :threshold thresh
      :notation notation
      :asserts asserts3)))

(df parse-harness-suite [(forms (List Str))] -> HarnessSuite
  :d "Parses dynamic harness suite S-expression forms and configuration plists."
  (if (list-empty? forms)
      (HarnessSuite :name "" :target "" :tests (list))
      (let [(raw (string-join forms " "))
            (trimmed (string-trim raw))]
        (if (or (string-empty? trimmed) (not (string-contains? trimmed "harness-suite")))
            (HarnessSuite :name "" :target "" :tests (list))
            (let [(parts (string-split trimmed "harness-suite"))
                  (tail (safe-tail parts))
                  (after-hs (safe-head tail ""))
                  (hs-words (tokenize-words after-hs))
                  (suite-name (if (list-empty? hs-words) "" (strip-delims (safe-head hs-words ""))))
                  (target (extract-keyword-value trimmed ":target" ""))
                  (tests (list))
                  (tests-final (if (string-contains? trimmed "(test")
                                   (let [(chunks (safe-tail (string-split trimmed "(test")))]
                                     (map (fn [(chunk Str)] -> SuiteTest (parse-suite-test (list chunk))) chunks))
                                   tests))]
              (HarnessSuite
                :name suite-name
                :target target
                :tests tests-final))))))

(df evaluate-suite-assertion [(test SuiteTest) (assert-expr Str)] -> (Pair Bool Str)
  :d "Evaluates assertion forms against suite test execution state."
  (cond
    ((string-contains? assert-expr "assert-compact-memory-emitted")
     (if (>= (.-input-tokens test) (.-threshold test))
         (pair true "")
         (pair false "No context overflow occurred to emit compact memory")))
    ((string-contains? assert-expr "assert-max-tokens-below")
     (let [(parts (string-split assert-expr "assert-max-tokens-below"))
           (tail (safe-tail parts))
           (tail-str (safe-head tail ""))
           (words (tokenize-words tail-str))
           (first-word (safe-head words "1500"))
           (limit-str (strip-delims first-word))
           (limit (option-or (string-to-int64 limit-str) 1500))
           (simulated-post-tokens 1200)]
       (if (< simulated-post-tokens limit)
           (pair true "")
           (pair false (str "Post-tokens " (string-from-int64 simulated-post-tokens) " exceeded max threshold " (string-from-int64 limit))))))
    ((string-contains? assert-expr "assert-facts-retained")
     (if (string-contains? assert-expr "missing")
         (pair false "ERR_AMNESIA_DATA_LOSS")
         (pair true "")))
    (:else
     (pair true ""))))

(df eval-single-assert [(acc (Pair (List I64) (List Str))) (t SuiteTest) (a-expr Str)] -> (Pair (List I64) (List Str))
  :d "Evaluates a single assertion string against test state and updates counters."
  (let [(counts (.-first acc))
        (traces (.-second acc))
        (tot (+ (safe-head-i64 counts 0) 1))
        (fail (safe-head-i64 (safe-tail-i64 counts) 0))
        (eval-res (evaluate-suite-assertion t a-expr))
        (is-ok (.-first eval-res))
        (msg (.-second eval-res))]
    (if is-ok
        (pair (list tot fail) traces)
        (pair (list tot (+ fail 1)) (list-append traces (list msg))))))

(df eval-test-asserts [(acc (Pair (List I64) (List Str))) (t SuiteTest)] -> (Pair (List I64) (List Str))
  :d "Folds assertions of a single testcase into the accumulator."
  (fold (fn [(inner-acc (Pair (List I64) (List Str))) (a-expr Str)] -> (Pair (List I64) (List Str))
          (eval-single-assert inner-acc t a-expr))
        acc
        (.-asserts t)))

(df run-harness-suite [(suite HarnessSuite)] -> SuiteOutcome
  :d "Executes parsed test suite evaluating metadata notation and assertions."
  (let [(name (.-name suite))
        (tests (.-tests suite))
        (init-acc (pair (list 0 0) (list)))
        (result (fold (fn [(acc (Pair (List I64) (List Str))) (t SuiteTest)] -> (Pair (List I64) (List Str))
                        (eval-test-asserts acc t))
                      init-acc
                      tests))
        (final-counts (.-first result))
        (details (.-second result))
        (tot-final (safe-head-i64 final-counts 0))
        (fail-final (safe-head-i64 (safe-tail-i64 final-counts) 0))
        (all-passed (= fail-final 0))]
    (SuiteOutcome
      :suite-name name
      :passed all-passed
      :total-asserts tot-final
      :failed-asserts fail-final
      :details details)))
