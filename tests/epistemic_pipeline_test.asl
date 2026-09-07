(module asl-harness/epistemic-pipeline-test
  :d "Unit verification test suite for the 7-stage epistemic reflection pipeline and task entropy controller."
  :x [test-pipeline-stage-enumeration
      test-reflection-config-defaults
      test-fidelity-gate-evaluation
      test-fidelity-gate-prompt-overlap
      test-task-entropy-formula
      test-adaptive-entropy-thresholds
      test-7-stage-pipeline-construction
      test-operational-model-construction-and-formatting
      test-epistemic-pipeline-execution
      run-tests]
  :i [(steps-pipeline :a sp) (operational-model :a op)])

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
    (and (= (list-length (.-enabled-stages cfg)) 7)
         (and (not (.-allow-fast-path cfg))
              (and (>= (.-min-fidelity-score cfg) 0.95)
                   (.-strict-falsify cfg))))))

(df test-fidelity-gate-evaluation [] -> Bool
  :d "Verifies fidelity gate accepts high confidence and rejects low or failed verdicts."
  (let [(cfg (sp/default-reflection-config))
        (v-pass (sp/ReflectionVerdict
                  :stage (sp/s7-verify)
                  :passed true
                  :hallucinations (list)
                  :omitted-constraints (list)
                  :confidence-score 0.98))
        (v-low (sp/ReflectionVerdict
                 :stage (sp/s7-verify)
                 :passed true
                 :hallucinations (list)
                 :omitted-constraints (list "missing corner case")
                 :confidence-score 0.82))
        (v-fail (sp/ReflectionVerdict
                  :stage (sp/s7-verify)
                  :passed false
                  :hallucinations (list "unsupported claim")
                  :omitted-constraints (list)
                  :confidence-score 0.99))]
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
         (and (>= (.-confidence-score v-good) 0.8)
              (and (not (.-passed v-bad))
                   (and (< (.-confidence-score v-bad) 0.8)
                        (> (list-length (.-omitted-constraints v-bad)) 0)))))))

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

(df test-operational-model-construction-and-formatting [] -> Bool
  :d "Verifies operational model constructor and ASN serializer."
  (let [(model (op/make-operational-model
                 (list "harness/src/steps-pipeline.asl" "harness/src/operational-model.asl")
                 (list "execute-epistemic-pipeline" "OperationalModel")
                 "asl test --strict-falsify"
                 (list "no foreign deps" "zero comments")))
        (formatted (op/format-operational-model model))]
    (and (= (list-length (.-target-files model)) 2)
         (and (= (list-length (.-required-symbols model)) 2)
              (and (= (.-expected-exit-behavior model) "asl test --strict-falsify")
                   (and (= (list-length (.-forbidden-side-effects model)) 2)
                        (and (string-contains? formatted ":operational-model")
                             (and (string-contains? formatted ":target-files")
                                  (and (string-contains? formatted "harness/src/steps-pipeline.asl")
                                       (and (string-contains? formatted ":required-symbols")
                                            (string-contains? formatted ":forbidden-side-effects")))))))))))

(df test-epistemic-pipeline-execution [] -> Bool
  :d "Verifies Stage 3 Intent-Fidelity Gate and multi-stage verification engine."
  (let [(cfg (sp/default-reflection-config))
        (inst-clean "Refactor harness/src/steps-pipeline.asl to implement execute-epistemic-pipeline with zero foreign files and verify via asl test --strict-falsify")
        (model-clean (op/make-operational-model
                       (list "harness/src/steps-pipeline.asl")
                       (list "execute-epistemic-pipeline")
                       "asl test --strict-falsify harness/tests/epistemic_pipeline_test.asl"
                       (list "zero foreign files" "never use foreign packages")))
        (v-clean (sp/execute-epistemic-pipeline inst-clean model-clean cfg))
        (inst-omitted "Refactor harness/src/steps-pipeline.asl and harness/src/operational-model.asl to implement execute-epistemic-pipeline with zero foreign files and verify via asl test --strict-falsify")
        (model-omitted (op/make-operational-model
                         (list "harness/src/steps-pipeline.asl")
                         (list "execute-epistemic-pipeline")
                         "asl test --strict-falsify"
                         (list "zero foreign files")))
        (v-omitted (sp/execute-epistemic-pipeline inst-omitted model-omitted cfg))
        (inst-hallucinated "Refactor harness/src/steps-pipeline.asl to implement execute-epistemic-pipeline with zero foreign files and verify via asl test --strict-falsify")
        (model-hallucinated (op/make-operational-model
                              (list "harness/src/steps-pipeline.asl")
                              (list "execute-epistemic-pipeline" "axios-http-client")
                              "asl test --strict-falsify"
                              (list "zero foreign files")))
        (v-hallucinated (sp/execute-epistemic-pipeline inst-hallucinated model-hallucinated cfg))]
    (and (.-passed v-clean)
         (and (>= (.-confidence-score v-clean) 0.95)
              (and (= (list-length (.-omitted-constraints v-clean)) 0)
                   (and (= (list-length (.-hallucinations v-clean)) 0)
                        (and (not (.-passed v-omitted))
                             (and (> (list-length (.-omitted-constraints v-omitted)) 0)
                                  (and (not (.-passed v-hallucinated))
                                       (> (list-length (.-hallucinations v-hallucinated)) 0))))))))))

(df run-tests [] -> Bool
  :d "Executes all epistemic pipeline assertions."
  (do
    (assert (test-pipeline-stage-enumeration))
    (assert (test-reflection-config-defaults))
    (assert (test-fidelity-gate-evaluation))
    (assert (test-fidelity-gate-prompt-overlap))
    (assert (test-task-entropy-formula))
    (assert (test-adaptive-entropy-thresholds))
    (assert (test-7-stage-pipeline-construction))
    (assert (test-operational-model-construction-and-formatting))
    (assert (test-epistemic-pipeline-execution))))
