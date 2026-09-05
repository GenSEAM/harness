(module asl-harness/compactor-test
  :d "Unit tests for context sliding-window compactor and fence stripper."
  :x [test-strip-code-fences test-truncate-output test-extract-sexpr test-compact-history run-tests]
  :i [(compactor :a comp)])

(df test-strip-code-fences [] -> Bool
  :d "Verifies markdown code fences are stripped cleanly."
  (let [(raw "```asl\n(df add [(a I64) (b I64)] (+ a b))\n```")
        (stripped (comp/strip-code-fences raw))]
    (and (= stripped "(df add [(a I64) (b I64)] (+ a b))")
         (not (string-contains? stripped "```")))))

(df test-truncate-output [] -> Bool
  :d "Verifies long terminal outputs are truncated preserving head and tail."
  (let [(lines (list "line 1" "line 2" "line 3" "line 4" "line 5" "line 6" "line 7" "line 8" "line 9" "line 10"))
        (text (string-join lines "\n"))
        (truncated (comp/truncate-output text 4))]
    (and (string-contains? truncated "line 1")
         (and (string-contains? truncated "line 10")
              (string-contains? truncated "lines omitted")))))

(df test-extract-sexpr [] -> Bool
  :d "Verifies S-expression is extracted from conversational preamble."
  (let [(chatter "Here is the code to fix the issue:\n(df fix [] true)")
        (extracted (comp/extract-sexpr chatter))]
    (and (string-starts-with? extracted "(df fix")
         (string-ends-with? extracted "true)"))))

(df test-compact-history [] -> Bool
  :d "Verifies older turns are compacted into 1-line receipts."
  (let [(hist (list "recent 1" "recent 2" "exec-cmd: test gate passed" "fs-read: src/paged.asl"))
        (compacted (comp/compact-history hist 2))]
    (and (= (list-length compacted) 4)
         (and (= (option-or (list-head compacted) "") "recent 1")
              (string-contains? (option-or (list-last compacted) "") "fs-read file cached")))))

(df run-tests [] -> Bool
  :d "Executes full compactor test suite."
  (and (test-strip-code-fences)
       (and (test-truncate-output)
            (and (test-extract-sexpr)
                 (test-compact-history)))))

