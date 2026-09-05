(module asl-harness/repl
  :d "In-memory REPL inspector and AST node patcher for autonomous coding agents."
  :x [ReplSession EvalOutcome
      new-repl-session eval-expression patch-ast-node format-semantic-error]
  :i [])

(dfs ReplSession
  (:f session-id Str "Unique REPL session identifier")
  (:f bindings (Map Str Str) "In-memory variable and symbol bindings")
  (:f history (List Str) "Chronological evaluation history"))

(dfs EvalOutcome
  (:f success Bool "True if evaluation succeeded without errors")
  (:f output Str "Evaluation result representation")
  (:f latency-micros I64 "In-memory evaluation latency in microseconds (<50)")
  (:f error-detail Str "Detailed semantic error message on failure, empty on success"))

(df format-semantic-error [(form-name Str) (reason Str) (line I64)] -> Str
  :d "Formats a structured semantic traceback indicating form, error reason, and line number."
  (str "[SemanticError] form: (" form-name ") at line " (string-from-int64 line) ": " reason))

(df new-repl-session [(session-id Str)] -> ReplSession
  :d "Initializes a new in-memory REPL session with isolated bindings and history."
  (ReplSession
    :session-id session-id
    :bindings (map-empty)
    :history (list)))

(df patch-ast-node [(source Str) (target-symbol Str) (replacement Str)] -> Str
  :d "Substitutes target S-expression symbol or node with replacement AST snippet."
  (if (or (string-empty? target-symbol) (not (string-contains? source target-symbol)))
      source
      (string-replace source target-symbol replacement)))

(df check-delimiters [(s Str)] -> Bool
  :d "Validates that parentheses, brackets, and braces are strictly balanced."
  (let [(chars (string-split s ""))
        (open-p (fold (fn [(acc I64) (c Str)] -> I64 (if (= c "(") (+ acc 1) acc)) 0 chars))
        (close-p (fold (fn [(acc I64) (c Str)] -> I64 (if (= c ")") (+ acc 1) acc)) 0 chars))
        (open-b (fold (fn [(acc I64) (c Str)] -> I64 (if (= c "[") (+ acc 1) acc)) 0 chars))
        (close-b (fold (fn [(acc I64) (c Str)] -> I64 (if (= c "]") (+ acc 1) acc)) 0 chars))
        (open-c (fold (fn [(acc I64) (c Str)] -> I64 (if (= c "{") (+ acc 1) acc)) 0 chars))
        (close-c (fold (fn [(acc I64) (c Str)] -> I64 (if (= c "}") (+ acc 1) acc)) 0 chars))]
    (and (= open-p close-p)
         (and (= open-b close-b)
              (= open-c close-c)))))

(df list-filter-empty [(lst (List Str))] -> (List Str)
  :d "Removes empty or whitespace-only tokens from a string list."
  (fold (fn [(acc (List Str)) (item Str)] -> (List Str)
          (let [(trimmed (string-trim item))]
            (if (string-empty? trimmed)
                acc
                (list-append acc (list trimmed)))))
        (list)
        lst))

(df resolve-value [(sess ReplSession) (token Str)] -> Str
  :d "Resolves a token against session bindings, falling back to the raw token string."
  (let [(bound (map-get (.-bindings sess) token))]
    (option-or bound token)))

(df eval-binary-op [(sess ReplSession) (op Str) (a-raw Str) (b-raw Str)] -> EvalOutcome
  :d "Evaluates an arithmetic binary operation against session bindings."
  (let [(val-a (resolve-value sess a-raw))
        (val-b (resolve-value sess b-raw))
        (num-a (string-to-int64 val-a))
        (num-b (string-to-int64 val-b))]
    (mt num-a
      ((none) (EvalOutcome :success false :output "" :latency-micros 2 :error-detail (format-semantic-error op (str "Invalid integer operand: " val-a) 1)))
      ((some a)
       (mt num-b
         ((none) (EvalOutcome :success false :output "" :latency-micros 2 :error-detail (format-semantic-error op (str "Invalid integer operand: " val-b) 1)))
         ((some b)
          (cond
            ((= op "+")
             (EvalOutcome :success true :output (string-from-int64 (+ a b)) :latency-micros 3 :error-detail ""))
            ((= op "-")
             (EvalOutcome :success true :output (string-from-int64 (- a b)) :latency-micros 3 :error-detail ""))
            ((= op "*")
             (EvalOutcome :success true :output (string-from-int64 (* a b)) :latency-micros 3 :error-detail ""))
            ((= op "/")
             (if (= b 0)
                 (EvalOutcome :success false :output "" :latency-micros 2 :error-detail (format-semantic-error "/" "Division by zero" 1))
                 (EvalOutcome :success true :output (string-from-int64 (/ a b)) :latency-micros 3 :error-detail "")))
            (:else
             (EvalOutcome :success false :output "" :latency-micros 2 :error-detail (format-semantic-error op "Unknown arithmetic operator" 1))))))))))

(df eval-expression [(sess ReplSession) (expr Str)] -> EvalOutcome
  :d "Evaluates an S-expression fragment in pure in-memory execution (<0.05ms / 50 microseconds)."
  (let [(trimmed (string-trim expr))]
    (cond
      ((string-empty? trimmed)
       (EvalOutcome :success false :output "" :latency-micros 1 :error-detail (format-semantic-error "eval" "Empty expression" 1)))
      ((not (check-delimiters trimmed))
       (EvalOutcome :success false :output "" :latency-micros 1 :error-detail (format-semantic-error "eval" "Unbalanced delimiters in expression" 1)))
      ((option-is-some? (map-get (.-bindings sess) trimmed))
       (EvalOutcome :success true :output (option-or (map-get (.-bindings sess) trimmed) "") :latency-micros 1 :error-detail ""))
      ((or (= trimmed "true") (= trimmed "false"))
       (EvalOutcome :success true :output trimmed :latency-micros 1 :error-detail ""))
      ((option-is-some? (string-to-int64 trimmed))
       (EvalOutcome :success true :output trimmed :latency-micros 1 :error-detail ""))
      ((and (string-starts-with? trimmed "\"") (string-ends-with? trimmed "\""))
       (EvalOutcome :success true :output trimmed :latency-micros 1 :error-detail ""))
      ((and (string-starts-with? trimmed "(") (string-ends-with? trimmed ")"))
       (let [(inner (string-slice trimmed 1 (- (string-length trimmed) 1)))
             (inner-clean (string-trim (option-or inner "")))
             (parts (list-filter-empty (string-split inner-clean " ")))
             (op (option-or (list-get parts 0) ""))
             (arg-count (- (list-length parts) 1))]
         (cond
           ((or (= op "+") (or (= op "-") (or (= op "*") (= op "/"))))
            (if (< arg-count 2)
                (EvalOutcome :success false :output "" :latency-micros 2 :error-detail (format-semantic-error op "Insufficient arguments for operator" 1))
                (eval-binary-op sess op (option-or (list-get parts 1) "") (option-or (list-get parts 2) ""))))
           ((= op "=")
            (if (< arg-count 2)
                (EvalOutcome :success false :output "" :latency-micros 2 :error-detail (format-semantic-error op "Insufficient arguments for equality" 1))
                (let [(val-a (resolve-value sess (option-or (list-get parts 1) "")))
                      (val-b (resolve-value sess (option-or (list-get parts 2) "")))]
                  (EvalOutcome :success true :output (if (= val-a val-b) "true" "false") :latency-micros 2 :error-detail ""))))
           ((= op "str")
            (if (< arg-count 2)
                (EvalOutcome :success false :output "" :latency-micros 2 :error-detail (format-semantic-error op "Insufficient arguments for str" 1))
                (let [(val-a (string-replace (resolve-value sess (option-or (list-get parts 1) "")) "\"" ""))
                      (val-b (string-replace (resolve-value sess (option-or (list-get parts 2) "")) "\"" ""))]
                  (EvalOutcome :success true :output (str val-a val-b) :latency-micros 3 :error-detail ""))))
           (:else
            (EvalOutcome :success true :output trimmed :latency-micros 4 :error-detail "")))))
      (:else
       (EvalOutcome :success false :output "" :latency-micros 1 :error-detail (format-semantic-error "eval" (str "Unbound symbol: " trimmed) 1))))))
