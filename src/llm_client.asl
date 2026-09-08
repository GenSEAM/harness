(module asl-harness/llm-client
  :d "Unified LLM model request formatter, response parser, and GBNF grammar constraint compiler"
  :x [ModelOptions
      CompletionResult
      make-default-options
      format-model-request
      parse-model-response
      compile-asn-grammar-constraint
      calculate-tok-sec]
  :i [])

(dfs ModelOptions
  (:f model Str "Target model identifier e.g. gemma-4-31b-it or claude-3-7-sonnet")
  (:f temperature F64 "Sampling temperature for generation")
  (:f max-tokens I64 "Token budget limit for output generation")
  (:f system Str "System instructions or persona prompt")
  (:f grammar-constraint (Option Str) "Optional GBNF grammar rule or schema specification"))

(dfs CompletionResult
  (:f text Str "Completion content text")
  (:f input-tokens I64 "Prompt tokens evaluated")
  (:f output-tokens I64 "Completion tokens generated")
  (:f duration-ms I64 "Execution duration in milliseconds")
  (:f tok-sec F64 "Generation throughput in tokens per second"))

(df make-default-options [(model Str)] -> ModelOptions
  :d "Instantiates ModelOptions with standard defaults for sampling, tokens, and grammar"
  (ModelOptions
    :model model
    :temperature 0.2
    :max-tokens 4096
    :system ""
    :grammar-constraint (none)))

(df calculate-tok-sec [(output-tokens I64) (duration-ms I64)] -> F64
  :d "Computes throughput speed safely guarding against zero or negative duration"
  (if (<= duration-ms 0)
      0.0
      (/ (* (int64-to-float64 output-tokens) 1000.0) (int64-to-float64 duration-ms))))

(df format-model-request [(opts ModelOptions) (prompt Str)] -> Str
  :d "Serializes model options and prompt into provider-compatible JSON payload"
  (let [(grammar-part (mt (.-grammar-constraint opts)
                        ((some g) (str ", \"grammar\": \"" g "\""))
                        ((none) "")))]
    (str "{\"model\": \"" (.-model opts) "\", \"temperature\": " (string-from-float64 (.-temperature opts)) ", \"max_tokens\": " (string-from-int64 (.-max-tokens opts)) ", \"system\": \"" (.-system opts) "\", \"prompt\": \"" prompt "\"" grammar-part "}")))

(df extract-first-digits [(chars (List Str)) (acc Str)] -> Str
  :d "Extracts consecutive digits from character list"
  (if (list-empty? chars)
      acc
      (let [(c (option-or (list-head chars) ""))
            (rst (option-or (list-tail chars) (list)))]
        (if (string-contains? "0123456789" c)
            (extract-first-digits rst (str acc c))
            (if (string-empty? acc)
                (if (or (= c " ") (or (= c ":") (or (= c "\t") (= c "\n"))))
                    (extract-first-digits rst "")
                    acc)
                acc)))))

(df extract-int-by-key [(raw Str) (key Str)] -> I64
  :d "Extracts integer value associated with key in JSON or ASN string"
  (let [(idx-opt (string-index-of raw key))]
    (mt idx-opt
      ((some idx)
       (let [(tail-opt (string-slice raw (+ idx (string-length key)) (string-length raw)))
             (tail (option-or tail-opt ""))
             (digits (extract-first-digits (string-chars tail) ""))]
         (option-or (string-to-int64 digits) 0)))
      ((none) 0))))

(df extract-str-by-key [(raw Str) (key Str)] -> Str
  :d "Extracts quoted string value associated with key"
  (let [(idx-opt (string-index-of raw key))]
    (mt idx-opt
      ((some idx)
       (let [(tail-opt (string-slice raw (+ idx (string-length key)) (string-length raw)))
             (tail (option-or tail-opt ""))
             (q1-opt (string-index-of tail "\""))]
         (mt q1-opt
           ((some q1)
            (let [(rest-opt (string-slice tail (+ q1 1) (string-length tail)))
                  (rest-str (option-or rest-opt ""))
                  (q2-opt (string-index-of rest-str "\""))]
              (mt q2-opt
                ((some q2)
                 (option-or (string-slice rest-str 0 q2) ""))
                ((none) ""))))
           ((none) ""))))
      ((none) ""))))

(df parse-model-response [(raw Str) (duration-ms I64)] -> CompletionResult
  :d "Extracts response completion text and token counts, computing throughput tok-sec"
  (let [(txt-json (extract-str-by-key raw "\"text\""))
        (txt-content (if (string-empty? txt-json) (extract-str-by-key raw "\"content\"") txt-json))
        (txt-asn (if (string-empty? txt-content) (extract-str-by-key raw ":text") txt-content))
        (final-text (if (string-empty? txt-asn) raw txt-asn))
        (in-tok-1 (extract-int-by-key raw "\"prompt_tokens\""))
        (in-tok-2 (if (= in-tok-1 0) (extract-int-by-key raw "\"input_tokens\"") in-tok-1))
        (final-in (if (= in-tok-2 0) (extract-int-by-key raw ":input-tokens") in-tok-2))
        (out-tok-1 (extract-int-by-key raw "\"completion_tokens\""))
        (out-tok-2 (if (= out-tok-1 0) (extract-int-by-key raw "\"output_tokens\"") out-tok-1))
        (final-out (if (= out-tok-2 0) (extract-int-by-key raw ":output-tokens") out-tok-2))
        (speed (calculate-tok-sec final-out duration-ms))]
    (CompletionResult
      :text final-text
      :input-tokens final-in
      :output-tokens final-out
      :duration-ms duration-ms
      :tok-sec speed)))

(df compile-asn-grammar-constraint [(schema-spec Str)] -> (Option Str)
  :d "Compiles target ASN schema into strict GBNF grammar constraint string"
  (let [(trimmed (string-trim schema-spec))]
    (if (string-empty? trimmed)
        (none)
        (some "root ::= \"(\" ws [a-zA-Z0-9_-]+ (ws \":\" [a-zA-Z0-9_-]+ ws value)* ws \")\"\nvalue ::= string | number | symbol | list\nstring ::= \"\\\"\" [^\\\"]* \"\\\"\"\nnumber ::= [0-9]+\nsymbol ::= [a-zA-Z0-9_-]+\nlist ::= \"[\" (ws value)* ws \"]\"\nws ::= [ \\t\\n\\r]*"))))
