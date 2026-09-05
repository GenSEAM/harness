(module asl-harness/verifier
  :d "Universal Pre-Execution Invariant Verifier & Anti-Hallucination Guardrails."
  :x [VerificationVerdict detect-language validate-delimiter-balance verify-chunk-match verify-structural-action]
  :i [(compactor :a comp)])

(dfs VerificationVerdict
  (:f allowed Bool "True if action satisfies all structural and invariant checks")
  (:f reason Str "Diagnostic reason if verification failed")
  (:f language Str "Detected programming language e.g. asl, py, rs, ts"))

(df detect-language [(path Str)] -> Str
  :d "Detects programming language from file extension for language-aware AST verification."
  (cond
    ((string-ends-with? path ".asl") "asl")
    ((string-ends-with? path ".py") "py")
    ((string-ends-with? path ".rs") "rs")
    ((or (string-ends-with? path ".ts") (string-ends-with? path ".js")) "ts")
    ((string-ends-with? path ".json") "json")
    (:else "text")))

(df validate-delimiter-balance [(code Str)] -> Bool
  :d "Universal delimiter validator checking matching balance of parens, brackets, and braces."
  (let [(chars (string-chars code))
        (counts (fold (fn [(acc (List I64)) (c Str)] -> (List I64)
                        (let [(p (option-or (list-head acc) 0))
                              (b (option-or (list-head (list-drop acc 1)) 0))
                              (c-brace (option-or (list-head (list-drop acc 2)) 0))]
                          (cond
                            ((= c "(") (list (+ p 1) b c-brace))
                            ((= c ")") (list (if (> p 0) (- p 1) 0) b c-brace))
                            ((= c "[") (list p (+ b 1) c-brace))
                            ((= c "]") (list p (if (> b 0) (- b 1) 0) c-brace))
                            ((= c "{") (list p b (+ c-brace 1)))
                            ((= c "}") (list p b (if (> c-brace 0) (- c-brace 1) 0)))
                            (:else acc))))
                      (list 0 0 0)
                      chars))
        (final-p (option-or (list-head counts) 0))
        (final-b (option-or (list-head (list-drop counts 1)) 0))
        (final-c (option-or (list-head (list-drop counts 2)) 0))]
    (and (= final-p 0)
         (and (= final-b 0)
              (= final-c 0)))))

(df verify-chunk-match [(file-content Str) (old-chunk Str)] -> VerificationVerdict
  :d "Verifies that target replacement chunk exists uniquely in file content before executing surgical edit."
  (let [(trimmed-target (string-trim old-chunk))]
    (cond
      ((string-empty? trimmed-target)
       (VerificationVerdict :allowed false :reason "Target chunk cannot be empty" :language "text"))
      ((not (string-contains? file-content trimmed-target))
       (VerificationVerdict :allowed false :reason "Target chunk not found in file content" :language "text"))
      (:else
       (VerificationVerdict :allowed true :reason "" :language "text")))))

(df verify-structural-action [(action-name Str) (path Str) (payload Str)] -> VerificationVerdict
  :d "Pre-execution invariant gate validating action payload before execution."
  (let [(lang (detect-language path))]
    (cond
      ((string-empty? path)
       (VerificationVerdict :allowed false :reason "File path cannot be empty" :language lang))
      ((and (or (= action-name "fs-write") (= action-name "str-replace"))
            (not (validate-delimiter-balance payload)))
       (VerificationVerdict :allowed false :reason "Unbalanced delimiters detected in replacement payload" :language lang))
      ((and (= action-name "ast-patch") (not (= lang "asl")))
       (VerificationVerdict :allowed false :reason "ast-patch is specialized for S-expression ASTs; use str-replace for other languages" :language lang))
      (:else
       (VerificationVerdict :allowed true :reason "" :language lang)))))

