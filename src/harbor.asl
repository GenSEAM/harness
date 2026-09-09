(module asl-harness/harbor
  :d "Pure ASL Harbor Benchmark Environment & Addie Harbor Adapter Specification: baseline environment configuration, supervisor session persistence traps, and head-tail diagnostic formatting."
  :x [HarborConfig
      make-baseline-env
      wrap-supervisor-command
      extract-diagnostic-markers
      format-head-tail-banner
      make-environment-contract
      make-stage-prompt]
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

(df make-stage-prompt [(stage Str) (instruction Str) (omissions (List Str))] -> Str
  :d "Constructs standardized prompt for given epistemic stage ensuring ASL toolbelt guidance and ANK rigor."
  (cond
    ((= stage "s1-ingest")
     (str "TASK INSTRUCTION:\n" instruction "\n\n"
          "=== STAGE 1/7: PERCEPTION & ENVIRONMENTAL INGESTION (s1) ===\n"
          "Explore the environment before modifying any files.\n"
          "Inspect the filesystem, current working directory, installed runtimes, and dependencies.\n"
          "Use native ASL Batch RPC:\n"
          "```bash\n"
          "asl rpc '(:batch\n"
          "  (:ls \"/app\")\n"
          "  (:find \"\" :ext \"py\")\n"
          "  (:exec :cmd \"python3 --version 2>/dev/null || which python\")\n"
          "  (:exec :cmd \"pip list 2>/dev/null || true\")\n"
          ")'\n"
          "```\n"
          "Output your inspection commands in a ```bash ... ``` block now."))
    ((= stage "s2-reformulate")
     (str "=== STAGE 2/7: OPERATIONAL REFORMULATION & INVARIANTS (s2) ===\n"
          "Analyze the observation from Stage 1 and the original task instruction.\n"
          "Explicitly define:\n"
          "1. TARGET FILES: What exact file paths must be created or modified?\n"
          "2. CLI / API CONTRACT: How will the program be invoked? (argv[1], options, stdin/stdout, exit codes)\n"
          "3. TRANSFORMATION: What exact logic must be implemented?\n"
          "4. PRESERVATION INVARIANTS: What legitimate content, structure, or behavior must NOT be altered or broken? (Negative constraints)\n"
          "Output your explicit operational specification now."))
    ((= stage "s3-intent-gate")
     (str "=== STAGE 3/7: INTENT-FIDELITY GATE REVISION (s3) ===\n"
          "Your reformulation in Stage 2 omitted critical requirements from the task instruction:\n"
          (string-join (map (fn [(o Str)] -> Str (str "- " o)) omissions) "\n") "\n\n"
          "Please revise your operational specification to explicitly address all omitted items."))
    ((= stage "s4-plan")
     (str "=== STAGE 4/7: ACTION DAG & ALL KNOWN UNKNOWNS (s4) ===\n"
          "1. ACTION DAG: Ordered sequence of atomic implementation steps.\n"
          "2. ANKs (All Known Unknowns & Domain Adversarial Checklist):\n"
          "   Enumerate ALL edge cases and potential failure modes:\n"
          "   - CLI / Boundary: Missing arguments, empty input files, non-existent files (must exit non-zero), unicode.\n"
          "   - Domain Adversarial Cases: Malformed inputs, bypass attempts, unexpected encodings, resource limits.\n"
          "   - Security / Injection Vectors: Nested execution contexts (iframe srcdoc, data: URIs, event handlers), bypass encodings.\n"
          "   - Preservation Invariants: Confirm legitimate structures, existing baseline behavior, and negative constraints remain completely intact.\n"
          "3. ADVERSARIAL TEST DESIGN:\n"
          "   Specify an adversarial test script that tests:\n"
          "   (a) Attack/bypass payloads and boundary conditions.\n"
          "   (b) Preservation of legitimate baseline inputs and formatting.\n"
          "   (c) Non-zero exit codes on invalid usage/errors.\n"
          "Output your plan and test specification now."))
    ((= stage "s5-plan-gate")
     (str "=== STAGE 5/7: PRE-MORTEM PLAN GATE REVISION (s5) ===\n"
          "Your plan lacks sufficient adversarial rigor:\n"
          (string-join (map (fn [(i Str)] -> Str (str "- " i)) omissions) "\n") "\n\n"
          "Please update your plan with explicit adversarial edge cases and a non-vacuous test suite."))
    ((= stage "s6-implement")
     (str "=== STAGE 6/7: ATOMIC IMPLEMENTATION (s6) ===\n"
          "Implement the complete, hardened solution now.\n"
          "- To create or write target files, prioritize native ASL Batch RPC:\n"
          "  asl rpc '(:batch (:write \"<file>\" \"<content>\"))'\n"
          "  (This writes cleanly in memory and flushes to disk without heredoc escaping or truncation errors).\n"
          "- If editing existing files, use native ASL batch RPC:\n"
          "  asl rpc '(:batch (:edit \"<file>\" \"<old>\" \"<new>\") (:diff) (:flush))\n"
          "- Ensure all requirements, argument handling, and edge cases from Stages 2 & 4 are handled.\n"
          "- Write robust, production-grade code with zero stubs, zero TODOs, and explicit error handling.\n"
          "Output your implementation commands in a ```bash ... ``` block now."))
    ((= stage "s7-verify")
     (str "=== STAGE 7/7: PHYSICAL ADVERSARIAL VERIFICATION & RECONCILIATION (s7) ===\n"
          "Execute physical verification now:\n"
          "1. Verify target files exist on disk with non-zero size:\n"
          "   `test -s <target_file> && echo \"File verified\"`\n"
          "2. Write and execute your adversarial test script using `asl rpc '(:batch (:write \"<test_file>\" \"<content>\") (:exec :cmd \"<runner>\"))'`:\n"
          "   - Verify all boundary conditions and edge cases from Stage 4 pass cleanly.\n"
          "   - Verify legitimate existing baseline behavior is preserved completely.\n"
          "   - Verify invalid arguments or missing inputs exit with non-zero code.\n"
          "3. If all tests pass cleanly (exit 0), conclude by running:\n"
          "   echo \"TASK_FINISHED_SUCCESS\"\n"
          "Output your test and verification commands in a ```bash ... ``` block now."))
    (true "")))
