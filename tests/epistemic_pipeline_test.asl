(module asl-harness/epistemic-pipeline-test
  :d "Unit verification test suite for the 7-stage epistemic reflection pipeline and task entropy controller."
  :x [test-pipeline-stage-enumeration
      test-reflection-config-defaults
      test-fidelity-gate-evaluation
      test-fidelity-gate-prompt-overlap
      test-task-entropy-formula
      test-adaptive-entropy-thresholds
      test-7-stage-pipeline-construction
      run-tests]
  :i [(steps-pipeline :a sp)])

(df test-pipeline-stage-enumeration [] -> Bool
  :d "Verifies PipelineStage enum variants."
  (let [(s1 (sp/s1-ingest))
        (s2 (sp/s2-reformulate))
        (s3 (sp/s3-intent-gate))
        (s4 (sp/s4-plan))
        (s5 (sp/s5-plan-gate))
        (s6 (sp/s6-implement))
        (s7 (sp/s7-verify))]
    (and (not (= s1 s2))
         (and (not (= s3 s4))
              (not (= s5 s6))))))

(df test-reflection-config-defaults [] -> Bool
  :d "Verifies default reflection configuration invariants."
  (let [(cfg (sp/default-reflection-config))]
    (and (= (.-max-hops cfg) 2)
         (and (.-quarantined-channel cfg)
              (and (>= (.-fidelity-threshold cfg) 0.90)
                   (.-echo-suppression cfg))))))

(df test-fidelity-gate-evaluation [] -> Bool
  :d "Verifies fidelity gate accepts high confidence and rejects low or failed verdicts."
  (let [(cfg (sp/default-reflection-config))
        (v-pass (sp/ReflectionVerdict
                  :stage (sp/s7-verify)
                  :fidelity-score 0.98
                  :omissions (list)
                  :unsupported-claims (list)
                  :passed true))
        (v-low (sp/ReflectionVerdict
                 :stage (sp/s7-verify)
                 :fidelity-score 0.82
                 :omissions (list "missing corner case")
                 :unsupported-claims (list)
                 :passed true))
        (v-fail (sp/ReflectionVerdict
                  :stage (sp/s7-verify)
                  :fidelity-score 0.99
                  :omissions (list)
                  :unsupported-claims (list "unsupported claim")
                  :passed false))]
    (and (sp/evaluate-fidelity-gate v-pass cfg)
         (and (not (sp/evaluate-fidelity-gate v-low cfg))
              (not (sp/evaluate-fidelity-gate v-fail cfg))))))

(df test-fidelity-gate-prompt-overlap [] -> Bool
  :d "Verifies intent-fidelity gate validates agent reformulation against original prompt."
  (let [(prompt "Implement cross-agent task contract and verified execution receipts")
        (good-ref "Will implement cross-agent task contract and verified execution receipts in mesh")
        (bad-ref "Unrelated text talking about cooking recipes without any keywords")
        (v-good (sp/evaluate-prompt-fidelity prompt good-ref 0.8))
        (v-bad (sp/evaluate-prompt-fidelity prompt bad-ref 0.8))]
    (and (.-passed v-good)
         (and (>= (.-fidelity-score v-good) 0.8)
              (and (not (.-passed v-bad))
                   (and (< (.-fidelity-score v-bad) 0.8)
                        (> (list-length (.-omissions v-bad)) 0)))))))

(df test-task-entropy-formula [] -> Bool
  :d "Verifies task entropy meta-controller computation."
  (let [(e-low (sp/compute-task-entropy 1 0.1 0.1 0.1))
        (e-high (sp/compute-task-entropy 12 0.9 0.9 0.9))]
    (and (< e-low 1.0)
         (> e-high 9.0))))

(df test-adaptive-entropy-thresholds [] -> Bool
  :d "Verifies continuous adaptive entropy meta-controller profile selection."
  (let [(h-low (sp/compute-task-entropy 1 0.2 0.1 0.1))
        (h-med (sp/compute-task-entropy 2 0.5 0.5 0.2))
        (h-high (sp/compute-task-entropy 4 0.9 0.8 0.9))
        (prof-low (sp/select-pipeline-profile h-low))
        (prof-med (sp/select-pipeline-profile h-med))
        (prof-high (sp/select-pipeline-profile h-high))]
    (and (= prof-low "fast")
         (and (= prof-med "standard")
              (= prof-high "full")))))

(df test-7-stage-pipeline-construction [] -> Bool
  :d "Verifies that make-7-stage-pipeline creates exactly 7 sequential phases."
  (let [(pipe (sp/make-7-stage-pipeline "task-42" "Implement Epistemic Reflection Pipeline"))
        (phases (.-phases pipe))]
    (and (= (.-task-id pipe) "task-42")
         (and (= (.-active-stage pipe) "s1-ingest")
              (and (= (list-length phases) 7)
                   (= (.-stage (option-or (list-head phases) (sp/StepPhase :id "" :name "" :stage "" :gate-command "" :status "" :findings (list)))) "s1-ingest"))))))

(df run-tests [] -> Bool
  :d "Executes all epistemic pipeline assertions."
  (do
    (assert (test-pipeline-stage-enumeration))
    (assert (test-reflection-config-defaults))
    (assert (test-fidelity-gate-evaluation))
    (assert (test-fidelity-gate-prompt-overlap))
    (assert (test-task-entropy-formula))
    (assert (test-adaptive-entropy-thresholds))
    (assert (test-7-stage-pipeline-construction))))
