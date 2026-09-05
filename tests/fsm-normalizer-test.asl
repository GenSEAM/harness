(module asl-harness/fsm-normalizer-test
  :d "Unit tests for pure ASL FSM grammar normalizer, keyword repairs, and delimiter balancing."
  :x [test-keyword-normalization test-delimiter-auto-balance test-nested-form-repair run-tests]
  :i [(fsm-normalizer :a fsm)])

(df test-keyword-normalization [] -> Bool
  :d "Verifies keyword hallucination replacement for defun, defn, and lambda."
  (let [(t1 (= (fsm/normalize-keywords "defun") "df"))
        (t2 (= (fsm/normalize-keywords "defn") "df"))
        (t3 (= (fsm/normalize-keywords "lambda") "fn"))
        (t4 (= (fsm/normalize-keywords "(defun add [(x I64) (y I64)] -> I64 (+ x y))")
               "(df add [(x I64) (y I64)] -> I64 (+ x y))"))
        (t5 (= (fsm/normalize-keywords "(defn sub [(x I64) (y I64)] -> I64 (- x y))")
               "(df sub [(x I64) (y I64)] -> I64 (- x y))"))
        (t6 (= (fsm/normalize-keywords "(map (lambda [(x I64)] (+ x 1)) xs)")
               "(map (fn [(x I64)] (+ x 1)) xs)"))
        (t7 (= (fsm/normalize-keywords "(lambda [(x I64)] (* x 2))")
               "(fn [(x I64)] (* x 2))"))]
    (and t1
         (and t2
              (and t3
                   (and t4
                        (and t5
                             (and t6 t7))))))))

(df test-delimiter-auto-balance [] -> Bool
  :d "Verifies single-pass FSM delimiter tracking and automatic closing of open delimiters."
  (let [(clean "(df greet [(name Str)] -> Str (str \"hello \" name))")
        (r-clean (fsm/balance-delimiters-fsm clean))
        (t-clean (and (.-balanced? r-clean)
                      (and (= (.-open-parens r-clean) 0)
                           (and (= (.-open-brackets r-clean) 0)
                                (= (.-repaired r-clean) clean)))))
        (dirty-parens "(df compute [(x I64)] (+ x 1")
        (r-parens (fsm/balance-delimiters-fsm dirty-parens))
        (t-parens (and (not (.-balanced? r-parens))
                       (and (= (.-open-parens r-parens) 2)
                            (and (= (.-open-brackets r-parens) 0)
                                 (= (.-repaired r-parens) "(df compute [(x I64)] (+ x 1))")))))
        (dirty-str "(df prompt [] \"unclosed string")
        (r-str (fsm/balance-delimiters-fsm dirty-str))
        (t-str (and (not (.-balanced? r-str))
                    (and (= (.-open-parens r-str) 1)
                         (and (= (.-open-brackets r-str) 0)
                              (= (.-repaired r-str) "(df prompt [] \"unclosed string\")")))))
        (with-delims-in-str "(df show [] \"(ignore [delimiters] in strings)\")")
        (r-with-delims (fsm/balance-delimiters-fsm with-delims-in-str))
        (t-with-delims (and (.-balanced? r-with-delims)
                            (and (= (.-open-parens r-with-delims) 0)
                                 (and (= (.-open-brackets r-with-delims) 0)
                                      (= (.-repaired r-with-delims) with-delims-in-str)))))]
    (and t-clean
         (and t-parens
              (and t-str t-with-delims)))))

(df test-nested-form-repair [] -> Bool
  :d "Verifies nested delimiter recovery and end-to-end syntax repair."
  (let [(nested-let "(let [(a 1) (b 2")
        (r-nested (fsm/balance-delimiters-fsm nested-let))
        (t-nested (and (not (.-balanced? r-nested))
                       (and (= (.-open-parens r-nested) 2)
                            (and (= (.-open-brackets r-nested) 1)
                                 (= (.-repaired r-nested) "(let [(a 1) (b 2)])")))))
        (deep "(df compute [(items (List I64))] (let [(x 10)] (if (> x 0) (+ x 5")
        (r-deep (fsm/balance-delimiters-fsm deep))
        (t-deep (and (not (.-balanced? r-deep))
                     (and (= (.-open-parens r-deep) 4)
                          (and (= (.-open-brackets r-deep) 0)
                               (= (.-repaired r-deep) "(df compute [(items (List I64))] (let [(x 10)] (if (> x 0) (+ x 5))))")))))
        (dirty-full "(defun calc [(vals (List I64))] (map (lambda [(v I64)] (* v 2)) (let [(init 0")
        (repaired-full (fsm/repair-syntax-fsm dirty-full))
        (t-full (= repaired-full "(df calc [(vals (List I64))] (map (fn [(v I64)] (* v 2)) (let [(init 0)])))"))]
    (and t-nested
         (and t-deep t-full))))

(df run-tests [] -> Bool
  :d "Executes the full FSM normalizer test suite."
  (and (test-keyword-normalization)
       (and (test-delimiter-auto-balance)
            (test-nested-form-repair))))
