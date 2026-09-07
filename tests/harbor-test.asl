(module asl-harness-tests/harbor-test
  :d "Unit tests for pure ASL Harbor benchmark runner and Modal Cloud bench specifications"
  :x [test-make-baseline-env
      test-wrap-supervisor-command
      test-extract-diagnostic-markers
      test-format-head-tail-banner
      test-make-environment-contract
      test-compute-bench-metrics
      run-tests]
  :i [(asl-harness/harbor :a hb)
      (asl-harness/modal-bench :a mb)])

(df test-make-baseline-env [] -> Bool
  (let [(env (hb/make-baseline-env))]
    (and (string-contains? env "export ASL_AIRGAP=1 ASL_OFFLINE=1")
         (and (string-contains? env "DEBIAN_FRONTEND=noninteractive")
              (and (string-contains? env "PYTHONUNBUFFERED=1")
                   (and (string-contains? env "GIT_TERMINAL_PROMPT=0")
                        (and (string-contains? env "PIP_NO_INPUT=1")
                             (and (string-contains? env "NO_COLOR=1")
                                  (string-contains? env "TERM=dumb")))))))))

(df test-wrap-supervisor-command [] -> Bool
  (let [(wrapped (hb/wrap-supervisor-command "/workspace/app" "cargo test --offline"))]
    (and (string-contains? wrapped "/workspace/app")
         (and (string-contains? wrapped "cargo test --offline")
              (and (string-contains? wrapped "__save_state() {")
                   (and (string-contains? wrapped "trap __save_state EXIT")
                        (and (string-contains? wrapped "__asl_rc=$?")
                             (and (string-contains? wrapped "exit $__asl_rc")
                                  (and (string-contains? wrapped "/tmp/.harness/state.cwd")
                                       (string-contains? wrapped "/tmp/.harness/state.env"))))))))))

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
    (and (= (list-length markers) 5)
         (and (= (list-length empty-res) 0)
              (and (string-contains? (option-or (list-head markers) "") "error")
                   (string-contains? (string-join markers " ") "panic"))))))

(df test-format-head-tail-banner [] -> Bool
  (let [(diags (list "error: out of memory" "panic: abort"))
        (banner-with-diag (hb/format-head-tail-banner 120 60 diags))
        (banner-empty (hb/format-head-tail-banner 120 60 (list)))]
    (and (string-contains? banner-with-diag "[... truncated 60 lines; diagnostic: error: out of memory | panic: abort ...]")
         (string-contains? banner-empty "[... truncated 60 lines ...]"))))

(df test-make-environment-contract [] -> Bool
  (let [(contract (hb/make-environment-contract))]
    (and (string-contains? contract "Environment Contract:")
         (and (string-contains? contract "no TTY")
              (and (string-contains? contract "/dev/null")
                   (and (string-contains? contract "90s")
                        (and (string-contains? contract "Session persistence")
                             (string-contains? contract "nohup"))))))))

(df test-compute-bench-metrics [] -> Bool
  (let [(r1 (mb/TaskResult :task-id "TB4-001" :passed true :exit-code 0 :duration-ms 1200))
        (r2 (mb/TaskResult :task-id "TB4-002" :passed false :exit-code 1 :duration-ms 2500))
        (r3 (mb/TaskResult :task-id "TB4-003" :passed true :exit-code 0 :duration-ms 800))
        (results (list r1 r2 r3))
        (metrics (mb/compute-bench-metrics results))
        (empty-metrics (mb/compute-bench-metrics (list)))]
    (and (string-contains? metrics ":total 3")
         (and (string-contains? metrics ":passed 2")
              (and (string-contains? metrics ":failed 1")
                   (and (string-contains? empty-metrics ":total 0")
                        (and (string-contains? empty-metrics ":passed 0")
                             (and (string-contains? empty-metrics ":failed 0")
                                  (string-contains? empty-metrics ":pass-rate-pct 0.0")))))))))

(df run-tests [] -> Bool
  (and (test-make-baseline-env)
       (and (test-wrap-supervisor-command)
            (and (test-extract-diagnostic-markers)
                 (and (test-format-head-tail-banner)
                      (and (test-make-environment-contract)
                           (test-compute-bench-metrics)))))))
