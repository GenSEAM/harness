(module asl-harness/verifier-test
  :d "Unit tests for universal pre-execution verifier and anti-hallucination guardrails."
  :x [test-detect-language test-validate-delimiter-balance test-verify-chunk-match test-verify-structural-action run-tests]
  :i [(verifier :a v)])

(df test-detect-language [] -> Bool
  :d "Verifies language detection across extensions."
  (and (= (v/detect-language "src/main.asl") "asl")
       (and (= (v/detect-language "scripts/calc.py") "py")
            (and (= (v/detect-language "engine/lib.rs") "rs")
                 (and (= (v/detect-language "web/app.ts") "ts")
                      (= (v/detect-language "manifest.json") "json"))))))

(df test-validate-delimiter-balance [] -> Bool
  :d "Verifies universal delimiter matching."
  (let [(valid-py "def foo():\n    return [x for x in (1, 2, 3)]")
        (invalid-py "def foo():\n    return [x for x in (1, 2, 3]")]
    (and (v/validate-delimiter-balance valid-py)
         (not (v/validate-delimiter-balance invalid-py)))))

(df test-verify-chunk-match [] -> Bool
  :d "Verifies chunk match validation for surgical edits."
  (let [(content "def add(a, b):\n    return a + b\n")
        (good-chunk "return a + b")
        (bad-chunk "return a * b")
        (res-good (v/verify-chunk-match content good-chunk))
        (res-bad (v/verify-chunk-match content bad-chunk))]
    (and (.-allowed res-good)
         (not (.-allowed res-bad)))))

(df test-verify-structural-action [] -> Bool
  :d "Verifies pre-execution structural action gate."
  (let [(res-good (v/verify-structural-action "str-replace" "main.py" "x = 1"))
        (res-unbalanced (v/verify-structural-action "str-replace" "main.py" "x = (1 + 2"))]
    (and (.-allowed res-good)
         (not (.-allowed res-unbalanced)))))

(df run-tests [] -> Bool
  :d "Executes full verifier test suite."
  (and (test-detect-language)
       (and (test-validate-delimiter-balance)
            (and (test-verify-chunk-match)
                 (test-verify-structural-action)))))

