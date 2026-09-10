(module asl-harness/tiered-evaluator-test
  :d "Unit verification test suite for Tiered Execution Router"
  :x [test-tiered-evaluator-construction
      test-analyze-complexity-micro
      test-analyze-complexity-heavy
      test-select-execution-tier-ast
      test-select-execution-tier-wasm-escalation
      test-manual-tier-override
      test-route-execution-end-to-end
      run-tests]
  :i [(tiered_evaluator :a te)])

(df test-tiered-evaluator-construction [] -> Bool
  :d "Verifies construction of TieredEvaluator configuration"
  (let [(ev (te/make-tiered-evaluator 500 1000))]
    (assert (= (.-node-threshold ev) 500) "Node threshold must be 500")
    (assert (= (.-iteration-threshold ev) 1000) "Iteration threshold must be 1000")
    (assert (= (.-force-tier ev) "auto") "Default force tier must be auto")
    (assert (= (.-default-timeout-ms ev) 5000) "Default timeout must be 5000ms")
    true))

(df test-analyze-complexity-micro [] -> Bool
  :d "Verifies complexity metrics for micro S-expressions"
  (let [(code "(+ 1 2)")
        (c (te/analyze-complexity code))]
    (assert (= (.-ast-node-count c) 1) "Micro expression has 1 open paren")
    (assert (= (.-loop-depth c) 0) "Micro expression has 0 loop depth")
    (assert (not (.-has-heavy-recursion c)) "Micro expression has no recursion")
    (assert (> (.-score c) 0) "Composite score must be positive")
    true))

(df test-analyze-complexity-heavy [] -> Bool
  :d "Verifies complexity metrics for loops and recursive functions"
  (let [(code "(loop [i 0] (fibonacci i))")
        (c (te/analyze-complexity code))]
    (assert (.-has-heavy-recursion c) "Must detect heavy recursion keyword")
    (assert (>= (.-estimated-iterations c) 5000) "Estimated iterations must be >= 5000")
    (assert (>= (.-score c) 200) "Composite score must account for loop depth")
    true))

(df test-select-execution-tier-ast [] -> Bool
  :d "Verifies fast-path AST evaluation routing for small workloads"
  (let [(ev (te/make-tiered-evaluator 500 1000))
        (c (te/ComplexityScore
             :ast-node-count 10
             :loop-depth 0
             :estimated-iterations 1
             :has-heavy-recursion false
             :score 10))
        (dec (te/select-execution-tier ev c))]
    (assert (not (.-requires-jit dec)) "Micro script must not require JIT")
    (assert (string-contains? (.-reason dec) "AST") "Routing reason must identify AST fast-path")
    (assert (= (.-score (.-complexity dec)) 10) "Complexity must be preserved")
    true))

(df test-select-execution-tier-wasm-escalation [] -> Bool
  :d "Verifies WebAssembly JIT escalation when thresholds are exceeded"
  (let [(ev (te/make-tiered-evaluator 500 1000))
        (c (te/ComplexityScore
             :ast-node-count 600
             :loop-depth 2
             :estimated-iterations 2500
             :has-heavy-recursion true
             :score 1000))
        (dec (te/select-execution-tier ev c))]
    (assert (.-requires-jit dec) "Heavy workload must trigger JIT")
    (assert (string-contains? (.-reason dec) "WebAssembly") "Routing reason must cite WebAssembly JIT")
    (assert (= (.-score (.-complexity dec)) 1000) "Score must match")
    true))

(df test-manual-tier-override [] -> Bool
  :d "Verifies manual force-tier overrides"
  (let [(ev-wasm (te/TieredEvaluator :node-threshold 500 :iteration-threshold 1000 :force-tier "wasm" :default-timeout-ms 5000))
        (ev-ast (te/TieredEvaluator :node-threshold 500 :iteration-threshold 1000 :force-tier "ast" :default-timeout-ms 5000))
        (c-micro (te/ComplexityScore :ast-node-count 2 :loop-depth 0 :estimated-iterations 1 :has-heavy-recursion false :score 2))
        (c-heavy (te/ComplexityScore :ast-node-count 800 :loop-depth 2 :estimated-iterations 5000 :has-heavy-recursion true :score 1200))
        (dec-wasm (te/select-execution-tier ev-wasm c-micro))
        (dec-ast (te/select-execution-tier ev-ast c-heavy))]
    (assert (.-requires-jit dec-wasm) "Manual wasm override must require JIT")
    (assert (string-contains? (.-reason dec-wasm) "forced WebAssembly") "Reason must note manual wasm override")
    (assert (not (.-requires-jit dec-ast)) "Manual ast override must bypass JIT")
    (assert (string-contains? (.-reason dec-ast) "forced AST") "Reason must note manual ast override")
    true))

(df test-route-execution-end-to-end [] -> Bool
  :d "Verifies end-to-end execution routing outcomes"
  (let [(ev (te/make-tiered-evaluator 500 1000))
        (out-micro (te/route-execution ev "(+ 1 2)"))
        (out-heavy (te/route-execution ev "(loop [i 0] (fibonacci 10))"))]
    (assert (= (.-status out-micro) "ok") "Micro outcome must be ok")
    (assert (= (.-execution-ms out-micro) 1) "Micro outcome execution time must be 1ms")
    (assert (string-contains? (.-result-summary out-micro) "AST eval") "Summary must report AST eval")
    (assert (= (.-status out-heavy) "ok") "Heavy outcome must be ok")
    (assert (= (.-execution-ms out-heavy) 12) "Heavy outcome execution time must be 12ms")
    (assert (string-contains? (.-result-summary out-heavy) "WebAssembly") "Summary must report WebAssembly")
    true))

(df run-tests [] -> Bool
  :d "Executes all tiered execution router test cases"
  (and (test-tiered-evaluator-construction)
       (and (test-analyze-complexity-micro)
            (and (test-analyze-complexity-heavy)
                 (and (test-select-execution-tier-ast)
                      (and (test-select-execution-tier-wasm-escalation)
                           (and (test-manual-tier-override)
                                (test-route-execution-end-to-end))))))))
