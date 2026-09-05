(module asl-harness/normalizer
  :d "Hallucination Normalizer: auto-repairs LLM syntax defects, identifier drift, and AST conventions."
  :x [NormalizerReport normalize-identifier canonicalize-keyword canonicalize-type
      balance-delimiters normalize-asl-fragment repair-hallucinations]
  :i [])

(dfs NormalizerReport
  (:f original-code Str "Raw input from LLM")
  (:f normalized-code Str "Repaired canonical ASL code")
  (:f repairs-count I64 "Number of hallucination corrections applied")
  (:f is-clean Bool "True if no repairs were necessary"))

(df normalize-identifier [(name Str)] -> Str
  :d "Converts snake_case and camelCase identifiers into canonical kebab-case."
  (string-replace (string-replace name "_" "-") " " "-"))

(df canonicalize-keyword [(kw Str)] -> Str
  :d "Maps common LLM hallucinated keywords to canonical AgentScript forms."
  (cond
    ((or (= kw "def") (= kw "defun")) "df")
    ((= kw "defn") "df")
    ((= kw "fn*") "fn")
    ((or (= kw "defrecord") (= kw "struct")) "dfs")
    ((or (= kw "defenum") (= kw "enum")) "dfe")
    ((= kw "match") "mt")
    ((= kw "cond*") "cond")
    (:else kw)))

(df canonicalize-type [(ty Str)] -> Str
  :d "Maps common LLM hallucinated type spellings to canonical ASL types."
  (cond
    ((or (= ty "string") (= ty "str")) "Str")
    ((or (= ty "int") (or (= ty "int64") (= ty "i64"))) "I64")
    ((or (= ty "int32") (= ty "i32")) "I32")
    ((or (= ty "bool") (= ty "boolean")) "Bool")
    ((or (= ty "float") (or (= ty "float64") (= ty "f64"))) "F64")
    ((or (= ty "unit") (= ty "void")) "Unit")
    (:else ty)))

(df balance-delimiters [(src Str)] -> Str
  :d "Closes unclosed opening parentheses in truncated or hallucinated S-expression fragments."
  (let [(open-count (fold (fn [(count I64) (c Str)] -> I64 (if (= c "(") (+ count 1) count)) 0 (string-split src "")))
        (close-count (fold (fn [(count I64) (c Str)] -> I64 (if (= c ")") (+ count 1) count)) 0 (string-split src "")))]
    (if (> open-count close-count)
        (let [(diff (- open-count close-count))
              (closers (fold (fn [(acc Str) (_ I64)] -> Str (str acc ")")) "" (range 0 diff)))]
          (str src closers))
        src)))

(df normalize-asl-fragment [(src Str)] -> Str
  :d "Applies full normalization pipeline over an AgentScript code snippet."
  (let [(s1 (string-replace src "(defun " "(df "))
        (s2 (string-replace s1 "(def " "(df "))
        (s3 (string-replace s2 "(defn " "(df "))
        (s4 (string-replace s3 " String " " Str "))
        (s5 (string-replace s4 " Int64 " " I64 "))
        (s6 (string-replace s5 " Boolean " " Bool "))
        (s7 (balance-delimiters s6))]
    s7))

(df repair-hallucinations [(raw Str)] -> NormalizerReport
  :d "Analyzes LLM output and applies targeted corrections to produce valid ASL."
  (let [(normalized (normalize-asl-fragment raw))
        (repaired (not (= raw normalized)))]
    (NormalizerReport
      :original-code raw
      :normalized-code normalized
      :repairs-count (if repaired 1 0)
      :is-clean (not repaired))))
