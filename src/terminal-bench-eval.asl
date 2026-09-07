(module asl-harness/terminal-bench-eval
  :d "Pure AgentScript specification for Terminal Bench evaluation bridge, task categorization, and telemetry reporting."
  :x []
  :i [])

(dfs EvalTask
  (:f id Str "Unique task identifier e.g. TB4-001")
  (:f category Str "Operational failure domain category")
  (:f name Str "Descriptive name of challenge task")
  (:f desc Str "Detailed directive requirement description"))

(df make-eval-task [(id Str) (category Str) (name Str) (desc Str)] -> EvalTask
  :d "Constructs an EvalTask record binding identifier, category, name, and description."
  (EvalTask
    :id id
    :category category
    :name name
    :desc desc))

(df categorize-tb-task [(id Str)] -> Str
  :d "Categorizes a Terminal Bench challenge task identifier into its operational failure domain."
  (let [(num-str (if (string-starts-with? id "TB4-")
                     (option-or (string-slice id 4 (string-length id)) "")
                     (if (string-starts-with? id "TB-")
                         (option-or (string-slice id 3 (string-length id)) "")
                         id)))]
    (mt (string-to-int64 num-str)
      ((some n)
       (cond
         ((<= n 12) "subshell-isolation")
         ((<= n 24) "cross-compile")
         ((<= n 36) "context-resilience")
         ((<= n 48) "ast-refactor")
         ((<= n 60) "env-bootstrap")
         ((<= n 70) "stream-pipeline")
         ((<= n 80) "system-net")
         ((<= n 90) "git-vcs")
         ((<= n 100) "build-packaging")
         ((<= n 110) "sec-permissions")
         ((<= n 150) "proc-analytics")
         (true "general")))
      ((none) "general"))))

(df format-eval-report [(passed I64) (total I64)] -> Str
  :d "Formats terminal bench evaluation report into dense ASN S-expression."
  (let [(failed (- total passed))
        (rate-pct (if (= total 0) "0.0%" (if (= passed total) "100.0%" (str (string-from-int64 (/ (* passed 100) total)) "%"))))
        (status-kw (if (= passed total) ":verified" ":incomplete"))]
    (str "(:terminal-bench-eval"
         " :total-tasks " (string-from-int64 total)
         " :passed-tasks " (string-from-int64 passed)
         " :failed-tasks " (string-from-int64 failed)
         " :pass-rate-pct " "\"" rate-pct "\""
         " :status " status-kw
         ")")))
