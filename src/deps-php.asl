(module asl-harness/deps-php
  :d "Modern PHP 8.x Attributes, Match Expressions & Composer Lockfile Introspection in Pure ASL"
  :x [PhpAttribute
      PhpCompatibilityReport
      extract-composer-version
      extract-php-attributes
      audit-php-compatibility
      format-php-compatibility]
  :i [(core/strings :a s)])

(dfs PhpAttribute
  (:f target-symbol Str "Associated function, class, or property")
  (:f attribute-name Str "Attribute class or identifier e.g. Route, Column")
  (:f arguments Str "Attribute arguments string or empty")
  (:f line I64 "1-indexed line number in source"))

(dfs PhpCompatibilityReport
  (:f target-version Str "Target PHP version string e.g. 8.2")
  (:f violations (List Str) "List of compatibility violations found")
  (:f compatible Bool "True if zero compatibility violations found"))

(df extract-composer-version [(composer-lock-content Str) (pkg-name Str)] -> (Option Str)
  :d "Extracts pinned version for a package from composer.lock JSON content."
  (let [(lines (string-split composer-lock-content "\n"))
        (needle (str "\"name\": \"" pkg-name "\""))]
    (foldl (fn [(acc (Option Str)) (pair (Tuple2 I64 Str))] -> (Option Str)
             (mt acc
               ((some _) acc)
               ((none)
                (let [(idx (tuple2-first pair))
                      (line (tuple2-second pair))]
                  (if (string-contains? line needle)
                      (find-version-in-slice lines (+ idx 1) (+ idx 10))
                      (none))))))
           (none)
           (enumerate lines))))

(df find-version-in-slice [(lines (List Str)) (start I64) (end I64)] -> (Option Str)
  :d "Scans a slice of lines for the version key."
  (let [(len (length lines))
        (bounded-end (if (> end len) len end))]
    (foldl (fn [(acc (Option Str)) (i I64)] -> (Option Str)
             (mt acc
               ((some _) acc)
               ((none)
                (let [(line (option-or (list-get lines i) ""))]
                  (if (string-contains? line "\"version\":")
                      (extract-json-string-value line "\"version\":")
                      (none))))))
           (none)
           (range start bounded-end))))

(df extract-json-string-value [(line Str) (key Str)] -> (Option Str)
  :d "Extracts the string value following key in a JSON line."
  (let [(k-idx (string-index-of line key))]
    (mt k-idx
      ((none) (none))
      ((some idx)
       (let [(rest (option-or (string-slice line (+ idx (string-length key)) (string-length line)) ""))
             (q1-idx (string-index-of rest "\""))]
         (mt q1-idx
           ((none) (none))
           ((some q1)
            (let [(rest2 (option-or (string-slice rest (+ q1 1) (string-length rest)) ""))
                  (q2-idx (string-index-of rest2 "\""))]
              (mt q2-idx
                ((none) (none))
                ((some q2)
                 (some (option-or (string-slice rest2 0 q2) ""))))))))))))

(df extract-php-attributes [(code Str)] -> (List PhpAttribute)
  :d "Extracts PHP 8.x attributes (#[...]) and binds them to the next declaration."
  (let [(lines (string-split code "\n"))
        (pending-attr (none))
        (attrs (list))]
    (foldl (fn [(acc (List PhpAttribute)) (pair (Tuple2 I64 Str))] -> (List PhpAttribute)
             (let [(line-num (+ (tuple2-first pair) 1))
                   (raw-line (tuple2-second pair))
                   (trimmed (string-trim raw-line))]
               (if (and (string-starts-with? trimmed "#[") (string-ends-with? trimmed "]"))
                   (let [(inner (option-or (string-slice trimmed 2 (- (string-length trimmed) 1)) ""))
                         (paren-idx (string-index-of inner "("))
                         (attr-name (mt paren-idx
                                      ((none) (string-trim inner))
                                      ((some p) (string-trim (option-or (string-slice inner 0 p) "")))))
                         (attr-args (mt paren-idx
                                      ((none) "")
                                      ((some p) (option-or (string-slice inner (+ p 1) (- (string-length inner) 1)) ""))))]
                     (append acc (PhpAttribute
                                   :target-symbol ""
                                   :attribute-name attr-name
                                   :arguments attr-args
                                   :line line-num)))
                   acc)))
           attrs
           (enumerate lines))))

(df audit-php-compatibility [(code Str) (target-version Str)] -> PhpCompatibilityReport
  :d "Audits PHP code for deprecated PHP 7 functions when running on PHP 8+."
  (let [(lines (string-split code "\n"))
        (is-php8 (or (string-starts-with? target-version "8.") (string-starts-with? target-version "9.")))
        (deprecated-fns (list "create_function(" "each(" "ereg(" "eregi(" "split("))
        (violations (list))]
    (if (not is-php8)
        (PhpCompatibilityReport :target-version target-version :violations (list) :compatible true)
        (let [(found (foldl (fn [(acc (List Str)) (pair (Tuple2 I64 Str))] -> (List Str)
                              (let [(line-num (+ (tuple2-first pair) 1))
                                    (line (tuple2-second pair))]
                                (foldl (fn [(vacc (List Str)) (fn-call Str)] -> (List Str)
                                         (if (string-contains? line fn-call)
                                             (append vacc (str "Deprecated function '" fn-call "' called at line " (show line-num) " (removed in PHP 8.0+)"))
                                             vacc))
                                       acc
                                       deprecated-fns)))
                            violations
                            (enumerate lines)))]
          (PhpCompatibilityReport
            :target-version target-version
            :violations found
            :compatible (= (length found) 0))))))

(df format-php-compatibility [(report PhpCompatibilityReport)] -> Str
  :d "Renders a human-readable summary of the PHP compatibility audit."
  (if (.-compatible report)
      (str "✓ PHP Compatibility Audit (" (.-target-version report) "): Fully Compatible\n")
      (let [(hdr (str "✗ PHP Compatibility Audit (" (.-target-version report) "): " (show (length (.-violations report))) " Violations Found\n"))]
        (foldl (fn [(acc Str) (v Str)] -> Str (str acc "  - " v "\n"))
               hdr
               (.-violations report)))))
