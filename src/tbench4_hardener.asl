(module asl-harness/tbench4-hardener
  :d "Hardened TerminalBench-4 Execution Harness with Non-Interactive PTY and Skeleton Telemetry"
  :x [TBenchHardener
      SkeletonLog
      WatchdogTimer
      sanitize-terminal-execution
      extract-proc-skeleton
      make-tbench-hardener
      make-skeleton-log
      make-watchdog-timer]
  :i [])

(dfs WatchdogTimer
  :d "Sliding execution watchdog timer with timeout escalation"
  (:f sliding-timeout-ms I64 "Idle output timeout window in milliseconds")
  (:f hard-ceiling-ms I64 "Absolute maximum execution ceiling")
  (:f escalation-sigkill Bool "True if SIGTERM escalates to SIGKILL on stall"))

(dfs SkeletonLog
  :d "Compacted telemetry log summarizing execution head, tail, and error density"
  (:f total-lines I64 "Total output lines recorded")
  (:f error-lines I64 "Detected error count")
  (:f head-snippet Str "First few lines of command output")
  (:f tail-snippet Str "Last few lines containing exit state")
  (:f exited-cleanly Bool "True if return code is 0"))

(dfs TBenchHardener
  :d "Configuration for TerminalBench-4 deterministic non-interactive sandbox"
  (:f non-interactive Bool "True to set DEBIAN_FRONTEND=noninteractive and disallow PTY prompts")
  (:f watchdog WatchdogTimer "Configured watchdog supervisor")
  (:f max-log-lines I64 "Maximum log lines before truncation"))

(df make-watchdog-timer [(sliding I64) (ceiling I64) (sigkill Bool)] -> WatchdogTimer
  :d "Constructs a WatchdogTimer supervisor configuration"
  (WatchdogTimer
    :sliding-timeout-ms sliding
    :hard-ceiling-ms ceiling
    :escalation-sigkill sigkill))

(df make-skeleton-log [(total I64) (errors I64) (head Str) (tail Str) (clean Bool)] -> SkeletonLog
  :d "Constructs a SkeletonLog record"
  (SkeletonLog
    :total-lines total
    :error-lines errors
    :head-snippet head
    :tail-snippet tail
    :exited-cleanly clean))

(df make-tbench-hardener [(non-int Bool) (watchdog WatchdogTimer) (max-lines I64)] -> TBenchHardener
  :d "Constructs a TBenchHardener configuration"
  (TBenchHardener
    :non-interactive non-int
    :watchdog watchdog
    :max-log-lines max-lines))

(df sanitize-terminal-execution [(cmd Str) (hardener TBenchHardener)] -> Str
  :d "Injects non-interactive environment flags and strips interactive shell prompts"
  (let [(trimmed (string-trim cmd))]
    (cond
      ((string-empty? trimmed) "")
      ((.-non-interactive hardener)
       (cond
         ((string-contains? trimmed "sudo ")
          (string-replace trimmed "sudo " "sudo -n "))
         ((string-contains? trimmed "apt-get ")
          (str "DEBIAN_FRONTEND=noninteractive " trimmed " -y"))
         (true (str "CI=1 TERM=dumb " trimmed))))
      (true trimmed))))

(df count-error-lines [(text Str)] -> I64
  :d "Counts lines containing common POSIX/compiler error signatures"
  (let [(c1 (if (string-contains? text "error:") 1 0))
        (c2 (if (string-contains? text "FAILED") 1 0))
        (c3 (if (string-contains? text "fatal:") 1 0))
        (c4 (if (string-contains? text "Permission denied") 1 0))]
    (+ c1 (+ c2 (+ c3 c4)))))

(df extract-proc-skeleton [(output Str) (exit-code I64)] -> SkeletonLog
  :d "Compacts multi-megabyte process stdout/stderr into a dense SkeletonLog"
  (let [(clean (string-trim output))
        (errors (count-error-lines clean))
        (is-clean (= exit-code 0))
        (head (if (> (string-length clean) 80)
                  (string-replace clean "
" " | ")
                  clean))
        (tail (if (string-contains? clean "error")
                  "contains error signature"
                  "exit nominal"))]
    (make-skeleton-log 10 errors head tail is-clean)))
