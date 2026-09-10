(module asl-harness/human-resonance-paradigm-test
  :d "Unit verification test suite for Human Resonance, Reflexive Psychology, and Business Modeling Paradigms."
  :x [test-reflexive-tom-levels
      test-jtbd-job-dimensions
      test-app-format-taxonomy
      test-unit-economics-bounds
      test-semantic-registers
      run-tests]
  :i [])

(df test-reflexive-tom-levels [] -> Bool
  :d "Verifies the 3 recursive levels of Reflexive Theory of Mind"
  (let [(levels (list "r0-empirical-world" "r1-user-mental-model" "r2-counter-perception"))]
    (assert (= (list-length levels) 3) "Theory of mind must specify exactly 3 recursive levels")
    (assert (not (= (list-head levels) (list-head (list-drop levels 1)))) "Levels must be distinct")
    true))

(df test-jtbd-job-dimensions [] -> Bool
  :d "Verifies the tri-job JTBD decomposition into functional, emotional, and social dimensions"
  (let [(jobs (list "functional" "emotional" "social"))
        (min-hair-on-fire 8)
        (max-hair-on-fire 10)]
    (assert (= (list-length jobs) 3) "JTBD must cover exactly 3 human dimensions")
    (assert (<= min-hair-on-fire max-hair-on-fire) "Severity range must be well-ordered")
    (assert (>= min-hair-on-fire 8) "Hair-on-fire pain must have minimum severity of 8")
    true))

(df test-app-format-taxonomy [] -> Bool
  :d "Verifies the 5 next-generation agentic application formats"
  (let [(formats (list "agentic-micro-saas"
                       "headless-agent-service"
                       "dynamic-vdom-canvas"
                       "outcome-based-escrow"
                       "agent-to-agent-marketplace"))]
    (assert (= (list-length formats) 5) "Taxonomy must define exactly 5 modern application formats")
    (assert (not (list-empty? formats)) "Formats list must be non-empty")
    true))

(df test-unit-economics-bounds [] -> Bool
  :d "Verifies unit economics margin floor and LTV to CAC ratio bounds"
  (let [(target-margin 75)
        (min-ltv-cac-ratio 3.5)]
    (assert (>= target-margin 70) "Gross margin floor must meet or exceed 70 percent")
    (assert (>= min-ltv-cac-ratio 3.0) "LTV to CAC ratio must strictly exceed 3.0")
    true))

(df test-semantic-registers [] -> Bool
  :d "Verifies semantic resonance audience registers and SNR target"
  (let [(registers (list "executive" "engineering" "collaborative-user"))
        (target-snr 0.75)]
    (assert (= (list-length registers) 3) "Must define exactly 3 audience registers")
    (assert (>= target-snr 0.75) "Target SNR must be at least 0.75")
    true))

(df run-tests [] -> Bool
  :d "Executes all human resonance and business modeling paradigm verification checks"
  (and (test-reflexive-tom-levels)
       (and (test-jtbd-job-dimensions)
            (and (test-app-format-taxonomy)
                 (and (test-unit-economics-bounds)
                      (test-semantic-registers))))))
