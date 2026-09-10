(module asl-harness/stream-demuxer
  :d "Universal L7 Gateway Stream Demuxer and Reasoning Channel Quarantine"
  :x [StreamDemuxer
      DemuxResult
      ReasoningQuarantine
      demux-llm-stream
      normalize-toolcall-output
      make-stream-demuxer
      make-demux-result
      make-quarantine
      extract-thought-channel
      extract-content-channel]
  :i [])

(dfs ReasoningQuarantine
  :d "Quarantined chain-of-thought tokens and thinking trace"
  (:f thought-tokens Str "Raw extracted reasoning content")
  (:f quarantined Bool "True if reasoning tokens were successfully isolated")
  (:f token-count I64 "Estimated token count of quarantined thinking"))

(dfs DemuxResult
  :d "Demuxed output separating reasoning channel from user-facing action content"
  (:f content Str "Clean user-facing response or tool call payload")
  (:f quarantine ReasoningQuarantine "Quarantined thinking metadata")
  (:f has-toolcall Bool "True if content contains structured tool call invocation")
  (:f model-family Str "Detected or specified model archetype"))

(dfs StreamDemuxer
  :d "Configuration and state for stream demuxing pipeline"
  (:f model-id Str "Model identifier e.g. kimi-3, gemini-flash, gpt-4o")
  (:f strip-thoughts Bool "True to prevent thought leakage into downstream context")
  (:f normalize-json Bool "True to normalize JSON tool calls into ASN S-expressions"))

(df make-quarantine [(thought Str) (quarantined Bool) (tokens I64)] -> ReasoningQuarantine
  :d "Constructs a ReasoningQuarantine record"
  (ReasoningQuarantine
    :thought-tokens thought
    :quarantined quarantined
    :token-count tokens))

(df make-stream-demuxer [(model Str) (strip Bool) (norm Bool)] -> StreamDemuxer
  :d "Constructs a StreamDemuxer configuration"
  (StreamDemuxer
    :model-id model
    :strip-thoughts strip
    :normalize-json norm))

(df make-demux-result [(content Str) (quarantine ReasoningQuarantine) (has-tc Bool) (family Str)] -> DemuxResult
  :d "Constructs a DemuxResult record"
  (DemuxResult
    :content content
    :quarantine quarantine
    :has-toolcall has-tc
    :model-family family))

(df estimate-tokens [(text Str)] -> I64
  :d "BPE token heuristic estimator"
  (let [(len (string-length text))]
    (cond
      ((<= len 0) 0)
      ((<= len 4) 1)
      (true (/ (+ len 3) 4)))))

(df extract-thought-channel [(raw Str)] -> ReasoningQuarantine
  :d "Isolates and extracts thought tokens from raw stream text"
  (cond
    ((string-empty? raw)
     (make-quarantine "" false 0))
    ((and (string-contains? raw "<think>") (string-contains? raw "</think>"))
     (let [(p1 (string-split raw "<think>"))
           (rest (option-or (list-head (list-drop p1 1)) ""))
           (p2 (string-split rest "</think>"))
           (think (option-or (list-head p2) ""))
           (trimmed (string-trim think))]
       (make-quarantine trimmed true (estimate-tokens trimmed))))
    ((and (string-contains? raw "[THOUGHT]") (string-contains? raw "[/THOUGHT]"))
     (let [(p1 (string-split raw "[THOUGHT]"))
           (rest (option-or (list-head (list-drop p1 1)) ""))
           (p2 (string-split rest "[/THOUGHT]"))
           (think (option-or (list-head p2) ""))
           (trimmed (string-trim think))]
       (make-quarantine trimmed true (estimate-tokens trimmed))))
    (true
     (make-quarantine "" false 0))))

(df extract-content-channel [(raw Str)] -> Str
  :d "Extracts pure action and user content channel, stripping thinking tokens"
  (cond
    ((string-empty? raw) "")
    ((and (string-contains? raw "<think>") (string-contains? raw "</think>"))
     (let [(p1 (string-split raw "<think>"))
           (pre (option-or (list-head p1) ""))
           (rest (option-or (list-head (list-drop p1 1)) ""))
           (p2 (string-split rest "</think>"))
           (post (option-or (list-head (list-drop p2 1)) ""))]
       (string-trim (str pre post))))
    ((and (string-contains? raw "[THOUGHT]") (string-contains? raw "[/THOUGHT]"))
     (let [(p1 (string-split raw "[THOUGHT]"))
           (pre (option-or (list-head p1) ""))
           (rest (option-or (list-head (list-drop p1 1)) ""))
           (p2 (string-split rest "[/THOUGHT]"))
           (post (option-or (list-head (list-drop p2 1)) ""))]
       (string-trim (str pre post))))
    (true (string-trim raw))))

(df normalize-toolcall-output [(raw Str)] -> Str
  :d "Normalizes JSON and XML tool calls into canonical ASN (:call :tool ...) S-expressions"
  (let [(trimmed (string-trim raw))]
    (cond
      ((string-empty? trimmed) "")
      ((string-starts-with? trimmed "(:call") trimmed)
      ((string-contains? trimmed "name:")
       (let [(s1 (string-replace trimmed "{" "(:call "))
             (s2 (string-replace s1 "}" ")"))
             (s3 (string-replace s2 "name:" ":tool"))
             (s4 (string-replace s3 "arguments:" ":args"))
             (s5 (string-replace s4 "parameters:" ":args"))]
         (string-trim s5)))
      (true trimmed))))

(df demux-llm-stream [(demuxer StreamDemuxer) (raw Str)] -> DemuxResult
  :d "Demuxes LLM stream chunk into quarantined thoughts and clean content"
  (let [(quarantine (extract-thought-channel raw))
        (raw-content (if (.-strip-thoughts demuxer)
                         (extract-content-channel raw)
                         raw))
        (clean-content (if (.-normalize-json demuxer)
                           (normalize-toolcall-output raw-content)
                           raw-content))
        (has-tc (or (string-contains? clean-content "(:call")
                    (string-contains? clean-content "tool_calls")))
        (model (.-model-id demuxer))]
    (make-demux-result clean-content quarantine has-tc model)))
