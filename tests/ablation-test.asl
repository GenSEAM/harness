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
    (assert (.-verified-pass m) "preload ablation verified pass")
    (assert (string-contains? (.-delta m) "-95.0%") "preload token advantage delta")
    (assert (> (.-improvement-factor m) 10.0) "preload improvement factor > 10")
    true))

(df test-ablation-health [] -> Bool
  :d "Verifies structural health ablation asserts cycle prevention."
  (let [(m (ab/measure-health-ablation))]
    (assert (.-verified-pass m) "health ablation verified pass")
    (assert (string-contains? (.-delta m) "cycle prevention") "health delta contains cycle prevention")
    true))

(df test-ablation-deps [] -> Bool
  :d "Verifies ghost API ablation asserts detection of deprecated methods."
  (let [(m (ab/measure-deps-ablation))]
    (assert (.-verified-pass m) "deps ablation verified pass")
    (assert (string-contains? (.-delta m) "Zero API skew") "deps delta zero API skew")
    true))

(df test-ablation-fsm [] -> Bool
  :d "Verifies FSM normalizer ablation asserts keyword and delimiter repair."
  (let [(m (ab/measure-fsm-ablation))]
    (assert (.-verified-pass m) "fsm ablation verified pass")
    (assert (string-contains? (.-delta m) "valid execution") "fsm delta valid execution")
    true))

(df test-ablation-ast-gate [] -> Bool
  :d "Verifies AST mutation gate ablation asserts blocked assertion deletion."
  (let [(m (ab/measure-ast-gate-ablation))]
    (assert (.-verified-pass m) "ast gate ablation verified pass")
    (assert (string-contains? (.-delta m) "test preservation") "ast gate delta test preservation")
    true))

(df test-ablation-sanitizer [] -> Bool
  :d "Verifies error sanitizer ablation asserts traceback token reduction."
  (let [(m (ab/measure-sanitizer-ablation))]
    (assert (.-verified-pass m) "sanitizer ablation verified pass")
    (assert (string-contains? (.-delta m) "-93.5%") "sanitizer delta -93.5%")
    true))

(df test-ablation-pointer [] -> Bool
  :d "Verifies perceptual pointer ablation asserts >99% prompt bloat reduction."
  (let [(m (ab/measure-pointer-ablation))]
    (assert (.-verified-pass m) "pointer ablation verified pass")
    (assert (string-contains? (.-delta m) "-99.3%") "pointer delta -99.3%")
    true))

(df test-ablation-gateway [] -> Bool
  :d "Verifies L7 gateway ablation asserts prevention of verbal ESH claims."
  (let [(m (ab/measure-gateway-ablation))]
    (assert (.-verified-pass m) "gateway ablation verified pass")
    (assert (string-contains? (.-delta m) "unverified task aborts") "gateway delta unverified task aborts")
    true))

(df test-ablation-dag [] -> Bool
  :d "Verifies blackboard DAG ablation asserts elimination of infinite retries."
  (let [(m (ab/measure-dag-ablation))]
    (assert (.-verified-pass m) "dag ablation verified pass")
    (assert (string-contains? (.-delta m) "-90% wasted turns") "dag delta -90% wasted turns")
    true))

(df test-full-ablation-report [] -> Bool
  :d "Verifies end-to-end execution of full ablation suite and report formatting."
  (let [(rep (ab/run-full-ablation-suite))
        (md (ab/format-ablation-markdown rep))]
    (assert (= (list-length (.-metrics rep)) 9) "metrics length 9")
    (assert (= (.-total-regressions-prevented rep) 9) "total regressions prevented 9")
    (assert (string-contains? md "Empirical Ablation Analysis") "report title")
    (assert (string-contains? md "Graph-Horizon Preload") "report preload")
    (assert (string-contains? md "Blackboard Task-Premise DAG") "report dag")
    (assert (string-contains? md "Overall Context Token Reduction") "report token reduction")
    true))

(df run-tests [] -> Bool
  :d "Executes full ablation verification test suite."
  (do
    (test-ablation-preload)
    (test-ablation-health)
    (test-ablation-deps)
    (test-ablation-fsm)
    (test-ablation-ast-gate)
    (test-ablation-sanitizer)
    (test-ablation-pointer)
    (test-ablation-gateway)
    (test-ablation-dag)
    (test-full-ablation-report)
    true))
