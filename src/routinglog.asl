(module asl-harness/routinglog
  :d "Operational routing audit logging, misroute tracking, and performance telemetry"
  :x [RoutingEntry
      RoutingLogSummary
      make-routing-entry
      append-routing-entry
      filter-misrouted
      summarize-routing-log
      format-routing-asn]
  :i [])

(dfs RoutingEntry
  (:f entry-id Str "Unique audit log entry identifier")
  (:f timestamp-ms Int64 "Monotonic millisecond timestamp")
  (:f task-id Str "Task or conversation request identifier")
  (:f prompt-snippet Str "Truncated or summarized input prompt")
  (:f entropy-score Float "Continuous task entropy or routing score")
  (:f selected-tier Str "Selected execution tier")
  (:f executed-locally Bool "True if tool was executed locally without remote LLM hop")
  (:f tokens-saved Int64 "Estimated tokens saved by local routing")
  (:f latency-ms Int64 "Actual execution latency in milliseconds")
  (:f gate-verdict Str "Final gate verdict")
  (:f misrouted Bool "True if route failed and required fallback to deeper tier"))

(dfs RoutingLogSummary
  (:f total-entries Int64 "Total routing audit entries recorded")
  (:f local-count Int64 "Number of locally executed tool routes")
  (:f remote-count Int64 "Number of remote LLM routes")
  (:f local-ratio Float "Percentage of toolcalls routed locally")
  (:f misroute-count Int64 "Number of misrouted events requiring fallback")
  (:f misroute-rate Float "Misroute percentage")
  (:f total-tokens-saved Int64 "Cumulative tokens saved across all local routes"))

(df make-routing-entry [(id Str) (ts Int64) (task-id Str) (snippet Str) (entropy Float) (tier Str) (local Bool) (tokens Int64) (latency Int64) (verdict Str) (misrouted Bool)] -> RoutingEntry
  :d "Constructor for routing audit entries."
  (RoutingEntry
    :entry-id id
    :timestamp-ms ts
    :task-id task-id
    :prompt-snippet snippet
    :entropy-score entropy
    :selected-tier tier
    :executed-locally local
    :tokens-saved tokens
    :latency-ms latency
    :gate-verdict verdict
    :misrouted misrouted))

(df append-routing-entry [(entries (List RoutingEntry)) (new-entry RoutingEntry)] -> (List RoutingEntry)
  :d "Appends entry to audit trail in chronological order."
  (list-append entries (list new-entry)))

(df filter-misrouted [(entries (List RoutingEntry))] -> (List RoutingEntry)
  :d "Extracts all misrouted instances for active learning feedback and model calibration."
  (if (list-empty? entries)
      (list)
      (let [(head (option-or (list-head entries) (RoutingEntry :entry-id "" :timestamp-ms 0 :task-id "" :prompt-snippet "" :entropy-score 0.0 :selected-tier "" :executed-locally false :tokens-saved 0 :latency-ms 0 :gate-verdict "" :misrouted false)))
            (tail (option-or (list-tail entries) (list)))]
        (if (.-misrouted head)
            (list-cons head (filter-misrouted tail))
            (filter-misrouted tail)))))

(df count-local-routes [(entries (List RoutingEntry))] -> Int64
  :d "Counts entries where tool was executed locally without remote LLM hop."
  (if (list-empty? entries)
      0
      (let [(head (option-or (list-head entries) (RoutingEntry :entry-id "" :timestamp-ms 0 :task-id "" :prompt-snippet "" :entropy-score 0.0 :selected-tier "" :executed-locally false :tokens-saved 0 :latency-ms 0 :gate-verdict "" :misrouted false)))
            (tail (option-or (list-tail entries) (list)))
            (inc (if (.-executed-locally head) 1 0))]
        (+ inc (count-local-routes tail)))))

(df count-misrouted-entries [(entries (List RoutingEntry))] -> Int64
  :d "Counts entries marked as misrouted requiring fallback to deeper tier."
  (if (list-empty? entries)
      0
      (let [(head (option-or (list-head entries) (RoutingEntry :entry-id "" :timestamp-ms 0 :task-id "" :prompt-snippet "" :entropy-score 0.0 :selected-tier "" :executed-locally false :tokens-saved 0 :latency-ms 0 :gate-verdict "" :misrouted false)))
            (tail (option-or (list-tail entries) (list)))
            (inc (if (.-misrouted head) 1 0))]
        (+ inc (count-misrouted-entries tail)))))

(df sum-tokens-saved [(entries (List RoutingEntry))] -> Int64
  :d "Accumulates cumulative tokens saved across all local routes."
  (if (list-empty? entries)
      0
      (let [(head (option-or (list-head entries) (RoutingEntry :entry-id "" :timestamp-ms 0 :task-id "" :prompt-snippet "" :entropy-score 0.0 :selected-tier "" :executed-locally false :tokens-saved 0 :latency-ms 0 :gate-verdict "" :misrouted false)))
            (tail (option-or (list-tail entries) (list)))]
        (+ (.-tokens-saved head) (sum-tokens-saved tail)))))

(df summarize-routing-log [(entries (List RoutingEntry))] -> RoutingLogSummary
  :d "Computes aggregate counts, local ratio, misroute rate, and cumulative token savings."
  (let [(total (list-length entries))]
    (if (<= total 0)
        (RoutingLogSummary
          :total-entries 0
          :local-count 0
          :remote-count 0
          :local-ratio 0.0
          :misroute-count 0
          :misroute-rate 0.0
          :total-tokens-saved 0)
        (let [(local-c (count-local-routes entries))
              (remote-c (- total local-c))
              (misroute-c (count-misrouted-entries entries))
              (tokens-sum (sum-tokens-saved entries))
              (total-f (int64-to-float64 total))
              (l-ratio (* (/ (int64-to-float64 local-c) total-f) 100.0))
              (m-rate (* (/ (int64-to-float64 misroute-c) total-f) 100.0))]
          (RoutingLogSummary
            :total-entries total
            :local-count local-c
            :remote-count remote-c
            :local-ratio l-ratio
            :misroute-count misroute-c
            :misroute-rate m-rate
            :total-tokens-saved tokens-sum)))))

(df format-routing-asn [(entry RoutingEntry)] -> Str
  :d "Serializes routing entry into pure ASN S-expression notation."
  (str "(:routing-entry :id \"" (.-entry-id entry)
       "\" :task-id \"" (.-task-id entry)
       "\" :tier \"" (.-selected-tier entry)
       "\" :entropy " (string-from-float64 (.-entropy-score entry))
       " :local " (if (.-executed-locally entry) "true" "false")
       " :tokens-saved " (string-from-int64 (.-tokens-saved entry))
       " :latency-ms " (string-from-int64 (.-latency-ms entry))
       " :verdict \"" (.-gate-verdict entry)
       "\" :misrouted " (if (.-misrouted entry) "true" "false") ")"))
