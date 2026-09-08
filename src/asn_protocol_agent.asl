(module asl-harness/asn-protocol-agent
  :d "Pure ASN Prompt and Completion Protocol Harness Adapter for sovereign agent communication."
  :x [AsnAgentState
      AsnToolDefinition
      AsnToolCall
      AsnToolReturn
      AsnParsedCompletion
      format-asn-tool-schema
      format-asn-agent-prompt
      parse-asn-completion
      format-asn-tool-return]
  :i [])

(dfs AsnAgentState
  (:f session-id Str "Unique session identifier")
  (:f turns I64 "Current turn counter")
  (:f context (List Str) "Working context buffer lines")
  (:f active-tools (List Str) "List of active tool names"))

(dfs AsnToolDefinition
  (:f name Str "Tool identifier name")
  (:f desc Str "Human and agent readable tool description")
  (:f params (List Str) "Ordered parameter names or type signatures"))

(dfs AsnToolCall
  (:f id Str "Unique invocation identifier")
  (:f tool Str "Target tool name")
  (:f args (List Str) "Invocation argument payloads"))

(dfs AsnToolReturn
  (:f call-id Str "Matching invocation identifier")
  (:f status Str "Execution outcome status e.g. success or error")
  (:f payload Str "Serialized outcome payload or error message"))

(dfs AsnParsedCompletion
  (:f intent Str "Stated primary agent intent")
  (:f reveal (List Str) "Epistemic reveal reasoning observations")
  (:f tool-calls (List AsnToolCall) "Extracted structured tool invocations")
  (:f delta Str "Structured state or file delta payload")
  (:f summary Str "Execution summary or conclusion"))

(df format-str-list [(items (List Str))] -> Str
  :d "Formats a list of strings into a bracketed ASN vector representation."
  (if (list-empty? items)
    "[]"
    (let [(quoted (map (fn [(s Str)] -> Str (str "\"" s "\"")) items))]
      (str "[" (string-join quoted " ") "]"))))

(df format-single-tool [(tool AsnToolDefinition)] -> Str
  :d "Formats an individual tool definition as compact ASN S-expression."
  (str "(:tool :name \"" (.-name tool)
       "\" :desc \"" (.-desc tool)
       "\" :params " (format-str-list (.-params tool)) ")"))

(df format-asn-tool-schema [(tools (List AsnToolDefinition))] -> Str
  :d "Formats a list of tool definitions into compact ASN tools block."
  (if (list-empty? tools)
    "(:tools [])"
    (let [(rendered (map (fn [(t AsnToolDefinition)] -> Str (format-single-tool t)) tools))]
      (str "(:tools [" (string-join rendered " ") "])"))))

(df format-asn-agent-prompt [(state AsnAgentState) (tools (List AsnToolDefinition))] -> Str
  :d "Encodes agent state, context buffer, and tool schemas into pure ASN S-expression prompt."
  (str "(:asn-prompt :session-id \"" (.-session-id state)
       "\" :turns " (string-from-int64 (.-turns state))
       " :ctx " (format-str-list (.-context state))
       " :active-tools " (format-str-list (.-active-tools state))
       " " (format-asn-tool-schema tools) ")"))

(df format-asn-tool-return [(ret AsnToolReturn)] -> Str
  :d "Formats tool execution result as compact ASN S-expression."
  (str "(:return :call-id \"" (.-call-id ret)
       "\" :status \"" (.-status ret)
       "\" :payload \"" (.-payload ret) "\")"))

(df extract-quoted-chars [(chars (List Str)) (acc Str) (esc Bool)] -> Str
  :d "Extracts inner string characters preserving escaped quotes."
  (if (list-empty? chars)
    acc
    (let [(c (option-or (list-head chars) ""))
          (rst (option-or (list-tail chars) (list)))]
      (if esc
        (extract-quoted-chars rst (str-concat acc c) false)
        (if (= c "\\")
          (extract-quoted-chars rst (str-concat acc c) true)
          (if (= c "\"")
            acc
            (extract-quoted-chars rst (str-concat acc c) false)))))))

(df extract-str-field [(raw Str) (kw Str)] -> Str
  :d "Extracts quoted string attribute value for keyword in S-expression."
  (let [(idx-opt (string-index-of raw kw))]
    (mt idx-opt
      ((some idx)
       (let [(tail-opt (string-slice raw (+ idx (string-length kw)) (string-length raw)))
             (tail (option-or tail-opt ""))
             (q-opt (string-index-of tail "\""))]
         (mt q-opt
           ((some q-idx)
            (let [(val-tail-opt (string-slice tail (+ q-idx 1) (string-length tail)))
                  (val-tail (option-or val-tail-opt ""))]
              (extract-quoted-chars (string-chars val-tail) "" false)))
           ((none) ""))))
      ((none) ""))))

(df extract-list-items [(chars (List Str)) (in-str Bool) (cur Str) (acc (List Str))] -> (List Str)
  :d "Extracts list of quoted string tokens from bracketed sequence."
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
  :d "Extracts list of string values for keyword vector attribute."
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

(df find-matching-paren-chars [(chars (List Str)) (depth I64) (in-quote Bool) (escape Bool) (idx I64)] -> (Option I64)
  :d "Finds matching closing parenthesis handling quoted strings and escapes."
  (if (list-empty? chars)
    (none)
    (let [(c (option-or (list-head chars) ""))
          (rst (option-or (list-tail chars) (list)))]
      (if escape
        (find-matching-paren-chars rst depth in-quote false (+ idx 1))
        (if in-quote
          (if (= c "\\")
            (find-matching-paren-chars rst depth true true (+ idx 1))
            (if (= c "\"")
              (find-matching-paren-chars rst depth false false (+ idx 1))
              (find-matching-paren-chars rst depth true false (+ idx 1))))
          (if (= c "\"")
            (find-matching-paren-chars rst depth true false (+ idx 1))
            (if (= c "(")
              (find-matching-paren-chars rst (+ depth 1) false false (+ idx 1))
              (if (= c ")")
                (if (= depth 1)
                  (some idx)
                  (find-matching-paren-chars rst (- depth 1) false false (+ idx 1)))
                (find-matching-paren-chars rst depth false false (+ idx 1))))))))))

(df find-matching-paren [(raw Str) (start I64)] -> (Option I64)
  :d "Finds matching closing parenthesis for form starting at index start."
  (let [(len (string-length raw))]
    (if (>= (+ start 1) len)
      (none)
      (let [(tail-opt (string-slice raw (+ start 1) len))]
        (mt tail-opt
          ((some tail)
           (find-matching-paren-chars (string-chars tail) 1 false false (+ start 1)))
          ((none) (none)))))))

(df find-next-call-index [(raw Str) (start-idx I64)] -> (Option I64)
  :d "Finds index of next tool call token starting at given offset."
  (let [(len (string-length raw))]
    (if (>= start-idx len)
      (none)
      (let [(slice (option-or (string-slice raw start-idx len) ""))
            (idx-call (string-index-of slice "(:call"))
            (idx-tool-call (string-index-of slice "(:tool-call"))]
        (mt idx-call
          ((some c)
           (mt idx-tool-call
             ((some tc)
              (if (< c tc) (some (+ start-idx c)) (some (+ start-idx tc))))
             ((none) (some (+ start-idx c)))))
          ((none)
           (mt idx-tool-call
             ((some tc) (some (+ start-idx tc)))
             ((none) (none)))))))))

(df parse-single-tool-call [(call-str Str)] -> AsnToolCall
  :d "Parses single tool call S-expression into AsnToolCall record."
  (let [(id (extract-str-field call-str ":id"))
        (tool-raw (extract-str-field call-str ":tool"))
        (tool (if (string-empty? tool-raw)
                (extract-str-field call-str ":name")
                tool-raw))
        (args-raw (extract-list-field call-str ":args"))
        (args (if (list-empty? args-raw)
                (extract-list-field call-str ":params")
                args-raw))]
    (AsnToolCall
      :id id
      :tool tool
      :args args)))

(df parse-tool-calls-loop [(raw Str) (offset I64) (acc (List AsnToolCall))] -> (List AsnToolCall)
  :d "Recursively extracts all tool calls from raw completion string."
  (let [(next-opt (find-next-call-index raw offset))]
    (mt next-opt
      ((none) acc)
      ((some call-start)
       (let [(close-opt (find-matching-paren raw call-start))]
         (mt close-opt
           ((none) acc)
           ((some call-end)
            (let [(call-slice (option-or (string-slice raw call-start (+ call-end 1)) ""))
                  (parsed (parse-single-tool-call call-slice))
                  (new-acc (list-append acc (list parsed)))]
              (parse-tool-calls-loop raw (+ call-end 1) new-acc)))))))))

(df parse-asn-completion [(raw-completion Str)] -> AsnParsedCompletion
  :d "Parses pure ASN completion into typed structured completion record."
  (let [(intent (extract-str-field raw-completion ":intent"))
        (reveal (extract-list-field raw-completion ":reveal"))
        (calls (parse-tool-calls-loop raw-completion 0 (list)))
        (delta (extract-str-field raw-completion ":delta"))
        (summary-raw (extract-str-field raw-completion ":summary"))
        (summary (if (string-empty? summary-raw)
                   (extract-str-field raw-completion ":desc")
                   summary-raw))]
    (AsnParsedCompletion
      :intent intent
      :reveal reveal
      :tool-calls calls
      :delta delta
      :summary summary)))
