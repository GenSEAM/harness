(module asl-harness/knowledge-mount
  :d "Pluggable Knowledge Mounting Engine managing external documentation, API contracts, and web research digests with strict token clamping and perceptual pointer offloading."
  :x [KnowledgeSource
      MountedKnowledge
      make-knowledge-source
      make-mounted-knowledge
      clamp-knowledge-payload
      mount-knowledge-source
      unmount-knowledge-source
      is-knowledge-mounted?
      find-mounted-knowledge
      to-context-block
      to-context-blocks
      format-mounted-knowledge-asn]
  :i [(context_assembler :a ca)])

(dfs KnowledgeSource
  (:f source-id Str "Unique knowledge source identifier")
  (:f kind Str "Knowledge kind e.g. api-doc, web-digest, interface-contract, mem-fact")
  (:f uri Str "Origin URI or file path")
  (:f raw-content Str "Full uncompressed raw payload")
  (:f clamped-tokens I64 "Token budget ceiling for this knowledge source"))

(dfs MountedKnowledge
  (:f source-id Str "Unique identifier")
  (:f kind Str "Knowledge kind")
  (:f uri Str "Origin URI")
  (:f active Bool "Mount state flag")
  (:f clamped-payload Str "Payload clamped to token ceiling")
  (:f tokens I64 "Calculated token weight of clamped payload")
  (:f pointer-uri Str "Perceptual pointer if document was clamped"))

(df make-knowledge-source [(id Str) (kind Str) (uri Str) (content Str) (clamped-tokens I64)] -> KnowledgeSource
  :d "Constructs KnowledgeSource specification"
  (let [(tokens (if (> clamped-tokens 0) clamped-tokens 350))]
    (KnowledgeSource
      :source-id id
      :kind kind
      :uri uri
      :raw-content content
      :clamped-tokens tokens)))

(df make-mounted-knowledge [(id Str) (kind Str) (uri Str) (active Bool) (payload Str) (tokens I64) (pointer Str)] -> MountedKnowledge
  :d "Constructs MountedKnowledge state"
  (MountedKnowledge
    :source-id id
    :kind kind
    :uri uri
    :active active
    :clamped-payload payload
    :tokens tokens
    :pointer-uri pointer))

(df clamp-knowledge-payload [(content Str) (uri Str) (token-ceiling I64)] -> MountedKnowledge
  :d "Clamps knowledge content to token budget emitting perceptual pointer if truncated"
  (let [(ceiling (if (> token-ceiling 0) token-ceiling 350))
        (raw-tok (ca/estimate-tokens content))]
    (if (<= raw-tok ceiling)
      (MountedKnowledge
        :source-id ""
        :kind "knowledge"
        :uri uri
        :active true
        :clamped-payload content
        :tokens raw-tok
        :pointer-uri "")
      (let [(max-chars (* ceiling 4))
            (truncated (option-or (string-slice content 0 max-chars) content))
            (ptr (str "(:ptr :uri \"" uri "\" :tokens " (string-from-int64 raw-tok) ")"))
            (clamped-body (str truncated "\n... [TRUNCATED - use (:ptr :uri \"" uri "\") for full slice]"))
            (clamped-tok (ca/estimate-tokens clamped-body))]
        (MountedKnowledge
          :source-id ""
          :kind "knowledge"
          :uri uri
          :active true
          :clamped-payload clamped-body
          :tokens clamped-tok
          :pointer-uri ptr)))))

(df mount-knowledge-source [(mounted (List MountedKnowledge)) (src KnowledgeSource)] -> (List MountedKnowledge)
  :d "Mounts or updates knowledge source in active working set with bounded token budget"
  (let [(id (.-source-id src))
        (filtered (filter (fn [(mk MountedKnowledge)] -> Bool
                            (not (= (.-source-id mk) id)))
                          mounted))
        (clamped (clamp-knowledge-payload (.-raw-content src) (.-uri src) (.-clamped-tokens src)))
        (new-mounted (MountedKnowledge
                       :source-id id
                       :kind (.-kind src)
                       :uri (.-uri src)
                       :active true
                       :clamped-payload (.-clamped-payload clamped)
                       :tokens (.-tokens clamped)
                       :pointer-uri (.-pointer-uri clamped)))]
    (list-append filtered (list new-mounted))))

(df unmount-knowledge-source [(mounted (List MountedKnowledge)) (source-id Str)] -> (List MountedKnowledge)
  :d "Unmounts knowledge source completely freeing context tokens"
  (filter (fn [(mk MountedKnowledge)] -> Bool
            (not (= (.-source-id mk) source-id)))
          mounted))

(df is-knowledge-mounted? [(mounted (List MountedKnowledge)) (source-id Str)] -> Bool
  :d "True if knowledge source is currently active in mounted set"
  (if (list-empty? mounted)
    false
    (let [(head-mk (option-or (list-head mounted) (make-mounted-knowledge "" "" "" false "" 0 "")))
          (tail-mk (option-or (list-tail mounted) (list)))]
      (if (and (= (.-source-id head-mk) source-id) (.-active head-mk))
        true
        (is-knowledge-mounted? tail-mk source-id)))))

(df find-mounted-knowledge [(mounted (List MountedKnowledge)) (source-id Str)] -> (Option MountedKnowledge)
  :d "Finds active mounted knowledge record by source-id"
  (if (list-empty? mounted)
    (none)
    (let [(head-mk (option-or (list-head mounted) (make-mounted-knowledge "" "" "" false "" 0 "")))
          (tail-mk (option-or (list-tail mounted) (list)))]
      (if (= (.-source-id head-mk) source-id)
        (some head-mk)
        (find-mounted-knowledge tail-mk source-id)))))

(df to-context-block [(mk MountedKnowledge)] -> ca/ContextBlock
  :d "Transpiles active mounted knowledge into standard ContextBlock"
  (let [(block-id (str "k-" (.-source-id mk)))
        (content (if (string-empty? (.-pointer-uri mk))
                   (.-clamped-payload mk)
                   (str (.-clamped-payload mk) "\n" (.-pointer-uri mk))))
        (tok (ca/estimate-tokens content))]
    (ca/make-context-block block-id "knowledge" tok content)))

(df to-context-blocks [(mounted (List MountedKnowledge))] -> (List ca/ContextBlock)
  :d "Transpiles all active mounted knowledge items into ContextBlock list"
  (map (fn [(mk MountedKnowledge)] -> ca/ContextBlock
         (to-context-block mk))
       (filter (fn [(mk MountedKnowledge)] -> Bool (.-active mk)) mounted)))

(df format-mounted-knowledge-asn [(mk MountedKnowledge)] -> Str
  :d "Formats mounted knowledge into structured ASN string"
  (let [(esc-ptr (string-replace (.-pointer-uri mk) "\"" "\\\""))]
    (str "(:mounted-knowledge\n"
         "  :source-id \"" (.-source-id mk) "\"\n"
         "  :kind \"" (.-kind mk) "\"\n"
         "  :uri \"" (.-uri mk) "\"\n"
         "  :active " (if (.-active mk) "true" "false") "\n"
         "  :tokens " (string-from-int64 (.-tokens mk)) "\n"
         "  :pointer-uri \"" esc-ptr "\"\n"
         ")")))
