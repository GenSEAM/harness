(module asl-harness/component-mapper
  :d "Component Usage Mapper, 1-Tool Batch Transformer, Design Policy Guard & Residue Hunter in Pure ASL"
  :x [ElementUsage
      ComponentMap
      BatchTransformRule
      BatchTransformResult
      PolicyViolation
      PolicyAuditReport
      ResidueMatch
      ResidueReport
      scan-component-usages
      batch-transform-classes
      audit-design-policy
      hunt-library-residues
      format-component-map]
  :i [(core/strings :a s)])

(dfs ElementUsage
  (:f tag-name Str "Component identifier or native tag name e.g. Button, input, Modal")
  (:f is-native Bool "True if lowercase native tag (input, div), false if uppercase component (Button)")
  (:f file-path Str "Originating source file path")
  (:f line I64 "1-indexed line number of tag appearance")
  (:f class-names (List Str) "Extracted class names from className or class attribute"))

(dfs ComponentMap
  (:f file-path Str "Scanned source file path")
  (:f usages (List ElementUsage) "List of all detected tag usages")
  (:f total-components I64 "Count of custom component instances")
  (:f total-native I64 "Count of native DOM element instances"))

(dfs BatchTransformRule
  (:f target-tag Str "Optional tag filter (empty for all tags)")
  (:f old-class Str "Target class name to replace e.g. btn-old")
  (:f new-class Str "Replacement class name e.g. btn-new")
  (:f scope-pattern Str "File path pattern to restrict mutation e.g. /pages/"))

(dfs BatchTransformResult
  (:f occurrences-replaced I64 "Number of replaced class or tag occurrences")
  (:f modified-content Str "Transformed source code string"))

(dfs PolicyViolation
  (:f file-path Str "File where violation occurred")
  (:f line I64 "Line number of violation")
  (:f forbidden-tag Str "Disallowed native element tag e.g. input")
  (:f recommended-replacement Str "Design system component alternative e.g. Input")
  (:f rule-name Str "Design system policy identifier"))

(dfs PolicyAuditReport
  (:f passed Bool "True if zero policy violations found")
  (:f violations (List PolicyViolation) "List of policy violations"))

(dfs ResidueMatch
  (:f file-path Str "File where decommissioned residue was detected")
  (:f line I64 "Line number of match")
  (:f library-name Str "Target decommissioned library name")
  (:f snippet Str "Context code snippet"))

(dfs ResidueReport
  (:f clean Bool "True if zero residual occurrences found")
  (:f matches (List ResidueMatch) "Found residual code locations"))

(df is-uppercase-char? [(c Str)] -> Bool
  :d "Checks if character is ASCII uppercase (A-Z)."
  (and (>= c "A") (<= c "Z")))

(df is-native-tag? [(tag-name Str)] -> Bool
  :d "True if tag starts with lowercase letter."
  (if (string-empty? tag-name)
      true
      (not (is-uppercase-char? (option-or (string-slice tag-name 0 1) "")))))

(df extract-classes-from-line [(line Str)] -> (List Str)
  :d "Extracts class names from className= or class= attribute."
  (let [(c-idx (string-index-of line "className=\""))]
    (mt c-idx
      ((none)
       (let [(c2-idx (string-index-of line "class=\""))]
         (mt c2-idx
           ((none) (list))
           ((some idx)
            (let [(rest (option-or (string-slice line (+ idx 7) (string-length line)) ""))
                  (q-idx (string-index-of rest "\""))]
              (mt q-idx
                ((none) (list))
                ((some q)
                 (let [(val (option-or (string-slice rest 0 q) ""))
                       (tokens (string-split (string-trim val) " "))]
                   (filter (fn [(t Str)] -> Bool (> (string-length t) 0)) tokens)))))))))
      ((some idx)
       (let [(rest (option-or (string-slice line (+ idx 11) (string-length line)) ""))
             (q-idx (string-index-of rest "\""))]
         (mt q-idx
           ((none) (list))
           ((some q)
            (let [(val (option-or (string-slice rest 0 q) ""))
                  (tokens (string-split (string-trim val) " "))]
              (filter (fn [(t Str)] -> Bool (> (string-length t) 0)) tokens)))))))))

(df scan-line-for-tags [(line Str) (file-path Str) (line-num I64)] -> (List ElementUsage)
  :d "Extracts JSX/HTML element tags from a single line."
  (let [(parts (string-split line "<"))]
    (fold (fn [(acc (List ElementUsage)) (part Str)] -> (List ElementUsage)
            (let [(trimmed (string-trim part))]
              (if (or (string-empty? trimmed)
                      (or (string-starts-with? trimmed "/")
                          (or (string-starts-with? trimmed "!")
                              (string-starts-with? trimmed "?"))))
                  acc
                  (let [(space-idx (string-index-of trimmed " "))
                        (gt-idx (string-index-of trimmed ">"))
                        (slash-idx (string-index-of trimmed "/"))
                        (end-idx (min-valid-index space-idx gt-idx slash-idx (string-length trimmed)))
                        (tag-name (option-or (string-slice trimmed 0 end-idx) ""))]
                    (if (and (> (string-length tag-name) 0) (is-valid-tag-name? tag-name))
                        (let [(native (is-native-tag? tag-name))
                              (classes (extract-classes-from-line line))
                              (usage (ElementUsage
                                       :tag-name tag-name
                                       :is-native native
                                       :file-path file-path
                                       :line line-num
                                       :class-names classes))]
                          (list-append acc (list usage)))
                        acc)))))
          (list)
          parts)))

(df min-valid-index [(s (Option I64)) (g (Option I64)) (sl (Option I64)) (fallback I64)] -> I64
  :d "Finds smallest positive index delimiter."
  (let [(v1 (mt s ((none) fallback) ((some i) (if (> i 0) i fallback))))
        (v2 (mt g ((none) v1) ((some i) (if (and (> i 0) (< i v1)) i v1))))
        (v3 (mt sl ((none) v2) ((some i) (if (and (> i 0) (< i v2)) i v2))))]
    v3))

(df is-valid-tag-name? [(tag Str)] -> Bool
  :d "Checks if token has valid identifier characters for tag."
  (and (not (string-contains? tag "="))
       (and (not (string-contains? tag "\""))
            (not (string-contains? tag "{")))))

(df scan-component-usages [(source-code Str) (file-path Str)] -> ComponentMap
  :d "Scans source code for all component instances and native element tags."
  (let [(lines (string-split source-code "\n"))
        (usages (fold (fn [(acc (List ElementUsage)) (idx I64)] -> (List ElementUsage)
                        (let [(line (option-or (list-get lines idx) ""))
                              (line-usages (scan-line-for-tags line file-path (+ idx 1)))]
                          (list-concat acc line-usages)))
                      (list)
                      (range 0 (list-length lines))))
        (comp-count (list-length (filter (fn [(u ElementUsage)] -> Bool (not (.-is-native u))) usages)))
        (nat-count (list-length (filter (fn [(u ElementUsage)] -> Bool (.-is-native u)) usages)))]
    (ComponentMap
      :file-path file-path
      :usages usages
      :total-components comp-count
      :total-native nat-count)))

(df count-delimited-matches [(src Str) (target Str)] -> I64
  :d "Counts occurrences of target class bounded by quotes or whitespace."
  (let [(c1 (- (list-length (string-split src (str "\"" target "\""))) 1))
        (c2 (- (list-length (string-split src (str "\"" target " "))) 1))
        (c3 (- (list-length (string-split src (str " " target "\""))) 1))
        (c4 (- (list-length (string-split src (str " " target " "))) 1))
        (c5 (- (list-length (string-split src (str "'" target "'"))) 1))
        (c6 (- (list-length (string-split src (str "'" target " "))) 1))
        (c7 (- (list-length (string-split src (str " " target "'"))) 1))]
    (+ c1 (+ c2 (+ c3 (+ c4 (+ c5 (+ c6 c7))))))))

(df replace-delimited-class [(src Str) (target Str) (replacement Str)] -> Str
  :d "Replaces target class only when delimited by whitespace or quote boundaries."
  (let [(s1 (string-replace src (str "\"" target "\"") (str "\"" replacement "\"")))
        (s2 (string-replace s1 (str "\"" target " ") (str "\"" replacement " ")))
        (s3 (string-replace s2 (str " " target "\"") (str " " replacement "\"")))
        (s4 (string-replace s3 (str " " target " ") (str " " replacement " ")))
        (s5 (string-replace s4 (str "'" target "'") (str "'" replacement "'")))
        (s6 (string-replace s5 (str "'" target " ") (str "'" replacement " ")))
        (s7 (string-replace s6 (str " " target "'") (str " " replacement "'")))]
    s7))

(df batch-transform-classes [(source-code Str) (rule BatchTransformRule)] -> BatchTransformResult
  :d "Replaces target class names across matching file scope with word-boundary delimiters."
  (let [(target-str (.-old-class rule))
        (replace-str (.-new-class rule))
        (delimited-count (count-delimited-matches source-code target-str))]
    (if (> delimited-count 0)
        (let [(modified (replace-delimited-class source-code target-str replace-str))]
          (BatchTransformResult
            :occurrences-replaced delimited-count
            :modified-content modified))
        (if (string-contains? source-code target-str)
            (let [(occurrences (- (list-length (string-split source-code target-str)) 1))
                  (modified (string-replace source-code target-str replace-str))]
              (BatchTransformResult
                :occurrences-replaced occurrences
                :modified-content modified))
            (BatchTransformResult
              :occurrences-replaced 0
              :modified-content source-code)))))

(df audit-design-policy [(map ComponentMap) (forbidden-native-tags (List Str)) (replacement-component Str)] -> PolicyAuditReport
  :d "Audits component map against forbidden native elements in design policy."
  (let [(usages (.-usages map))
        (violations
          (fold (fn [(acc (List PolicyViolation)) (u ElementUsage)] -> (List PolicyViolation)
                  (if (and (.-is-native u) (list-contains? forbidden-native-tags (.-tag-name u)))
                      (let [(v (PolicyViolation
                                 :file-path (.-file-path u)
                                 :line (.-line u)
                                 :forbidden-tag (.-tag-name u)
                                 :recommended-replacement replacement-component
                                 :rule-name "no-raw-native-inputs"))]
                        (list-append acc (list v)))
                      acc))
                (list)
                usages))]
    (PolicyAuditReport
      :passed (list-empty? violations)
      :violations violations)))

(df hunt-library-residues [(source-code Str) (file-path Str) (decommissioned-lib Str) (known-symbols (List Str))] -> ResidueReport
  :d "Detects residual imports or calls from decommissioned third-party libraries."
  (let [(lines (string-split source-code "\n"))
        (matches
          (fold (fn [(acc (List ResidueMatch)) (idx I64)] -> (List ResidueMatch)
                  (let [(line (option-or (list-get lines idx) ""))]
                    (if (or (string-contains? line decommissioned-lib)
                            (any-symbol-in-line? line known-symbols))
                        (let [(m (ResidueMatch
                                   :file-path file-path
                                   :line (+ idx 1)
                                   :library-name decommissioned-lib
                                   :snippet (string-trim line)))]
                          (list-append acc (list m)))
                        acc)))
                (list)
                (range 0 (list-length lines))))]
    (ResidueReport
      :clean (list-empty? matches)
      :matches matches)))

(df any-symbol-in-line? [(line Str) (symbols (List Str))] -> Bool
  :d "Returns true if line contains any symbol in list."
  (fold (fn [(matched Bool) (sym Str)] -> Bool
          (or matched (string-contains? line sym)))
        false
        symbols))

(df format-component-map [(map ComponentMap)] -> Str
  :d "Formats component map into concise ASN summary."
  (let [(comps (filter (fn [(u ElementUsage)] -> Bool (not (.-is-native u))) (.-usages map)))
        (comp-names (s/join " " (map (fn [(u ElementUsage)] -> Str (.-tag-name u)) comps)))]
    (s/concat "(:component-map :file \"" (.-file-path map) "\" "
              ":components " (string-from-int64 (.-total-components map)) " "
              ":native " (string-from-int64 (.-total-native map)) " "
              ":tags [" comp-names "])")))
