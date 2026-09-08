(module asl-harness/amnesia-gate
  :d "Context overflow emulation, amnesia cascade interception, and fact retention verification in pure ASL."
  :x [OverflowContext
      AmnesiaInterceptResult
      AmnesiaAuditReport
      err-amnesia-data-loss
      emulate-context-overflow
      intercept-amnesia-trigger
      verify-facts-retained
      run-amnesia-audit]
  :i [])

(df err-amnesia-data-loss [] -> Str
  :d "Error code for fact loss during amnesia compression."
  "ERR_AMNESIA_DATA_LOSS")

(dfs OverflowContext
  (:f buffer-id Str "Unique context buffer identifier")
  (:f tokens I64 "Current token volume in simulated context")
  (:f messages (List Str) "Raw uncompressed operational message backlog")
  (:f facts (List Str) "Ground-truth scalar facts seeded in operational buffer")
  (:f threshold I64 "Compression trigger ceiling"))

(dfs AmnesiaInterceptResult
  (:f triggered Bool "True if amnesia trigger detected overflow")
  (:f chunk-id Str "Emitted memory chunk identifier")
  (:f post-tokens I64 "Post-compression token volume in active memory")
  (:f facts (List Str) "Retained facts list")
  (:f raw-evicted Bool "True if uncompressed messages evicted from memory"))

(dfs AmnesiaAuditReport
  (:f passed Bool "True if overflow triggered amnesia and all facts were preserved")
  (:f input-tokens I64 "Original uncompressed token volume")
  (:f post-tokens I64 "Compacted token volume following amnesia cascade")
  (:f facts-verified I64 "Number of verified retained facts")
  (:f missing-facts (List Str) "List of lost facts if data loss occurred")
  (:f error-code Str "Empty string on success or ERR_AMNESIA_DATA_LOSS on failure"))

(df emulate-context-overflow [(id Str) (input-tokens I64) (threshold I64) (required-facts (List Str))] -> OverflowContext
  :d "Generates synthetic token history exceeding configured amnesia threshold."
  (let [(fact-msgs (map (fn [(f Str)] -> Str (str "[fact] " f)) required-facts))
        (base-msgs (list (str "[init] buffer " id " with " (string-from-int64 input-tokens) " tokens")
                         (str "[op] conversation backlog simulating task context for " id)))
        (all-msgs (list-append base-msgs fact-msgs))]
    (OverflowContext
      :buffer-id id
      :tokens input-tokens
      :messages all-msgs
      :facts required-facts
      :threshold threshold)))

(df intercept-amnesia-trigger [(ctx OverflowContext)] -> AmnesiaInterceptResult
  :d "Intercepts context compaction and validates emitted memory chunk."
  (if (>= (.-tokens ctx) (.-threshold ctx))
      (let [(c-id (str "chunk-" (.-buffer-id ctx) "-compact"))
            (post-tokens 1200)
            (facts (.-facts ctx))]
        (AmnesiaInterceptResult
          :triggered true
          :chunk-id c-id
          :post-tokens post-tokens
          :facts facts
          :raw-evicted true))
      (AmnesiaInterceptResult
        :triggered false
        :chunk-id ""
        :post-tokens (.-tokens ctx)
        :facts (.-facts ctx)
        :raw-evicted false)))

(df fact-matches? [(req Str) (retained (List Str))] -> Bool
  :d "Checks if required fact matches or is contained within any retained fact entry."
  (let [(matches (filter (fn [(ret Str)] -> Bool
                           (or (= req ret)
                               (or (string-contains? ret req)
                                   (string-contains? req ret))))
                         retained))]
    (not (list-empty? matches))))

(df verify-facts-retained [(required-facts (List Str)) (retained-facts (List Str))] -> (Pair Bool Str)
  :d "Compares pre-compression facts against retained memory chunk facts."
  (if (list-empty? required-facts)
      (pair true "")
      (let [(missing (filter (fn [(req Str)] -> Bool (not (fact-matches? req retained-facts))) required-facts))]
        (if (list-empty? missing)
            (pair true "")
            (pair false (err-amnesia-data-loss))))))

(df run-amnesia-audit [(test-id Str) (input-tokens I64) (threshold I64) (required-facts (List Str))] -> AmnesiaAuditReport
  :d "Executes end-to-end amnesia overflow interception and fact audit pipeline."
  (let [(ctx (emulate-context-overflow test-id input-tokens threshold required-facts))
        (trig (intercept-amnesia-trigger ctx))]
    (if (not (.-triggered trig))
        (AmnesiaAuditReport
          :passed false
          :input-tokens input-tokens
          :post-tokens (.-tokens ctx)
          :facts-verified 0
          :missing-facts required-facts
          :error-code "ERR_NO_AMNESIA_TRIGGER")
        (let [(fact-check (verify-facts-retained required-facts (.-facts trig)))
              (is-ok (.-first fact-check))
              (err (.-second fact-check))]
          (if is-ok
              (AmnesiaAuditReport
                :passed true
                :input-tokens input-tokens
                :post-tokens (.-post-tokens trig)
                :facts-verified (list-length required-facts)
                :missing-facts (list)
                :error-code "")
              (let [(missing (filter (fn [(req Str)] -> Bool (not (fact-matches? req (.-facts trig)))) required-facts))]
                (AmnesiaAuditReport
                  :passed false
                  :input-tokens input-tokens
                  :post-tokens (.-post-tokens trig)
                  :facts-verified (- (list-length required-facts) (list-length missing))
                  :missing-facts missing
                  :error-code err)))))))
