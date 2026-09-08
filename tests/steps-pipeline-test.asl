(module asl-harness/steps-pipeline-test
  :d "Unit tests for Steps & GAP Cognitive Pipeline Engine"
  :x [test-create-pipeline
      test-gap-audit-clean
      test-gap-audit-omission
      test-gap-audit-bloat
      test-impl-audit-clean
      test-impl-audit-failed
      test-advance-stage
      test-entropy-classification
      test-pipeline-modes
      test-addie-config
      run-steps-pipeline-tests
      run-tests]
  :i [(steps-pipeline :a sp)])

(df test-create-pipeline [] -> Bool
  :d "Verifies instantiation of steps pipeline with standard 5 phases"
  (let [(p (sp/create-steps-pipeline "task-x" "Build an HTML sanitizer in /app/filter.py"))]
    (and (= (.-task-id p) "task-x")
         (and (= (.-active-stage p) "scout")
              (and (= (len (.-phases p)) 5)
                   (not (.-is-completed p)))))))

(df test-gap-audit-clean [] -> Bool
  :d "Verifies plan gap audit approves a complete, minimal plan"
  (let [(inst "Write a script taking argv[1] and exit 1 on error")
        (steps ["1. Check argv[1] input" "2. Parse payload" "3. If error exit 1" "4. Test runner"])
        (audit (sp/audit-plan-gaps inst steps))]
    (and (= (.-verdict audit) "approve")
         (.-invariants-preserved audit))))

(df test-gap-audit-omission [] -> Bool
  :d "Verifies plan gap audit flags omitted CLI argument handling"
  (let [(inst "Write a script taking argv[1] and modifying in-place")
        (steps ["1. Just process hardcoded file" "2. Done"])
        (audit (sp/audit-plan-gaps inst steps))]
    (and (= (.-verdict audit) "approve-with-amendments")
         (and (not (.-invariants-preserved audit))
              (> (len (.-omissions audit)) 0)))))

(df test-gap-audit-bloat [] -> Bool
  :d "Verifies plan gap audit flags over-engineering and excessive phases"
  (let [(inst "Simple string replace")
        (steps ["1. A" "2. B" "3. C" "4. D" "5. E" "6. F" "7. G" "8. H" "9. I" "10. J"])
        (audit (sp/audit-plan-gaps inst steps))]
    (and (= (.-verdict audit) "approve-with-amendments")
         (> (len (.-bloat-warnings audit)) 0))))

(df test-impl-audit-clean [] -> Bool
  :d "Verifies implementation gap audit approves verified code diff"
  (let [(inst "Modify in-place")
        (diff "+ with open(p, 'w') as f: f.write(res)")
        (audit (sp/audit-impl-gaps inst diff true))]
    (and (= (.-verdict audit) "approve")
         (.-invariants-preserved audit))))

(df test-impl-audit-failed [] -> Bool
  :d "Verifies implementation gap audit rejects when test gate fails"
  (let [(inst "Modify in-place")
        (diff "+ bad code")
        (audit (sp/audit-impl-gaps inst diff false))]
    (= (.-verdict audit) "reject")))

(df test-advance-stage [] -> Bool
  :d "Verifies stage transitions through the pipeline"
  (let [(p (sp/create-steps-pipeline "task-1" "Simple task"))
        (p1 (sp/advance-pipeline-stage p true "ls ok"))]
    (and (= (.-current-phase-idx p1) 1)
         (= (.-active-stage p1) "plan"))))

(df test-entropy-classification [] -> Bool
  :d "Verifies task entropy classifier routes high-stakes tasks to full and simple tasks to fast"
  (and (= (sp/classify-task-entropy "terminal-bench/html-js-filter: prevent xss attacks") "full")
       (and (= (sp/classify-task-entropy "TB-042: solve interleaved vigenere cipher") "full")
            (and (= (sp/classify-task-entropy "Fix small typo in comment") "fast")
                 (= (sp/classify-task-entropy "Add REST endpoint for user profiles") "standard")))))

(df test-pipeline-modes [] -> Bool
  :d "Verifies creation of fast, standard, and full pipelines"
  (let [(p-fast (sp/make-pipeline-by-mode "t-fast" "fix typo" "fast"))
        (p-std (sp/make-pipeline-by-mode "t-std" "add endpoint" "standard"))
        (p-full (sp/make-pipeline-by-mode "t-full" "xss security filter" "full"))
        (p-adapt (sp/make-pipeline-by-mode "t-adapt" "crypto vigenere solver" "adaptive"))]
    (and (= (len (.-phases p-fast)) 2)
         (and (= (.-active-stage p-fast) "impl")
              (and (= (len (.-phases p-std)) 3)
                   (and (= (.-active-stage p-std) "plan")
                        (and (= (len (.-phases p-full)) 5)
                             (and (= (.-active-stage p-full) "scout")
                                  (= (len (.-phases p-adapt)) 5)))))))))

(df test-addie-config [] -> Bool
  :d "Verifies default Addie configuration"
  (let [(cfg (sp/default-addie-config))]
    (and (= (.-pipeline cfg) "full")
         (and (.-asl-first cfg)
              (.-scout-polyglot cfg)))))

(df run-steps-pipeline-tests [] -> Bool
  :d "Runs all steps pipeline test cases"
  (do
    (assert (test-create-pipeline))
    (assert (test-gap-audit-clean))
    (assert (test-gap-audit-omission))
    (assert (test-gap-audit-bloat))
    (assert (test-impl-audit-clean))
    (assert (test-impl-audit-failed))
    (assert (test-advance-stage))
    (assert (test-entropy-classification))
    (assert (test-pipeline-modes))
    (assert (test-addie-config))
    true))

(df run-tests [] -> Bool
  :d "Executes full steps pipeline test suite."
  (run-steps-pipeline-tests))
