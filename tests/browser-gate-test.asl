(module asl-harness/tests/browser-gate-test
  :d "Unit tests for pure AgentScript Browser Verification Gate"
  :x [run-tests]
  :i [(browser_gate :a bg)])

(df test-svg-clean [] -> Bool
  :d "Verifies clean SVG passes all three gates"
  (let [(code "<svg viewBox=\"0 0 320 320\"><rect x=\"0\" y=\"0\" width=\"320\" height=\"320\" /></svg>")
        (res (bg/run-browser-gates code "svg"))]
    (assert (.-passed res) "clean SVG passes gates")
    (assert (string-empty? (.-healing-directive res)) "healing directive empty")
    true))

(df test-asn-unbalanced [] -> Bool
  :d "Verifies unbalanced ASN fails Gate 1"
  (let [(code "(:svg :w 320 (:rc :x 0")
        (v (bg/check-syntax-gate code "svg"))]
    (assert (not (.-passed v)) "unbalanced ASN fails syntax gate")
    true))

(df test-security-eval [] -> Bool
  :d "Verifies eval() call fails Gate 2"
  (let [(code "function foo() { eval('alert(1)'); }")
        (v (bg/check-security-gate code))]
    (assert (not (.-passed v)) "eval call fails security gate")
    true))

(df test-games-readiness [] -> Bool
  :d "Verifies missing requestAnimationFrame fails Gate 3 in games mode"
  (let [(code "<canvas id=\"game\"></canvas><script>console.log('idle');</script>")
        (v (bg/check-readiness-gate code "games"))]
    (assert (not (.-passed v)) "missing rAF fails games readiness gate")
    true))

(df run-tests [] -> Bool
  :d "Executes all test cases in suite"
  (do
    (test-svg-clean)
    (test-asn-unbalanced)
    (test-security-eval)
    (test-games-readiness)
    true))
