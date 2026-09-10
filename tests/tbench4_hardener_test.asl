(module asl-harness/tbench4-hardener-test
  :d "Unit test suite for Hardened TerminalBench-4 Execution Harness"
  :x [test-watchdog-timer-creation
      test-skeleton-log-extraction
      test-sanitize-terminal-execution
      test-non-interactive-guards
      test-skeleton-error-detection
      run-tests]
  :i [(tbench4_hardener :a tb)])

(df test-watchdog-timer-creation [] -> Bool
  :d "Verifies WatchdogTimer parameter initialization and escalation"
  (let [(w1 (tb/make-watchdog-timer 10000 60000 true))
        (w2 (tb/make-watchdog-timer 5000 30000 false))]
    (assert (= (.-sliding-timeout-ms w1) 10000) "Watchdog sliding window must match 10s")
    (assert (= (.-hard-ceiling-ms w1) 60000) "Watchdog hard ceiling must match 60s")
    (assert (.-escalation-sigkill w1) "Escalation must be true for w1")
    (assert (not (.-escalation-sigkill w2)) "Escalation must be false for w2")
    true))

(df test-skeleton-log-extraction [] -> Bool
  :d "Verifies SkeletonLog construction and clean exit status"
  (let [(clean-out "building target
compilation ok
exit 0")
        (sk1 (tb/extract-proc-skeleton clean-out 0))
        (sk2 (tb/extract-proc-skeleton clean-out 1))]
    (assert (.-exited-cleanly sk1) "sk1 must report clean exit")
    (assert (not (.-exited-cleanly sk2)) "sk2 must report failed exit on non-zero return")
    (assert (> (string-length (.-head-snippet sk1)) 0) "Head snippet must be populated")
    (assert (= (.-error-lines sk1) 0) "Zero error lines in clean output")
    true))

(df test-sanitize-terminal-execution [] -> Bool
  :d "Verifies environment decoration and non-interactive sudo injection"
  (let [(w (tb/make-watchdog-timer 10000 60000 true))
        (h-active (tb/make-tbench-hardener true w 1000))
        (h-passive (tb/make-tbench-hardener false w 1000))
        (cmd1 "sudo apt update")
        (cmd2 "make test")
        (san1 (tb/sanitize-terminal-execution cmd1 h-active))
        (san2 (tb/sanitize-terminal-execution cmd2 h-active))
        (san3 (tb/sanitize-terminal-execution cmd2 h-passive))]
    (assert (string-contains? san1 "sudo -n") "Sudo must be converted to non-interactive sudo -n")
    (assert (string-contains? san2 "CI=1") "Active hardener must prepend CI=1")
    (assert (string-contains? san2 "TERM=dumb") "Active hardener must prepend TERM=dumb")
    (assert (= san3 cmd2) "Passive hardener must preserve command untouched")
    true))

(df test-non-interactive-guards [] -> Bool
  :d "Verifies apt-get non-interactive flags injection"
  (let [(w (tb/make-watchdog-timer 10000 60000 true))
        (h (tb/make-tbench-hardener true w 1000))
        (res (tb/sanitize-terminal-execution "apt-get install curl" h))]
    (assert (string-contains? res "DEBIAN_FRONTEND=noninteractive") "Must inject noninteractive frontend")
    (assert (string-contains? res "-y") "Must inject auto-yes flag -y")
    true))

(df test-skeleton-error-detection [] -> Bool
  :d "Verifies detection of fatal error markers in process logs"
  (let [(err-out "compiling file.c
fatal: failed to open header
error: undefined symbol
FAILED")
        (sk (tb/extract-proc-skeleton err-out 2))]
    (assert (not (.-exited-cleanly sk)) "Must report failed execution")
    (assert (> (.-error-lines sk) 0) "Must count multiple error lines")
    (assert (string-contains? (.-tail-snippet sk) "error") "Tail snippet must reflect error state")
    true))

(df run-tests [] -> Bool
  :d "Executes all tbench4 hardener test cases"
  (and (test-watchdog-timer-creation)
       (and (test-skeleton-log-extraction)
            (and (test-sanitize-terminal-execution)
                 (and (test-non-interactive-guards)
                      (test-skeleton-error-detection))))))
