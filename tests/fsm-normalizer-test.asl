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
    (assert t1 "defun -> df")
    (assert t2 "defn -> df")
    (assert t3 "lambda -> fn")
    (assert t4 "defun signature normalized")
    (assert t5 "defn signature normalized")
    (assert t6 "lambda in map normalized")
    (assert t7 "lambda expr normalized")
    true))

(df test-delimiter-auto-balance [] -> Bool
  :d "Verifies single-pass FSM delimiter tracking and automatic closing of open delimiters."
  (let [(clean "(df greet [(name Str)] -> Str (str \"hello \" name))")
        (r-clean (fsm/balance-delimiters-fsm clean))
        (dirty-parens "(df compute [(x I64)] (+ x 1")
        (r-parens (fsm/balance-delimiters-fsm dirty-parens))
        (dirty-str "(df prompt [] \"unclosed string")
        (r-str (fsm/balance-delimiters-fsm dirty-str))
        (with-delims-in-str "(df show [] \"(ignore [delimiters] in strings)\")")
        (r-with-delims (fsm/balance-delimiters-fsm with-delims-in-str))]
    (assert (.-balanced? r-clean) "clean is balanced")
    (assert (= (.-open-parens r-clean) 0) "clean open parens is 0")
    (assert (= (.-open-brackets r-clean) 0) "clean open brackets is 0")
    (assert (= (.-repaired r-clean) clean) "clean repaired matches")
    (assert (not (.-balanced? r-parens)) "dirty parens not balanced")
    (assert (= (.-open-parens r-parens) 2) "dirty open parens is 2")
    (assert (= (.-open-brackets r-parens) 0) "dirty open brackets is 0")
    (assert (= (.-repaired r-parens) "(df compute [(x I64)] (+ x 1))") "dirty parens repaired")
    (assert (not (.-balanced? r-str)) "dirty str not balanced")
    (assert (= (.-open-parens r-str) 1) "dirty str open parens is 1")
    (assert (= (.-open-brackets r-str) 0) "dirty str open brackets is 0")
    (assert (= (.-repaired r-str) "(df prompt [] \"unclosed string\")") "dirty str repaired")
    (assert (.-balanced? r-with-delims) "with delims in str is balanced")
    (assert (= (.-open-parens r-with-delims) 0) "with delims open parens is 0")
    (assert (= (.-open-brackets r-with-delims) 0) "with delims open brackets is 0")
    (assert (= (.-repaired r-with-delims) with-delims-in-str) "with delims repaired matches")
    true))

(df test-nested-form-repair [] -> Bool
  :d "Verifies nested delimiter recovery and end-to-end syntax repair."
  (let [(nested-let "(let [(a 1) (b 2")
        (r-nested (fsm/balance-delimiters-fsm nested-let))
        (deep "(df compute [(items (List I64))] (let [(x 10)] (if (> x 0) (+ x 5")
        (r-deep (fsm/balance-delimiters-fsm deep))
        (dirty-full "(defun calc [(vals (List I64))] (map (lambda [(v I64)] (* v 2)) (let [(init 0")
        (repaired-full (fsm/repair-syntax-fsm dirty-full))]
    (assert (not (.-balanced? r-nested)) "nested not balanced")
    (assert (= (.-open-parens r-nested) 2) "nested open parens is 2")
    (assert (= (.-open-brackets r-nested) 1) "nested open brackets is 1")
    (assert (= (.-repaired r-nested) "(let [(a 1) (b 2)])") "nested repaired matches")
    (assert (not (.-balanced? r-deep)) "deep not balanced")
    (assert (= (.-open-parens r-deep) 4) "deep open parens is 4")
    (assert (= (.-open-brackets r-deep) 0) "deep open brackets is 0")
    (assert (= (.-repaired r-deep) "(df compute [(items (List I64))] (let [(x 10)] (if (> x 0) (+ x 5))))") "deep repaired matches")
    (assert (= repaired-full "(df calc [(vals (List I64))] (map (fn [(v I64)] (* v 2)) (let [(init 0)])))") "full syntax repair matches")
    true))

(df run-tests [] -> Bool
  :d "Executes the full FSM normalizer test suite."
  (do
    (test-keyword-normalization)
    (test-delimiter-auto-balance)
    (test-nested-form-repair)
    true))
