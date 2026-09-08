(module asl-harness/delegate
  :d "Native Agent Mesh task delegation engine and multi-context multiplexer over agent-bus"
  :x [DelegationMode
      DelegationPlan
      make-delegation-plan
      delegate-task-execution
      multiplex-context-slices]
  :i [])

(dfe DelegationMode
  (:c self [] "Direct single-turn execution by supervisor")
  (:c single [] "Single dedicated worker assigned to a task")
  (:c speculative-race [] "Concurrent dual-trajectory race across asymmetric temperature configurations")
  (:c clean-supervisor [] "Stateless audit evaluation with empty context"))

(dfs DelegationPlan
  (:f task-id Str "Unique task identifier")
  (:f mode DelegationMode "Selected delegation strategy")
  (:f lanes (List Str) "Active lane identifiers e.g. alpha and beta")
  (:f temperatures (List Float) "Target sampling temperatures e.g. 0.1 and 0.7")
  (:f max-turns Int64 "Maximum permitted turns before timeout"))

(df multiplex-context-slices [(base-spec Str) (lanes (List Str))] -> (List Str)
  :d "Derives isolated, lightweight context slices per lane without history cross-contamination"
  (if (list-empty? lanes)
    (list)
    (let [(head (option-or (list-head lanes) ""))
          (tail (option-or (list-tail lanes) (list)))
          (slice (str "(:context-slice :lane \"" head "\" :spec \"" base-spec "\")"))]
      (list-cons slice (multiplex-context-slices base-spec tail)))))

(df make-delegation-plan [(task-id Str) (mode DelegationMode)] -> DelegationPlan
  :d "Constructs canonical plan with default temperature profiles"
  (match mode
    ((speculative-race)
     (DelegationPlan
       :task-id task-id
       :mode mode
       :lanes (list "alpha" "beta")
       :temperatures (list 0.1 0.7)
       :max-turns 3))
    ((single)
     (DelegationPlan
       :task-id task-id
       :mode mode
       :lanes (list "alpha")
       :temperatures (list 0.2)
       :max-turns 5))
    ((clean-supervisor)
     (DelegationPlan
       :task-id task-id
       :mode mode
       :lanes (list "audit")
       :temperatures (list 0.0)
       :max-turns 1))
    ((self)
     (DelegationPlan
       :task-id task-id
       :mode mode
       :lanes (list "supervisor")
       :temperatures (list 0.0)
       :max-turns 1))))

(df delegate-task-execution [(plan DelegationPlan) (spec Str)] -> (List Str)
  :d "Dispatches task execution across planned worker lanes and multiplexes context slices"
  (multiplex-context-slices spec (.-lanes plan)))
