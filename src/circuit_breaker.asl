(module asl-harness/circuit-breaker
  :d "Anti-thrash circuit breaker and two-tier operator escalation protocol."
  :x [CircuitState CircuitBreaker make-circuit-breaker
      record-success record-failure is-tripped?
      resolve-escalation reset-circuit]
  :i [])

(dfe CircuitState
  (:c st-closed [] "Normal operating state: executions permitted")
  (:c st-open [] "Tripped state: anti-thrash circuit open, execution suspended")
  (:c st-half-open [] "Probe state: testing recovery after cooldown"))

(dfs CircuitBreaker
  (:f threshold I64 "Consecutive failure limit before tripping")
  (:f fail-count I64 "Current consecutive failure counter")
  (:f state CircuitState "Current operational circuit state")
  (:f last-error Str "Latest recorded error message or diagnostic")
  (:f tier I64 "Escalation tier: 0 (none), 1 (approver agent), 2 (human operator)"))

(df make-circuit-breaker [(threshold I64)] -> CircuitBreaker
  :d "Constructs an initialized circuit breaker with specified failure threshold."
  (CircuitBreaker
    :threshold threshold
    :fail-count 0
    :state (st-closed)
    :last-error ""
    :tier 0))

(df record-success [(cb CircuitBreaker)] -> CircuitBreaker
  :d "Records a successful execution, resetting consecutive failure counter and closing circuit."
  (CircuitBreaker
    :threshold (.-threshold cb)
    :fail-count 0
    :state (st-closed)
    :last-error ""
    :tier 0))

(df record-failure [(cb CircuitBreaker) (err Str)] -> CircuitBreaker
  :d "Records a failure, advancing failure counter and updating escalation tier when threshold is reached."
  (let [(new-count (+ (.-fail-count cb) 1))
        (tripped? (>= new-count (.-threshold cb)))
        (new-tier (if (>= new-count (* (.-threshold cb) 2))
                    2
                    (if tripped? 1 0)))
        (new-state (if tripped? (st-open) (st-closed)))]
    (CircuitBreaker
      :threshold (.-threshold cb)
      :fail-count new-count
      :state new-state
      :last-error err
      :tier new-tier)))

(df is-tripped? [(cb CircuitBreaker)] -> Bool
  :d "Checks if the circuit breaker is in open state preventing further automated attempts."
  (mt (.-state cb)
    ((st-open) true)
    ((st-closed) false)
    ((st-half-open) false)))

(df resolve-escalation [(cb CircuitBreaker)] -> Str
  :d "Resolves the appropriate recipient or channel based on escalation tier."
  (cond
    ((= (.-tier cb) 2) "human-operator")
    ((= (.-tier cb) 1) "approver")
    (true "none")))

(df reset-circuit [(cb CircuitBreaker)] -> CircuitBreaker
  :d "Manually resets the circuit breaker to clean closed state."
  (make-circuit-breaker (.-threshold cb)))
