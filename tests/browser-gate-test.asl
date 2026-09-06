(module asl-harness/tests/browser-gate-test
  :d "Unit tests for pure AgentScript Browser Verification Gate"
  :x [run-tests]
  :i [(browser_gate :a bg)])

(df test-svg-clean [] -> Bool
  :d "Verifies clean SVG passes all three gates"
  (let [(code "<svg viewBox=\"0 0 320 320\"><rect x=\"0\" y=\"0\" width=\"320\" height=\"320\" /></svg>")
        (res (bg/run-browser-gates code "svg"))]
    (and (.-passed res)
         (string-empty? (.-healing-directive res)))))

(df test-asn-unbalanced [] -> Bool
  :d "Verifies unbalanced ASN fails Gate 1"
  (let [(code "(:svg :w 320 (:rc :x 0")
        (v (bg/check-syntax-gate code "svg"))]
    (not (.-passed v))))

(df test-security-eval [] -> Bool
  :d "Verifies eval() call fails Gate 2"
  (let [(code "function foo() { eval('alert(1)'); }")
        (v (bg/check-security-gate code))]
    (not (.-passed v))))

(df test-games-readiness [] -> Bool
  :d "Verifies missing requestAnimationFrame fails Gate 3 in games mode"
  (let [(code "<canvas id=\"game\"></canvas><script>console.log('idle');</script>")
        (v (bg/check-readiness-gate code "games"))]
    (not (.-passed v))))

(df run-tests [] -> Bool
  :d "Executes all test cases in suite"
  (and (test-svg-clean)
       (and (test-asn-unbalanced)
            (and (test-security-eval)
                 (test-games-readiness)))))
