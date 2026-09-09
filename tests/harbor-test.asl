(module asl-harness-tests/harbor-test
  :d "Unit tests for pure ASL Harbor benchmark runner and Modal Cloud bench specifications"
  :x [test-make-baseline-env
      test-wrap-supervisor-command
      test-extract-diagnostic-markers
      test-format-head-tail-banner
      test-make-environment-contract
      test-compute-bench-metrics
      test-make-stage-prompt
      run-tests]
  :i [(asl-harness/harbor :a hb)
      (asl-harness/modal-bench :a mb)])

(df test-make-baseline-env [] -> Bool
  (let [(env (hb/make-baseline-env))]
    (assert (string-contains? env "export ASL_AIRGAP=1 ASL_OFFLINE=1") "contains airgap")
    (assert (string-contains? env "DEBIAN_FRONTEND=noninteractive") "contains debian frontend")
    (assert (string-contains? env "PYTHONUNBUFFERED=1") "contains python unbuffered")
    (assert (string-contains? env "GIT_TERMINAL_PROMPT=0") "contains git terminal prompt")
    (assert (string-contains? env "PIP_NO_INPUT=1") "contains pip no input")
    (assert (string-contains? env "NO_COLOR=1") "contains no color")
    (assert (string-contains? env "TERM=dumb") "contains term dumb")
    true))

(df test-wrap-supervisor-command [] -> Bool
  (let [(wrapped (hb/wrap-supervisor-command "/workspace/app" "cargo test --offline"))]
    (assert (string-contains? wrapped "/workspace/app") "contains app dir")
    (assert (string-contains? wrapped "cargo test --offline") "contains command")
    (assert (string-contains? wrapped "__save_state() {") "contains save state")
    (assert (string-contains? wrapped "trap __save_state EXIT") "contains trap")
    (assert (string-contains? wrapped "__asl_rc=$?") "contains asl rc")
    (assert (string-contains? wrapped "exit $__asl_rc") "contains exit rc")
    (assert (string-contains? wrapped "/tmp/.harness/state.cwd") "contains state cwd")
    (assert (string-contains? wrapped "/tmp/.harness/state.env") "contains state env")
    true))

(df test-extract-diagnostic-markers [] -> Bool
  (let [(omitted (list "compiling foo v0.1.0"
                       "warning: unused variable x"
                       "error[E0425]: cannot find value `bar`"
                       "note: informational message"
                       "FAILED: test_suite_auth"
                       "regular line without issues"
                       "fatal: remote repository not found"
                       "panic in worker thread: index out of bounds"
                       "execution exception logged"))
        (markers (hb/extract-diagnostic-markers omitted))
        (empty-res (hb/extract-diagnostic-markers (list "clean line 1" "clean line 2")))]
    (assert (= (list-length markers) 5) "5 diagnostic markers extracted")
    (assert (= (list-length empty-res) 0) "0 markers on clean lines")
    (assert (string-contains? (option-or (list-head markers) "") "error") "first marker contains error")
    (assert (string-contains? (string-join markers " ") "panic") "markers contain panic")
    true))

(df test-format-head-tail-banner [] -> Bool
  (let [(diags (list "error: out of memory" "panic: abort"))
        (banner-with-diag (hb/format-head-tail-banner 120 60 diags))
        (banner-empty (hb/format-head-tail-banner 120 60 (list)))]
    (assert (string-contains? banner-with-diag "[... truncated 60 lines; diagnostic: error: out of memory | panic: abort ...]") "banner with diag formatted")
    (assert (string-contains? banner-empty "[... truncated 60 lines ...]") "empty banner formatted")
    true))

(df test-make-environment-contract [] -> Bool
  (let [(contract (hb/make-environment-contract))]
    (assert (string-contains? contract "Environment Contract:") "contract header")
    (assert (string-contains? contract "no TTY") "no TTY")
    (assert (string-contains? contract "/dev/null") "dev null")
    (assert (string-contains? contract "90s") "90s")
    (assert (string-contains? contract "Session persistence") "session persistence")
    (assert (string-contains? contract "nohup") "nohup")
    true))

(df test-compute-bench-metrics [] -> Bool
  (let [(r1 (mb/TaskResult :task-id "TB4-001" :passed true :exit-code 0 :duration-ms 1200))
        (r2 (mb/TaskResult :task-id "TB4-002" :passed false :exit-code 1 :duration-ms 2500))
        (r3 (mb/TaskResult :task-id "TB4-003" :passed true :exit-code 0 :duration-ms 800))
        (results (list r1 r2 r3))
        (metrics (mb/compute-bench-metrics results))
        (empty-metrics (mb/compute-bench-metrics (list)))]
    (assert (string-contains? metrics ":total 3") "total 3")
    (assert (string-contains? metrics ":passed 2") "passed 2")
    (assert (string-contains? metrics ":failed 1") "failed 1")
    (assert (string-contains? empty-metrics ":total 0") "empty total 0")
    (assert (string-contains? empty-metrics ":passed 0") "empty passed 0")
    (assert (string-contains? empty-metrics ":failed 0") "empty failed 0")
    (assert (string-contains? empty-metrics ":pass-rate-pct 0.0") "empty pass rate 0.0")
    true))

(df test-make-stage-prompt [] -> Bool
  (let [(p1 (hb/make-stage-prompt "s1-ingest" "Fix python bug" (list)))
        (p2 (hb/make-stage-prompt "s2-reformulate" "" (list)))
        (p3 (hb/make-stage-prompt "s3-intent-gate" "" (list "missing arg")))
        (p4 (hb/make-stage-prompt "s4-plan" "" (list)))
        (p5 (hb/make-stage-prompt "s5-plan-gate" "" (list "missing edge case")))
        (p6 (hb/make-stage-prompt "s6-implement" "" (list)))
        (p7 (hb/make-stage-prompt "s7-verify" "" (list)))]
    (assert (string-contains? p1 "STAGE 1/7") "s1 contains header")
    (assert (string-contains? p1 "asl rpc") "s1 guides asl rpc")
    (assert (string-contains? p2 "STAGE 2/7") "s2 contains header")
    (assert (string-contains? p2 "PRESERVATION INVARIANTS") "s2 contains preservation")
    (assert (string-contains? p3 "STAGE 3/7") "s3 contains header")
    (assert (string-contains? p3 "- missing arg") "s3 lists omissions")
    (assert (string-contains? p4 "STAGE 4/7") "s4 contains header")
    (assert (string-contains? p4 "ALL KNOWN UNKNOWNS") "s4 contains anks")
    (assert (string-contains? p5 "STAGE 5/7") "s5 contains header")
    (assert (string-contains? p5 "- missing edge case") "s5 lists issues")
    (assert (string-contains? p6 "STAGE 6/7") "s6 contains header")
    (assert (string-contains? p6 "(:write") "s6 guides atomic write")
    (assert (string-contains? p7 "STAGE 7/7") "s7 contains header")
    (assert (string-contains? p7 "TASK_FINISHED_SUCCESS") "s7 defines victory marker")
    true))

(df run-tests [] -> Bool
  (do
    (test-make-baseline-env)
    (test-wrap-supervisor-command)
    (test-extract-diagnostic-markers)
    (test-format-head-tail-banner)
    (test-make-environment-contract)
    (test-compute-bench-metrics)
    (test-make-stage-prompt)
    true))
