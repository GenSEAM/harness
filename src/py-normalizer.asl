(module asl-harness/py-normalizer
  :d "Deterministic Python syntax normalizer: indentation repair, colon auto-completion, and traceback extraction."
  :x [normalize-indentation repair-py-colons parse-py-traceback detect-missing-imports repair-python-code]
  :i [])

(df has-compound-prefix? [(line Str)] -> Bool
  :d "Checks if a trimmed line begins with a Python compound statement keyword."
  (or (string-starts-with? line "def ")
      (or (string-starts-with? line "class ")
          (or (string-starts-with? line "if ")
              (or (string-starts-with? line "elif ")
                  (or (= line "else")
                      (or (string-starts-with? line "for ")
                          (or (string-starts-with? line "while ")
                              (or (= line "try")
                                  (or (string-starts-with? line "except ")
                                      (or (= line "finally")
                                          (string-starts-with? line "with "))))))))))))

(df repair-line-colon [(line Str)] -> Str
  :d "Appends missing colon to a Python compound header line if absent."
  (let [(trimmed (string-trim line))]
    (if (and (has-compound-prefix? trimmed)
             (not (string-ends-with? trimmed ":")))
        (str line ":")
        line)))

(df repair-py-colons [(code Str)] -> Str
  :d "Repairs missing colons on all compound statement headers across a Python code block."
  (let [(lines (string-split code "\n"))
        (fixed-lines (map repair-line-colon lines))]
    (string-join fixed-lines "\n")))

(df normalize-indent-line [(line Str)] -> Str
  :d "Replaces leading tabs with 4 spaces for strict Python indentation compliance."
  (string-replace line "\t" "    "))

(df normalize-indentation [(code Str)] -> Str
  :d "Normalizes tabbed or mixed whitespace indentation into standard 4-space blocks."
  (let [(lines (string-split code "\n"))
        (fixed-lines (map normalize-indent-line lines))]
    (string-join fixed-lines "\n")))

(df detect-missing-imports [(code Str)] -> (List Str)
  :d "Identifies referenced standard library modules that lack import statements."
  (let [(modules (list "json" "math" "re" "os" "sys" "time"))
        (missing (fold (fn [(acc (List Str)) (m Str)] -> (List Str)
                         (let [(ref-pattern (str m "."))
                               (import-pattern (str "import " m))]
                           (if (and (string-contains? code ref-pattern)
                                    (not (string-contains? code import-pattern)))
                               (list-cons m acc)
                               acc)))
                       (list)
                       modules))]
    missing))

(df parse-py-traceback [(stderr Str)] -> Str
  :d "Parses verbose Python tracebacks into a concise 1-line diagnostic receipt."
  (let [(lines (string-split stderr "\n"))
        (err-line (fold (fn [(acc Str) (l Str)] -> Str
                          (if (or (string-contains? l "Error:") (string-contains? l "Exception:"))
                              l
                              acc))
                        ""
                        lines))
        (loc-line (fold (fn [(acc Str) (l Str)] -> Str
                          (if (and (string-contains? l "File \"") (string-contains? l "line "))
                              l
                              acc))
                        ""
                        lines))]
    (if (and (not (= err-line "")) (not (= loc-line "")))
        (str "(:py-error :location \"" (string-trim loc-line) "\" :cause \"" (string-trim err-line) "\")")
        (str "(:py-error :raw \"" (string-trim (option-or (list-last lines) stderr)) "\")"))))

(df repair-python-code [(code Str)] -> Str
  :d "Runs end-to-end Python syntax repair pipeline."
  (let [(indented (normalize-indentation code))
        (coloned (repair-py-colons indented))
        (missing-mods (detect-missing-imports coloned))]
    (if (list-empty? missing-mods)
        coloned
        (let [(imports-header (fold (fn [(acc Str) (m Str)] -> Str (str acc "import " m "\n")) "" missing-mods))]
          (str imports-header coloned)))))

