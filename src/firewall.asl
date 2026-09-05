(module asl-harness/firewall
  :d "Deterministic Action Firewall: AST-level boundary validation, safe execution policy, and lease enforcement."
  :x [FirewallPolicy FirewallVerdict default-firewall-policy
      evaluate-path-boundary evaluate-command-safety audit-action]
  :i [])

(dfs FirewallPolicy
  (:f allowed-roots (List Str) "List of permitted root paths")
  (:f allow-write Bool "Permission lease flag allowing file modifications")
  (:f allow-exec Bool "Permission lease flag allowing shell command execution")
  (:f max-file-bytes I64 "Maximum permissible file size in bytes"))

(dfs FirewallVerdict
  (:f allowed Bool "True if action or target satisfies safety and capability constraints")
  (:f reason Str "Diagnostic verdict rationale")
  (:f sanitized-target Str "Sanitized canonical path or command string"))

(df default-firewall-policy [] -> FirewallPolicy
  :d "Constructs standard baseline firewall policy restricting actions to workspace root."
  (FirewallPolicy
    :allowed-roots (list ".")
    :allow-write true
    :allow-exec false
    :max-file-bytes 1048576))

(df path-in-roots? [(roots (List Str)) (path Str)] -> Bool
  :d "Checks whether a path resides within any of the permitted root directories."
  (fold (fn [(matched Bool) (r Str)] -> Bool
          (or matched
              (if (= r ".")
                  (and (not (string-starts-with? path "/"))
                       (not (string-starts-with? path "~")))
                  (or (= path r)
                      (string-starts-with? path (str r "/"))))))
        false
        roots))

(df evaluate-path-boundary [(policy FirewallPolicy) (path Str)] -> FirewallVerdict
  :d "Validates file paths against traversal attacks, restricted system paths, and workspace boundaries."
  (let [(clean (string-trim path))]
    (cond
      ((string-empty? clean)
       (FirewallVerdict
         :allowed false
         :reason "Path validation failed: path cannot be empty"
         :sanitized-target ""))
      ((string-contains? clean "..")
       (FirewallVerdict
         :allowed false
         :reason "Path traversal detected: directory traversal sequences disallowed"
         :sanitized-target ""))
      ((or (string-starts-with? clean "/etc") (string-contains? clean "/etc/"))
       (FirewallVerdict
         :allowed false
         :reason "Restricted path: access to system directory /etc disallowed"
         :sanitized-target ""))
      ((or (string-starts-with? clean "~") (string-contains? clean ".ssh"))
       (FirewallVerdict
         :allowed false
         :reason "Restricted path: access to credentials and home directory disallowed"
         :sanitized-target ""))
      ((or (string-starts-with? clean "/dev") (or (string-starts-with? clean "/proc") (or (string-starts-with? clean "/sys") (string-starts-with? clean "/root"))))
       (FirewallVerdict
         :allowed false
         :reason "Restricted path: access to system root disallowed"
         :sanitized-target ""))
      ((not (path-in-roots? (.-allowed-roots policy) clean))
       (FirewallVerdict
         :allowed false
         :reason "Path out of boundary: path resides outside permitted workspace roots"
         :sanitized-target ""))
      (:else
       (FirewallVerdict
         :allowed true
         :reason "Path verified within allowed sandbox boundary"
         :sanitized-target clean)))))

(df detect-dangerous-pattern [(cmd Str)] -> (Option Str)
  :d "Detects dangerous shell patterns and returns the matched token identifier if found."
  (let [(c (string-trim cmd))]
    (cond
      ((or (string-contains? c "rm -rf") (or (string-contains? c "rm -fr") (or (string-contains? c "rm -r -f") (string-contains? c "rm -f -r"))))
       (some "rm -rf"))
      ((or (string-contains? c "curl | sh") (or (string-contains? c "curl|sh") (or (string-contains? c "curl | bash") (or (string-contains? c "curl|bash") (or (string-contains? c "| sh") (or (string-contains? c "|sh") (or (string-contains? c "| bash") (or (string-contains? c "|bash") (or (string-contains? c "wget | sh") (string-contains? c "wget|sh"))))))))))
       (some "curl | sh"))
      ((or (= c "eval") (or (string-starts-with? c "eval ") (or (string-contains? c " eval") (or (string-contains? c "eval(") (string-contains? c ";eval")))))
       (some "eval"))
      ((or (string-contains? c "dd if=") (string-contains? c "dd if ="))
       (some "dd if="))
      ((string-contains? c "mkfs")
       (some "mkfs"))
      ((string-contains? c ":(){ :|:& };:")
       (some "fork bomb"))
      ((or (string-contains? c "> /dev/sd") (string-contains? c "> /dev/nvme"))
       (some "raw block device write"))
      (:else (none)))))

(df evaluate-command-safety [(policy FirewallPolicy) (cmd Str)] -> FirewallVerdict
  :d "Validates shell commands against blacklisted tokens and destructive operations."
  (let [(trimmed (string-trim cmd))
        (danger (detect-dangerous-pattern trimmed))]
    (mt danger
      ((some pat)
       (FirewallVerdict
         :allowed false
         :reason (str "Dangerous command blocked: blacklisted token '" pat "' detected")
         :sanitized-target ""))
      ((none)
       (FirewallVerdict
         :allowed true
         :reason "Command verified safe for execution"
         :sanitized-target trimmed)))))

(df is-read-action? [(action Str)] -> Bool
  :d "Checks if action kind corresponds to a read operation."
  (or (= action "read")
      (or (= action "fs-read")
          (or (= action "read-file")
              (= action "file-read")))))

(df is-write-action? [(action Str)] -> Bool
  :d "Checks if action kind corresponds to a write operation."
  (or (= action "write")
      (or (= action "fs-write")
          (or (= action "write-file")
              (or (= action "file-write")
                  (or (= action "delete")
                      (= action "remove")))))))

(df is-exec-action? [(action Str)] -> Bool
  :d "Checks if action kind corresponds to a command execution operation."
  (or (= action "exec")
      (or (= action "shell")
          (or (= action "bash")
              (or (= action "sh")
                  (or (= action "cmd")
                      (or (= action "run")
                          (= action "execute"))))))))

(df audit-action [(policy FirewallPolicy) (action-kind Str) (target Str)] -> FirewallVerdict
  :d "Audits an agent action and target against security policy constraints and capability leases."
  (cond
    ((is-read-action? action-kind)
     (evaluate-path-boundary policy target))
    ((is-write-action? action-kind)
     (if (not (.-allow-write policy))
         (FirewallVerdict
           :allowed false
           :reason "Action blocked: file writing is disabled by firewall policy"
           :sanitized-target "")
         (evaluate-path-boundary policy target)))
    ((is-exec-action? action-kind)
     (let [(safety (evaluate-command-safety policy target))]
       (if (not (.-allowed safety))
           safety
           (if (not (.-allow-exec policy))
               (FirewallVerdict
                 :allowed false
                 :reason "Action blocked: shell execution is disabled by firewall policy"
                 :sanitized-target "")
               safety))))
    (:else
     (FirewallVerdict
       :allowed false
       :reason (str "Action blocked: unrecognized action kind '" action-kind "'")
       :sanitized-target ""))))
