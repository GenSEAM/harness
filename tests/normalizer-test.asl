(module asl-harness/tests/normalizer-test
  :d "Unit tests for hallucination normalizer, keyword canonicalizer, type mappings, and delimiter repair."
  :x [test-normalize-identifier test-canonicalize-keywords test-canonicalize-types
      test-balance-delimiters test-repair-hallucinations run-tests]
  :i [(normalizer :a norm)])

(df test-normalize-identifier [] -> Bool
  :d "Verifies snake_case, spaces, and kebab-case conversions."
  (let [(case1 (norm/normalize-identifier "read_file_content"))
        (case2 (norm/normalize-identifier "execute command"))
        (case3 (norm/normalize-identifier "get-ast-node"))]
    (assert (= case1 "read-file-content") "snake_case must convert to kebab-case")
    (assert (= case2 "execute-command") "spaces must convert to kebab-case")
    (assert (= case3 "get-ast-node") "kebab-case must remain unchanged")
    true))

(df test-canonicalize-keywords [] -> Bool
  :d "Verifies keyword canonicalization from common LLM hallucinations."
  (let [(kw-def (norm/canonicalize-keyword "def"))
        (kw-defun (norm/canonicalize-keyword "defun"))
        (kw-defn (norm/canonicalize-keyword "defn"))
        (kw-fn (norm/canonicalize-keyword "fn*"))
        (kw-struct (norm/canonicalize-keyword "struct"))
        (kw-enum (norm/canonicalize-keyword "defenum"))
        (kw-match (norm/canonicalize-keyword "match"))
        (kw-cond (norm/canonicalize-keyword "cond*"))]
    (assert (= kw-def "df") "def -> df")
    (assert (= kw-defun "df") "defun -> df")
    (assert (= kw-defn "df") "defn -> df")
    (assert (= kw-fn "fn") "fn* -> fn")
    (assert (= kw-struct "dfs") "struct -> dfs")
    (assert (= kw-enum "dfe") "defenum -> dfe")
    (assert (= kw-match "mt") "match -> mt")
    (assert (= kw-cond "cond") "cond* -> cond")
    true))

(df test-canonicalize-types [] -> Bool
  :d "Verifies type identifier mapping into canonical ASL types."
  (let [(t-str (norm/canonicalize-type "string"))
        (t-i64 (norm/canonicalize-type "int64"))
        (t-i32 (norm/canonicalize-type "int32"))
        (t-bool (norm/canonicalize-type "boolean"))
        (t-f64 (norm/canonicalize-type "float64"))
        (t-unit (norm/canonicalize-type "void"))]
    (assert (= t-str "Str") "string -> Str")
    (assert (= t-i64 "I64") "int64 -> I64")
    (assert (= t-i32 "I32") "int32 -> I32")
    (assert (= t-bool "Bool") "boolean -> Bool")
    (assert (= t-f64 "F64") "float64 -> F64")
    (assert (= t-unit "Unit") "void -> Unit")
    true))

(df test-balance-delimiters [] -> Bool
  :d "Verifies auto-closing of unclosed delimiter balance."
  (let [(unclosed "(df calculate [(x I64)] (+ x 1")
        (balanced (norm/balance-delimiters unclosed))
        (nested "(let [(a 1) (b 2)] (+ a b")
        (nested-balanced (norm/balance-delimiters nested))
        (with-str "(print \"hello ) world\"")
        (balanced-str (norm/balance-delimiters with-str))]
    (assert (string-contains? balanced "))") "Unclosed must append closing parens")
    (assert (string-contains? nested-balanced "))") "Nested must append closing parens")
    (assert (= balanced-str "(print \"hello ) world\")") "Parens in string literal must not cause extra closer")
    true))

(df test-repair-hallucinations [] -> Bool
  :d "Verifies end-to-end hallucination repair and cleanliness reporting."
  (let [(dirty "(defun compute [(x String)] -> Int64 x")
        (rep-dirty (norm/repair-hallucinations dirty))
        (clean "(df compute [(x Str)] -> I64 x)")
        (rep-clean (norm/repair-hallucinations clean))]
    (assert (not (.-is-clean rep-dirty)) "Dirty snippet must not be clean")
    (assert (= (.-repairs-count rep-dirty) 1) "Repairs count must be 1")
    (assert (.-is-clean rep-clean) "Clean snippet must be clean")
    (assert (= (.-repairs-count rep-clean) 0) "Clean snippet repairs must be 0")
    true))

(df run-tests [] -> Bool
  :d "Executes full normalizer test suite."
  (and (test-normalize-identifier)
       (and (test-canonicalize-keywords)
            (and (test-canonicalize-types)
                 (and (test-balance-delimiters)
                      (test-repair-hallucinations))))))
