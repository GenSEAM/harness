(module asl-harness/engine-gateway-test
  :d "Unit test suite verifying unified engine gateway tripartite dispatch, RRF scoring, and airgap fallback."
  :x [test-rrf-scoring
      test-tier-dispatch
      test-tier-git-dispatch
      test-airgap-fallback
      test-all-tiers-fusion
      test-resolve-query
      run-tests]
  :i [(engine-gateway :a eg)])

(df test-rrf-scoring [] -> Bool
  :d "Verifies Reciprocal Rank Fusion mathematical calculation."
  (let [(s1 (eg/calculate-rrf-score 1 60))
        (s2 (eg/calculate-rrf-score 2 60))]
    (assert (> s1 0.015) "rrf score 1 is positive and bounded")
    (assert (> s1 s2) "higher rank produces strictly greater RRF score")
    true))

(df test-tier-dispatch [] -> Bool
  :d "Verifies independent Tier 0 and Tier 1 dispatch."
  (let [(res-t0 (eg/query-gateway "make-engine" "tier-0-ast" 5 true))
        (res-t1 (eg/query-gateway "cache-key" "tier-1-mem" 5 true))]
    (assert (= (list-length res-t0) 1) "tier-0 returns expected single result")
    (assert (= (list-length res-t1) 1) "tier-1 returns expected single result")
    (assert (= (.-tier (option-or (list-head res-t0) (eg/EngineResult :tier "" :source "" :score 0.0 :title "" :snippet ""))) "tier-0-ast") "tier matches tier-0-ast")
    (assert (= (.-tier (option-or (list-head res-t1) (eg/EngineResult :tier "" :source "" :score 0.0 :title "" :snippet ""))) "tier-1-mem") "tier matches tier-1-mem")
    true))

(df test-airgap-fallback [] -> Bool
  :d "Verifies airgap policy intercepts Tier 2 external search without network dependency."
  (let [(res-airgap (eg/query-gateway "external-docs" "tier-2-web" 5 true))]
    (assert (= (list-length res-airgap) 1) "airgap returns fallback entry")
    (assert (= (.-source (option-or (list-head res-airgap) (eg/EngineResult :tier "" :source "" :score 0.0 :title "" :snippet ""))) "airgap-policy") "source reflects airgap-policy")
    (assert (string-contains? (.-snippet (option-or (list-head res-airgap) (eg/EngineResult :tier "" :source "" :score 0.0 :title "" :snippet ""))) "airgap policy") "snippet confirms airgap enforcement")
    true))

(df test-all-tiers-fusion [] -> Bool
  :d "Verifies all tiers are concatenated and bounded by limit."
  (let [(all-res (eg/query-gateway "query-all" "all" 2 true))]
    (assert (<= (list-length all-res) 2) "result count respects limit")
    (assert (not (list-empty? all-res)) "result count is not empty")
    true))

(df test-resolve-query [] -> Bool
  :d "Verifies top-level resolve-query produces serialized ASN envelope."
  (let [(serialized (eg/resolve-query "engine-test"))]
    (assert (string-starts-with? serialized "(:engine-results") "serialized output starts with :engine-results")
    (assert (string-contains? serialized ":count") "serialized output contains count")
    true))

(df test-tier-git-dispatch [] -> Bool
  :d "Verifies independent Tier Git dispatch for cross-branch retrieval."
  (let [(res-git (eg/query-gateway "feature-branch" "tier-git" 5 true))]
    (assert (= (list-length res-git) 1) "tier-git returns expected single result")
    (let [(r (option-or (list-head res-git) (eg/EngineResult :tier "" :source "" :score 0.0 :title "" :snippet "")))]
      (assert (= (.-tier r) "tier-git") "tier matches tier-git")
      (assert (= (.-source r) "asl-sh/git-search") "source matches asl-sh/git-search")
      (assert (> (.-score r) 0.9) "git tier score is bounded above 0.9")
      true)))

(df run-tests [] -> Bool
  :d "Executes all engine gateway test suites."
  (do
    (test-rrf-scoring)
    (test-tier-dispatch)
    (test-tier-git-dispatch)
    (test-airgap-fallback)
    (test-all-tiers-fusion)
    (test-resolve-query)
    true))
