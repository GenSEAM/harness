(module asl-harness/ablation-test
  :d "Unit tests for Instrumental Ablation Suite verifying WITH vs WITHOUT deltas."
  :x [test-ablation-preload
      test-ablation-health
      test-ablation-deps
      test-ablation-fsm
      test-ablation-ast-gate
      test-ablation-sanitizer
      test-ablation-pointer
      test-ablation-gateway
      test-ablation-dag
      test-full-ablation-report
      run-tests]
  :i [(ablation :a ab)])

"run: (run-tests)"

(df test-ablation-preload [] -> Bool
  :d "Verifies preload horizon ablation asserts token advantage."
  (let [(m (ab/measure-preload-ablation))]
    (and (.-verified-pass m)
         (and (string-contains? (.-delta m) "-95.0%")
              (> (.-improvement-factor m) 10.0)))))

(df test-ablation-health [] -> Bool
  :d "Verifies structural health ablation asserts cycle prevention."
  (let [(m (ab/measure-health-ablation))]
    (and (.-verified-pass m)
         (string-contains? (.-delta m) "cycle prevention"))))

(df test-ablation-deps [] -> Bool
  :d "Verifies ghost API ablation asserts detection of deprecated methods."
  (let [(m (ab/measure-deps-ablation))]
    (and (.-verified-pass m)
         (string-contains? (.-delta m) "Zero API skew"))))

(df test-ablation-fsm [] -> Bool
  :d "Verifies FSM normalizer ablation asserts keyword and delimiter repair."
  (let [(m (ab/measure-fsm-ablation))]
    (and (.-verified-pass m)
         (string-contains? (.-delta m) "valid execution"))))

(df test-ablation-ast-gate [] -> Bool
  :d "Verifies AST mutation gate ablation asserts blocked assertion deletion."
  (let [(m (ab/measure-ast-gate-ablation))]
    (and (.-verified-pass m)
         (string-contains? (.-delta m) "test preservation"))))

(df test-ablation-sanitizer [] -> Bool
  :d "Verifies error sanitizer ablation asserts traceback token reduction."
  (let [(m (ab/measure-sanitizer-ablation))]
    (and (.-verified-pass m)
         (string-contains? (.-delta m) "-93.5%"))))

(df test-ablation-pointer [] -> Bool
  :d "Verifies perceptual pointer ablation asserts >99% prompt bloat reduction."
  (let [(m (ab/measure-pointer-ablation))]
    (and (.-verified-pass m)
         (string-contains? (.-delta m) "-99.3%"))))

(df test-ablation-gateway [] -> Bool
  :d "Verifies L7 gateway ablation asserts prevention of verbal ESH claims."
  (let [(m (ab/measure-gateway-ablation))]
    (and (.-verified-pass m)
         (string-contains? (.-delta m) "unverified task aborts"))))

(df test-ablation-dag [] -> Bool
  :d "Verifies blackboard DAG ablation asserts elimination of infinite retries."
  (let [(m (ab/measure-dag-ablation))]
    (and (.-verified-pass m)
         (string-contains? (.-delta m) "-90% wasted turns"))))

(df test-full-ablation-report [] -> Bool
  :d "Verifies end-to-end execution of full ablation suite and report formatting."
  (let [(rep (ab/run-full-ablation-suite))
        (md (ab/format-ablation-markdown rep))]
    (and (= (list-length (.-metrics rep)) 9)
         (and (= (.-total-regressions-prevented rep) 9)
              (and (string-contains? md "Empirical Ablation Analysis")
                   (and (string-contains? md "Graph-Horizon Preload")
                        (and (string-contains? md "Blackboard Task-Premise DAG")
                             (string-contains? md "Overall Context Token Reduction"))))))))

(df run-tests [] -> Bool
  :d "Executes full ablation verification test suite."
  (and (test-ablation-preload)
       (and (test-ablation-health)
            (and (test-ablation-deps)
                 (and (test-ablation-fsm)
                      (and (test-ablation-ast-gate)
                           (and (test-ablation-sanitizer)
                                (and (test-ablation-pointer)
                                     (and (test-ablation-gateway)
                                          (and (test-ablation-dag)
                                               (test-full-ablation-report)))))))))))
