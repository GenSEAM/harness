(module asl-harness/compactor-test
  :d "Unit tests for context sliding-window compactor and fence stripper."
  :x [test-strip-code-fences test-truncate-output test-extract-sexpr test-compact-history test-compact-at-watermark run-tests]
  :i [(compactor :a comp)])

(df test-strip-code-fences [] -> Bool
  :d "Verifies markdown code fences are stripped cleanly."
  (let [(raw "```asl\n(df add [(a I64) (b I64)] (+ a b))\n```")
        (stripped (comp/strip-code-fences raw))]
    (assert (= stripped "(df add [(a I64) (b I64)] (+ a b))") "fences stripped")
    (assert (not (string-contains? stripped "```")) "no backticks remain")
    true))

(df test-truncate-output [] -> Bool
  :d "Verifies long terminal outputs are truncated preserving head and tail."
  (let [(lines (list "line 1" "line 2" "line 3" "line 4" "line 5" "line 6" "line 7" "line 8" "line 9" "line 10"))
        (text (string-join lines "\n"))
        (truncated (comp/truncate-output text 4))]
    (assert (string-contains? truncated "line 1") "contains head line 1")
    (assert (string-contains? truncated "line 10") "contains tail line 10")
    (assert (string-contains? truncated "lines omitted") "contains omitted receipt")
    true))

(df test-extract-sexpr [] -> Bool
  :d "Verifies S-expression is extracted from conversational preamble."
  (let [(chatter "Here is the code to fix the issue:\n(df fix [] true)")
        (extracted (comp/extract-sexpr chatter))]
    (assert (string-starts-with? extracted "(df fix") "starts with (df fix")
    (assert (string-ends-with? extracted "true)") "ends with true)")
    true))

(df test-compact-history [] -> Bool
  :d "Verifies older turns are compacted into 1-line receipts."
  (let [(hist (list "recent 1" "recent 2" "exec-cmd: test gate passed" "fs-read: src/paged.asl"))
        (compacted (comp/compact-history hist 2))]
    (assert (= (list-length compacted) 4) "compacted list length is 4")
    (assert (= (option-or (list-head compacted) "") "recent 1") "head matches recent 1")
    (assert (string-contains? (option-or (list-last compacted) "") "fs-read file cached") "last compacted contains receipt")
    true))

(df test-compact-at-watermark [] -> Bool
  :d "Verifies deterministic watermark-driven compaction at normal, soft (60%), and hard (80%) thresholds."
  (let [(hist (list "recent 1" "recent 2" "recent 3" "recent 4" "recent 5" "ast-patch: src/main.asl" "exec-cmd: test gate passed"))
        (under-watermark (comp/compact-at-watermark hist 50 100))
        (soft-watermark (comp/compact-at-watermark hist 65 100))
        (hard-watermark (comp/compact-at-watermark hist 85 100))]
    (assert (= (list-length under-watermark) 7) "under watermark retains verbatim length")
    (assert (= (option-or (list-last under-watermark) "") "exec-cmd: test gate passed") "under watermark retains verbatim last item")
    (assert (= (list-length soft-watermark) 7) "soft watermark retains total length")
    (assert (string-contains? (option-or (list-last soft-watermark) "") "exec-cmd verified gate") "soft watermark compacts older turns to receipt")
    (assert (string-contains? (option-or (list-last hard-watermark) "") "exec-cmd verified gate") "hard watermark compacts older turns to receipt")
    (assert (string-contains? (option-or (list-head (list-drop hard-watermark 2)) "") "ast-patch executed cleanly") "hard watermark keeps only 2 recent turns verbatim")
    true))

(df run-tests [] -> Bool
  :d "Executes full compactor test suite."
  (do
    (test-strip-code-fences)
    (test-truncate-output)
    (test-extract-sexpr)
    (test-compact-history)
    (test-compact-at-watermark)
    true))

