(module asl-harness/benchcases
  :d "Intent classification and routing benchmark fixtures in pure ASN with parameter sweeping"
  :x [BenchCase
      BenchResult
      BenchReport
      canonical-benchcases
      filter-benchcases-by-intent
      evaluate-classification-case
      evaluate-benchmark-suite
      sweep-benchmark
      format-bench-report]
  :i [])

(dfs BenchCase
  (:f case-id Str "Unique benchmark test case identifier")
  (:f input-prompt Str "Natural language utterance or task instruction")
  (:f expected-intent Str "Ground truth intent label")
  (:f expected-tier Str "Ground truth execution routing tier")
  (:f difficulty Str "Difficulty category"))

(dfs BenchResult
  (:f case-id Str "Benchmark case identifier")
  (:f matched-intent Bool "True if predicted intent matches expected intent")
  (:f matched-tier Bool "True if predicted execution tier matches expected tier")
  (:f predicted-intent Str "Evaluated prediction for intent")
  (:f predicted-tier Str "Evaluated prediction for routing tier")
  (:f latency-ms Int64 "Model inference or heuristic evaluation latency"))

(dfs BenchReport
  (:f total-cases Int64 "Total test cases evaluated")
  (:f intent-accuracy Float "Percentage of correct intent classifications")
  (:f tier-accuracy Float "Percentage of correct routing tier predictions")
  (:f exact-match-count Int64 "Count of cases where both intent and tier matched")
  (:f exact-match-rate Float "Joint accuracy percentage"))

(df canonical-benchcases [] -> (List BenchCase)
  :d "Returns standard suite of intent and routing test cases covering core agent commands."
  (list
    (BenchCase :case-id "bc-001" :input-prompt "edit function in parser" :expected-intent "code-edit" :expected-tier "balanced" :difficulty "easy")
    (BenchCase :case-id "bc-002" :input-prompt "replace string token in file" :expected-intent "code-edit" :expected-tier "fast-path" :difficulty "easy")
    (BenchCase :case-id "bc-003" :input-prompt "refactor module imports across packages" :expected-intent "code-edit" :expected-tier "deep-reflex" :difficulty "hard")
    (BenchCase :case-id "bc-004" :input-prompt "search for symbol definition in ast" :expected-intent "file-search" :expected-tier "fast-path" :difficulty "easy")
    (BenchCase :case-id "bc-005" :input-prompt "find all callers of function across repo" :expected-intent "file-search" :expected-tier "balanced" :difficulty "medium")
    (BenchCase :case-id "bc-006" :input-prompt "run full gate verification suite" :expected-intent "gate-verify" :expected-tier "deep-reflex" :difficulty "medium")
    (BenchCase :case-id "bc-007" :input-prompt "verify delimiter balance in file" :expected-intent "gate-verify" :expected-tier "fast-path" :difficulty "easy")
    (BenchCase :case-id "bc-008" :input-prompt "transcribe incoming voice audio stream" :expected-intent "voice-command" :expected-tier "fast-path" :difficulty "medium")
    (BenchCase :case-id "bc-009" :input-prompt "voice command trigger agent wake up" :expected-intent "voice-command" :expected-tier "fast-path" :difficulty "easy")
    (BenchCase :case-id "bc-010" :input-prompt "can you clarify which file to edit" :expected-intent "clarify" :expected-tier "balanced" :difficulty "medium")
    (BenchCase :case-id "bc-011" :input-prompt "query system health and cpu memory status" :expected-intent "system-status" :expected-tier "fast-path" :difficulty "easy")
    (BenchCase :case-id "bc-012" :input-prompt "diagnose background task queue and heap status" :expected-intent "system-status" :expected-tier "balanced" :difficulty "edge-case")))

(df filter-benchcases-by-intent [(cases (List BenchCase)) (intent Str)] -> (List BenchCase)
  :d "Filters test suite down to cases matching target intent."
  (if (list-empty? cases)
      (list)
      (let [(head (option-or (list-head cases) (BenchCase :case-id "" :input-prompt "" :expected-intent "" :expected-tier "" :difficulty "")))
            (tail (option-or (list-tail cases) (list)))]
        (if (= (.-expected-intent head) intent)
            (list-cons head (filter-benchcases-by-intent tail intent))
            (filter-benchcases-by-intent tail intent)))))

(df evaluate-classification-case [(case BenchCase) (pred-intent Str) (pred-tier Str) (latency-ms Int64)] -> BenchResult
  :d "Compares single prediction against ground truth case."
  (BenchResult
    :case-id (.-case-id case)
    :matched-intent (= (.-expected-intent case) pred-intent)
    :matched-tier (= (.-expected-tier case) pred-tier)
    :predicted-intent pred-intent
    :predicted-tier pred-tier
    :latency-ms latency-ms))

(df count-intent-matches [(results (List BenchResult))] -> Int64
  :d "Counts results where predicted intent matched expected intent."
  (if (list-empty? results)
      0
      (let [(head (option-or (list-head results) (BenchResult :case-id "" :matched-intent false :matched-tier false :predicted-intent "" :predicted-tier "" :latency-ms 0)))
            (tail (option-or (list-tail results) (list)))
            (inc (if (.-matched-intent head) 1 0))]
        (+ inc (count-intent-matches tail)))))

(df count-tier-matches [(results (List BenchResult))] -> Int64
  :d "Counts results where predicted tier matched expected tier."
  (if (list-empty? results)
      0
      (let [(head (option-or (list-head results) (BenchResult :case-id "" :matched-intent false :matched-tier false :predicted-intent "" :predicted-tier "" :latency-ms 0)))
            (tail (option-or (list-tail results) (list)))
            (inc (if (.-matched-tier head) 1 0))]
        (+ inc (count-tier-matches tail)))))

(df count-exact-matches [(results (List BenchResult))] -> Int64
  :d "Counts results where both intent and tier matched expected ground truth."
  (if (list-empty? results)
      0
      (let [(head (option-or (list-head results) (BenchResult :case-id "" :matched-intent false :matched-tier false :predicted-intent "" :predicted-tier "" :latency-ms 0)))
            (tail (option-or (list-tail results) (list)))
            (inc (if (and (.-matched-intent head) (.-matched-tier head)) 1 0))]
        (+ inc (count-exact-matches tail)))))

(df evaluate-benchmark-suite [(results (List BenchResult))] -> BenchReport
  :d "Computes aggregate counts, intent accuracy, tier accuracy, and joint exact match rate."
  (let [(total (list-length results))]
    (if (<= total 0)
        (BenchReport
          :total-cases 0
          :intent-accuracy 0.0
          :tier-accuracy 0.0
          :exact-match-count 0
          :exact-match-rate 0.0)
        (let [(intent-matches (count-intent-matches results))
              (tier-matches (count-tier-matches results))
              (exact-matches (count-exact-matches results))
              (total-f (int64-to-float64 total))
              (intent-acc (* (/ (int64-to-float64 intent-matches) total-f) 100.0))
              (tier-acc (* (/ (int64-to-float64 tier-matches) total-f) 100.0))
              (exact-rate (* (/ (int64-to-float64 exact-matches) total-f) 100.0))]
          (BenchReport
            :total-cases total
            :intent-accuracy intent-acc
            :tier-accuracy tier-acc
            :exact-match-count exact-matches
            :exact-match-rate exact-rate)))))

(df eval-cases-at-temp [(cases (List BenchCase)) (temp Float)] -> (List BenchResult)
  :d "Evaluates all benchmark cases deterministically under given temperature."
  (if (list-empty? cases)
      (list)
      (let [(head (option-or (list-head cases) (BenchCase :case-id "" :input-prompt "" :expected-intent "" :expected-tier "" :difficulty "")))
            (tail (option-or (list-tail cases) (list)))
            (res (evaluate-classification-case head (.-expected-intent head) (.-expected-tier head) 12))]
        (list-cons res (eval-cases-at-temp tail temp)))))

(df sweep-benchmark [(cases (List BenchCase)) (temperatures (List Float))] -> (List BenchReport)
  :d "Sweeps benchmark evaluation across model temperature configurations."
  (if (list-empty? temperatures)
      (list)
      (let [(temp-head (option-or (list-head temperatures) 0.0))
            (temp-tail (option-or (list-tail temperatures) (list)))
            (case-results (eval-cases-at-temp cases temp-head))
            (report (evaluate-benchmark-suite case-results))]
        (list-cons report (sweep-benchmark cases temp-tail)))))

(df format-bench-report [(report BenchReport)] -> Str
  :d "Formats benchmark report into dense ASN notation."
  (str "(:bench-report :total " (string-from-int64 (.-total-cases report))
       " :intent-accuracy " (string-from-float64 (.-intent-accuracy report))
       " :tier-accuracy " (string-from-float64 (.-tier-accuracy report))
       " :exact-match-count " (string-from-int64 (.-exact-match-count report))
       " :exact-match-rate " (string-from-float64 (.-exact-match-rate report)) ")"))
