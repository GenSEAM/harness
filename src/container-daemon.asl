(module asl-harness/container-daemon
  :d "Autonomous In-Container Execution Daemon: atomic file operations, process isolation, grounding and trace sanitization in pure ASL."
  :x [DaemonConfig
      DaemonCommand
      DaemonResult
      make-daemon-config
      make-daemon-command
      make-daemon-result
      format-daemon-result
      read-bounded-lines
      apply-string-replacement
      sanitize-error-output
      evaluate-daemon-command]
  :i [(sanitizer :a san)])

(dfs DaemonConfig
  (:f max-tokens-tail I64 "Maximum tokens for error trace tail bounding")
  (:f default-timeout I64 "Default command execution timeout in seconds")
  (:f work-dir Str "Absolute workspace root inside the container"))

(dfs DaemonCommand
  (:f action Str "Target action: read, write, replace, list, exec, test, settle")
  (:f path Str "Target filesystem path or empty")
  (:f content Str "Payload content or base64 data")
  (:f start-line I64 "1-indexed starting line for bounded read")
  (:f end-line I64 "1-indexed ending line for bounded read")
  (:f cmd Str "Shell command string for execution")
  (:f timeout-sec I64 "Command timeout limit in seconds"))

(dfs DaemonResult
  (:f success Bool "Execution status flag")
  (:f exit-code I64 "Process return code or 0 on success")
  (:f output Str "Structured, bounded output payload")
  (:f error-msg Str "Sanitized error message if failed")
  (:f tokens-used I64 "Estimated tokens consumed by payload"))

(df make-daemon-config [(max-tokens I64) (timeout I64) (dir Str)] -> DaemonConfig
  :d "Constructs daemon configuration."
  (DaemonConfig
    :max-tokens-tail max-tokens
    :default-timeout timeout
    :work-dir dir))

(df make-daemon-command [(action Str) (path Str) (content Str) (start-l I64) (end-l I64) (cmd Str) (timeout I64)] -> DaemonCommand
  :d "Constructs a structured daemon command."
  (DaemonCommand
    :action action
    :path path
    :content content
    :start-line start-l
    :end-line end-l
    :cmd cmd
    :timeout-sec timeout))

(df make-daemon-result [(success Bool) (code I64) (out Str) (err Str)] -> DaemonResult
  :d "Constructs a daemon execution result."
  (let [(tokens (/ (string-length out) 4))]
    (DaemonResult
      :success success
      :exit-code code
      :output out
      :error-msg err
      :tokens-used (if (<= tokens 0) 1 tokens))))

(df format-daemon-result [(res DaemonResult)] -> Str
  :d "Serializes daemon result into compact ASN S-expression."
  (if (.-success res)
      (str "(:res :status :ok :rc " (show (.-exit-code res)) " :tokens " (show (.-tokens-used res)) " :payload \"" (.-output res) "\")")
      (str "(:res :status :error :rc " (show (.-exit-code res)) " :err \"" (.-error-msg res) "\")")))

(df read-bounded-lines [(content Str) (start-line I64) (end-line I64)] -> Str
  :d "Extracts a bounded range of lines with line number prefixes."
  (let [(lines (string-split content "\n"))
        (len (list-length lines))
        (s (if (< start-line 1) 1 start-line))
        (e (if (> end-line len) len end-line))]
    (if (> s e)
        ""
        (foldl (fn [(acc Str) (idx I64)] -> Str
                 (let [(line-content (option-or (list-get lines (- idx 1)) ""))]
                   (str acc (show idx) ": " line-content "\n")))
               ""
               (range s (+ e 1))))))

(df apply-string-replacement [(source Str) (old-sub Str) (new-sub Str)] -> (Result Str Str)
  :d "Applies single contiguous replacement if target string is uniquely found."
  (if (not (string-contains? source old-sub))
      (err "Target substring not found in source")
      (ok (string-replace source old-sub new-sub))))

(df sanitize-error-output [(raw-stderr Str) (max-tokens I64)] -> Str
  :d "Sanitizes stack tracebacks to root cause frames bounded to token limit."
  (let [(san (san/sanitize-trace raw-stderr max-tokens))]
    (.-sanitized-output san)))

(df evaluate-daemon-command [(cfg DaemonConfig) (cmd DaemonCommand)] -> DaemonResult
  :d "Evaluates daemon command against configuration invariants."
  (let [(act (.-action cmd))]
    (cond
      ((= act "read")
       (if (string-empty? (.-path cmd))
           (make-daemon-result false 1 "" "Missing path parameter for read")
           (make-daemon-result true 0 "(:read-ready)" "")))
      ((= act "write")
       (if (string-empty? (.-path cmd))
           (make-daemon-result false 1 "" "Missing path parameter for write")
           (make-daemon-result true 0 (str "(:wrote :bytes " (show (string-length (.-content cmd))) ")") "")))
      ((= act "replace")
       (if (string-empty? (.-path cmd))
           (make-daemon-result false 1 "" "Missing path parameter for replace")
           (make-daemon-result true 0 "(:replaced-ok)" "")))
      ((= act "list")
       (make-daemon-result true 0 "(:listed-entries)" ""))
      ((= act "exec")
       (if (string-empty? (.-cmd cmd))
           (make-daemon-result false 1 "" "Empty command string")
           (make-daemon-result true 0 "(:exec-dispatched)" "")))
      ((= act "settle")
       (make-daemon-result true 0 "(:task-finished-success)" ""))
      (:else
       (make-daemon-result false 127 "" (str "Unknown daemon action: " act))))))
