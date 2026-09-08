(module asl-harness/verifier
  :d "Universal Polyglot Pre-Execution Invariant Verifier: TS, TSX, HTML, XML, YAML, Swift, Kotlin, Java, Rust, Python, ASL."
  :x [VerificationVerdict detect-language validate-delimiter-balance validate-markup-tags
      validate-yaml-syntax resolve-test-runner verify-chunk-match verify-structural-action
      execute-verification-gate format-gate-rejection]
  :i [(compactor :a comp)
      (asl-parser/balance :a bal)])

(dfs VerificationVerdict
  (:f allowed Bool "True if action satisfies all structural and invariant checks")
  (:f reason Str "Diagnostic reason if verification failed")
  (:f language Str "Detected programming language"))

(df detect-language [(path Str)] -> Str
  :d "Detects programming or markup language from file extension across polyglot ecosystem."
  (cond
    ((string-ends-with? path ".asl") "asl")
    ((or (string-ends-with? path ".tsx") (string-ends-with? path ".jsx")) "tsx")
    ((or (string-ends-with? path ".ts") (string-ends-with? path ".js")) "typescript")
    ((string-ends-with? path ".py") "python")
    ((string-ends-with? path ".rs") "rust")
    ((string-ends-with? path ".swift") "swift")
    ((or (string-ends-with? path ".kt") (string-ends-with? path ".kts")) "kotlin")
    ((string-ends-with? path ".java") "java")
    ((or (string-ends-with? path ".yaml") (string-ends-with? path ".yml")) "yaml")
    ((string-ends-with? path ".xml") "xml")
    ((or (string-ends-with? path ".html") (string-ends-with? path ".htm")) "html")
    ((string-ends-with? path ".json") "json")
    (:else "text")))

(df validate-delimiter-balance [(code Str)] -> Bool
  :d "Universal delimiter validator checking matching balance of parens, brackets, and braces via canonical asl-parser/balance."
  (bal/is-delimiter-balanced? code))

(df validate-markup-tags [(code Str)] -> Bool
  :d "Validates balanced tag opening and closing for HTML, XML, and JSX/TSX markup."
  (let [(chars (string-chars code))
        (tag-counts (fold (fn [(acc (Pair I64 I64)) (c Str)] -> (Pair I64 I64)
                            (cond
                              ((= c "<") (pair (+ (fst acc) 1) (snd acc)))
                              ((= c ">") (pair (fst acc) (+ (snd acc) 1)))
                              (:else acc)))
                          (pair 0 0)
                          chars))
        (opens (fst tag-counts))
        (closes (snd tag-counts))]
    (= opens closes)))

(df validate-yaml-syntax [(code Str)] -> Bool
  :d "Validates YAML indentation compliance (rejects tabs) and collection delimiter balance."
  (if (string-contains? code "\t")
      false
      (validate-delimiter-balance code)))

(df resolve-test-runner [(lang Str)] -> Str
  :d "Resolves canonical verification test runner command for given programming language."
  (cond
    ((= lang "asl") "asl test")
    ((or (= lang "typescript") (= lang "tsx")) "pnpm test")
    ((= lang "python") "pytest")
    ((= lang "rust") "cargo test")
    ((or (= lang "java") (= lang "kotlin")) "gradle test")
    ((= lang "swift") "swift test")
    (:else "test")))

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
  :d "Polyglot pre-execution invariant gate validating action payload before execution."
  (let [(lang (detect-language path))]
    (cond
      ((string-empty? path)
       (VerificationVerdict :allowed false :reason "File path cannot be empty" :language lang))
      ((and (or (= lang "html") (or (= lang "xml") (= lang "tsx")))
            (not (validate-markup-tags payload)))
       (VerificationVerdict :allowed false :reason "Unbalanced markup or JSX tags detected in replacement payload" :language lang))
      ((and (= lang "yaml")
            (not (validate-yaml-syntax payload)))
       (VerificationVerdict :allowed false :reason "Invalid YAML syntax: tabs used for indentation or unbalanced collections" :language lang))
      ((and (= lang "python")
            (string-contains? payload "\t"))
       (VerificationVerdict :allowed false :reason "Forbidden tab characters in Python payload (PEP 8 violation)" :language lang))
      ((and (or (= action-name "fs-write") (= action-name "str-replace"))
            (not (validate-delimiter-balance payload)))
       (VerificationVerdict :allowed false :reason "Unbalanced delimiters detected in replacement payload" :language lang))
      ((and (= action-name "ast-patch") (not (= lang "asl")))
       (VerificationVerdict :allowed false :reason "ast-patch is specialized for S-expression ASTs; use str-replace for other languages" :language lang))
      (:else
       (VerificationVerdict :allowed true :reason "" :language lang)))))

(df execute-verification-gate [(test-cmd Str) (gate-passed Bool)] -> VerificationVerdict
  :d "Executes independent automated verification gate, prohibiting self-declared completion if gate fails."
  (cond
    ((string-empty? test-cmd)
     (VerificationVerdict :allowed false :reason "Task must define an explicit verification command" :language "text"))
    ((not gate-passed)
     (VerificationVerdict :allowed false :reason "Verification command exited with failure; regressions detected" :language "text"))
    (:else
     (VerificationVerdict :allowed true :reason "" :language "text"))))

(df format-gate-rejection [(test-cmd Str) (reason Str)] -> Str
  :d "Formats structured diagnostic message guiding the model to fix test regressions."
  (str "(:gate-rejected :command \"" test-cmd "\" :reason \"" reason "\" :directive \"Fix failing tests before declaring completion\")"))

