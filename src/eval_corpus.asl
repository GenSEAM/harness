(module asl-harness/eval-corpus
  :d "Curate and export interaction pairs into offline evaluation datasets and SFT/DPO preference sets"
  :x [EvalInteractionPair
      EvalCorpus
      make-eval-corpus
      add-interaction-pair
      curate-interaction-corpus
      export-benchmark-dataset
      export-preference-pairs
      format-eval-pair-asn]
  :i [(llm_client :a lc) (trace_recorder :a tr)])

(dfs EvalInteractionPair
  (:f pair-id Str "Unique evaluation pair identifier")
  (:f prompt Str "Input prompt text")
  (:f response Str "Model completion text")
  (:f model Str "Generating model identifier")
  (:f verdict Str "Gate or evaluation verdict: pass | fail | unverified")
  (:f rating F64 "Quality score rating (0.0 to 1.0)"))

(dfs EvalCorpus
  (:f corpus-name Str "Identifier of evaluation benchmark suite")
  (:f pairs (List EvalInteractionPair) "Chronologically recorded interaction pairs")
  (:f total-pairs I64 "Count of recorded pairs in corpus"))

(df make-eval-corpus [(name Str)] -> EvalCorpus
  :d "Instantiates empty evaluation corpus"
  (EvalCorpus
    :corpus-name name
    :pairs (list)
    :total-pairs 0))

(df add-interaction-pair [(corpus EvalCorpus) (pair EvalInteractionPair)] -> EvalCorpus
  :d "Appends pair to corpus and increments total-pairs"
  (EvalCorpus
    :corpus-name (.-corpus-name corpus)
    :pairs (list-append (.-pairs corpus) (list pair))
    :total-pairs (+ (.-total-pairs corpus) 1)))

(df curate-interaction-corpus [(corpus EvalCorpus) (min-rating F64)] -> EvalCorpus
  :d "Filters corpus pairs, retaining only pairs meeting or exceeding min-rating"
  (let [(filtered (fold (fn [(acc (List EvalInteractionPair)) (p EvalInteractionPair)] -> (List EvalInteractionPair)
                          (if (>= (.-rating p) min-rating)
                              (list-append acc (list p))
                              acc))
                        (list)
                        (.-pairs corpus)))]
    (EvalCorpus
      :corpus-name (.-corpus-name corpus)
      :pairs filtered
      :total-pairs (list-length filtered))))

(df format-eval-pair-asn [(pair EvalInteractionPair)] -> Str
  :d "Formats single evaluation pair into canonical ASN S-expression string"
  (str "(:eval-pair :id \""
       (.-pair-id pair)
       "\" :model \""
       (.-model pair)
       "\" :verdict \""
       (.-verdict pair)
       "\" :rating "
       (string-from-float64 (.-rating pair))
       " :prompt \""
       (.-prompt pair)
       "\" :response \""
       (.-response pair)
       "\")"))

(df export-benchmark-dataset [(corpus EvalCorpus)] -> (List Str)
  :d "Formats all curated pairs into standardized offline benchmark prompt/response fixtures"
  (fold (fn [(acc (List Str)) (p EvalInteractionPair)] -> (List Str)
          (list-append acc (list (str "(:benchmark-fixture :id \""
                                      (.-pair-id p)
                                      "\" :prompt \""
                                      (.-prompt p)
                                      "\" :response \""
                                      (.-response p)
                                      "\" :model \""
                                      (.-model p)
                                      "\")"))))
        (list)
        (.-pairs corpus)))

(df find-matching-fail [(prompt Str) (failing (List EvalInteractionPair))] -> (Option EvalInteractionPair)
  :d "Finds first failing interaction pair matching prompt"
  (fold (fn [(found (Option EvalInteractionPair)) (f EvalInteractionPair)] -> (Option EvalInteractionPair)
          (mt found
            ((some _) found)
            ((none) (if (= (.-prompt f) prompt) (some f) (none)))))
        (none)
        failing))

(df export-preference-pairs [(corpus EvalCorpus)] -> (List Str)
  :d "Segregates passing and failing pairs into contrastive SFT/DPO training sets"
  (let [(passing (fold (fn [(acc (List EvalInteractionPair)) (p EvalInteractionPair)] -> (List EvalInteractionPair)
                         (if (= (.-verdict p) "pass")
                             (list-append acc (list p))
                             acc))
                       (list)
                       (.-pairs corpus)))
        (failing (fold (fn [(acc (List EvalInteractionPair)) (p EvalInteractionPair)] -> (List EvalInteractionPair)
                         (if (= (.-verdict p) "fail")
                             (list-append acc (list p))
                             acc))
                       (list)
                       (.-pairs corpus)))]
    (fold (fn [(acc (List Str)) (pass-p EvalInteractionPair)] -> (List Str)
            (let [(match-opt (find-matching-fail (.-prompt pass-p) failing))
                  (target-fail (mt match-opt
                                 ((some f) (some f))
                                 ((none) (list-head failing))))]
              (mt target-fail
                ((some fail-p)
                 (list-append acc (list (str "(:preference-pair :prompt \""
                                             (.-prompt pass-p)
                                             "\" :chosen \""
                                             (.-response pass-p)
                                             "\" :rejected \""
                                             (.-response fail-p)
                                             "\")"))))
                ((none) acc))))
          (list)
          passing)))
