(module asl-harness/context-assembler
  :d "Modular dynamic context compilation engine with multi-strategy assembly and agent self-directed context management."
  :x [ContextBlock
      AgentCtxOp
      ContextAssemblyConfig
      AssembledPrompt
      make-context-block
      make-agent-ctx-op
      make-default-config
      estimate-tokens
      format-context-blocks
      assemble-baseline-context
      assemble-receipts-context
      assemble-jit-context
      assemble-agent-directed-context
      apply-universal-default-canvas
      is-core-block?
      is-knowledge-block?
      is-delta-block?
      is-other-canvas-block?
      parse-agent-ctx-op
      assemble-prompt]
  :i [(compactor :a comp)
      (context_priority :a cp)])

(dfs ContextBlock
  (:f id Str "Unique identifier for context block")
  (:f kind Str "Block category e.g. sys-mandate, task-spec, history, receipt, working-set, delta, knowledge")
  (:f tokens I64 "Token weight estimate")
  (:f payload Str "Serialized payload of block"))

(dfs AgentCtxOp
  (:f retain (List Str) "List of block or symbol IDs to explicitly keep")
  (:f evict (List Str) "List of block or turn IDs to explicitly drop")
  (:f prefetch (List Str) "List of file paths or symbol names to dynamically fetch"))

(dfs ContextAssemblyConfig
  (:f strategy Str "Strategy name: baseline, receipts, jit-memory, agent-directed")
  (:f token-ceiling I64 "Maximum allowable prompt tokens")
  (:f keep-recent I64 "Number of recent turns to preserve uncompressed in receipts mode"))

(dfs AssembledPrompt
  (:f strategy Str "Strategy applied")
  (:f total-tokens I64 "Total token count of retained blocks")
  (:f prompt-str Str "Formatted ASN S-expression prompt")
  (:f retained-count I64 "Count of retained blocks")
  (:f evicted-count I64 "Count of evicted blocks"))

(df estimate-tokens [(text Str)] -> I64
  :d "Heuristic token estimator assuming 4 characters per token with minimum 1"
  (let [(len (string-length text))]
    (if (<= len 0)
      0
      (max 1 (/ (+ len 3) 4)))))

(df make-context-block [(id Str) (kind Str) (tokens I64) (payload Str)] -> ContextBlock
  :d "Constructs ContextBlock calculating token weight if unspecified"
  (let [(tok (if (> tokens 0) tokens (estimate-tokens payload)))]
    (ContextBlock :id id :kind kind :tokens tok :payload payload)))

(df make-agent-ctx-op [(retain (List Str)) (evict (List Str)) (prefetch (List Str))] -> AgentCtxOp
  :d "Constructs AgentCtxOp directive"
  (AgentCtxOp :retain retain :evict evict :prefetch prefetch))

(df make-default-config [(strategy Str)] -> ContextAssemblyConfig
  :d "Constructs ContextAssemblyConfig with standard ceilings and defaults"
  (ContextAssemblyConfig :strategy strategy :token-ceiling 4096 :keep-recent 2))

(df format-context-blocks [(blocks (List ContextBlock))] -> Str
  :d "Formats a list of context blocks into an ASN :ctx payload"
  (if (list-empty? blocks)
    "(:ctx [])"
    (let [(lines (map (fn [(b ContextBlock)] -> Str
                        (let [(escaped (string-replace (string-replace (.-payload b) "\\" "\\\\") "\"" "\\\""))]
                          (str "    (:block :id \"" (.-id b)
                               "\" :kind \"" (.-kind b)
                               "\" :tokens " (string-from-int64 (.-tokens b))
                               " :data \"" escaped "\")")))
                      blocks))]
      (str "(:ctx [\n" (string-join lines "\n") "\n  ])"))))

(dfs BlockAccumulator
  (:f retained (List ContextBlock) "Accumulated retained blocks")
  (:f evicted (List ContextBlock) "Accumulated evicted blocks")
  (:f tokens I64 "Current token total"))

(df accumulate-blocks-loop [(remaining (List ContextBlock)) (ceiling I64) (acc BlockAccumulator)] -> BlockAccumulator
  :d "Appends blocks within token ceiling marking overflows as evicted"
  (if (list-empty? remaining)
    acc
    (let [(default-b (ContextBlock :id "" :kind "" :tokens 0 :payload ""))
          (head-b (option-or (list-head remaining) default-b))
          (tail-b (option-or (list-tail remaining) (list)))
          (tok (.-tokens head-b))]
      (if (<= (+ (.-tokens acc) tok) ceiling)
        (accumulate-blocks-loop
          tail-b
          ceiling
          (BlockAccumulator
            :retained (list-append (.-retained acc) (list head-b))
            :evicted (.-evicted acc)
            :tokens (+ (.-tokens acc) tok)))
        (accumulate-blocks-loop
          tail-b
          ceiling
          (BlockAccumulator
            :retained (.-retained acc)
            :evicted (list-append (.-evicted acc) (list head-b))
            :tokens (.-tokens acc)))))))

(df assemble-baseline-context [(blocks (List ContextBlock)) (ceiling I64)] -> AssembledPrompt
  :d "Compiles standard sliding window without compression (Strategy 1)"
  (let [(acc (BlockAccumulator :retained (list) :evicted (list) :tokens 0))
        (res (accumulate-blocks-loop blocks ceiling acc))
        (retained (.-retained res))
        (p-str (format-context-blocks retained))]
    (AssembledPrompt
      :strategy "baseline"
      :total-tokens (.-tokens res)
      :prompt-str p-str
      :retained-count (list-length retained)
      :evicted-count (list-length (.-evicted res)))))

(df is-history-block? [(b ContextBlock)] -> Bool
  :d "True if block represents multi-turn dialogue or past tool return"
  (let [(k (.-kind b))]
    (or (= k "history")
        (or (= k "turn")
            (= k "tool-return")))))

(df compact-block-if-history [(b ContextBlock)] -> ContextBlock
  :d "Transforms older history block into concise 1-line ASN receipt"
  (if (is-history-block? b)
    (let [(compacted (comp/compact-receipt (.-payload b)))
          (tok (estimate-tokens compacted))]
      (ContextBlock
        :id (.-id b)
        :kind "receipt"
        :tokens tok
        :payload compacted))
    b))

(dfs HistoryFoldAcc
  (:f count I64 "Number of history blocks seen")
  (:f blocks (List ContextBlock) "Accumulated processed blocks"))

(df process-receipts-blocks [(blocks (List ContextBlock)) (keep-recent I64)] -> (List ContextBlock)
  :d "Preserves recent turns verbatim while compacting older turns into receipts"
  (let [(history-blocks (filter (fn [(b ContextBlock)] -> Bool (is-history-block? b)) blocks))
        (hist-len (list-length history-blocks))
        (cutoff (max 0 (- hist-len keep-recent)))]
    (if (<= cutoff 0)
      blocks
      (let [(init-acc (HistoryFoldAcc :count 0 :blocks (list)))
            (final-acc (fold (fn [(acc HistoryFoldAcc) (b ContextBlock)] -> HistoryFoldAcc
                               (if (is-history-block? b)
                                 (let [(cnt (.-count acc))]
                                   (if (< cnt cutoff)
                                     (HistoryFoldAcc
                                       :count (+ cnt 1)
                                       :blocks (list-append (.-blocks acc) (list (compact-block-if-history b))))
                                     (HistoryFoldAcc
                                       :count (+ cnt 1)
                                       :blocks (list-append (.-blocks acc) (list b)))))
                                 (HistoryFoldAcc
                                   :count (.-count acc)
                                   :blocks (list-append (.-blocks acc) (list b)))))
                             init-acc
                             blocks))]
        (.-blocks final-acc)))))

(df assemble-receipts-context [(blocks (List ContextBlock)) (ceiling I64) (keep-recent I64)] -> AssembledPrompt
  :d "Compiles context compacting historical turns into 1-line receipts (Strategy 2)"
  (let [(transformed (process-receipts-blocks blocks keep-recent))
        (acc (BlockAccumulator :retained (list) :evicted (list) :tokens 0))
        (res (accumulate-blocks-loop transformed ceiling acc))
        (retained (.-retained res))
        (p-str (format-context-blocks retained))]
    (AssembledPrompt
      :strategy "receipts"
      :total-tokens (.-tokens res)
      :prompt-str p-str
      :retained-count (list-length retained)
      :evicted-count (list-length (.-evicted res)))))

(df assemble-jit-context [(blocks (List ContextBlock)) (ceiling I64)] -> AssembledPrompt
  :d "Excludes conversational history and prioritizes AST working set chunks (Strategy 3)"
  (let [(essential-blocks (filter (fn [(b ContextBlock)] -> Bool
                                    (not (is-history-block? b)))
                                  blocks))
        (acc (BlockAccumulator :retained (list) :evicted (list) :tokens 0))
        (res (accumulate-blocks-loop essential-blocks ceiling acc))
        (retained (.-retained res))
        (p-str (format-context-blocks retained))
        (history-dropped (filter (fn [(b ContextBlock)] -> Bool (is-history-block? b)) blocks))
        (total-evicted (+ (list-length (.-evicted res)) (list-length history-dropped)))]
    (AssembledPrompt
      :strategy "jit-memory"
      :total-tokens (.-tokens res)
      :prompt-str p-str
      :retained-count (list-length retained)
      :evicted-count total-evicted)))

(df list-contains-str? [(items (List Str)) (needle Str)] -> Bool
  :d "True if list contains exact string match"
  (if (list-empty? items)
    false
    (let [(head-s (option-or (list-head items) ""))
          (tail-s (option-or (list-tail items) (list)))]
      (if (= head-s needle)
        true
        (list-contains-str? tail-s needle)))))

(df assemble-agent-directed-context [(blocks (List ContextBlock)) (ceiling I64) (op AgentCtxOp)] -> AssembledPrompt
  :d "Applies agent-directed eviction, retention, and prefetch directives (Strategy 4)"
  (let [(filtered-not-evicted (filter (fn [(b ContextBlock)] -> Bool
                                        (not (list-contains-str? (.-evict op) (.-id b))))
                                      blocks))
        (prefetched-blocks (map (fn [(target Str)] -> ContextBlock
                                  (let [(pl (str "(:prefetch-sym \"" target "\")"))]
                                    (ContextBlock
                                      :id (str "prefetch-" target)
                                      :kind "prefetched-ast"
                                      :tokens (estimate-tokens pl)
                                      :payload pl)))
                                (.-prefetch op)))
        (merged-candidate (list-append filtered-not-evicted prefetched-blocks))
        (prioritized-retained (filter (fn [(b ContextBlock)] -> Bool
                                        (list-contains-str? (.-retain op) (.-id b)))
                                      merged-candidate))
        (other-blocks (filter (fn [(b ContextBlock)] -> Bool
                                (not (list-contains-str? (.-retain op) (.-id b))))
                              merged-candidate))
        (final-candidate (list-append prioritized-retained other-blocks))
        (acc (BlockAccumulator :retained (list) :evicted (list) :tokens 0))
        (res (accumulate-blocks-loop final-candidate ceiling acc))
        (retained (.-retained res))
        (p-str (format-context-blocks retained))
        (explicitly-evicted (filter (fn [(b ContextBlock)] -> Bool
                                      (list-contains-str? (.-evict op) (.-id b)))
                                    blocks))
        (total-evicted (+ (list-length (.-evicted res)) (list-length explicitly-evicted)))]
    (AssembledPrompt
      :strategy "agent-directed"
      :total-tokens (.-tokens res)
      :prompt-str p-str
      :retained-count (list-length retained)
      :evicted-count total-evicted)))

(df extract-quoted-tokens [(raw Str)] -> (List Str)
  :d "Extracts space or quote separated tokens between square brackets"
  (let [(clean1 (string-replace raw "[" ""))
        (clean2 (string-replace clean1 "]" ""))
        (clean3 (string-replace clean2 "\"" ""))
        (clean4 (string-replace clean3 "'" ""))
        (parts (string-split clean4 " "))
        (filtered (filter (fn [(s Str)] -> Bool
                            (let [(trimmed (string-trim s))]
                              (not (string-empty? trimmed))))
                          parts))]
    (map (fn [(s Str)] -> Str (string-trim s)) filtered)))

(df extract-section-tokens [(text Str) (tag Str)] -> (List Str)
  :d "Extracts bracketed token list associated with tag e.g. :retain [...]"
  (let [(idx-opt (string-index-of text tag))]
    (mt idx-opt
      ((some idx)
       (let [(sub (option-or (string-slice text (+ idx (string-length tag)) (string-length text)) ""))
             (open-br (string-index-of sub "["))
             (close-br (string-index-of sub "]"))]
         (mt open-br
           ((some ob)
            (mt close-br
              ((some cb)
               (if (< ob cb)
                 (let [(inner (option-or (string-slice sub (+ ob 1) cb) ""))]
                   (extract-quoted-tokens inner))
                 (list)))
              ((none) (list))))
           ((none) (list)))))
      ((none) (list)))))

(df parse-agent-ctx-op [(raw Str)] -> (Option AgentCtxOp)
  :d "Parses model response extracting :ctx-op directive with :retain, :evict, :prefetch"
  (if (not (string-contains? raw ":ctx-op"))
    (none)
    (let [(retain-items (extract-section-tokens raw ":retain"))
          (evict-items (extract-section-tokens raw ":evict"))
          (prefetch-items (extract-section-tokens raw ":prefetch"))]
      (some (AgentCtxOp :retain retain-items :evict evict-items :prefetch prefetch-items)))))

(df is-core-block? [(b ContextBlock)] -> Bool
  :d "True if block represents immutable system mandate or task specification"
  (let [(k (.-kind b))]
    (or (= k "sys-mandate")
        (= k "task-spec"))))

(df is-knowledge-block? [(b ContextBlock)] -> Bool
  :d "True if block represents mounted external documentation or contract"
  (= (.-kind b) "knowledge"))

(df is-delta-block? [(b ContextBlock)] -> Bool
  :d "True if block represents immediate reactive feedback error or diff"
  (let [(k (.-kind b))]
    (or (= k "delta")
        (or (= k "error")
            (= k "gate-rejection")))))

(df is-other-canvas-block? [(b ContextBlock)] -> Bool
  :d "True if block is neither core, knowledge, delta, nor history"
  (and (not (is-core-block? b))
       (and (not (is-knowledge-block? b))
            (and (not (is-delta-block? b))
                 (not (is-history-block? b))))))

(df apply-universal-default-canvas [(blocks (List ContextBlock)) (ceiling I64) (agent-op (Option AgentCtxOp))] -> AssembledPrompt
  :d "Compiles context according to the Universal Golden Default Canvas: Core + Knowledge + Other + Receipts + Delta"
  (mt agent-op
    ((some op)
     (assemble-agent-directed-context blocks ceiling op))
    ((none)
     (let [(core-blocks (filter (fn [(b ContextBlock)] -> Bool (is-core-block? b)) blocks))
           (knowledge-blocks (filter (fn [(b ContextBlock)] -> Bool (is-knowledge-block? b)) blocks))
           (other-blocks (filter (fn [(b ContextBlock)] -> Bool (is-other-canvas-block? b)) blocks))
           (delta-blocks (filter (fn [(b ContextBlock)] -> Bool (is-delta-block? b)) blocks))
           (history-candidates (filter (fn [(b ContextBlock)] -> Bool (is-history-block? b)) blocks))
           (receipt-blocks (process-receipts-blocks history-candidates 1))
           (prefix-blocks (list-append (list-append core-blocks knowledge-blocks) other-blocks))
           (ordered-candidates (list-append prefix-blocks (list-append receipt-blocks delta-blocks)))
           (acc (BlockAccumulator :retained (list) :evicted (list) :tokens 0))
           (res (accumulate-blocks-loop ordered-candidates ceiling acc))
           (retained (.-retained res))
           (p-str (format-context-blocks retained))]
       (AssembledPrompt
         :strategy "universal-default"
         :total-tokens (.-tokens res)
         :prompt-str p-str
         :retained-count (list-length retained)
         :evicted-count (list-length (.-evicted res)))))))

(df assemble-prompt [(blocks (List ContextBlock)) (cfg ContextAssemblyConfig) (agent-op (Option AgentCtxOp))] -> AssembledPrompt
  :d "Dispatches context compilation based on configured strategy"
  (let [(strat (.-strategy cfg))
        (ceiling (.-token-ceiling cfg))
        (recent (.-keep-recent cfg))]
    (cond
      ((= strat "baseline") (assemble-baseline-context blocks ceiling))
      ((= strat "receipts") (assemble-receipts-context blocks ceiling recent))
      ((= strat "jit-memory") (assemble-jit-context blocks ceiling))
      ((= strat "agent-directed")
       (mt agent-op
         ((some op) (assemble-agent-directed-context blocks ceiling op))
         ((none) (assemble-receipts-context blocks ceiling recent))))
      ((= strat "universal-default") (apply-universal-default-canvas blocks ceiling agent-op))
      ((= strat "golden-default") (apply-universal-default-canvas blocks ceiling agent-op))
      (true (assemble-baseline-context blocks ceiling)))))
