(module asl-harness/repl-test
  :d "Unit tests for pure AgentScript in-memory REPL inspector and AST node patcher."
  :x [test-eval-expression test-patch-ast-node test-semantic-error-formatting run-tests]
  :i [(repl :a repl)])

(df test-eval-expression [] -> Bool
  :d "Verifies sub-0.05ms in-memory S-expression evaluation with bindings, arithmetic, and error handling."
  (let [(sess0 (repl/new-repl-session "sess-alpha"))
        (res-add (repl/eval-expression sess0 "(+ 10 20)"))
        (res-mul (repl/eval-expression sess0 "(* 6 7)"))
        (res-sub (repl/eval-expression sess0 "(- 50 8)"))
        (res-lit (repl/eval-expression sess0 "42"))
        (res-bool (repl/eval-expression sess0 "true"))
        (sess-bound (repl/ReplSession
                      :session-id "sess-beta"
                      :bindings (map-set (map-empty) "x" "15")
                      :history (list)))
        (res-bound (repl/eval-expression sess-bound "(+ x 5)"))
        (res-div0 (repl/eval-expression sess0 "(/ 10 0)"))
        (res-unbalanced (repl/eval-expression sess0 "(+ 10 20"))
        (res-empty (repl/eval-expression sess0 ""))]
    (assert (= (.-session-id sess0) "sess-alpha") "session id matches")
    (assert (.-success res-add) "res-add success")
    (assert (= (.-output res-add) "30") "res-add output is 30")
    (assert (< (.-latency-micros res-add) 50) "res-add latency < 50")
    (assert (.-success res-mul) "res-mul success")
    (assert (= (.-output res-mul) "42") "res-mul output is 42")
    (assert (< (.-latency-micros res-mul) 50) "res-mul latency < 50")
    (assert (.-success res-sub) "res-sub success")
    (assert (= (.-output res-sub) "42") "res-sub output is 42")
    (assert (.-success res-lit) "res-lit success")
    (assert (= (.-output res-lit) "42") "res-lit output is 42")
    (assert (.-success res-bool) "res-bool success")
    (assert (= (.-output res-bool) "true") "res-bool output is true")
    (assert (.-success res-bound) "res-bound success")
    (assert (= (.-output res-bound) "20") "res-bound output is 20")
    (assert (< (.-latency-micros res-bound) 50) "res-bound latency < 50")
    (assert (not (.-success res-div0)) "div0 failed")
    (assert (string-contains? (.-error-detail res-div0) "Division by zero") "div0 error message")
    (assert (not (.-success res-unbalanced)) "unbalanced failed")
    (assert (string-contains? (.-error-detail res-unbalanced) "Unbalanced delimiters") "unbalanced error message")
    (assert (not (.-success res-empty)) "empty failed")
    (assert (string-contains? (.-error-detail res-empty) "Empty expression") "empty error message")
    true))

(df test-patch-ast-node [] -> Bool
  :d "Verifies AST node substitution and patching without full file rewrite."
  (let [(src1 "(df calc [(x I64)] (+ x 10))")
        (patched1 (repl/patch-ast-node src1 "(+ x 10)" "(* x 2)"))
        (src2 "(df old-calc [(x I64)] (+ x 10))")
        (patched2 (repl/patch-ast-node src2 "old-calc" "new-calc"))
        (src3 "(df calc [(x I64)] (+ x 10))")
        (patched3 (repl/patch-ast-node src3 "non-existent" "foo"))
        (patched4 (repl/patch-ast-node src3 "" "foo"))]
    (assert (= patched1 "(df calc [(x I64)] (* x 2))") "patched1 matches")
    (assert (= patched2 "(df new-calc [(x I64)] (+ x 10))") "patched2 matches")
    (assert (= patched3 src3) "patched3 unchanged")
    (assert (= patched4 src3) "patched4 unchanged")
    true))

(df test-semantic-error-formatting [] -> Bool
  :d "Verifies structured semantic traceback generation with form, line, and reason."
  (let [(err (repl/format-semantic-error "defun" "deprecated syntax: use df instead" 42))]
    (assert (string-contains? err "defun") "contains defun")
    (assert (string-contains? err "deprecated syntax: use df instead") "contains deprecated syntax")
    (assert (string-contains? err "42") "contains line 42")
    (assert (string-contains? err "SemanticError") "contains SemanticError")
    true))

(df run-tests [] -> Bool
  :d "Executes all REPL test cases."
  (do
    (test-eval-expression)
    (test-patch-ast-node)
    (test-semantic-error-formatting)
    true))
