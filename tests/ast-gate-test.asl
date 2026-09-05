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
    (and (.-allowed verdict)
         (and (list-empty? (.-violations verdict))
              (and (string-contains? (.-reason verdict) "preserved")
                   (string-contains? formatted ":allowed true"))))))

(df test-ast-mutation-deleted-assertion-blocked [] -> Bool
  :d "Verifies that deleting or commenting out a protected assertion is rejected."
  (let [(pre-code "(df add [(a I64) (b I64)] -> I64 (+ a b))\n\n(df test-add [] -> Bool (= (add 1 2) 3))\n\n(df test-security-invariants [] -> Bool (assert-safe))\n")
        (post-deleted "(df add [(a I64) (b I64)] -> I64 (+ a b))\n\n(df test-add [] -> Bool (= (add 1 2) 3))\n")
        (post-commented "(df add [(a I64) (b I64)] -> I64 (+ a b))\n\n(df test-add [] -> Bool (= (add 1 2) 3))\n\n;; (df test-security-invariants [] -> Bool (assert-safe))\n")
        (protected (list "test-security-invariants"))
        (v-del (gate/audit-ast-mutation pre-code post-deleted protected))
        (v-com (gate/audit-ast-mutation pre-code post-commented protected))
        (fmt-del (gate/format-mutation-verdict v-del))]
    (and (not (.-allowed v-del))
         (and (list-contains? (.-violations v-del) "test-security-invariants")
              (and (not (.-allowed v-com))
                   (and (list-contains? (.-violations v-com) "test-security-invariants")
                        (string-contains? fmt-del ":allowed false")))))))

(df test-ast-mutation-multiple-violations [] -> Bool
  :d "Verifies that multiple missing or commented out protected symbols are all recorded in violations list."
  (let [(pre-code "(df test-auth-token [] -> Bool (check-token))\n(df test-leak-prevention [] -> Bool (check-leak))\n(df test-audit-log [] -> Bool (check-log))\n")
        (post-code ";; (df test-auth-token [] -> Bool (check-token))\n(df test-audit-log [] -> Bool (check-log))\n")
        (protected (list "test-auth-token" "test-leak-prevention" "test-unrelated-symbol"))
        (verdict (gate/audit-ast-mutation pre-code post-code protected))
        (violations (.-violations verdict))]
    (and (not (.-allowed verdict))
         (and (= (list-length violations) 2)
              (and (list-contains? violations "test-auth-token")
                   (and (list-contains? violations "test-leak-prevention")
                        (not (list-contains? violations "test-unrelated-symbol"))))))))

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
    (and (= (.-target-file trace) "src/server/auth.py")
         (and (= (.-line-number trace) 42)
              (and (string-contains? (.-error-message trace) "AssertionError")
                   (and (not (string-contains? (.-sanitized-output trace) "site-packages"))
                        (and (not (string-contains? (.-sanitized-output trace) "pluggy"))
                             (and (string-contains? (.-sanitized-output trace) "src/server/auth.py")
                                  (string-contains? formatted ":sanitized-trace")))))))))

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
    (and (<= (.-token-count trace-small) 50)
         (and (< (.-token-count trace-capped) 300)
              (and (string-contains? (.-error-message trace-small) "AssertionError")
                   (= (.-target-file trace-small) "src/core/engine.py"))))))

(df run-tests [] -> Bool
  :d "Executes full AST gate and error trace sanitizer test suite."
  (and (test-ast-mutation-clean-edit)
       (and (test-ast-mutation-deleted-assertion-blocked)
            (and (test-ast-mutation-multiple-violations)
                 (and (test-sanitize-noisy-traceback)
                      (test-sanitize-token-budget))))))
