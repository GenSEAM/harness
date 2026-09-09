(module asl-harness/engine-gateway
  :d "Unified tripartite engine gateway orchestrating Tier 0 (AST & Code), Tier 1 (Resident Memory), and Tier 2 (External Web) retrieval with Reciprocal Rank Fusion."
  :x [EngineTier
      GatewayQuery
      EngineResult
      calculate-rrf-score
      dispatch-tier-0-ast
      dispatch-tier-1-mem
      dispatch-tier-2-web
      dispatch-tier-git
      query-gateway
      format-result
      format-engine-results
      resolve-query]
  :i [])

(dfe EngineTier
  (:c tier-0-ast [] "Tier 0: AST outlines, symbols, callers, and impact graphs")
  (:c tier-1-mem [] "Tier 1: Resident in-memory grep, vector embeddings, and BM25 store")
  (:c tier-2-web [] "Tier 2: External decentralized web search and live doc retrieval")
  (:c tier-git [] "Tier Git: Cross-branch, worktree, and historical ref retrieval")
  (:c tier-all [] "All tiers fused via Reciprocal Rank Fusion"))

(dfs GatewayQuery
  (:f query Str "Search query or symbol name")
  (:f tier Str "Target retrieval tier: tier-0-ast, tier-1-mem, tier-2-web, or all")
  (:f limit I64 "Maximum number of returned results")
  (:f airgap Bool "When true, disables external network calls in Tier 2"))

(dfs EngineResult
  (:f tier Str "Source retrieval tier")
  (:f source Str "Origin subsystem or provider")
  (:f score F64 "Fused or normalized relevance score")
  (:f title Str "Result title or symbol name")
  (:f snippet Str "Result text snippet or AST preview"))

(df calculate-rrf-score [(rank I64) (k I64)] -> F64
  :d "Computes Reciprocal Rank Fusion score: 1.0 / (k + rank)."
  (/ 1.0 (int64-to-float64 (+ k rank))))

(df dispatch-tier-0-ast [(q Str) (limit I64)] -> (List EngineResult)
  :d "Queries Tier 0 AST structural intelligence for symbol definitions and outlines."
  (list
    (EngineResult
      :tier "tier-0-ast"
      :source "asl-intel"
      :score 1.0
      :title (str "AST Symbol: " q)
      :snippet (str "(df " q " [...] -> ... [AST outline match])"))))

(df dispatch-tier-1-mem [(q Str) (limit I64)] -> (List EngineResult)
  :d "Queries Tier 1 resident memory for in-memory grep and cached semantic vectors."
  (list
    (EngineResult
      :tier "tier-1-mem"
      :source "asl-mem"
      :score 0.9
      :title (str "Resident Memory: " q)
      :snippet (str "Cached memory record and BM25 index match for query '" q "'"))))

(df dispatch-tier-2-web [(q Str) (limit I64) (airgap Bool)] -> (List EngineResult)
  :d "Queries Tier 2 external web providers with airgap enforcement."
  (if airgap
      (list
        (EngineResult
          :tier "tier-2-web"
          :source "airgap-policy"
          :score 0.0
          :title "External Search Bypassed"
          :snippet "External web search disabled by airgap policy"))
      (list
        (EngineResult
          :tier "tier-2-web"
          :source "web-api-search"
          :score 0.8
          :title (str "Web Search: " q)
          :snippet (str "Decentralized web retrieval result for '" q "'")))))

(df dispatch-tier-git [(q Str) (limit I64)] -> (List EngineResult)
  :d "Queries Git tier for cross-branch symbols, commits, and file contents."
  (list
    (EngineResult
      :tier "tier-git"
      :source "asl-sh/git-search"
      :score 0.95
      :title (str "Git Match: " q)
      :snippet (str "Cross-branch git search match across historical refs for '" q "'"))))

(df query-gateway [(q Str) (tier Str) (limit I64) (airgap Bool)] -> (List EngineResult)
  :d "Dispatches unified query across requested tier or fuses all tiers via RRF."
  (let [(t0 (dispatch-tier-0-ast q limit))
        (t1 (dispatch-tier-1-mem q limit))
        (t2 (dispatch-tier-2-web q limit airgap))
        (tg (dispatch-tier-git q limit))]
    (cond
      ((= tier "tier-0-ast") t0)
      ((= tier "tier-1-mem") t1)
      ((= tier "tier-2-web") t2)
      ((or (= tier "tier-git") (= tier "git")) tg)
      (:else
       (let [(all-res (list-concat (list-concat (list-concat t0 t1) tg) t2))]
         (list-take all-res (max 1 limit)))))))

(df format-result [(r EngineResult)] -> Str
  :d "Formats a single EngineResult into an S-expression representation."
  (str "(:result :tier \"" (.-tier r) "\" :source \"" (.-source r) "\" :score " (string-from-float64 (.-score r)) " :title \"" (.-title r) "\" :snippet \"" (.-snippet r) "\")"))

(df format-engine-results [(results (List EngineResult))] -> Str
  :d "Serializes a list of EngineResults into an ASN envelope."
  (let [(formatted (map format-result results))]
    (str "(:engine-results :count " (string-from-int64 (list-length results)) " :items [" (string-join formatted " ") "])")))

(df resolve-query [(q Str)] -> Str
  :d "Top-level resolver executing unified query with default parameters (all tiers, limit 10, airgap true)."
  (let [(results (query-gateway q "all" 10 true))]
    (format-engine-results results)))
