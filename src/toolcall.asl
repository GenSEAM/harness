(module asl-harness/toolcall
  :d "Bidirectional Tool-Calling Translator: ASN notation <-> Native OpenAI JSON tool format."
  :x [OpenAiTool OpenAiToolCall
      tool-to-openai-schema parse-openai-tool-call format-asn-tool-call
      asn-call-to-openai-json tools-to-openai-json]
  :i [(coding :a c)])

(dfs OpenAiTool
  (:f tool-type Str "Always 'function'")
  (:f name Str "Function name e.g. fs_read")
  (:f description Str "Docstring description")
  (:f parameters-json Str "JSON Schema string"))

(dfs OpenAiToolCall
  (:f id Str "Call identifier")
  (:f function-name Str "Target function name")
  (:f arguments-json Str "Raw JSON string of arguments"))

(df tool-name-to-json [(name Str)] -> Str
  :d "Maps kebab-case ASL tool name to model-friendly snake_case."
  (string-replace name "-" "_"))

(df json-name-to-tool [(name Str)] -> Str
  :d "Maps model snake_case tool name to canonical ASL kebab-case."
  (string-replace name "_" "-"))

(df map-asl-type-to-json [(t Str)] -> Str
  :d "Maps internal ASL type identifier to JSON Schema primitive type."
  (cond
    ((or (= t "Str") (= t "String")) "string")
    ((or (= t "I64") (or (= t "Int64") (or (= t "Int") (= t "i64")))) "integer")
    ((or (= t "F64") (or (= t "Float64") (or (= t "Float") (= t "f64")))) "number")
    ((or (= t "Bool") (= t "Boolean")) "boolean")
    ((or (= t "List") (= t "Array")) "array")
    ((or (= t "Map") (= t "Dict")) "object")
    (:else "string")))

(df format-param-prop [(p c/ToolParam)] -> Str
  (let [(p-name (tool-name-to-json (.-name p)))
        (j-type (map-asl-type-to-json (.-param-type p)))
        (doc (string-replace (.-doc p) "\"" "\\\""))]
    (str "\"" p-name "\": {\"type\": \"" j-type "\", \"description\": \"" doc "\"}")))

(df format-properties [(params (List c/ToolParam))] -> Str
  (let [(props-list (map (fn [(p c/ToolParam)] -> Str (format-param-prop p)) params))]
    (string-join props-list ", ")))

(df extract-required-fields [(params (List c/ToolParam))] -> Str
  (let [(req-params (filter (fn [(p c/ToolParam)] -> Bool (.-required p)) params))
        (req-names (map (fn [(p c/ToolParam)] -> Str (str "\"" (tool-name-to-json (.-name p)) "\"")) req-params))]
    (str "[" (string-join req-names ", ") "]")))

(df tool-to-openai-schema [(tool c/BuiltinTool)] -> OpenAiTool
  :d "Translates ASN BuiltinTool declaration into OpenAI function tool schema."
  (let [(fn-name (tool-name-to-json (.-name tool)))
        (desc (string-replace (.-description tool) "\"" "\\\""))
        (params (.-params tool))
        (props (format-properties params))
        (req (extract-required-fields params))
        (schema (str "{\"type\": \"object\", \"properties\": {" props "}, \"required\": " req "}"))]
    (OpenAiTool
      :tool-type "function"
      :name fn-name
      :description desc
      :parameters-json schema)))

(df tools-to-openai-json [(tools (List c/BuiltinTool))] -> Str
  :d "Generates standard OpenAI tools JSON array from list of ASN tools."
  (let [(schemas (map (fn [(t c/BuiltinTool)] -> OpenAiTool (tool-to-openai-schema t)) tools))
        (entries (map (fn [(s OpenAiTool)] -> Str
                        (str "{\"type\": \"function\", \"function\": {\"name\": \"" (.-name s) "\", \"description\": \"" (.-description s) "\", \"parameters\": " (.-parameters-json s) "}}"))
                      schemas))]
    (str "[" (string-join entries ", ") "]")))

(df format-asn-tool-call [(tool-name Str) (args (List (Pair Str Str)))] -> Str
  :d "Formats tool invocation in canonical ASN S-expression format."
  (let [(args-str (fold (fn [(acc Str) (p (Pair Str Str))] -> Str
                          (str acc ":" (fst p) " \"" (snd p) "\" "))
                        ""
                        args))]
    (str "(:call :tool \"" tool-name "\" " (string-trim args-str) ")")))

(df parse-json-pair [(entry Str)] -> (Option (Pair Str Str))
  :d "Parses a single 'key': value entry from a flat JSON object."
  (let [(colon-idx (string-index-of entry ":"))]
    (mt colon-idx
      ((none) (none))
      ((some idx)
       (let [(raw-k (option-or (string-slice entry 0 idx) ""))
             (raw-v (option-or (string-slice entry (+ idx 1) (string-length entry)) ""))
             (clean-k (json-name-to-tool (string-replace (string-trim raw-k) "\"" "")))
             (trimmed-v (string-trim raw-v))
             (clean-v (if (and (string-starts-with? trimmed-v "\"") (string-ends-with? trimmed-v "\""))
                          (option-or (string-slice trimmed-v 1 (- (string-length trimmed-v) 1)) "")
                          trimmed-v))]
         (if (string-empty? clean-k)
             (none)
             (some (pair clean-k clean-v))))))))

(df parse-json-arguments [(json-str Str)] -> (List (Pair Str Str))
  :d "Parses flat JSON arguments string into a list of key-value argument pairs."
  (let [(trimmed (string-trim json-str))]
    (if (or (string-empty? trimmed) (= trimmed "{}"))
        (list)
        (let [(inner (if (and (string-starts-with? trimmed "{") (string-ends-with? trimmed "}"))
                         (option-or (string-slice trimmed 1 (- (string-length trimmed) 1)) "")
                         trimmed))
              (parts (string-split inner ","))
              (parsed (fold (fn [(acc (List (Pair Str Str))) (part Str)] -> (List (Pair Str Str))
                              (let [(maybe-p (parse-json-pair part))]
                                (mt maybe-p
                                  ((none) acc)
                                  ((some p) (list-append acc (list p))))))
                            (list)
                            parts))]
          (if (list-empty? parsed)
              (list (pair "raw-json" json-str))
              parsed)))))

(df parse-openai-tool-call [(call OpenAiToolCall)] -> c/ToolCall
  :d "Converts model JSON tool-call back into typed ASL ToolCall."
  (let [(canonical-name (json-name-to-tool (.-function-name call)))
        (parsed-args (parse-json-arguments (.-arguments-json call)))]
    (c/ToolCall
      :id (.-id call)
      :tool-name canonical-name
      :arguments parsed-args)))

(df asn-call-to-openai-json [(call c/ToolCall)] -> Str
  :d "Translates internal ASL ToolCall into JSON payload for OpenAI-compatible gateway."
  (let [(fn-name (tool-name-to-json (.-tool-name call)))
        (args (.-arguments call))
        (args-pairs (map (fn [(p (Pair Str Str))] -> Str
                           (str "\"" (tool-name-to-json (fst p)) "\": \"" (string-replace (snd p) "\"" "\\\"") "\""))
                         args))
        (args-inner (string-join args-pairs ", "))
        (args-json (str "{" (string-replace (string-replace args-inner "\\" "\\\\") "\"" "\\\"") "}"))]
    (str "{\"id\": \"" (.-id call) "\", \"type\": \"function\", \"function\": {\"name\": \"" fn-name "\", \"arguments\": \"" args-json "\"}}")))
