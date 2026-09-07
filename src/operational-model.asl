(module asl-harness/operational-model
  :d "Stage 2 Operational Mental Model structures and formatters for epistemic reflection."
  :x [OperationalModel make-operational-model format-operational-model]
  :i [])

(dfs OperationalModel
  (:f target-files (List Str) "Identified files subject to modification")
  (:f required-symbols (List Str) "Symbols required to be declared or altered")
  (:f expected-exit-behavior Str "Verification expectations on exit")
  (:f forbidden-side-effects (List Str) "Negative boundaries and immutable zones"))

(df make-operational-model [(target-files (List Str)) (required-symbols (List Str)) (expected-exit-behavior Str) (forbidden-side-effects (List Str))] -> OperationalModel
  :d "Constructs an OperationalModel instance for Stage 2 self-reformulation."
  (OperationalModel
    :target-files target-files
    :required-symbols required-symbols
    :expected-exit-behavior expected-exit-behavior
    :forbidden-side-effects forbidden-side-effects))

(df format-operational-model [(model OperationalModel)] -> Str
  :d "Formats an OperationalModel into a canonical ASN S-expression representation."
  (str "(:operational-model"
       " :target-files [" (string-join (.-target-files model) " ") "]"
       " :required-symbols [" (string-join (.-required-symbols model) " ") "]"
       " :expected-exit-behavior \"" (.-expected-exit-behavior model) "\""
       " :forbidden-side-effects [" (string-join (.-forbidden-side-effects model) " ") "]"
       ")"))
