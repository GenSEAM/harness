(module asl-harness-tests/browser-harness-test
  :d "Unit tests for in-browser agent harness and SLM output coherence validation"
  :x [test-make-browser-action
      test-verify-slm-coherence-valid-click
      test-verify-slm-coherence-unbalanced-delimiters
      test-verify-slm-coherence-ghost-rejection
      test-execute-harness-turn-grounding
      test-benchmark-slm-coherence
      run-tests]
  :i [(asl-harness/browser-harness :a bh)
      (core/strings :a s)])

(df test-make-browser-action [] -> Bool
  (let [(act (bh/make-browser-action (bh/act-click) "#btn-save" "" "tab-101"))]
    (assert (= (.-selector act) "#btn-save") "selector matches")
    (assert (= (.-tab-id act) "tab-101") "tab id matches")
    true))

(df test-verify-slm-coherence-valid-click [] -> Bool
  (let [(sample "(! browser_click :selector \"#checkout-btn\")")
        (verdict (bh/verify-slm-coherence sample "tab-101"))]
    (assert (.-is-coherent verdict) "valid click is coherent")
    (assert (match (.-action verdict)
              ((none) false)
              ((some act)
               (and (= (.-selector act) "#checkout-btn")
                    (= (.-tab-id act) "tab-101")))) "action matched checkout-btn")
    true))

(df test-verify-slm-coherence-unbalanced-delimiters [] -> Bool
  (let [(bad-sample "(! browser_click :selector \"#checkout-btn\"")
        (verdict (bh/verify-slm-coherence bad-sample "tab-101"))]
    (assert (not (.-is-coherent verdict)) "unbalanced delimiters rejected")
    (assert (string-contains? (.-error-reason verdict) "Unbalanced delimiters") "error reason notes unbalanced")
    true))

(df test-verify-slm-coherence-ghost-rejection [] -> Bool
  (let [(ghost-sample "(! hack-root :target \"system\")")
        (verdict (bh/verify-slm-coherence ghost-sample "tab-101"))]
    (assert (not (.-is-coherent verdict)) "ghost action rejected")
    (assert (string-contains? (.-error-reason verdict) "ghost action") "error reason notes ghost action")
    true))

(df test-execute-harness-turn-grounding [] -> Bool
  (let [(dom "<div id=\"root\"><button id=\"btn-apply\">Apply</button></div>")
        (valid-turn (bh/execute-harness-turn dom "(! browser_click :selector \"#btn-apply\")" "tab-101"))
        (hallucinated-turn (bh/execute-harness-turn dom "(! browser_click :selector \"#ghost-btn\")" "tab-101"))]
    (assert (.-is-coherent valid-turn) "valid turn grounded in DOM")
    (assert (not (.-is-coherent hallucinated-turn)) "ungrounded turn rejected")
    (assert (string-contains? (.-error-reason hallucinated-turn) "not grounded in active DOM") "reason notes not grounded")
    true))

(df test-benchmark-slm-coherence [] -> Bool
  (let [(samples (list "(! browser_click :selector \"#btn\")"
                       "(! browser_type :selector \"#input\" :text \"val\")"
                       "(! bad-unbalanced ("
                       "(! hack-root :now true)"))
        (bench (bh/benchmark-slm-coherence samples))]
    (assert (= (fst bench) 2) "two valid coherent samples")
    (assert (= (snd bench) 50.0) "50 percent coherence score")
    true))

(df run-tests [] -> Bool
  (do
    (test-make-browser-action)
    (test-verify-slm-coherence-valid-click)
    (test-verify-slm-coherence-unbalanced-delimiters)
    (test-verify-slm-coherence-ghost-rejection)
    (test-execute-harness-turn-grounding)
    (test-benchmark-slm-coherence)
    true))
