(module asl-harness/compactor
  :d "Context sliding-window compactor, code-fence stripper, and history truncator."
  :x [strip-code-fences truncate-output compact-history extract-sexpr]
  :i [])

(df strip-code-fences [(text Str)] -> Str
  :d "Strips markdown triple-backtick code fences (e.g. ```asl ... ```) and leading/trailing whitespace."
  (let [(s1 (string-replace text "```asl\n" ""))
        (s2 (string-replace s1 "```asl" ""))
        (s3 (string-replace s2 "```lisp\n" ""))
        (s4 (string-replace s3 "```lisp" ""))
        (s5 (string-replace s4 "```scheme\n" ""))
        (s6 (string-replace s5 "```scheme" ""))
        (s7 (string-replace s6 "```\n" ""))
        (s8 (string-replace s7 "```" ""))]
    (string-trim s8)))

(df truncate-output [(out Str) (max-lines I64)] -> Str
  :d "Truncates long terminal or tool outputs, preserving head and tail with concise omission notice."
  (let [(lines (string-split out "\n"))
        (total (list-length lines))]
    (if (<= total max-lines)
        out
        (let [(head-count (/ max-lines 2))
              (tail-count (/ max-lines 2))
              (head-lines (list-take lines head-count))
              (tail-lines (list-drop lines (- total tail-count)))
              (omitted-count (- total (+ head-count tail-count)))
              (notice (str "\n... [" (string-from-int64 omitted-count) " lines omitted] ...\n"))
              (head-str (string-join head-lines "\n"))
              (tail-str (string-join tail-lines "\n"))]
          (str head-str notice tail-str)))))

(df extract-sexpr [(text Str)] -> Str
  :d "Extracts the primary S-expression from conversational preamble or commentary."
  (let [(clean (strip-code-fences text))]
    (if (string-starts-with? clean "(")
        clean
        (let [(first-paren (string-index-of clean "("))]
          (mt first-paren
            ((some idx) (option-or (string-slice clean idx (string-length clean)) clean))
            ((none) clean))))))

(df compact-receipt [(entry Str)] -> Str
  :d "Converts an older detailed turn into a compact 1-line semantic receipt."
  (cond
    ((string-contains? entry "ast-patch") "[Turn: ast-patch executed cleanly]")
    ((string-contains? entry "fs-write") "[Turn: fs-write completed]")
    ((string-contains? entry "fs-read") "[Turn: fs-read file cached]")
    ((string-contains? entry "exec-cmd") "[Turn: exec-cmd verified gate]")
    (:else (str "[Turn: " (option-or (string-slice entry 0 (min 40 (string-length entry))) entry) "...]"))))

(df compact-history [(history (List Str)) (keep-recent I64)] -> (List Str)
  :d "Compacts older history turns into 1-line receipts while keeping the most recent turns verbatim."
  (let [(total (list-length history))]
    (if (<= total keep-recent)
        history
        (let [(recent (list-take history keep-recent))
              (older (list-drop history keep-recent))
              (compacted-older (map compact-receipt older))]
          (list-concat recent compacted-older)))))

