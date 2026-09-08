(module asl-harness/llm-protocol-test
  :d "Unit verification test suite for canonical ASL LLM Protocol engine"
  :x [test-protocol-envelope-formatting-and-token-bounds
      test-protocol-response-delta-and-field-extraction
      test-rejection-markdown-code-fences
      test-rejection-conversational-fillers
      test-rejection-malformed-and-empty-inputs
      run-tests]
  :i [(llm_protocol :a proto)])

(df test-protocol-envelope-formatting-and-token-bounds [] -> Bool
  :d "Verifies protocol envelope formatting, token bounds, schema declaration, and delimiter balance"
  (let [(cfg-default (proto/LLMProtocolConfig
                       :model "claude-3-7-sonnet"
                       :position "postamble"
                       :target-tokens 120
                       :system-prompt "ASL Coding Agent"
                       :schema-mode "strict-asn"))
        (cfg-preamble (proto/LLMProtocolConfig
                        :model "gemma-4-31b-it"
                        :position "preamble"
                        :target-tokens 120
                        :system-prompt "ASL Coding Agent"
                        :schema-mode "compact-s-expr"))
        (cfg-system (proto/LLMProtocolConfig
                      :model "qwen-2.5-32b-instruct"
                      :position "system"
                      :target-tokens 120
                      :system-prompt "ASL Coding Agent"
                      :schema-mode "strict-asn"))
        (env-default (proto/format-protocol-envelope cfg-default))
        (env-preamble (proto/format-protocol-envelope cfg-preamble))
        (env-system (proto/format-protocol-envelope cfg-system))]
    (do
      (assert (<= (+ (/ (string-length env-default) 3) 1) 120) "Default envelope token count must be <= 120 tokens")
      (assert (<= (+ (/ (string-length env-preamble) 3) 1) 120) "Preamble envelope token count must be <= 120 tokens")
      (assert (<= (+ (/ (string-length env-system) 3) 1) 120) "System envelope token count must be <= 120 tokens")
      (assert (string-contains? env-default "(:schema (:intent :refs :markers :delta :state :d))") "Envelope must contain canonical schema declaration")
      (assert (string-contains? env-default "(:rules [:no-fences :pure-asn :dense-deltas])") "Envelope must specify strict rejection rules")
      (assert (and (string-starts-with? env-default "(") (string-ends-with? env-default ")")) "Envelope must have balanced outer delimiters")
      true)))

(df test-protocol-response-delta-and-field-extraction [] -> Bool
  :d "Verifies delta payload preservation and envelope field extraction from valid response"
  (let [(raw "(:envelope :intent \"patch-vfs\" :refs [\"mem/src/vfs.asl\"] :markers [\"M1_START\" \"M1_END\"] :delta \"(:replace :start 10 :end 15 :content \\\"...\\\")\" :state \"ok\" :d \"applied clean patch\")")
        (parsed (proto/parse-protocol-response raw))]
    (do
      (assert (.-valid parsed) "Valid protocol response must have valid flag true")
      (assert (= (.-error-code parsed) "") "Valid protocol response must have empty error code")
      (assert (= (.-intent parsed) "patch-vfs") "Extracted intent must equal patch-vfs")
      (assert (list-contains? (.-refs parsed) "mem/src/vfs.asl") "Extracted refs must contain target file reference")
      (assert (string-contains? (.-delta parsed) ":replace :start 10 :end 15") "Extracted delta must preserve atomic replacement payload")
      (assert (= (.-state parsed) "ok") "Extracted state must equal ok")
      true)))

(df test-rejection-markdown-code-fences [] -> Bool
  :d "Verifies strict rejection of markdown code fences and backticks"
  (let [(fenced-asn "```asn\n(:envelope :intent \"patch-vfs\" :state \"ok\")\n```")
        (fenced-lisp "```lisp\n(:envelope :intent \"patch-vfs\" :state \"ok\")\n```")
        (fenced-clojure "```clojure\n(:envelope :intent \"patch-vfs\" :state \"ok\")\n```")
        (trailing-fence "(:envelope :intent \"patch-vfs\" :state \"ok\")```")
        (embedded-fence "(:envelope :intent `patch-vfs` :state \"ok\")")
        (p-asn (proto/parse-protocol-response fenced-asn))
        (p-lisp (proto/parse-protocol-response fenced-lisp))
        (p-clj (proto/parse-protocol-response fenced-clojure))
        (p-trail (proto/parse-protocol-response trailing-fence))
        (p-embed (proto/parse-protocol-response embedded-fence))]
    (do
      (assert (and (not (.-valid p-asn)) (= (.-error-code p-asn) "ERR_MARKDOWN_FENCE")) "ASN code fence must be rejected with ERR_MARKDOWN_FENCE")
      (assert (and (not (.-valid p-lisp)) (= (.-error-code p-lisp) "ERR_MARKDOWN_FENCE")) "Lisp code fence must be rejected with ERR_MARKDOWN_FENCE")
      (assert (and (not (.-valid p-clj)) (= (.-error-code p-clj) "ERR_MARKDOWN_FENCE")) "Clojure code fence must be rejected with ERR_MARKDOWN_FENCE")
      (assert (and (not (.-valid p-trail)) (= (.-error-code p-trail) "ERR_MARKDOWN_FENCE")) "Trailing backtick fence must be rejected with ERR_MARKDOWN_FENCE")
      (assert (and (not (.-valid p-embed)) (= (.-error-code p-embed) "ERR_MARKDOWN_FENCE")) "Embedded backtick fence must be rejected with ERR_MARKDOWN_FENCE")
      (assert (string-empty? (.-delta p-asn)) "Fenced output delta must not be extracted or executed")
      true)))

(df test-rejection-conversational-fillers [] -> Bool
  :d "Verifies strict rejection of conversational filler prefixes"
  (let [(p1 (proto/parse-protocol-response "Sure, here is the protocol response: (:envelope :intent \"test\")"))
        (p2 (proto/parse-protocol-response "Certainly! I have executed the task."))
        (p3 (proto/parse-protocol-response "Here's the plan: (:envelope :intent \"test\")"))
        (p4 (proto/parse-protocol-response "I will now generate the patch."))
        (p5 (proto/parse-protocol-response "I'd be happy to help with that."))]
    (do
      (assert (and (not (.-valid p1)) (= (.-error-code p1) "ERR_CONVERSATIONAL_FILLER")) "Sure prefix must be rejected with ERR_CONVERSATIONAL_FILLER")
      (assert (and (not (.-valid p2)) (= (.-error-code p2) "ERR_CONVERSATIONAL_FILLER")) "Certainly prefix must be rejected with ERR_CONVERSATIONAL_FILLER")
      (assert (and (not (.-valid p3)) (= (.-error-code p3) "ERR_CONVERSATIONAL_FILLER")) "Heres the plan prefix must be rejected with ERR_CONVERSATIONAL_FILLER")
      (assert (and (not (.-valid p4)) (= (.-error-code p4) "ERR_CONVERSATIONAL_FILLER")) "I will now prefix must be rejected with ERR_CONVERSATIONAL_FILLER")
      (assert (and (not (.-valid p5)) (= (.-error-code p5) "ERR_CONVERSATIONAL_FILLER")) "Id be happy prefix must be rejected with ERR_CONVERSATIONAL_FILLER")
      true)))

(df test-rejection-malformed-and-empty-inputs [] -> Bool
  :d "Verifies rejection of empty, whitespace-only, unbalanced, and truncated payloads"
  (let [(cfg (proto/LLMProtocolConfig
               :model "claude-3-7-sonnet"
               :position "postamble"
               :target-tokens 120
               :system-prompt "ASL"
               :schema-mode "strict-asn"))
        (p-empty (proto/parse-protocol-response ""))
        (p-ws (proto/parse-protocol-response "   \n\t  "))
        (p-unbalanced (proto/parse-protocol-response "(:envelope :intent \"test\""))
        (p-trunc (proto/parse-protocol-response "(:envelope :intent \"truncated"))
        (env (proto/format-protocol-envelope cfg))]
    (do
      (assert (and (not (.-valid p-empty)) (= (.-error-code p-empty) "ERR_EMPTY_PAYLOAD")) "Empty string must be rejected with ERR_EMPTY_PAYLOAD")
      (assert (and (not (.-valid p-ws)) (= (.-error-code p-ws) "ERR_EMPTY_PAYLOAD")) "Whitespace string must be rejected with ERR_EMPTY_PAYLOAD")
      (assert (and (not (.-valid p-unbalanced)) (= (.-error-code p-unbalanced) "ERR_UNBALANCED_DELIMITERS")) "Unbalanced parens must be rejected with ERR_UNBALANCED_DELIMITERS")
      (assert (not (.-valid p-trunc)) "Truncated string must be marked invalid")
      (assert (<= (+ (/ (string-length env) 3) 1) 150) "All protocol envelope formats must remain strictly <= 150 tokens")
      true)))

(df run-tests [] -> Bool
  :d "Aggregates and executes all LLM protocol unit test functions"
  (and (test-protocol-envelope-formatting-and-token-bounds)
       (and (test-protocol-response-delta-and-field-extraction)
            (and (test-rejection-markdown-code-fences)
                 (and (test-rejection-conversational-fillers)
                      (test-rejection-malformed-and-empty-inputs))))))
