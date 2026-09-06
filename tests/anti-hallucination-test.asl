(module asl-harness/tests/anti-hallucination-test
  :d "Unit tests for pure AgentScript Anti-Hallucination FSM Normalizer"
  :x [run-tests]
  :i [(anti_hallucination :a ah)])

(df test-extract-thinking [] -> Bool
  :d "Verifies clean separation of <think>...</think> block from code payload"
  (let [(raw "<think>Analyzing bounds and coordinates</think>(:svg :w 320 :h 320)")
        (res (ah/extract-thinking raw))]
    (and (= (.-thinking res) "Analyzing bounds and coordinates")
         (= (.-code res) "(:svg :w 320 :h 320)"))))

(df test-strip-fences [] -> Bool
  :d "Verifies markdown fences are completely removed"
  (let [(raw "```asn\n(:svg :w 320 :h 320)\n```")
        (res (ah/strip-markdown-fences raw))]
    (= res "(:svg :w 320 :h 320)")))

(df test-strip-js-fences [] -> Bool
  :d "Verifies javascript markdown fences are completely removed"
  (let [(raw "```javascript\nconst x = 1;\n```")
        (res (ah/strip-markdown-fences raw))]
    (= res "const x = 1;")))

(df test-toolcall-kind [] -> Bool
  :d "Verifies toolcall kind classification"
  (let [(rep (ah/repair-and-normalize "(:call :tool \"write\" :path \"index.html\" :content \"<h1>test</h1>\")"))]
    (= (.-tool-kind rep) "html")))

(df test-balance-delimiters [] -> Bool
  :d "Verifies unclosed parentheses are appended to match open count"
  (let [(raw "(:svg :w 320 (:rc :x 0 :y 0")
        (res (ah/balance-delimiters raw))]
    (= res "(:svg :w 320 (:rc :x 0 :y 0))")))

(df test-repair-and-normalize [] -> Bool
  :d "Verifies full end-to-end normalization pipeline"
  (let [(raw "```asn\n<think>Drafting diamond</think>(:svg :w 320 (:rc :x 0\n```")
        (rep (ah/repair-and-normalize raw))]
    (and (.-repaired rep)
         (and (= (.-tool-kind rep) "svg")
              (= (.-thinking rep) "Drafting diamond")))))

(df run-tests [] -> Bool
  :d "Executes all test cases in suite"
  (and (test-extract-thinking)
       (and (test-strip-fences)
            (and (test-strip-js-fences)
                 (and (test-toolcall-kind)
                      (and (test-balance-delimiters)
                           (test-repair-and-normalize)))))))
