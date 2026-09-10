(module asl-harness/tests/model-calibration-test
  :d "Unit and falsifiable verification suite for model calibration stand and Pareto optimization."
  :x [test-canary-tasks-construction
      test-pareto-score-computation
      test-candidate-evaluation
      test-calibration-sweep-ranking
      test-optimal-candidate-selection
      test-format-calibration-result-asn
      test-ctrf-summary-parsing
      test-scalar-loss-and-progress
      test-continuous-gradient-directional-signal
      test-tiered-calibration-tasks
      test-browser-ceiling-and-nano-tasks
      run-tests]
  :i [(model_calibration :a mc)])

(df test-canary-tasks-construction [] -> Bool
  :d "Verifies construction of the 3 canonical calibration micro-canaries."
  (let [(canaries (mc/canonical-canary-tasks))
        (c1 (option-or (list-head canaries) (mc/make-canary-task "" "" "" 0 (list) (list))))]
    (do
      (assert (= (list-length canaries) 3) "Canary suite must have exactly 3 tasks")
      (assert (= (.-task-id c1) "CANARY-SYNTAX-01") "First canary must be CANARY-SYNTAX-01")
      (assert (= (.-kind c1) "syntax") "First canary kind must be syntax")
      (assert (= (list-length (.-required-facts c1)) 1) "First canary must have 1 required fact")
      true)))

(df test-pareto-score-computation [] -> Bool
  :d "Verifies Pareto multi-objective scoring formula and edge cases."
  (let [(score-good (mc/compute-pareto-score 100.0 500 false 80))
        (score-amn (mc/compute-pareto-score 100.0 500 true 80))
        (score-slow (mc/compute-pareto-score 100.0 500 false 800))
        (score-zero-tok (mc/compute-pareto-score 100.0 0 false 10))
        (score-zero-pass (mc/compute-pareto-score 0.0 500 false 80))]
    (do
      (assert (> score-good 0.0) "Clean run Pareto score must be positive")
      (assert (< score-amn score-good) "Amnesia detection must heavily penalize score")
      (assert (< score-slow score-good) "High latency must penalize score")
      (assert (> score-zero-tok score-good) "Lower tokens must yield higher score")
      (assert (< score-zero-pass score-good) "Zero pass rate must yield negative or lower score")
      (assert (<= score-zero-pass 0.0) "Zero pass rate must be non-positive")
      true)))

(df test-candidate-evaluation [] -> Bool
  :d "Verifies candidate evaluation across canary tasks."
  (let [(cand (mc/CalibrationCandidate
                :model-name "gemma-4-31b-it"
                :strategy "agent-directed"
                :temperature 0.2
                :budget-ceiling 4096))
        (canaries (mc/canonical-canary-tasks))
        (res (mc/evaluate-candidate cand canaries true))]
    (do
      (assert (= (.-status res) ":passed") "Candidate should pass canaries under agent-directed")
      (assert (= (.-pass-rate res) 100.0) "Pass rate should be 100%")
      (assert (not (.-amnesia-detected res)) "Amnesia should not be detected")
      (assert (> (.-avg-tokens res) 0) "Average tokens must be positive")
      (assert (> (.-latency-ms res) 0) "Latency must be positive")
      true)))

(df test-calibration-sweep-ranking [] -> Bool
  :d "Verifies grid sweep generates candidates and ranks them by Pareto score."
  (let [(cfg (mc/CalibrationSweepConfig
               :model-name "qwen-2.5-3b"
               :strategies (list "receipts" "agent-directed" "baseline")
               :temperatures (list 0.0 0.2)
               :budget-ceilings (list 4096)
               :dry-run true))
        (results (mc/run-calibration-sweep cfg))]
    (do
      (assert (= (list-length results) 6) "Sweep must generate 3 strategies * 2 temps = 6 results")
      (let [(first-res (option-or (list-head results)
                                  (mc/CalibrationEvaluationResult
                                    :candidate (mc/CalibrationCandidate :model-name "" :strategy "" :temperature 0.0 :budget-ceiling 0)
                                    :pass-rate 0.0
                                    :continuous-progress 0.0
                                    :avg-tokens 0
                                    :latency-ms 0
                                    :amnesia-detected false
                                    :pareto-score -999.0
                                    :status "")))
            (last-res (option-or (list-last results)
                                 (mc/CalibrationEvaluationResult
                                   :candidate (mc/CalibrationCandidate :model-name "" :strategy "" :temperature 0.0 :budget-ceiling 0)
                                   :pass-rate 0.0
                                   :continuous-progress 0.0
                                   :avg-tokens 0
                                   :latency-ms 0
                                   :amnesia-detected false
                                   :pareto-score 999.0
                                   :status "")))]
        (assert (>= (.-pareto-score first-res) (.-pareto-score last-res)) "Results must be sorted descending by Pareto score"))
      true)))

(df test-optimal-candidate-selection [] -> Bool
  :d "Verifies optimal candidate selection from sweep results."
  (let [(cfg (mc/CalibrationSweepConfig
               :model-name "gemma-4-31b-it"
               :strategies (list "receipts" "baseline")
               :temperatures (list 0.2)
               :budget-ceilings (list 4096)
               :dry-run true))
        (results (mc/run-calibration-sweep cfg))
        (opt-cand (mc/find-optimal-candidate results))]
    (mt opt-cand
      ((some cand)
       (do
         (assert (= (.-strategy cand) "receipts") "Receipts must win over baseline due to token savings")
         (assert (= (.-model-name cand) "gemma-4-31b-it") "Model name must match")
         true))
      ((none)
       (do
         (assert false "Expected some candidate")
         false)))))

(df test-format-calibration-result-asn [] -> Bool
  :d "Verifies structured ASN serialization of calibration result."
  (let [(cand (mc/CalibrationCandidate
                :model-name "ling-3.0-flash"
                :strategy "jit-memory"
                :temperature 0.0
                :budget-ceiling 2048))
        (res (mc/CalibrationEvaluationResult
               :candidate cand
               :pass-rate 100.0
               :continuous-progress 1.0
               :avg-tokens 320
               :latency-ms 45
               :amnesia-detected false
               :pareto-score 185.4
               :status ":passed"))
        (asn-str (mc/format-calibration-result-asn res))]
    (do
      (assert (string-starts-with? asn-str "(:calibration-result") "ASN must start with (:calibration-result")
      (assert (string-contains? asn-str ":model \"ling-3.0-flash\"") "ASN must contain model")
      (assert (string-contains? asn-str ":strategy \"jit-memory\"") "ASN must contain strategy")
      (assert (string-contains? asn-str ":pareto-score 185.4") "ASN must contain score")
      (assert (string-ends-with? asn-str ")") "ASN must end with closing paren")
      true)))

(df test-ctrf-summary-parsing [] -> Bool
  :d "Verifies parsing of real CTRF report from custom-memory-heap-crash benchmark trial."
  (let [(ctrf-raw (str "(\n"
                       "  :results (\n"
                       "    :tool (:name \"pytest\" :version \"8.4.1\")\n"
                       "    :summary (\n"
                       "      :tests 6\n"
                       "      :passed 4\n"
                       "      :failed 2\n"
                       "      :skipped 0\n"
                       "    )\n"
                       "  )\n"
                       ")"))
        (summary (mc/parse-ctrf-summary ctrf-raw))]
    (do
      (assert (= (.-total-tests summary) 6) "Total tests must be 6")
      (assert (= (.-passed-tests summary) 4) "Passed tests must be 4")
      (assert (= (.-failed-tests summary) 2) "Failed tests must be 2")
      (assert (> (.-progress-ratio summary) 0.66) "Progress ratio must be > 0.66")
      (assert (< (.-progress-ratio summary) 0.67) "Progress ratio must be < 0.67")
      true)))

(df test-scalar-loss-and-progress [] -> Bool
  :d "Verifies bounded scalar loss and continuous progress calculation for optimization tasks."
  (let [(metric (mc/compute-ceiling-loss "bin-packing-cost" 6000.0 3000.0))
        (prog (mc/compute-loss-progress (.-normalized-loss metric)))
        (cand (mc/CalibrationCandidate
                :model-name "gemma-4-31b-it"
                :strategy "receipts"
                :temperature 0.2
                :budget-ceiling 35000))
        (res (mc/evaluate-scalar-loss-trial cand metric 12000 1500))]
    (do
      (assert (= (.-current-val metric) 6000.0) "Current cost must match 6000.0")
      (assert (= (.-target-val metric) 3000.0) "Target ceiling must match 3000.0")
      (assert (= (.-normalized-loss metric) 1.0) "Normalized loss must be exactly 1.0 (100% over ceiling)")
      (assert (= prog 0.5) "Progress ratio for 1.0 loss must be 0.5")
      (assert (= (.-pass-rate res) 0.0) "Binary pass rate must be 0.0 when exceeding ceiling")
      (assert (= (.-continuous-progress res) 0.5) "Continuous progress must be 0.5")
      (assert (> (.-pareto-score res) 0.0) "Pareto score with 0.5 progress must remain positive")
      true)))

(df test-continuous-gradient-directional-signal [] -> Bool
  :d "Verifies directional gradient between failed runs: 4/6 passed subtests scores higher than 0/6."
  (let [(cand (mc/CalibrationCandidate
                :model-name "gemma-4-31b-it"
                :strategy "agent-directed"
                :temperature 0.2
                :budget-ceiling 35000))
        (ctrf-partial ":summary (:tests 6 :passed 4 :failed 2 :skipped 0)")
        (ctrf-zero ":summary (:tests 6 :passed 0 :failed 6 :skipped 0)")
        (res-partial (mc/evaluate-ctrf-trial cand ctrf-partial 25000 3000))
        (res-zero (mc/evaluate-ctrf-trial cand ctrf-zero 25000 3000))]
    (do
      (assert (= (.-pass-rate res-partial) 0.0) "Both trials must have 0.0 binary pass rate")
      (assert (= (.-pass-rate res-zero) 0.0) "Both trials must have 0.0 binary pass rate")
      (assert (> (.-pareto-score res-partial) (.-pareto-score res-zero)) "Partial progress run must score strictly higher than zero progress run")
      (assert (> (.-pareto-score res-partial) 0.0) "Partial progress with 66.7% subtests must yield positive efficiency")
      (assert (<= (.-pareto-score res-zero) 0.0) "Zero progress must yield non-positive efficiency")
      true)))

(df test-tiered-calibration-tasks [] -> Bool
  :d "Verifies stratified canary task suites for micro-SLMs and heavy frontier models."
  (let [(slm-tasks (mc/slm-calibration-tasks))
        (med-tasks (mc/medium-calibration-tasks))
        (front-tasks (mc/frontier-calibration-tasks))
        (hard-tasks (mc/super-hard-calibration-tasks))
        (all-tasks (mc/full-spectrum-canary-tasks))
        (slm-via-tier (mc/tasks-for-tier "slm"))
        (med-via-tier (mc/tasks-for-tier "medium"))
        (front-via-tier (mc/tasks-for-tier "frontier"))
        (hard-via-tier (mc/tasks-for-tier "impossible"))
        (superhard-via-tier (mc/tasks-for-tier "super-hard"))
        (all-via-tier (mc/tasks-for-tier "all"))
        (canon-via-tier (mc/tasks-for-tier "other"))
        (first-slm (option-or (list-head slm-tasks) (mc/make-canary-task "" "" "" 0 (list) (list))))
        (first-med (option-or (list-head med-tasks) (mc/make-canary-task "" "" "" 0 (list) (list))))
        (first-front (option-or (list-head front-tasks) (mc/make-canary-task "" "" "" 0 (list) (list))))
        (first-hard (option-or (list-head hard-tasks) (mc/make-canary-task "" "" "" 0 (list) (list))))]
    (do
      (assert (= (list-length slm-tasks) 5) "SLM suite must have 5 canary tasks")
      (assert (= (list-length med-tasks) 5) "Medium suite must have 5 canary tasks")
      (assert (= (list-length front-tasks) 5) "Frontier suite must have 5 challenge tasks")
      (assert (= (list-length hard-tasks) 2) "Super-hard suite must have 2 horizon challenge tasks")
      (assert (= (list-length all-tasks) 17) "Full spectrum canary suite must have 17 tasks")
      (assert (= (list-length slm-via-tier) 5) "Tier slm must return 5 tasks")
      (assert (= (list-length med-via-tier) 5) "Tier medium must return 5 tasks")
      (assert (= (list-length front-via-tier) 5) "Tier frontier must return 5 tasks")
      (assert (= (list-length hard-via-tier) 2) "Tier impossible must return 2 tasks")
      (assert (= (list-length superhard-via-tier) 2) "Tier super-hard must return 2 tasks")
      (assert (= (list-length all-via-tier) 17) "Tier all must return 17 tasks")
      (assert (= (list-length canon-via-tier) 3) "Default tier must return 3 canonical tasks")
      (assert (= (.-task-id first-slm) "SLM-DELIM-01") "First SLM task must be SLM-DELIM-01")
      (assert (= (.-task-id first-med) "MED-PARSE-01") "First medium task must be MED-PARSE-01")
      (assert (= (.-task-id first-front) "FRONT-HEAP-01") "First frontier task must be FRONT-HEAP-01")
      (assert (= (.-task-id first-hard) "IMPOSSIBLE-DISTRIB-CONSENSUS-01") "First hard task must be IMPOSSIBLE-DISTRIB-CONSENSUS-01")
      true)))

(df test-browser-ceiling-and-nano-tasks [] -> Bool
  :d "Verifies nano and browser calibration tasks and 3B browser ceiling enforcement"
  (let [(nano-tasks (mc/nano-calibration-tasks))
        (browser-tasks (mc/browser-calibration-tasks))
        (nano-via-tier (mc/tasks-for-tier "nano"))
        (browser-via-tier (mc/tasks-for-tier "browser"))
        (first-nano (option-or (list-head nano-tasks) (mc/make-canary-task "" "" "" 0 (list) (list))))
        (first-browser (option-or (list-head browser-tasks) (mc/make-canary-task "" "" "" 0 (list) (list))))]
    (do
      (assert (= (list-length nano-tasks) 3) "Nano suite must have 3 canary tasks")
      (assert (= (list-length browser-tasks) 4) "Browser suite must have 4 canary tasks")
      (assert (= (list-length nano-via-tier) 3) "Tier nano must return 3 tasks")
      (assert (= (list-length browser-via-tier) 4) "Tier browser must return 4 tasks")
      (assert (= (.-task-id first-nano) "NANO-TAG-01") "First nano task must be NANO-TAG-01")
      (assert (= (.-task-id first-browser) "BROWSER-DOM-01") "First browser task must be BROWSER-DOM-01")
      (assert (mc/enforce-browser-model-ceiling "SmolLM-135M") "100MB model allowed")
      (assert (mc/enforce-browser-model-ceiling "Qwen2.5-0.5B") "0.5B model allowed")
      (assert (mc/enforce-browser-model-ceiling "Qwen2.5-1.5B") "1.5B model allowed")
      (assert (mc/enforce-browser-model-ceiling "Qwen2.5-3B") "3B ceiling model allowed")
      (assert (not (mc/enforce-browser-model-ceiling "Qwen2.5-7B")) "7B rejected")
      (assert (not (mc/enforce-browser-model-ceiling "Gemma-2-9B")) "9B rejected")
      (assert (not (mc/enforce-browser-model-ceiling "Gemma-4-31B")) "31B rejected")
      true)))

(df run-tests [] -> Bool
  :d "Executes full model calibration test suite."
  (and (test-canary-tasks-construction)
       (and (test-pareto-score-computation)
            (and (test-candidate-evaluation)
                 (and (test-calibration-sweep-ranking)
                      (and (test-optimal-candidate-selection)
                           (and (test-format-calibration-result-asn)
                                (and (test-ctrf-summary-parsing)
                                     (and (test-scalar-loss-and-progress)
                                          (and (test-continuous-gradient-directional-signal)
                                               (and (test-tiered-calibration-tasks)
                                                    (test-browser-ceiling-and-nano-tasks))))))))))))
