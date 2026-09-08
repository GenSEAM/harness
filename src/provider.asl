(module asl-harness/provider
  :d "OpenAI-Compatible LLM Gateway Provider with tool-calling for Gemma 31B."
  :x [OpenAiConfig ChatMessage ProviderResponse
      default-gateway-config make-message build-request-payload parse-model-response]
  :i [(coding :a c) (toolcall :a tc)])

(dfs OpenAiConfig
  (:f api-key Str "Bearer authorization token")
  (:f base-url Str "Gateway endpoint URL")
  (:f model Str "Default model identifier")
  (:f temperature F64 "Sampling temperature")
  (:f max-tokens I64 "Token budget limit"))

(dfs ChatMessage
  (:f role Str "system | user | assistant | tool")
  (:f content Str "Text content")
  (:f tool-call-id Str "Optional reference to tool invocation"))

(dfs ProviderResponse
  (:f text Str "Completion message content")
  (:f tool-calls (List c/ToolCall) "Parsed tool calls if requested")
  (:f finish-reason Str "stop | tool_calls | length"))

(df default-gateway-config [] -> OpenAiConfig
  :d "Constructs default LLM Gateway configuration pointed at http://127.0.0.1:8765/v1 for Gemma 31B."
  (OpenAiConfig
    :api-key ""
    :base-url "http://127.0.0.1:8765/v1"
    :model "gemma-4-31b-it"
    :temperature 0.2
    :max-tokens 4096))

(df make-message [(role Str) (content Str)] -> ChatMessage
  :d "Constructs a simple chat message without tool reference."
  (ChatMessage :role role :content content :tool-call-id ""))

(df build-request-payload [(cfg OpenAiConfig) (messages (List ChatMessage)) (tools (List c/BuiltinTool))] -> Str
  :d "Serializes request body into standard JSON payload for OpenAI-compatible endpoint."
  (let [(msgs-json (fold (fn [(acc Str) (m ChatMessage)] -> Str
                           (str acc "{\"role\": \"" (.-role m) "\", \"content\": \"" (.-content m) "\"}, "))
                         ""
                         messages))
        (tools-json (tc/tools-to-openai-json tools))]
    (str "{\"model\": \"" (.-model cfg) "\", \"messages\": [" msgs-json "], \"tools\": " tools-json ", \"temperature\": 0.2}")))

(df parse-model-response [(raw-content Str) (has-tools Bool)] -> ProviderResponse
  :d "Parses model output payload into normalized ProviderResponse structure with reasoning quarantine."
  (let [(idx-open (string-index-of raw-content "<think>"))
        (idx-close (string-index-of raw-content "</think>"))]
    (let [(clean-text (mt idx-open
                        ((none) raw-content)
                        ((some o)
                         (mt idx-close
                           ((none) (option-or (string-slice raw-content 0 o) ""))
                           ((some c)
                            (let [(prefix (option-or (string-slice raw-content 0 o) ""))
                                  (suffix (option-or (string-slice raw-content (+ c 8) (string-length raw-content)) ""))]
                              (string-trim (str prefix " " suffix))))))))]
      (let [(lower (string-lower clean-text))
            (is-esh (or (string-contains? lower "all tests pass")
                        (or (string-contains? lower "all tests passed")
                            (or (string-contains? lower "i have run the tests and they pass")
                                (string-contains? lower "tests are passing")))))]
        (if is-esh
            (ProviderResponse
              :text clean-text
              :tool-calls (list)
              :finish-reason "esh_rejected")
            (ProviderResponse
              :text clean-text
              :tool-calls (list)
              :finish-reason "stop"))))))

