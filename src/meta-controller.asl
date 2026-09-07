(module asl-harness/meta-controller
  :d "Adaptive Harness Meta-Controller calculating continuous task entropy and routing execution across Fast-Path, Balanced, and Deep-Reflex tiers."
  :x [compute-task-entropy
      select-execution-tier
      select-execution-profile]
  :i [])

(df compute-task-entropy [(n-files I64) (domain-score F64) (ambiguity F64) (security-crit F64)] -> F64
  :d "Calculates continuous task entropy H_task from file count, domain depth, ambiguity, and security criticality."
  (let [(w1 0.5)
        (w2 1.5)
        (w3 1.0)
        (w4 1.5)
        (f-files (float-from-int64 n-files))]
    (+ (+ (* w1 f-files) (* w2 domain-score))
       (+ (* w3 ambiguity) (* w4 security-crit)))))

(df select-execution-tier [(entropy F64)] -> Str
  :d "Routes task entropy into execution tiers: fast-path, balanced, or deep-reflex."
  (cond
    ((< entropy 1.5) "fast-path")
    ((< entropy 4.0) "balanced")
    (:else "deep-reflex")))

(df select-execution-profile [(entropy F64)] -> Str
  :d "Selects execution profile matching Pillar VI specification from continuous entropy."
  (select-execution-tier entropy))
