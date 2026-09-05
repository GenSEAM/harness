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
    (and (== (.-selector act) "#btn-save")
         (== (.-tab-id act) "tab-101"))))

(df test-verify-slm-coherence-valid-click [] -> Bool
  (let [(sample "(! browser_click :selector \"#checkout-btn\")")
        (verdict (bh/verify-slm-coherence sample "tab-101"))]
    (and (.-is-coherent verdict)
         (mt (.-action verdict)
           ((none) false)
           ((some act)
            (and (== (.-selector act) "#checkout-btn")
                 (== (.-tab-id act) "tab-101")))))))

(df test-verify-slm-coherence-unbalanced-delimiters [] -> Bool
  (let [(bad-sample "(! browser_click :selector \"#checkout-btn\"")
        (verdict (bh/verify-slm-coherence bad-sample "tab-101"))]
    (and (not (.-is-coherent verdict))
         (string-contains? (.-error-reason verdict) "Unbalanced delimiters"))))

(df test-verify-slm-coherence-ghost-rejection [] -> Bool
  (let [(ghost-sample "(! hack-root :target \"system\")")
        (verdict (bh/verify-slm-coherence ghost-sample "tab-101"))]
    (and (not (.-is-coherent verdict))
         (string-contains? (.-error-reason verdict) "ghost action"))))

(df test-execute-harness-turn-grounding [] -> Bool
  (let [(dom "<div id=\"root\"><button id=\"btn-apply\">Apply</button></div>")
        (valid-turn (bh/execute-harness-turn dom "(! browser_click :selector \"#btn-apply\")" "tab-101"))
        (hallucinated-turn (bh/execute-harness-turn dom "(! browser_click :selector \"#ghost-btn\")" "tab-101"))]
    (and (.-is-coherent valid-turn)
         (not (.-is-coherent hallucinated-turn))
         (string-contains? (.-error-reason hallucinated-turn) "not grounded in active DOM"))))

(df test-benchmark-slm-coherence [] -> Bool
  (let [(samples (list "(! browser_click :selector \"#btn\")"
                       "(! browser_type :selector \"#input\" :text \"val\")"
                       "(! bad-unbalanced ("
                       "(! hack-root :now true)"))
        (bench (bh/benchmark-slm-coherence samples))]
    (and (== (fst bench) 2)
         (== (snd bench) 50.0))))

(df run-tests [] -> Bool
  (and (test-make-browser-action)
       (test-verify-slm-coherence-valid-click)
       (test-verify-slm-coherence-unbalanced-delimiters)
       (test-verify-slm-coherence-ghost-rejection)
       (test-execute-harness-turn-grounding)
       (test-benchmark-slm-coherence)))
