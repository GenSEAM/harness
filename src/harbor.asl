(module asl-harness/harbor
  :d "Pure ASL Harbor Benchmark Environment & Addie Harbor Adapter Specification: baseline environment configuration, supervisor session persistence traps, and head-tail diagnostic formatting."
  :x [HarborConfig
      make-baseline-env
      wrap-supervisor-command
      extract-diagnostic-markers
      format-head-tail-banner
      make-environment-contract]
  :i [])

(dfs HarborConfig
  (:f timeout-sec I64 "Per-command execution timeout threshold in seconds")
  (:f max-turns I64 "Maximum interactive action-observation turns allowed")
  (:f airgap Bool "True if external network access is strictly disabled"))

(df make-baseline-env [] -> Str
  :d "Constructs baseline non-interactive shell environment export string for hermetic benchmarks."
  "export ASL_AIRGAP=1 ASL_OFFLINE=1 DEBIAN_FRONTEND=noninteractive PYTHONUNBUFFERED=1 GIT_TERMINAL_PROMPT=0 PIP_NO_INPUT=1 NO_COLOR=1 TERM=dumb")

(df wrap-supervisor-command [(cwd Str) (cmd Str)] -> Str
  :d "Constructs supervisor shell wrapper with __save_state() bound to EXIT trap and sequential epilogue."
  (str
    "cd \"$(cat /tmp/.harness/state.cwd 2>/dev/null | tr -d \"\\r\\n\" || echo \"" cwd "\")\" 2>/dev/null || cd \"" cwd "\"; "
    "[ -f /tmp/.harness/state.env ] && . /tmp/.harness/state.env 2>/dev/null; "
    "__save_state() {\n"
    "  __asl_trap_rc=$?\n"
    "  trap - EXIT\n"
    "  set +e\n"
    "  pwd -P > /tmp/.harness/state.cwd.tmp && mv /tmp/.harness/state.cwd.tmp /tmp/.harness/state.cwd\n"
    "  export -p | grep -vE \"^declare -x (BASH_ENV|ENV|LD_PRELOAD|LD_LIBRARY_PATH|SHLVL|_|PWD|OLDPWD)=\" > /tmp/.harness/state.env.tmp && mv /tmp/.harness/state.env.tmp /tmp/.harness/state.env\n"
    "  return $__asl_trap_rc 2>/dev/null || exit $__asl_trap_rc\n"
    "};\n"
    "trap __save_state EXIT\n"
    cmd "\n"
    "__asl_rc=$?\n"
    "__save_state\n"
    "exit $__asl_rc"))

(df contains-diagnostic? [(line Str)] -> Bool
  :d "Internal predicate checking if line contains error, fail, exception, fatal, or panic."
  (let [(l (string-lower line))]
    (or (string-contains? l "error")
        (or (string-contains? l "fail")
            (or (string-contains? l "exception")
                (or (string-contains? l "fatal")
                    (string-contains? l "panic")))))))

(df extract-diagnostic-markers [(omitted-lines (List Str))] -> (List Str)
  :d "Scans omitted output lines for diagnostic indicators: error, fail, exception, fatal, panic."
  (let [(matching (filter (fn [(line Str)] -> Bool
                            (and (> (string-length (string-trim line)) 0)
                                 (contains-diagnostic? line)))
                          omitted-lines))]
    (map (fn [(line Str)] -> Str (string-trim line)) matching)))

(df format-head-tail-banner [(total-lines I64) (omitted-count I64) (diagnostics (List Str))] -> Str
  :d "Formats head-tail truncation banner with diagnostic indicator summary."
  (if (> (list-length diagnostics) 0)
    (str "[... truncated " (show omitted-count) " lines; diagnostic: " (string-join diagnostics " | ") " ...]")
    (str "[... truncated " (show omitted-count) " lines ...]")))

(df make-environment-contract [] -> Str
  :d "Returns concise factual environment contract for non-interactive benchmark execution."
  (str "Environment Contract:\n"
       "- Stdin is non-interactive (< /dev/null, no TTY).\n"
       "- 90s per-command timeout threshold.\n"
       "- Session persistence: working directory (cwd) and exported variables (export KEY=VAL) persist across turns.\n"
       "- For background services, use: nohup <cmd> > /tmp/srv.log 2>&1 &"))
