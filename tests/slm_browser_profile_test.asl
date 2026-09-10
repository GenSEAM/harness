(module asl-harness/slm-browser-profile-test
  :d "Unit verification test suite for Browser SLM Compact Profile and FSM Delimiter Mask"
  :x [test-browser-tools-schema
      test-affirmative-schema
      test-browser-profile-instantiation
      test-fsm-delimiter-mask-balanced
      test-fsm-delimiter-mask-unbalanced
      test-fsm-delimiter-mask-max-depth
      test-nano-browser-profile
      test-browser-ceiling-enforcement
      run-tests]
  :i [(slm_browser_profile :a slm)])

(df test-browser-tools-schema [] -> Bool
  :d "Verifies the 4-tool essential affirmative schema properties"
  (let [(tools (slm/make-browser-slm-tools))
        (t-dom (option-or (list-head tools) (slm/SlmBrowserTool :name "" :signature "" :summary "" :token-cost 0)))
        (tokens (slm/calculate-schema-tokens tools))]
    (assert (= (list-length tools) 4) "Browser SLM tool count must be exactly 4")
    (assert (= (.-name t-dom) "get_dom") "First tool must be get_dom")
    (assert (<= tokens 118) "Total schema token cost must not exceed 118 tokens")
    (assert (> tokens 0) "Schema token cost must be positive")
    (assert (string-contains? (.-signature t-dom) ":get_dom") "Signature must contain action name")
    true))

(df test-affirmative-schema [] -> Bool
  :d "Verifies affirmative schema invariants and constraints"
  (let [(schema (slm/make-browser-slm-schema))]
    (assert (= (.-max-tools schema) 4) "Max tools limit must be 4")
    (assert (= (.-total-tokens schema) 64) "Expected 64 token budget for essential 4 tools")
    (assert (string-contains? (.-affirmative-rule schema) "Never hallucinate") "Affirmative rule must enforce no hallucinations")
    true))

(df test-browser-profile-instantiation [] -> Bool
  :d "Verifies profile construction and 118-token priming prompt generation"
  (let [(p (slm/make-browser-slm-profile "Qwen2.5-0.5B" 2048))]
    (assert (= (.-model-name p) "Qwen2.5-0.5B") "Model name must match")
    (assert (= (.-context-budget p) 2048) "Context budget must match 2048")
    (assert (= (.-priming-token-count p) 118) "Priming token count must be 118")
    (assert (string-contains? (.-priming-prompt p) "Addie Browser SLM Agent") "Priming prompt must identify agent")
    true))

(df test-fsm-delimiter-mask-balanced [] -> Bool
  :d "Verifies FSM delimiter mask on balanced S-expressions"
  (let [(mask (slm/init-fsm-delimiter-mask 16))
        (s1 "(:act :click :selector btn)")
        (r1 (slm/validate-slm-token-stream mask s1))
        (s2 "[:act :eval :expression [query document]]")
        (r2 (slm/validate-slm-token-stream mask s2))]
    (assert (.-is-valid r1) "Standard action must be valid")
    (assert (= (.-depth r1) 0) "Depth must return to zero on balanced completion")
    (assert (not (.-in-string r1)) "Must not remain in string literal")
    (assert (.-is-valid r2) "Nested square bracket S-expression must be valid")
    (assert (= (.-depth r2) 0) "Nested depth must be zero")
    true))

(df test-fsm-delimiter-mask-unbalanced [] -> Bool
  :d "Verifies FSM delimiter mask rejects unbalanced inputs"
  (let [(mask (slm/init-fsm-delimiter-mask 16))
        (r-unclosed (slm/validate-slm-token-stream mask "(:act :click :selector btn"))
        (r-extra (slm/validate-slm-token-stream mask "(:act :click))"))
        (r-bracket (slm/validate-slm-token-stream mask "[:act :click :selector btn"))]
    (assert (not (.-is-valid r-unclosed)) "Unclosed delimiter must be marked invalid")
    (assert (string-contains? (.-error-reason r-unclosed) "Unclosed delimiter") "Error reason must report unclosed delimiter")
    (assert (not (.-is-valid r-extra)) "Extra closing paren must be marked invalid")
    (assert (string-contains? (.-error-reason r-extra) "Unmatched closing delimiter") "Error reason must report unmatched closing delimiter")
    (assert (not (.-is-valid r-bracket)) "Unclosed square bracket must be marked invalid")
    true))

(df test-fsm-delimiter-mask-max-depth [] -> Bool
  :d "Verifies FSM delimiter mask enforces maximum nesting depth limit"
  (let [(shallow-mask (slm/init-fsm-delimiter-mask 2))
        (r-deep (slm/validate-slm-token-stream shallow-mask "((((x))))"))]
    (assert (not (.-is-valid r-deep)) "Exceeding max depth must be rejected")
    (assert (string-contains? (.-error-reason r-deep) "Max nesting depth") "Error must identify max depth violation")
    true))

(df test-nano-browser-profile [] -> Bool
  :d "Verifies 100MB nano SLM profile construction and 2-tool schema"
  (let [(tools (slm/make-nano-slm-tools))
        (schema (slm/make-nano-slm-schema))
        (p (slm/make-nano-browser-slm-profile "SmolLM-135M" 1024))]
    (assert (= (list-length tools) 2) "Nano SLM tool count must be exactly 2")
    (assert (<= (.-total-tokens schema) 36) "Nano schema token cost must not exceed 36 tokens")
    (assert (= (.-priming-token-count p) 30) "Nano priming token count must be 30")
    (assert (string-contains? (.-priming-prompt p) "100MB") "Nano priming prompt must specify 100MB weight")
    true))

(df test-browser-ceiling-enforcement [] -> Bool
  :d "Verifies strict 3-billion parameter ceiling for browser deployment"
  (do
    (assert (slm/validate-browser-model-ceiling "SmolLM-135M") "100MB nano model is allowed")
    (assert (slm/validate-browser-model-ceiling "Qwen2.5-0.5B") "0.5B micro model is allowed")
    (assert (slm/validate-browser-model-ceiling "Qwen2.5-1.5B") "1.5B model is allowed")
    (assert (slm/validate-browser-model-ceiling "Qwen2.5-3B") "3B ceiling model is allowed")
    (assert (not (slm/validate-browser-model-ceiling "Qwen2.5-7B")) "7B model must be strictly rejected")
    (assert (not (slm/validate-browser-model-ceiling "Gemma-2-9B")) "9B model must be strictly rejected")
    (assert (not (slm/validate-browser-model-ceiling "Gemma-4-31B")) "31B model must be strictly rejected")
    true))

(df run-tests [] -> Bool
  :d "Runs all test cases for the browser SLM profile"
  (and (test-browser-tools-schema)
       (and (test-affirmative-schema)
            (and (test-browser-profile-instantiation)
                 (and (test-fsm-delimiter-mask-balanced)
                      (and (test-fsm-delimiter-mask-unbalanced)
                           (and (test-fsm-delimiter-mask-max-depth)
                                (and (test-nano-browser-profile)
                                     (test-browser-ceiling-enforcement)))))))))
