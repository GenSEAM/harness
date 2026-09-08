(module asl-harness/test
  :d "Unit tests for anti-hallucination grounding, proxy firewall, and cache in ASL"
  :x [test-adapter-name
      test-valid-grounding
      test-hallucinated-quote
      test-missing-doc
      test-namespace-cache
      test-proxy-firewall-action
      run-tests]
  :i [(core :a core) (grounding :a gr) (proxy :a px) (harness :a h)])

(df sample-doc [] -> core/SourceDocument
  :d "Creates a sample source document for testing."
  (core/make-source-document
    "doc-core-spec"
    "https://example.com/spec"
    "AgentScript compiles to WebAssembly and executes sandboxed in 0.04ms with zero host leaks."
    1725400000))

(df test-adapter-name [] -> Bool
  :d "Verifies adapter name resolution."
  (do
    (assert (= (h/get-adapter-name (h/code)) "Code Engine") "Code engine adapter name must match")
    (assert (= (h/get-adapter-name (h/browser)) "Browser Agent") "Browser adapter name must match")
    (assert (= (h/get-adapter-name (h/computer-use)) "Computer-Use Controller") "Computer use adapter name must match")
    (assert (= (h/get-adapter-name (h/chat)) "Chat RAG Assistant") "Chat adapter name must match")
    true))

(df test-valid-grounding [] -> Bool
  :d "Verifies that an exact verbatim quote verifies successfully."
  (let [(doc (sample-doc))
        (cit (core/ClaimCitation
               :claim-text "AgentScript runs in 0.04ms"
               :doc-id "doc-core-spec"
               :exact-quote "executes sandboxed in 0.04ms"
               :confidence 0.95))
        (res (gr/verify-citation (list doc) cit))]
    (do
      (assert (.-verified res) "Verbatim quote citation must be verified")
      (assert (string-empty? (.-failure-reason res)) "Failure reason must be empty on valid grounding")
      true)))

(df test-hallucinated-quote [] -> Bool
  :d "Verifies that a fabricated quote is rejected by grounding firewall."
  (let [(doc (sample-doc))
        (cit (core/ClaimCitation
               :claim-text "AgentScript has Python dependencies"
               :doc-id "doc-core-spec"
               :exact-quote "requires python runtime on client"
               :confidence 0.90))
        (res (gr/verify-citation (list doc) cit))]
    (do
      (assert (not (.-verified res)) "Fabricated quote must not be verified")
      (assert (string-contains? (.-failure-reason res) "Exact quote not found") "Failure reason must indicate quote not found")
      true)))

(df test-missing-doc [] -> Bool
  :d "Verifies rejection when source document is absent."
  (let [(doc (sample-doc))
        (cit (core/ClaimCitation
               :claim-text "Some assertion"
               :doc-id "unknown-doc"
               :exact-quote "something"
               :confidence 0.90))
        (res (gr/verify-citation (list doc) cit))]
    (do
      (assert (not (.-verified res)) "Missing document citation must not be verified")
      (assert (string-contains? (.-failure-reason res) "Source document not found") "Failure reason must indicate document not found")
      true)))

(df test-namespace-cache [] -> Bool
  :d "Verifies namespace isolation in prompt cache."
  (let [(p0 (px/init-proxy))
        (p1 (px/store-cache p0 "agent-alpha" "prompt-1" "response-alpha"))
        (p2 (px/store-cache p1 "agent-beta" "prompt-1" "response-beta"))]
    (let [(val-alpha (px/lookup-cache p2 "agent-alpha" "prompt-1"))
          (val-beta (px/lookup-cache p2 "agent-beta" "prompt-1"))
          (val-gamma (px/lookup-cache p2 "agent-gamma" "prompt-1"))]
      (do
        (assert (mt val-alpha ((none) false) ((some v) (= v "response-alpha"))) "Alpha namespace cache hit")
        (assert (mt val-beta ((none) false) ((some v) (= v "response-beta"))) "Beta namespace cache hit")
        (assert (mt val-gamma ((none) true) ((some _) false)) "Gamma namespace cache miss")
        true))))

(df test-proxy-firewall-action [] -> Bool
  :d "Verifies that ungrounded action is blocked and grounded action is approved."
  (let [(doc (sample-doc))
        (p (px/register-source (px/init-proxy) doc))
        (cit-good (core/ClaimCitation
                    :claim-text "Wasm execution"
                    :doc-id "doc-core-spec"
                    :exact-quote "compiles to WebAssembly"
                    :confidence 0.98))
        (cit-bad (core/ClaimCitation
                   :claim-text "Wasm execution"
                   :doc-id "doc-core-spec"
                   :exact-quote "compiles to Java bytecode"
                   :confidence 0.98))]
    (let [(dec-good (px/evaluate-action p "deploy-wasm" (list cit-good)))
          (dec-bad (px/evaluate-action p "deploy-java" (list cit-bad)))]
      (do
        (assert (.-allow dec-good) "Grounded action must be allowed")
        (assert (not (.-allow dec-bad)) "Ungrounded action must be blocked")
        (assert (string-contains? (.-reason dec-bad) "Exact quote not found") "Block reason must cite ungrounded quote")
        true))))

(df run-tests [] -> Bool
  :d "Runs all asl-harness unit tests under strict falsification."
  (do
    (assert (test-adapter-name))
    (assert (test-valid-grounding))
    (assert (test-hallucinated-quote))
    (assert (test-missing-doc))
    (assert (test-namespace-cache))
    (assert (test-proxy-firewall-action))
    true))
