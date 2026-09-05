(module asl-harness/repl-test
  :d "Unit tests for pure AgentScript in-memory REPL inspector and AST node patcher."
  :x [test-eval-expression test-patch-ast-node test-semantic-error-formatting]
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
    (and (= (.-session-id sess0) "sess-alpha")
         (.-success res-add)
         (= (.-output res-add) "30")
         (< (.-latency-micros res-add) 50)
         (.-success res-mul)
         (= (.-output res-mul) "42")
         (< (.-latency-micros res-mul) 50)
         (.-success res-sub)
         (= (.-output res-sub) "42")
         (.-success res-lit)
         (= (.-output res-lit) "42")
         (.-success res-bool)
         (= (.-output res-bool) "true")
         (.-success res-bound)
         (= (.-output res-bound) "20")
         (< (.-latency-micros res-bound) 50)
         (not (.-success res-div0))
         (string-contains? (.-error-detail res-div0) "Division by zero")
         (not (.-success res-unbalanced))
         (string-contains? (.-error-detail res-unbalanced) "Unbalanced delimiters")
         (not (.-success res-empty))
         (string-contains? (.-error-detail res-empty) "Empty expression"))))

(df test-patch-ast-node [] -> Bool
  :d "Verifies AST node substitution and patching without full file rewrite."
  (let [(src1 "(df calc [(x I64)] (+ x 10))")
        (patched1 (repl/patch-ast-node src1 "(+ x 10)" "(* x 2)"))
        (src2 "(df old-calc [(x I64)] (+ x 10))")
        (patched2 (repl/patch-ast-node src2 "old-calc" "new-calc"))
        (src3 "(df calc [(x I64)] (+ x 10))")
        (patched3 (repl/patch-ast-node src3 "non-existent" "foo"))
        (patched4 (repl/patch-ast-node src3 "" "foo"))]
    (and (= patched1 "(df calc [(x I64)] (* x 2))")
         (= patched2 "(df new-calc [(x I64)] (+ x 10))")
         (= patched3 src3)
         (= patched4 src3))))

(df test-semantic-error-formatting [] -> Bool
  :d "Verifies structured semantic traceback generation with form, line, and reason."
  (let [(err (repl/format-semantic-error "defun" "deprecated syntax: use df instead" 42))]
    (and (string-contains? err "defun")
         (string-contains? err "deprecated syntax: use df instead")
         (string-contains? err "42")
         (string-contains? err "SemanticError"))))
