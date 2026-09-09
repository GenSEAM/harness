(module asl-harness/pre-mortem-test
  :d "Unit verification tests for Stage 4 pre-mortem reasoning engine and 2-hop speculation ceiling."
  :x [test-pre-mortem-2-hop-ceiling
      test-pre-mortem-falsification-triggers
      run-tests]
  :i [(pre-mortem :a pm)])

(df test-pre-mortem-2-hop-ceiling [] -> Bool
  :d "Verifies strict enforcement of 2-hop speculation ceiling and risk grounding."
  (let [(r-valid-1 (pm/ConsequenceRisk
                     :description "Schema mutation causes deserialization mismatch in peer node"
                     :hop-count 1
                     :falsification-trigger "asl test --strict-falsify harness/tests/feedback-test.asl"
                     :severity "medium"
                     :is-grounded true))
        (r-valid-2 (pm/ConsequenceRisk
                     :description "Secondary cache invalidation failure cascades to stale read"
                     :hop-count 2
                     :falsification-trigger "asl test --strict-falsify harness/tests/ast-gate-test.asl"
                     :severity "low"
                     :is-grounded true))
        (r-excessive (pm/ConsequenceRisk
                       :description "3-hop speculation: downstream timeout causes cluster partition"
                       :hop-count 3
                       :falsification-trigger "asl test --strict-falsify harness/tests/epistemic_pipeline_test.asl"
                       :severity "medium"
                       :is-grounded true))
        (v-pass (pm/evaluate-pre-mortem "Action within 2-hop ceiling" (list r-valid-1 r-valid-2) 2))
        (v-fail-ceiling (pm/evaluate-pre-mortem "Action exceeding 2-hop ceiling" (list r-valid-1 r-excessive) 2))
        (v-fail-custom-max (pm/evaluate-pre-mortem "Action exceeding custom 1-hop ceiling" (list r-valid-1 r-valid-2) 1))
        (v-fail-cap (pm/evaluate-pre-mortem "Action attempting 3-hop ceiling capped to 2" (list r-excessive) 3))
        (ungrounded-in-fail (filter (fn [(c pm/ConsequenceRisk)] -> Bool (not (.-is-grounded c))) (.-consequences v-fail-ceiling)))]
    (do
      (assert (.-passed v-pass))
      (assert (= (list-length (.-blocked-reasons v-pass)) 0))
      (assert (not (.-passed v-fail-ceiling)))
      (assert (> (list-length (.-blocked-reasons v-fail-ceiling)) 0))
      (assert (> (list-length ungrounded-in-fail) 0))
      (assert (not (.-passed v-fail-custom-max)))
      (assert (not (.-passed v-fail-cap)))
      true)))

(df test-pre-mortem-falsification-triggers [] -> Bool
  :d "Verifies falsification trigger generation and trigger existence enforcement."
  (let [(trig (pm/generate-falsification-trigger "stale-cache" "harness/src/proxy.asl" "cache-cleared"))
        (r-missing-trig (pm/ConsequenceRisk
                          :description "Risk with missing falsification trigger"
                          :hop-count 1
                          :falsification-trigger ""
                          :severity "low"
                          :is-grounded true))
        (r-critical (pm/ConsequenceRisk
                      :description "Unmitigated critical security vulnerability"
                      :hop-count 1
                      :falsification-trigger trig
                      :severity "critical"
                      :is-grounded true))
        (r-ok (pm/ConsequenceRisk
                :description "Mitigated low-severity risk with trigger"
                :hop-count 1
                :falsification-trigger trig
                :severity "low"
                :is-grounded true))
        (v-ok (pm/evaluate-pre-mortem "Safe action" (list r-ok) 2))
        (v-no-trig (pm/evaluate-pre-mortem "Action missing trigger" (list r-missing-trig) 2))
        (v-crit (pm/evaluate-pre-mortem "Action with critical risk" (list r-critical) 2))]
    (do
      (assert (string-contains? trig "asl test"))
      (assert (string-contains? trig "harness/src/proxy.asl"))
      (assert (string-contains? trig "stale-cache"))
      (assert (.-passed v-ok))
      (assert (not (.-passed v-no-trig)))
      (assert (> (list-length (.-blocked-reasons v-no-trig)) 0))
      (assert (not (.-passed v-crit)))
      (assert (> (list-length (.-blocked-reasons v-crit)) 0))
      true)))

(df run-tests [] -> Bool
  :d "Executes full pre-mortem test suite."
  (do
    (assert (test-pre-mortem-2-hop-ceiling))
    (assert (test-pre-mortem-falsification-triggers))
    true))
