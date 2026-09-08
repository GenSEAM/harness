(module asl-harness/protocol-comparator
  :d "Condition A Markdown/JSON vs Condition B Pure ASN comparative benchmarking and efficiency metrics engine."
  :x [ProtocolProfile
      ComparisonMetrics
      ProtocolBenchmarkReport
      measure-protocol-tokens
      compare-protocol-efficiency
      format-protocol-comparison]
  :i [(asn_protocol_agent :a apa)])

(dfs ProtocolProfile
  (:f name Str "Protocol profile identifier e.g. condition-a-markdown or condition-b-asn")
  (:f prompt-tokens I64 "Prompt token volume")
  (:f completion-tokens I64 "Completion token volume")
  (:f parse-errors I64 "Syntax parse error count"))

(dfs ComparisonMetrics
  (:f condition-a-tokens I64 "Condition A total token consumption")
  (:f condition-b-tokens I64 "Condition B total token consumption")
  (:f token-savings-pct F64 "Token reduction percentage delivered by Condition B")
  (:f error-reduction-pct F64 "Syntax error reduction percentage delivered by Condition B"))

(dfs ProtocolBenchmarkReport
  (:f benchmark-id Str "Benchmark comparison identifier")
  (:f task-count I64 "Evaluated task volume")
  (:f metrics ComparisonMetrics "Computed comparison metrics")
  (:f recommendation Str "Target runtime routing recommendation"))

(df measure-protocol-tokens [(payload Str)] -> I64
  :d "Measures estimated token count of serialized protocol payload."
  (let [(len (string-length payload))]
    (if (<= len 0)
      0
      (let [(q (/ len 4))]
        (if (<= q 0) 1 q)))))

(df compare-protocol-efficiency [(cond-a ProtocolProfile) (cond-b ProtocolProfile)] -> ComparisonMetrics
  :d "Calculates comparative token savings and syntax parse error reduction percentages."
  (let [(tok-a (+ (.-prompt-tokens cond-a) (.-completion-tokens cond-a)))
        (tok-b (+ (.-prompt-tokens cond-b) (.-completion-tokens cond-b)))
        (err-a (.-parse-errors cond-a))
        (err-b (.-parse-errors cond-b))
        (savings (if (<= tok-a 0)
                   0.0
                   (/ (* (float64-from-int64 (- tok-a tok-b)) 100.0) (float64-from-int64 tok-a))))
        (err-red (if (<= err-a 0)
                   0.0
                   (/ (* (float64-from-int64 (- err-a err-b)) 100.0) (float64-from-int64 err-a))))]
    (ComparisonMetrics
      :condition-a-tokens tok-a
      :condition-b-tokens tok-b
      :token-savings-pct savings
      :error-reduction-pct err-red)))

(df format-protocol-comparison [(report ProtocolBenchmarkReport)] -> Str
  :d "Formats comparative benchmark metrics into human-readable ledger."
  (let [(m (.-metrics report))]
    (str "(:protocol-comparison :benchmark-id \"" (.-benchmark-id report)
         "\" :task-count " (string-from-int64 (.-task-count report))
         " :condition-a-tokens " (string-from-int64 (.-condition-a-tokens m))
         " :condition-b-tokens " (string-from-int64 (.-condition-b-tokens m))
         " :token-savings-pct " (string-from-float64 (.-token-savings-pct m))
         " :error-reduction-pct " (string-from-float64 (.-error-reduction-pct m))
         " :recommendation \"" (.-recommendation report) "\")")))
