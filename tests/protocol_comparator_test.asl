(module asl-harness/tests/protocol-comparator-test
  :d "Unit verification suite for Condition A Markdown vs Condition B Pure ASN protocol comparator."
  :x [test-protocol-profile-construction
      test-measure-protocol-tokens
      test-compare-protocol-efficiency
      test-format-protocol-comparison
      test-protocol-efficiency-ab-simulation
      run-tests]
  :i [(protocol_comparator :a pc)
      (asn_protocol_agent :a apa)])

(df test-protocol-profile-construction [] -> Bool
  :d "Verifies ProtocolProfile record construction and field values."
  (let [(p-a (pc/ProtocolProfile
               :name "condition-a-markdown"
               :prompt-tokens 1200
               :completion-tokens 800
               :parse-errors 15))
        (p-b (pc/ProtocolProfile
               :name "condition-b-asn"
               :prompt-tokens 500
               :completion-tokens 350
               :parse-errors 0))]
    (do
      (assert (= (.-name p-a) "condition-a-markdown") "Condition A name must match")
      (assert (= (.-prompt-tokens p-a) 1200) "Condition A prompt tokens must equal 1200")
      (assert (= (.-completion-tokens p-a) 800) "Condition A completion tokens must equal 800")
      (assert (= (.-parse-errors p-a) 15) "Condition A parse errors must equal 15")
      (assert (= (.-name p-b) "condition-b-asn") "Condition B name must match")
      (assert (= (.-parse-errors p-b) 0) "Condition B parse errors must be zero")
      true)))

(df test-measure-protocol-tokens [] -> Bool
  :d "Verifies token measurement estimation across empty, short, and realistic strings."
  (let [(tok-empty (pc/measure-protocol-tokens ""))
        (tok-short (pc/measure-protocol-tokens "(:call)"))
        (tok-20 (pc/measure-protocol-tokens "12345678901234567890"))
        (tok-100 (pc/measure-protocol-tokens "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890"))
        (tok-asn-call (pc/measure-protocol-tokens "(:call :id \"c1\" :tool \"read_file\" :args [\"test.txt\"])"))
        (tok-md-call (pc/measure-protocol-tokens "```json\n{\n  \"function\": \"read_file\",\n  \"arguments\": {\"path\": \"test.txt\"}\n}\n```"))]
    (do
      (assert (= tok-empty 0) "Empty string must yield zero tokens")
      (assert (> tok-short 0) "Short string must yield positive tokens")
      (assert (= tok-20 5) "20-char string must yield 5 tokens")
      (assert (= tok-100 25) "100-char string must yield 25 tokens")
      (assert (> tok-asn-call 0) "ASN call token count must be positive")
      (assert (> tok-md-call tok-asn-call) "Markdown JSON tool call must consume more tokens than compact ASN")
      true)))

(df test-compare-protocol-efficiency [] -> Bool
  :d "Verifies efficiency comparison metrics calculation for tokens and parse errors."
  (let [(p-a (pc/ProtocolProfile
               :name "cond-a"
               :prompt-tokens 1000
               :completion-tokens 1000
               :parse-errors 20))
        (p-b (pc/ProtocolProfile
               :name "cond-b"
               :prompt-tokens 500
               :completion-tokens 500
               :parse-errors 0))
        (m (pc/compare-protocol-efficiency p-a p-b))
        (p-empty-a (pc/ProtocolProfile :name "ea" :prompt-tokens 0 :completion-tokens 0 :parse-errors 0))
        (p-empty-b (pc/ProtocolProfile :name "eb" :prompt-tokens 0 :completion-tokens 0 :parse-errors 0))
        (m-zero (pc/compare-protocol-efficiency p-empty-a p-empty-b))]
    (do
      (assert (= (.-condition-a-tokens m) 2000) "Condition A tokens must equal 2000")
      (assert (= (.-condition-b-tokens m) 1000) "Condition B tokens must equal 1000")
      (assert (= (.-token-savings-pct m) 50.0) "Token savings must equal 50.0 percent")
      (assert (= (.-error-reduction-pct m) 100.0) "Error reduction must equal 100.0 percent")
      (assert (= (.-token-savings-pct m-zero) 0.0) "Zero baseline token savings must equal 0.0")
      (assert (= (.-error-reduction-pct m-zero) 0.0) "Zero baseline error reduction must equal 0.0")
      true)))

(df test-format-protocol-comparison [] -> Bool
  :d "Verifies formatting of ProtocolBenchmarkReport into structured ASN representation."
  (let [(metrics (pc/ComparisonMetrics
                   :condition-a-tokens 24000
                   :condition-b-tokens 11000
                   :token-savings-pct 54.16
                   :error-reduction-pct 100.0))
        (report (pc/ProtocolBenchmarkReport
                  :benchmark-id "tb4-ab-test-battery"
                  :task-count 10
                  :metrics metrics
                  :recommendation "Deploy Condition B pure ASN protocol in production"))
        (formatted (pc/format-protocol-comparison report))]
    (do
      (assert (string-contains? formatted "(:protocol-comparison") "Report must begin with (:protocol-comparison")
      (assert (string-contains? formatted ":benchmark-id \"tb4-ab-test-battery\"") "Report must embed benchmark id")
      (assert (string-contains? formatted ":task-count 10") "Report must embed task count")
      (assert (string-contains? formatted ":condition-a-tokens 24000") "Report must embed condition a tokens")
      (assert (string-contains? formatted ":condition-b-tokens 11000") "Report must embed condition b tokens")
      (assert (string-contains? formatted ":recommendation \"Deploy Condition B pure ASN protocol in production\"") "Report must embed recommendation")
      true)))

(df test-protocol-efficiency-ab-simulation [] -> Bool
  :d "Verifies end-to-end integration with AsnAgentState and empirical protocol compaction measurement."
  (let [(st (apa/AsnAgentState
              :session-id "sess-sim-1"
              :turns 3
              :context (list "goal: resolve terminal bench challenge" "analyzing repository structure" "diagnosed failure point")
              :active-tools (list "run_command" "view_file" "replace_file_content")))
        (tools (list (apa/AsnToolDefinition :name "run_command" :desc "Run shell command" :params (list "CommandLine" "Cwd"))
                     (apa/AsnToolDefinition :name "view_file" :desc "View file content" :params (list "AbsolutePath" "StartLine"))))
        (asn-prompt (apa/format-asn-agent-prompt st tools))
        (asn-tok (pc/measure-protocol-tokens asn-prompt))
        (md-prompt "System: You are an autonomous coding assistant.\nAvailable tools:\n```json\n[{\"name\":\"run_command\",\"description\":\"Run shell command\",\"parameters\":{\"CommandLine\":\"string\",\"Cwd\":\"string\"}},{\"name\":\"view_file\",\"description\":\"View file content\",\"parameters\":{\"AbsolutePath\":\"string\",\"StartLine\":\"integer\"}}]\n```\nContext:\n- goal: resolve terminal bench challenge\n- analyzing repository structure\n- diagnosed failure point\nTurn: 3\nActive tools: [\"run_command\", \"view_file\", \"replace_file_content\"]\nPlease provide your response in Markdown with JSON tool calls inside ```json code blocks.")
        (md-tok (pc/measure-protocol-tokens md-prompt))
        (prof-a (pc/ProtocolProfile :name "md-json" :prompt-tokens md-tok :completion-tokens 100 :parse-errors 4))
        (prof-b (pc/ProtocolProfile :name "pure-asn" :prompt-tokens asn-tok :completion-tokens 50 :parse-errors 0))
        (res (pc/compare-protocol-efficiency prof-a prof-b))]
    (do
      (assert (> md-tok asn-tok) "Markdown prompt tokens must exceed pure ASN prompt tokens")
      (assert (> (.-token-savings-pct res) 30.0) "Empirical token savings must exceed 30 percent")
      (assert (= (.-error-reduction-pct res) 100.0) "Error reduction must equal 100 percent")
      (assert (> (.-condition-a-tokens res) (.-condition-b-tokens res)) "Condition A total tokens must exceed Condition B")
      (assert (> asn-tok 0) "ASN token measurement must be positive")
      (assert (> md-tok 0) "Markdown token measurement must be positive")
      true)))

(df run-tests [] -> Bool
  :d "Executes full protocol comparator unit test battery."
  (and (test-protocol-profile-construction)
       (and (test-measure-protocol-tokens)
            (and (test-compare-protocol-efficiency)
                 (and (test-format-protocol-comparison)
                      (test-protocol-efficiency-ab-simulation))))))
