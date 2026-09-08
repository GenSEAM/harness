(module asl-harness/trace-recorder
  :d "Interaction trace recorder, rolling model speed profiler, and slow-provider anomaly detector"
  :x [ModelProfile
      InteractionTrace
      make-model-profile
      record-interaction-trace
      update-model-profile
      format-trace-asn
      is-slow-provider?]
  :i [(llm_client :a lc)])

(dfs ModelProfile
  (:f model Str "Target model identifier")
  (:f avg-tok-sec F64 "Running average throughput in tokens per second")
  (:f avg-duration-ms I64 "Running average latency in milliseconds")
  (:f total-calls I64 "Cumulative invocations recorded")
  (:f slow-provider Bool "Anomaly flag indicating slow provider latency or throughput"))

(dfs InteractionTrace
  (:f trace-id Str "Unique trace identifier")
  (:f timestamp-ms I64 "Monotonic execution timestamp in milliseconds")
  (:f model-options lc/ModelOptions "Configured model options used for dispatch")
  (:f result lc/CompletionResult "Execution completion and performance metrics")
  (:f status Str "Execution status verdict e.g. success, timeout, or error"))

(df make-model-profile [(model Str)] -> ModelProfile
  :d "Instantiates initialized model profile with zero calls and normal status"
  (ModelProfile
    :model model
    :avg-tok-sec 0.0
    :avg-duration-ms 0
    :total-calls 0
    :slow-provider false))

(df is-slow-provider? [(avg-tok-sec F64) (avg-duration-ms I64)] -> Bool
  :d "Determines if provider throughput or latency indicates anomalous performance"
  (or (< avg-tok-sec 10.0) (> avg-duration-ms 3000)))

(df update-model-profile [(profile ModelProfile) (res lc/CompletionResult)] -> ModelProfile
  :d "Updates running cumulative averages using weighted recurrence"
  (let [(new-calls (+ (.-total-calls profile) 1))
        (new-avg-tok-sec (/ (+ (* (.-avg-tok-sec profile) (int64-to-float64 (.-total-calls profile))) (.-tok-sec res)) (int64-to-float64 new-calls)))
        (new-avg-duration (/ (+ (* (.-avg-duration-ms profile) (.-total-calls profile)) (.-duration-ms res)) new-calls))
        (slow (is-slow-provider? new-avg-tok-sec new-avg-duration))]
    (ModelProfile
      :model (.-model profile)
      :avg-tok-sec new-avg-tok-sec
      :avg-duration-ms new-avg-duration
      :total-calls new-calls
      :slow-provider slow)))

(df record-interaction-trace [(trace-id Str) (ts-ms I64) (opts lc/ModelOptions) (res lc/CompletionResult) (status Str)] -> InteractionTrace
  :d "Constructs typed interaction trace record"
  (InteractionTrace
    :trace-id trace-id
    :timestamp-ms ts-ms
    :model-options opts
    :result res
    :status status))

(df format-trace-asn [(trace InteractionTrace)] -> Str
  :d "Formats interaction trace into compact canonical ASN S-expression string"
  (str "(:interaction-trace :trace-id \""
       (.-trace-id trace)
       "\" :model \""
       (.-model (.-model-options trace))
       "\" :tokens-in "
       (string-from-int64 (.-input-tokens (.-result trace)))
       " :tokens-out "
       (string-from-int64 (.-output-tokens (.-result trace)))
       " :tok-sec "
       (string-from-float64 (.-tok-sec (.-result trace)))
       " :status \""
       (.-status trace)
       "\" :text \""
       (.-text (.-result trace))
       "\")"))
