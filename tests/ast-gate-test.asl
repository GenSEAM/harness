(module asl-harness/ast-gate-test
  :d "Unit tests for AST Mutation Gate (Delta_AST) and Error Trace Sanitizer."
  :x [test-ast-mutation-clean-edit test-ast-mutation-deleted-assertion-blocked
      test-ast-mutation-multiple-violations test-sanitize-noisy-traceback
      test-sanitize-token-budget run-tests]
  :i [(ast-gate :a gate) (sanitizer :a s)])

(df test-ast-mutation-clean-edit [] -> Bool
  :d "Verifies that an edit preserving all protected symbols and assertions passes the AST mutation gate."
  (let [(pre-code "(df calculate [(x I64)] -> I64 (+ x 1))\n\n(df test-calculate [] -> Bool (= (calculate 1) 2))\n\n(df test-security-boundary [] -> Bool true)\n")
        (post-code "(df calculate [(x I64)] -> I64 (+ x 2))\n\n(df test-calculate [] -> Bool (= (calculate 1) 3))\n\n(df test-security-boundary [] -> Bool true)\n")
        (protected (list "test-calculate" "test-security-boundary"))
        (verdict (gate/audit-ast-mutation pre-code post-code protected))
        (formatted (gate/format-mutation-verdict verdict))]
    (assert (.-allowed verdict) "clean edit allowed")
    (assert (list-empty? (.-violations verdict)) "no violations on clean edit")
    (assert (string-contains? (.-reason verdict) "preserved") "reason notes preserved")
    (assert (string-contains? formatted ":allowed true") "formatted notes allowed")
    true))

(df test-ast-mutation-deleted-assertion-blocked [] -> Bool
  :d "Verifies that deleting or commenting out a protected assertion is rejected."
  (let [(pre-code "(df add [(a I64) (b I64)] -> I64 (+ a b))\n\n(df test-add [] -> Bool (= (add 1 2) 3))\n\n(df test-security-invariants [] -> Bool (assert-safe))\n")
        (post-deleted "(df add [(a I64) (b I64)] -> I64 (+ a b))\n\n(df test-add [] -> Bool (= (add 1 2) 3))\n")
        (post-commented "(df add [(a I64) (b I64)] -> I64 (+ a b))\n\n(df test-add [] -> Bool (= (add 1 2) 3))\n\n;; (df test-security-invariants [] -> Bool (assert-safe))\n")
        (protected (list "test-security-invariants"))
        (v-del (gate/audit-ast-mutation pre-code post-deleted protected))
        (v-com (gate/audit-ast-mutation pre-code post-commented protected))
        (fmt-del (gate/format-mutation-verdict v-del))]
    (assert (not (.-allowed v-del)) "deleted assertion disallowed")
    (assert (list-contains? (.-violations v-del) "test-security-invariants") "deleted assertion in violations")
    (assert (not (.-allowed v-com)) "commented assertion disallowed")
    (assert (list-contains? (.-violations v-com) "test-security-invariants") "commented assertion in violations")
    (assert (string-contains? fmt-del ":allowed false") "formatted marks disallowed")
    true))

(df test-ast-mutation-multiple-violations [] -> Bool
  :d "Verifies that multiple missing or commented out protected symbols are all recorded in violations list."
  (let [(pre-code "(df test-auth-token [] -> Bool (check-token))\n(df test-leak-prevention [] -> Bool (check-leak))\n(df test-audit-log [] -> Bool (check-log))\n")
        (post-code ";; (df test-auth-token [] -> Bool (check-token))\n(df test-audit-log [] -> Bool (check-log))\n")
        (protected (list "test-auth-token" "test-leak-prevention" "test-unrelated-symbol"))
        (verdict (gate/audit-ast-mutation pre-code post-code protected))
        (violations (.-violations verdict))]
    (assert (not (.-allowed verdict)) "multiple violations disallowed")
    (assert (= (list-length violations) 2) "two violations recorded")
    (assert (list-contains? violations "test-auth-token") "auth token in violations")
    (assert (list-contains? violations "test-leak-prevention") "leak prevention in violations")
    (assert (not (list-contains? violations "test-unrelated-symbol")) "unrelated symbol not in violations")
    true))

(df test-sanitize-noisy-traceback [] -> Bool
  :d "Verifies that noisy internal framework frames are stripped and root failure site is extracted."
  (let [(raw-trace (str "Traceback (most recent call last):\n"
                        "  File \"/usr/local/lib/python3.11/site-packages/pytest/runner.py\", line 123, in run\n"
                        "    result = call()\n"
                        "  File \"/usr/local/lib/python3.11/site-packages/pluggy/_hooks.py\", line 45, in _hookexec\n"
                        "    return self._inner_hookexec(hook_name, methods, kwargs)\n"
                        "  File \"src/server/auth.py\", line 42, in verify_token\n"
                        "    raise AssertionError(\"Expected valid token, got null\")\n"
                        "AssertionError: Expected valid token, got null\n"))
        (trace (s/sanitize-trace raw-trace 200))
        (formatted (s/format-sanitized-trace trace))]
    (assert (= (.-target-file trace) "src/server/auth.py") "target file extracted")
    (assert (= (.-line-number trace) 42) "line number extracted")
    (assert (string-contains? (.-error-message trace) "AssertionError") "error message extracted")
    (assert (not (string-contains? (.-sanitized-output trace) "site-packages")) "stripped site-packages")
    (assert (not (string-contains? (.-sanitized-output trace) "pluggy")) "stripped pluggy")
    (assert (string-contains? (.-sanitized-output trace) "src/server/auth.py") "contains root file")
    (assert (string-contains? formatted ":sanitized-trace") "formatted contains sanitized-trace")
    true))

(df test-sanitize-token-budget [] -> Bool
  :d "Verifies that sanitized output is strictly bounded to max-tokens < 300 even with huge tracebacks."
  (let [(huge-line "   at core::panicking::panic_fmt (/rustc/12345/library/core/src/panicking.rs:142)\n")
        (huge-log (str huge-line huge-line huge-line huge-line huge-line
                       huge-line huge-line huge-line huge-line huge-line
                       huge-line huge-line huge-line huge-line huge-line
                       huge-line huge-line huge-line huge-line huge-line
                       "  File \"src/core/engine.py\", line 108, in evaluate\n"
                       "    assert state == expected\n"
                       "AssertionError: assert 42 == 100\n"
                       huge-line huge-line huge-line huge-line huge-line))
        (trace-small (s/sanitize-trace huge-log 50))
        (trace-capped (s/sanitize-trace huge-log 500))]
    (assert (<= (.-token-count trace-small) 50) "small trace within 50 tokens")
    (assert (< (.-token-count trace-capped) 300) "capped trace under 300 tokens")
    (assert (string-contains? (.-error-message trace-small) "AssertionError") "assertion error captured")
    (assert (= (.-target-file trace-small) "src/core/engine.py") "target file captured")
    true))

(df run-tests [] -> Bool
  :d "Executes full AST gate and error trace sanitizer test suite."
  (do
    (test-ast-mutation-clean-edit)
    (test-ast-mutation-deleted-assertion-blocked)
    (test-ast-mutation-multiple-violations)
    (test-sanitize-noisy-traceback)
    (test-sanitize-token-budget)
    true))
