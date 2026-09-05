(module asl-harness/sanitizer
  :d "Error Trace Sanitizer: strips noisy framework frames, extracts root failure site, and bounds output tokens."
  :x [SanitizedTrace sanitize-trace format-sanitized-trace]
  :i [])

(dfs SanitizedTrace
  (:f target-file Str "Target failing source file extracted from traceback")
  (:f line-number I64 "Line number where assertion or failure occurred")
  (:f error-message Str "Root failure or assertion error message")
  (:f token-count I64 "Estimated token count of sanitized output")
  (:f sanitized-output Str "Clean, bounded diagnostic output for agent prompt"))

(df estimate-trace-tokens [(text Str)] -> I64
  :d "Deterministic token count heuristic: max(1, length / 4), or 0 if empty."
  (let [(len (string-length text))]
    (if (<= len 0)
        0
        (let [(q (/ len 4))]
          (if (<= q 0) 1 q)))))

(df is-framework-noise? [(line Str)] -> Bool
  :d "Identifies noisy internal test runner and runtime framework frames."
  (let [(trimmed (string-trim line))]
    (cond
      ((string-empty? trimmed) false)
      ;; Python noisy framework frames
      ((string-contains? trimmed "site-packages") true)
      ((string-contains? trimmed "dist-packages") true)
      ((string-contains? trimmed "/usr/lib/python") true)
      ((string-contains? trimmed "/usr/local/lib/python") true)
      ((string-contains? trimmed "_pytest") true)
      ((string-contains? trimmed "pluggy") true)
      ((string-contains? trimmed "pytest/runner.py") true)
      ;; Rust runtime noise
      ((string-contains? trimmed "rust_begin_unwind") true)
      ((string-contains? trimmed "core::panicking") true)
      ((string-contains? trimmed "library/std/") true)
      ((string-contains? trimmed "library/core/") true)
      ((string-contains? trimmed "library/alloc/") true)
      ((string-contains? trimmed "/rustc/") true)
      ((string-contains? trimmed "stack backtrace:") true)
      ;; Node/JS noise
      ((string-contains? trimmed "node_modules") true)
      ((string-contains? trimmed "node:internal") true)
      ((string-contains? trimmed "internal/modules") true)
      (:else false))))

(df extract-digits [(text Str)] -> Str
  :d "Extracts consecutive leading digit characters from string."
  (let [(chars (string-chars (string-trim text)))
        (digits (fold (fn [(acc (Pair (List Str) Bool)) (c Str)] -> (Pair (List Str) Bool)
                        (if (snd acc)
                            acc
                            (if (or (= c "0")
                                    (or (= c "1")
                                        (or (= c "2")
                                            (or (= c "3")
                                                (or (= c "4")
                                                    (or (= c "5")
                                                        (or (= c "6")
                                                            (or (= c "7")
                                                                (or (= c "8")
                                                                    (= c "9"))))))))))
                                (pair (list-append (fst acc) (list c)) false)
                                (pair (fst acc) true))))
                      (pair (list) false)
                      chars))]
    (string-join (fst digits) "")))

(df extract-frame-info [(line Str)] -> (Pair Str I64)
  :d "Extracts failing target file and line number from a stack frame line."
  (cond
    ;; Python traceback format: File "path/file.ext", line 123
    ((string-contains? line "File \"")
     (let [(after-file (option-or (string-slice line (+ (option-or (string-index-of line "File \"") 0) 6) (string-length line)) ""))
           (q-idx (option-or (string-index-of after-file "\"") 0))
           (file-path (option-or (string-slice after-file 0 q-idx) ""))
           (line-marker (string-index-of line ", line "))]
       (mt line-marker
         ((some l-idx)
          (let [(after-line (option-or (string-slice line (+ l-idx 7) (string-length line)) ""))
                (digits (extract-digits after-line))
                (ln (option-or (string-to-int64 digits) 0))]
            (pair file-path ln)))
         ((none) (pair file-path 0)))))

    ;; Polyglot colon format: path/file.ext:123
    (:else
     (let [(words (string-split (string-trim line) " "))]
       (fold (fn [(acc (Pair Str I64)) (w Str)] -> (Pair Str I64)
               (if (> (string-length (fst acc)) 0)
                   acc
                   (let [(w-clean (string-replace (string-replace (string-replace w "(" "") ")" "") "'" ""))
                         (parts (string-split w-clean ":"))]
                     (if (>= (list-length parts) 2)
                         (let [(p0 (option-or (list-head parts) ""))
                               (p1 (option-or (list-head (list-drop parts 1)) ""))
                               (digits (extract-digits p1))]
                           (if (and (string-contains? p0 ".") (> (string-length digits) 0))
                               (pair p0 (option-or (string-to-int64 digits) 0))
                               acc))
                         acc))))
             (pair "" 0)
             words)))))

(df extract-target-site [(lines (List Str))] -> (Pair Str I64)
  :d "Finds the failing target file and line number across non-noise traceback frames."
  (fold (fn [(acc (Pair Str I64)) (ln Str)] -> (Pair Str I64)
          (if (is-framework-noise? ln)
              acc
              (let [(frame (extract-frame-info ln))]
                (if (> (string-length (fst frame)) 0)
                    frame
                    acc))))
        (pair "" 0)
        lines))

(df is-error-line? [(line Str)] -> Bool
  :d "Checks if a line contains root failure or assertion error description."
  (let [(trimmed (string-trim line))]
    (cond
      ((string-starts-with? trimmed "E   ") true)
      ((string-contains? trimmed "AssertionError") true)
      ((string-contains? trimmed "assertion failed") true)
      ((string-contains? trimmed "panicked at") true)
      ((string-contains? trimmed "Error:") true)
      ((string-contains? trimmed "FAILED") true)
      (:else false))))

(df clean-error-text [(line Str)] -> Str
  :d "Strips error prefixes and formats concise root failure message."
  (let [(trimmed (string-trim line))]
    (if (string-starts-with? trimmed "E   ")
        (string-trim (option-or (string-slice trimmed 4 (string-length trimmed)) trimmed))
        trimmed)))

(df extract-error-message [(lines (List Str))] -> Str
  :d "Finds the root error or assertion failure from traceback lines."
  (let [(explicit-error (fold (fn [(acc Str) (ln Str)] -> Str
                                (if (is-error-line? ln)
                                    (clean-error-text ln)
                                    acc))
                              ""
                              lines))]
    (if (> (string-length explicit-error) 0)
        explicit-error
        ;; Fallback to last non-empty line
        (fold (fn [(acc Str) (ln Str)] -> Str
                (let [(t (string-trim ln))]
                  (if (> (string-length t) 0) t acc)))
              "Unknown error"
              lines))))

(df sanitize-trace [(raw-traceback Str) (max-tokens I64)] -> SanitizedTrace
  :d "Strips internal framework frames, extracts root failure site, and bounds output tokens."
  (let [(lines (string-split raw-traceback "\n"))
        ;; Step 1: Filter out noisy internal framework frames
        (clean-lines (fold (fn [(acc (List Str)) (ln Str)] -> (List Str)
                             (if (is-framework-noise? ln)
                                 acc
                                 (list-append acc (list ln))))
                           (list)
                           lines))
        ;; Step 2: Extract failure site and root error message
        (site (extract-target-site clean-lines))
        (tgt-file (fst site))
        (line-no (snd site))
        (err-msg (extract-error-message clean-lines))
        ;; Step 3: Format initial clean output
        (raw-output (string-trim (string-join clean-lines "\n")))
        (base-output (if (string-empty? raw-output)
                         (str tgt-file ":" (string-from-int64 line-no) ": " err-msg)
                         raw-output))
        ;; Step 4: Token ceiling calculation (strictly bounded to max-tokens and < 300)
        (effective-budget (if (<= max-tokens 0) 250 (min max-tokens 299)))
        (max-chars (* effective-budget 4))
        (bounded-output (if (> (string-length base-output) max-chars)
                            (let [(head-chars (/ max-chars 2))
                                  (tail-chars (/ max-chars 2))
                                  (s-head (option-or (string-slice base-output 0 head-chars) ""))
                                  (s-tail (option-or (string-slice base-output (- (string-length base-output) tail-chars) (string-length base-output)) ""))]
                              (str s-head "\n... [truncated] ...\n" s-tail))
                            base-output))
        ;; Ensure hard clamp on character length
        (final-output (if (> (string-length bounded-output) max-chars)
                          (option-or (string-slice bounded-output 0 max-chars) bounded-output)
                          bounded-output))
        (final-tokens (estimate-trace-tokens final-output))]
    (SanitizedTrace
      :target-file tgt-file
      :line-number line-no
      :error-message err-msg
      :token-count final-tokens
      :sanitized-output final-output)))

(df format-sanitized-trace [(trace SanitizedTrace)] -> Str
  :d "Formats a sanitized traceback into a structured diagnostic block."
  (let [(safe-output (string-replace (string-replace (.-sanitized-output trace) "\"" "'") "\n" " "))
        (safe-error (string-replace (.-error-message trace) "\"" "'"))]
    (str "(:sanitized-trace :file \"" (.-target-file trace)
         "\" :line " (string-from-int64 (.-line-number trace))
         " :error \"" safe-error
         "\" :tokens " (string-from-int64 (.-token-count trace))
         " :diagnostic \"" safe-output "\")")))
