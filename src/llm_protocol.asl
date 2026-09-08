(module asl-harness/llm-protocol
  :d "Canonical ASL LLM Protocol engine with compact handshake envelope formatting and response parsing"
  :x [LLMProtocolConfig
      LLMResponseEnvelope
      format-protocol-envelope
      parse-protocol-response]
  :i [])

(dfs LLMProtocolConfig
  (:f model Str "Target model identifier e.g. gemma-4-31b-it or claude-3-7-sonnet")
  (:f position Str "Placement position: postamble | preamble | system")
  (:f target-tokens I64 "Token budget ceiling for envelope handshake (< 120 tokens)")
  (:f system-prompt Str "Base system instructions or task context")
  (:f schema-mode Str "Schema representation mode: strict-asn | compact-s-expr"))

(dfs LLMResponseEnvelope
  (:f intent Str "Extracted action intent identifier")
  (:f refs (List Str) "List of perceptual symbol and file references")
  (:f markers (List Str) "Execution and telemetry boundary markers")
  (:f delta Str "Structured atomic state or file delta payload")
  (:f state Str "Reported protocol state code e.g. ok, cont, or done")
  (:f d Str "Docstring or rationale description")
  (:f valid Bool "Flag indicating whether response adhered to protocol without fences or filler")
  (:f error-code Str "Error description if rejected e.g. ERR_MARKDOWN_FENCE or ERR_CONVERSATIONAL_FILLER"))

(df format-protocol-envelope [(cfg LLMProtocolConfig)] -> Str
  :d "Generates compact standard protocol priming envelope for model handshake"
  (str-concat
    "(:protocol-envelope :version \"1.0\" :position \""
    (.-position cfg)
    "\" :model \""
    (.-model cfg)
    "\" :mode \""
    (.-schema-mode cfg)
    "\" (:schema (:intent :refs :markers :delta :state :d)) (:rules [:no-fences :pure-asn :dense-deltas]))"))

(df extract-str-field [(raw Str) (kw Str)] -> Str
  :d "Extracts quoted string value for keyword in S-expression"
  (let [(idx-opt (string-index-of raw kw))]
    (mt idx-opt
      ((some idx)
       (let [(tail-opt (string-slice raw (+ idx (string-length kw)) (string-length raw)))
             (tail (option-or tail-opt ""))
             (q-opt (string-index-of tail "\""))]
         (mt q-opt
           ((some q-idx)
            (let [(val-tail-opt (string-slice tail (+ q-idx 1) (string-length tail)))
                  (val-tail (option-or val-tail-opt ""))
                  (q2-opt (string-index-of val-tail "\""))]
              (mt q2-opt
                ((some q2-idx)
                 (option-or (string-slice val-tail 0 q2-idx) ""))
                ((none) ""))))
           ((none) ""))))
      ((none) ""))))

(df extract-delta-chars [(chars (List Str)) (acc Str) (esc Bool)] -> Str
  :d "Extracts delta payload string preserving escaped inner quotes"
  (if (list-empty? chars)
      acc
      (let [(c (option-or (list-head chars) ""))
            (rst (option-or (list-tail chars) (list)))]
        (if esc
            (extract-delta-chars rst (str-concat acc c) false)
            (if (= c "\\")
                (extract-delta-chars rst (str-concat acc c) true)
                (if (= c "\"")
                    acc
                    (extract-delta-chars rst (str-concat acc c) false)))))))

(df extract-delta-field [(raw Str)] -> Str
  :d "Extracts delta attribute string payload from protocol response"
  (let [(idx-opt (string-index-of raw ":delta"))]
    (mt idx-opt
      ((some idx)
       (let [(tail-opt (string-slice raw (+ idx (string-length ":delta")) (string-length raw)))
             (tail (option-or tail-opt ""))
             (q-opt (string-index-of tail "\""))]
         (mt q-opt
           ((some q-idx)
            (let [(val-tail-opt (string-slice tail (+ q-idx 1) (string-length tail)))
                  (val-tail (option-or val-tail-opt ""))]
              (extract-delta-chars (string-chars val-tail) "" false)))
           ((none) ""))))
      ((none) ""))))

(df extract-list-items [(chars (List Str)) (in-str Bool) (cur Str) (acc (List Str))] -> (List Str)
  :d "Extracts list of quoted string tokens from bracketed or parenthesized sequence"
  (if (list-empty? chars)
      acc
      (let [(c (option-or (list-head chars) ""))
            (rst (option-or (list-tail chars) (list)))]
        (if in-str
            (if (= c "\"")
                (extract-list-items rst false "" (list-append acc (list cur)))
                (extract-list-items rst true (str-concat cur c) acc))
            (if (= c "\"")
                (extract-list-items rst true "" acc)
                (extract-list-items rst false "" acc))))))

(df extract-list-field [(raw Str) (kw Str)] -> (List Str)
  :d "Extracts list of string values for keyword vector attribute"
  (let [(idx-opt (string-index-of raw kw))]
    (mt idx-opt
      ((some idx)
       (let [(tail-opt (string-slice raw (+ idx (string-length kw)) (string-length raw)))
             (tail (option-or tail-opt ""))
             (b-start (string-index-of tail "["))]
         (mt b-start
           ((some b-idx)
            (let [(b-tail-opt (string-slice tail (+ b-idx 1) (string-length tail)))
                  (b-tail (option-or b-tail-opt ""))
                  (b-end (string-index-of b-tail "]"))]
              (mt b-end
                ((some end-idx)
                 (let [(content (option-or (string-slice b-tail 0 end-idx) ""))]
                   (extract-list-items (string-chars content) false "" (list))))
                ((none) (list)))))
           ((none) (list)))))
      ((none) (list)))))

(df check-delimiters-balanced [(chars (List Str)) (p I64) (b I64) (q Bool)] -> Bool
  :d "Validates balanced parentheses, brackets, and quotes in raw protocol response"
  (if (list-empty? chars)
      (and (= p 0) (and (= b 0) (not q)))
      (let [(c (option-or (list-head chars) ""))
            (rst (option-or (list-tail chars) (list)))]
        (if q
            (if (= c "\\")
                (if (list-empty? rst)
                    false
                    (let [(rst2 (option-or (list-tail rst) (list)))]
                      (check-delimiters-balanced rst2 p b true)))
                (if (= c "\"")
                    (check-delimiters-balanced rst p b false)
                    (check-delimiters-balanced rst p b true)))
            (if (= c "\"")
                (check-delimiters-balanced rst p b true)
                (if (= c "(")
                    (check-delimiters-balanced rst (+ p 1) b false)
                    (if (= c ")")
                        (if (<= p 0)
                            false
                            (check-delimiters-balanced rst (- p 1) b false))
                        (if (= c "[")
                            (check-delimiters-balanced rst p (+ b 1) false)
                            (if (= c "]")
                                (if (<= b 0)
                                    false
                                    (check-delimiters-balanced rst p (- b 1) false))
                                (check-delimiters-balanced rst p b false))))))))))

(df is-filler-phrase? [(s Str)] -> Bool
  :d "Identifies common conversational filler prefixes in model completion"
  (or (str-contains? s "Sure,")
      (or (str-contains? s "Certainly")
          (or (str-contains? s "Here is")
              (or (str-contains? s "Here's")
                  (or (str-contains? s "I'd be happy")
                      (str-contains? s "I will now")))))))

(df has-code-fence? [(s Str)] -> Bool
  :d "Detects markdown code fences anywhere in completion string"
  (str-contains? s "`"))

(df parse-protocol-response [(raw Str)] -> LLMResponseEnvelope
  :d "Parses and validates raw LLM protocol response extracting envelope components and rejecting markdown fences and fillers"
  (let [(trimmed (string-trim raw))]
    (if (string-empty? trimmed)
        (LLMResponseEnvelope
          :intent ""
          :refs (list)
          :markers (list)
          :delta ""
          :state ""
          :d ""
          :valid false
          :error-code "ERR_EMPTY_PAYLOAD")
        (if (has-code-fence? raw)
            (LLMResponseEnvelope
              :intent ""
              :refs (list)
              :markers (list)
              :delta ""
              :state ""
              :d ""
              :valid false
              :error-code "ERR_MARKDOWN_FENCE")
            (if (or (is-filler-phrase? raw) (not (string-starts-with? trimmed "(")))
                (LLMResponseEnvelope
                  :intent ""
                  :refs (list)
                  :markers (list)
                  :delta ""
                  :state ""
                  :d ""
                  :valid false
                  :error-code "ERR_CONVERSATIONAL_FILLER")
                (if (not (check-delimiters-balanced (string-chars raw) 0 0 false))
                    (LLMResponseEnvelope
                      :intent ""
                      :refs (list)
                      :markers (list)
                      :delta ""
                      :state ""
                      :d ""
                      :valid false
                      :error-code "ERR_UNBALANCED_DELIMITERS")
                    (LLMResponseEnvelope
                      :intent (extract-str-field raw ":intent")
                      :refs (extract-list-field raw ":refs")
                      :markers (extract-list-field raw ":markers")
                      :delta (extract-delta-field raw)
                      :state (extract-str-field raw ":state")
                      :d (extract-str-field raw ":d")
                      :valid true
                      :error-code "")))))))
