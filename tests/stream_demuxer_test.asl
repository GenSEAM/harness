(module asl-harness/stream-demuxer-test
  :d "Unit verification test suite for Universal L7 Gateway Stream Demuxer"
  :x [test-extract-deepseek-think
      test-extract-bracket-thought
      test-content-quarantine-separation
      test-toolcall-normalization
      test-demux-stream-flow
      test-empty-and-bare-streams
      run-tests]
  :i [(stream_demuxer :a demux)])

(df test-extract-deepseek-think [] -> Bool
  :d "Verifies extraction of XML style think tokens e.g. DeepSeek and Kimi 3"
  (let [(raw "<think>Calculating prime factors of 42</think>Answer is 42")
        (q (demux/extract-thought-channel raw))]
    (assert (.-quarantined q) "Quarantined flag must be true for think tags")
    (assert (= (.-thought-tokens q) "Calculating prime factors of 42") "Thought tokens must match exactly")
    (assert (> (.-token-count q) 0) "Token count must be strictly positive")
    true))

(df test-extract-bracket-thought [] -> Bool
  :d "Verifies extraction of bracket style thoughts e.g. [THOUGHT]...[/THOUGHT]"
  (let [(raw "[THOUGHT]Reviewing security constraints[/THOUGHT]Deploy completed")
        (q (demux/extract-thought-channel raw))]
    (assert (.-quarantined q) "Quarantined flag must be true for bracket thoughts")
    (assert (= (.-thought-tokens q) "Reviewing security constraints") "Thought tokens must match")
    (assert (> (.-token-count q) 0) "Token count must be positive")
    true))

(df test-content-quarantine-separation [] -> Bool
  :d "Verifies clean separation of action content without thought leakage"
  (let [(raw1 "<think>internal reasoning</think>Final user output")
        (raw2 "[THOUGHT]planning step[/THOUGHT]action payload")
        (c1 (demux/extract-content-channel raw1))
        (c2 (demux/extract-content-channel raw2))]
    (assert (= c1 "Final user output") "Content 1 must not contain think tags")
    (assert (not (string-contains? c1 "internal reasoning")) "Content 1 must quarantine thoughts")
    (assert (= c2 "action payload") "Content 2 must not contain thought tags")
    (assert (not (string-contains? c2 "planning step")) "Content 2 must quarantine thoughts")
    true))

(df test-toolcall-normalization [] -> Bool
  :d "Verifies conversion of JSON tool calls into ASN S-expressions"
  (let [(json-call "{\"name:\": \"read_file\", \"arguments:\": [\"foo.txt\"]}")
        (asn-call "(:call :tool \"read_file\" :args [\"foo.txt\"])")
        (norm-json (demux/normalize-toolcall-output json-call))
        (norm-asn (demux/normalize-toolcall-output asn-call))]
    (assert (string-starts-with? norm-json "(:call") "Normalized JSON must start with :call")
    (assert (string-contains? norm-json ":tool") "Normalized JSON must contain :tool keyword")
    (assert (= norm-asn asn-call) "Pure ASN toolcall must remain unchanged")
    true))

(df test-demux-stream-flow [] -> Bool
  :d "Verifies end-to-end stream demuxing pipeline across diverse model configs"
  (let [(d1 (demux/make-stream-demuxer "kimi-3" true true))
        (d2 (demux/make-stream-demuxer "gpt-4o" false true))
        (raw "<think>need to check file</think>(:call :tool \"check\" :args [\"src\"])")
        (r1 (demux/demux-llm-stream d1 raw))
        (r2 (demux/demux-llm-stream d2 raw))]
    (assert (= (.-model-family r1) "kimi-3") "Model family 1 must be kimi-3")
    (assert (= (.-model-family r2) "gpt-4o") "Model family 2 must be gpt-4o")
    (assert (.-has-toolcall r1) "Result 1 must identify tool call")
    (assert (.-has-toolcall r2) "Result 2 must identify tool call")
    (assert (.-quarantined (.-quarantine r1)) "Result 1 must have quarantined thoughts")
    (assert (not (string-contains? (.-content r1) "<think>")) "Stripped result must not have think tags")
    (assert (string-contains? (.-content r2) "<think>") "Unstripped result must retain raw content")
    true))

(df test-empty-and-bare-streams [] -> Bool
  :d "Verifies edge cases including empty strings and bare responses"
  (let [(d (demux/make-stream-demuxer "gemini-flash" true true))
        (r-empty (demux/demux-llm-stream d ""))
        (r-bare (demux/demux-llm-stream d "Hello world plain response"))]
    (assert (= (.-content r-empty) "") "Empty stream produces empty content")
    (assert (not (.-quarantined (.-quarantine r-empty))) "Empty stream has unquarantined thoughts")
    (assert (= (.-content r-bare) "Hello world plain response") "Bare stream preserves response")
    (assert (not (.-quarantined (.-quarantine r-bare))) "Bare stream has no thinking tokens")
    (assert (not (.-has-toolcall r-bare)) "Bare stream has no tool calls")
    true))

(df run-tests [] -> Bool
  :d "Executes all stream demuxer test cases"
  (and (test-extract-deepseek-think)
       (and (test-extract-bracket-thought)
            (and (test-content-quarantine-separation)
                 (and (test-toolcall-normalization)
                      (and (test-demux-stream-flow)
                           (test-empty-and-bare-streams)))))))
