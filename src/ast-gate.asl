(module asl-harness/ast-gate
  :d "AST Mutation Gate (Delta_AST): verifies that surgical code edits preserve all protected symbols and test assertions."
  :x [AstMutationVerdict audit-ast-mutation format-mutation-verdict]
  :i [])

(dfs AstMutationVerdict
  (:f allowed Bool "True if mutation preserves all protected symbol definitions")
  (:f reason Str "Diagnostic verdict summary")
  (:f violations (List Str) "List of protected symbols that were missing or commented out"))

(df line-is-comment [(line Str)] -> Bool
  :d "Determines if a trimmed line is a comment in ASL, Python, JS/TS, Rust, or SQL."
  (let [(trimmed (string-trim line))]
    (cond
      ((string-empty? trimmed) true)
      ((string-starts-with? trimmed ";") true)
      ((string-starts-with? trimmed "#") true)
      ((string-starts-with? trimmed "//") true)
      ((string-starts-with? trimmed "/*") true)
      ((string-starts-with? trimmed "*") true)
      ((string-starts-with? trimmed "--") true)
      (:else false))))

(df strip-comment [(line Str)] -> Str
  :d "Strips inline comments from code line across polyglot delimiters."
  (if (line-is-comment line)
      ""
      (let [(s1 (mt (string-index-of line ";")
                  ((some idx) (option-or (string-slice line 0 idx) line))
                  ((none) line)))
            (s2 (mt (string-index-of s1 "//")
                  ((some idx) (option-or (string-slice s1 0 idx) s1))
                  ((none) s1)))
            (s3 (mt (string-index-of s2 " #")
                  ((some idx) (option-or (string-slice s2 0 idx) s2))
                  ((none) s2)))]
        (string-trim s3))))

(df get-active-code [(source Str)] -> Str
  :d "Extracts only active uncommented code lines from source."
  (let [(lines (string-split source "\n"))
        (active-lines (fold (fn [(acc (List Str)) (ln Str)] -> (List Str)
                              (let [(code (strip-comment ln))]
                                (if (string-empty? code)
                                    acc
                                    (list-append acc (list code)))))
                            (list)
                            lines))]
    (string-join active-lines "\n")))

(df symbol-present-in-active? [(source Str) (sym Str)] -> Bool
  :d "Checks if a symbol is present in active uncommented code."
  (let [(active (get-active-code source))]
    (string-contains? active sym)))

(df extract-first-word [(text Str)] -> Str
  :d "Extracts the first identifier token from a definition prefix."
  (let [(trimmed (string-trim text))
        (chars (string-chars trimmed))
        (token-chars (fold (fn [(acc (Pair (List Str) Bool)) (c Str)] -> (Pair (List Str) Bool)
                             (if (snd acc)
                                 acc
                                 (if (or (= c " ")
                                         (or (= c "\t")
                                             (or (= c "[")
                                                 (or (= c "(")
                                                     (or (= c ":")
                                                         (or (= c "{")
                                                             (or (= c ")")
                                                                 (= c "]"))))))))
                                     (pair (fst acc) true)
                                     (pair (list-append (fst acc) (list c)) false))))
                           (pair (list) false)
                           chars))]
    (string-join (fst token-chars) "")))

(df extract-def-name [(line Str)] -> Str
  :d "Extracts the defined symbol name from a definition header line."
  (let [(trimmed (string-trim line))
        (s (if (string-starts-with? trimmed "(")
               (option-or (string-slice trimmed 1 (string-length trimmed)) trimmed)
               trimmed))]
    (cond
      ((string-starts-with? s "df ") (extract-first-word (option-or (string-slice s 3 (string-length s)) "")))
      ((string-starts-with? s "dfs ") (extract-first-word (option-or (string-slice s 4 (string-length s)) "")))
      ((string-starts-with? s "dfe ") (extract-first-word (option-or (string-slice s 4 (string-length s)) "")))
      ((string-starts-with? s "def ") (extract-first-word (option-or (string-slice s 4 (string-length s)) "")))
      ((string-starts-with? s "defun ") (extract-first-word (option-or (string-slice s 6 (string-length s)) "")))
      ((string-starts-with? s "defn ") (extract-first-word (option-or (string-slice s 5 (string-length s)) "")))
      ((string-starts-with? s "fn ") (extract-first-word (option-or (string-slice s 3 (string-length s)) "")))
      ((string-starts-with? s "function ") (extract-first-word (option-or (string-slice s 9 (string-length s)) "")))
      ((string-starts-with? s "class ") (extract-first-word (option-or (string-slice s 6 (string-length s)) "")))
      ((string-starts-with? s "struct ") (extract-first-word (option-or (string-slice s 7 (string-length s)) "")))
      (:else ""))))

(df extract-symbol-definitions [(source Str)] -> (List Str)
  :d "Extracts list of symbol definitions from active source code."
  (let [(lines (string-split source "\n"))]
    (fold (fn [(acc (List Str)) (ln Str)] -> (List Str)
            (let [(code (strip-comment ln))
                  (sym (extract-def-name code))]
              (if (string-empty? sym)
                  acc
                  (if (list-contains? acc sym)
                      acc
                      (list-append acc (list sym))))))
          (list)
          lines)))

(df audit-ast-mutation [(pre-source Str) (post-source Str) (protected-symbols (List Str))] -> AstMutationVerdict
  :d "Audits source mutation ensuring all protected symbols defined in pre-source are preserved and not commented out."
  (let [(defined-pre (extract-symbol-definitions pre-source))
        (violations (fold (fn [(acc (List Str)) (sym Str)] -> (List Str)
                            (let [(in-pre (or (list-contains? defined-pre sym)
                                              (symbol-present-in-active? pre-source sym)))]
                              (if in-pre
                                  (cond
                                    ((symbol-present-in-active? post-source sym) acc)
                                    (:else (list-append acc (list sym))))
                                  acc)))
                          (list)
                          protected-symbols))
        (has-violations (> (list-length violations) 0))]
    (if has-violations
        (AstMutationVerdict
          :allowed false
          :reason (str "Protected symbol violations detected: " (string-join violations ", "))
          :violations violations)
        (AstMutationVerdict
          :allowed true
          :reason "AST mutation verified: all protected symbols preserved"
          :violations (list)))))

(df format-mutation-verdict [(verdict AstMutationVerdict)] -> Str
  :d "Formats structured diagnostic verdict for AST mutation gate."
  (if (.-allowed verdict)
      "(:ast-mutation-verdict :allowed true :reason \"All protected symbols preserved\" :violations ())"
      (str "(:ast-mutation-verdict :allowed false :reason \"" (.-reason verdict) "\" :violations ("
           (string-join (.-violations verdict) " ")
           "))")))
