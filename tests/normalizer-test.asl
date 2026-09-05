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
    (and (= case1 "read-file-content")
         (and (= case2 "execute-command")
              (= case3 "get-ast-node")))))

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
    (and (= kw-def "df")
         (and (= kw-defun "df")
              (and (= kw-defn "df")
                   (and (= kw-fn "fn")
                        (and (= kw-struct "dfs")
                             (and (= kw-enum "dfe")
                                  (and (= kw-match "mt")
                                       (= kw-cond "cond"))))))))))

(df test-canonicalize-types [] -> Bool
  :d "Verifies type identifier mapping into canonical ASL types."
  (let [(t-str (norm/canonicalize-type "string"))
        (t-i64 (norm/canonicalize-type "int64"))
        (t-i32 (norm/canonicalize-type "int32"))
        (t-bool (norm/canonicalize-type "boolean"))
        (t-f64 (norm/canonicalize-type "float64"))
        (t-unit (norm/canonicalize-type "void"))]
    (and (= t-str "Str")
         (and (= t-i64 "I64")
              (and (= t-i32 "I32")
                   (and (= t-bool "Bool")
                        (and (= t-f64 "F64")
                             (= t-unit "Unit"))))))))

(df test-balance-delimiters [] -> Bool
  :d "Verifies auto-closing of unclosed delimiter balance."
  (let [(unclosed "(df calculate [(x I64)] (+ x 1")
        (balanced (norm/balance-delimiters unclosed))
        (nested "(let [(a 1) (b 2)] (+ a b")
        (nested-balanced (norm/balance-delimiters nested))]
    (and (string-contains? balanced "))")
         (string-contains? nested-balanced "))"))))

(df test-repair-hallucinations [] -> Bool
  :d "Verifies end-to-end hallucination repair and cleanliness reporting."
  (let [(dirty "(defun compute [(x String)] -> Int64 x")
        (rep-dirty (norm/repair-hallucinations dirty))
        (clean "(df compute [(x Str)] -> I64 x)")
        (rep-clean (norm/repair-hallucinations clean))]
    (and (not (.-is-clean rep-dirty))
         (and (= (.-repairs-count rep-dirty) 1)
              (and (.-is-clean rep-clean)
                   (= (.-repairs-count rep-clean) 0))))))

(df run-tests [] -> Bool
  :d "Executes full normalizer test suite."
  (and (test-normalize-identifier)
       (and (test-canonicalize-keywords)
            (and (test-canonicalize-types)
                 (and (test-balance-delimiters)
                      (test-repair-hallucinations))))))
