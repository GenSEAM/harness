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

(df tool-to-openai-schema [(tool c/BuiltinTool)] -> OpenAiTool
  :d "Translates ASN BuiltinTool declaration into OpenAI function tool schema."
  (let [(fn-name (tool-name-to-json (.-name tool)))
        (desc (.-description tool))
        (params (.-params tool))
        (props (fold (fn [(acc Str) (p c/ToolParam)] -> Str
                       (str acc "\"" (.-name p) "\": {\"type\": \"string\", \"description\": \"" (.-doc p) "\"}, "))
                     ""
                     params))
        (schema (str "{\"type\": \"object\", \"properties\": {" props "}, \"required\": []}"))]
    (OpenAiTool
      :tool-type "function"
      :name fn-name
      :description desc
      :parameters-json schema)))

(df tools-to-openai-json [(tools (List c/BuiltinTool))] -> Str
  :d "Generates standard OpenAI tools JSON array from list of ASN tools."
  (let [(schemas (map (fn [(t c/BuiltinTool)] -> OpenAiTool (tool-to-openai-schema t)) tools))
        (body (fold (fn [(acc Str) (s OpenAiTool)] -> Str
                      (str acc "{\"type\": \"function\", \"function\": {\"name\": \"" (.-name s) "\", \"description\": \"" (.-description s) "\", \"parameters\": " (.-parameters-json s) "}}, "))
                    ""
                    schemas))]
    (str "[" body "]")))

(df format-asn-tool-call [(tool-name Str) (args (List (Pair Str Str)))] -> Str
  :d "Formats tool invocation in canonical ASN S-expression format."
  (let [(args-str (fold (fn [(acc Str) (p (Pair Str Str))] -> Str
                          (str acc ":" (fst p) " \"" (snd p) "\" "))
                        ""
                        args))]
    (str "(:call :tool \"" tool-name "\" " args-str ")")))

(df parse-openai-tool-call [(call OpenAiToolCall)] -> c/ToolCall
  :d "Converts model JSON tool-call back into typed ASL ToolCall."
  (let [(canonical-name (json-name-to-tool (.-function-name call)))]
    (c/ToolCall
      :id (.-id call)
      :tool-name canonical-name
      :arguments (list (pair "raw-json" (.-arguments-json call))))))

(df asn-call-to-openai-json [(call c/ToolCall)] -> Str
  :d "Translates internal ASL ToolCall into JSON payload for OpenAI-compatible gateway."
  (let [(fn-name (tool-name-to-json (.-tool-name call)))
        (args-json (fold (fn [(acc Str) (p (Pair Str Str))] -> Str
                           (str acc "\"" (fst p) "\": \"" (snd p) "\", "))
                         "{"
                         (.-arguments call)))]
    (str "{\"id\": \"" (.-id call) "\", \"type\": \"function\", \"function\": {\"name\": \"" fn-name "\", \"arguments\": \"" args-json "}\"}}")))
