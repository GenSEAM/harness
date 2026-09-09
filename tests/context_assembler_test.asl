(module asl-harness/tests/context-assembler-test
  :d "Unit and falsifiable verification suite for dynamic context assembler and agent-directed context management."
  :x [test-context-block-creation
      test-strategy-1-baseline
      test-strategy-2-receipts-compaction
      test-strategy-3-jit-working-memory
      test-strategy-4-agent-ctx-op-parsing
      test-strategy-4-self-directed-assembly
      test-assemble-prompt-dispatcher
      test-escaped-payload-serialization
      test-watermark-compaction-assembly
      run-tests]
  :i [(context_assembler :a ca)])

(df test-context-block-creation [] -> Bool
  :d "Verifies ContextBlock construction, token estimation, and field accessors."
  (let [(b1 (ca/make-context-block "sys-1" "sys-mandate" 120 "You are Scout agent"))
        (b2 (ca/make-context-block "spec-1" "task-spec" 0 "Solve challenge TB4-SOLV-01"))
        (op (ca/make-agent-ctx-op (list "spec-1") (list "turn-0") (list "core/parser.asl")))]
    (do
      (assert (= (.-id b1) "sys-1") "b1 ID must match constructor")
      (assert (= (.-kind b1) "sys-mandate") "b1 kind must match sys-mandate")
      (assert (= (.-tokens b1) 120) "b1 explicit tokens must equal 120")
      (assert (= (.-id b2) "spec-1") "b2 ID must match constructor")
      (assert (> (.-tokens b2) 0) "b2 estimated tokens must be non-zero")
      (assert (= (list-length (.-retain op)) 1) "op retain list length must equal 1")
      (assert (= (list-length (.-evict op)) 1) "op evict list length must equal 1")
      (assert (= (list-length (.-prefetch op)) 1) "op prefetch list length must equal 1")
      true)))

(df test-strategy-1-baseline [] -> Bool
  :d "Verifies Strategy 1 uncompressed sliding window within token ceiling."
  (let [(b1 (ca/make-context-block "b1" "sys-mandate" 100 "System instructions"))
        (b2 (ca/make-context-block "b2" "task-spec" 150 "Task specification"))
        (b3 (ca/make-context-block "b3" "history" 200 "Turn 1 history payload"))
        (blocks (list b1 b2 b3))
        (res-unlimited (ca/assemble-baseline-context blocks 1000))
        (res-constrained (ca/assemble-baseline-context blocks 200))]
    (do
      (assert (= (.-strategy res-unlimited) "baseline") "Strategy must be baseline")
      (assert (= (.-total-tokens res-unlimited) 450) "Total tokens must equal 450")
      (assert (= (.-retained-count res-unlimited) 3) "All 3 blocks must be retained under 1000 ceiling")
      (assert (= (.-evicted-count res-unlimited) 0) "Zero blocks evicted under 1000 ceiling")
      (assert (string-contains? (.-prompt-str res-unlimited) "(:block :id \"b1\"") "Prompt must format b1")
      (assert (string-contains? (.-prompt-str res-unlimited) "(:block :id \"b3\"") "Prompt must format b3")
      (assert (= (.-retained-count res-constrained) 1) "Only 1 block must fit in 200 ceiling")
      (assert (= (.-evicted-count res-constrained) 2) "2 blocks must be evicted in 200 ceiling")
      true)))

(df test-strategy-2-receipts-compaction [] -> Bool
  :d "Verifies Strategy 2 compaction of older history turns into 1-line receipts."
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 50 "System prompt"))
        (b-t1 (ca/make-context-block "t1" "history" 300 "fs-read: src/core.asl dumped 500 lines of file content"))
        (b-t2 (ca/make-context-block "t2" "history" 250 "exec-cmd: test gate passed with exit 0"))
        (b-t3 (ca/make-context-block "t3" "history" 200 "ast-patch: patched function token-stream"))
        (blocks (list b-sys b-t1 b-t2 b-t3))
        (res (ca/assemble-receipts-context blocks 4096 1))]
    (do
      (assert (= (.-strategy res) "receipts") "Strategy must be receipts")
      (assert (= (.-retained-count res) 4) "All 4 blocks should be retained")
      (assert (< (.-total-tokens res) 800) "Total tokens must be compacted below uncompressed 800")
      (assert (string-contains? (.-prompt-str res) "[Turn: fs-read file cached]") "t1 should be compacted into receipt")
      (assert (string-contains? (.-prompt-str res) "[Turn: exec-cmd verified gate]") "t2 should be compacted into receipt")
      (assert (string-contains? (.-prompt-str res) "ast-patch: patched function token-stream") "t3 (most recent) must remain uncompacted")
      true)))

(df test-strategy-3-jit-working-memory [] -> Bool
  :d "Verifies Strategy 3 JIT working memory drops all history and retains AST working set."
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 50 "System prompt"))
        (b-spec (ca/make-context-block "spec" "task-spec" 80 "Specification"))
        (b-t1 (ca/make-context-block "t1" "history" 350 "Old history turn"))
        (b-t2 (ca/make-context-block "t2" "turn" 300 "Another old turn"))
        (b-ast (ca/make-context-block "ast-1" "working-set" 120 "(:sym \"tokenize\" :args [(stream Str)])"))
        (blocks (list b-sys b-spec b-t1 b-t2 b-ast))
        (res (ca/assemble-jit-context blocks 4096))]
    (do
      (assert (= (.-strategy res) "jit-memory") "Strategy must be jit-memory")
      (assert (= (.-retained-count res) 3) "Retained count must be 3 (sys, spec, ast-1)")
      (assert (= (.-evicted-count res) 2) "Evicted count must be 2 (t1, t2 history dropped)")
      (assert (not (string-contains? (.-prompt-str res) "Old history turn")) "Prompt must not contain old history")
      (assert (string-contains? (.-prompt-str res) "tokenize") "Prompt must contain working-set AST")
      true)))

(df test-strategy-4-agent-ctx-op-parsing [] -> Bool
  :d "Verifies parsing of model :ctx-op directive with retain, evict, and prefetch."
  (let [(model-resp "(:response :action (:batch (:chk)) :ctx-op (:retain [\"b-spec\" \"ast-core\"] :evict [\"t1\" \"t2\"] :prefetch [\"core/lexer.asl\" \"core/parser.asl\"]) :summary \"checked\")")
        (parsed-opt (ca/parse-agent-ctx-op model-resp))
        (no-op-resp "(:response :action (:batch (:chk)) :summary \"done\")")
        (no-op-opt (ca/parse-agent-ctx-op no-op-resp))]
    (mt parsed-opt
      ((some op)
       (do
         (assert (= (list-length (.-retain op)) 2) "Retain count must be 2")
         (assert (= (list-length (.-evict op)) 2) "Evict count must be 2")
         (assert (= (list-length (.-prefetch op)) 2) "Prefetch count must be 2")
         (assert (option-none? no-op-opt) "Response without ctx-op must return none")
         true))
      ((none)
       (do
         (assert false "Expected parsed AgentCtxOp")
         false)))))

(df test-strategy-4-self-directed-assembly [] -> Bool
  :d "Verifies Strategy 4 applies agent-directed eviction and prefetch injection."
  (let [(b-spec (ca/make-context-block "b-spec" "task-spec" 100 "Task specification"))
        (b-stale (ca/make-context-block "t-stale" "history" 400 "Stale verbose tool output"))
        (b-useful (ca/make-context-block "t-useful" "history" 150 "Important finding"))
        (blocks (list b-spec b-stale b-useful))
        (op (ca/make-agent-ctx-op
              (list "b-spec")
              (list "t-stale")
              (list "core/parser.asl")))
        (res (ca/assemble-agent-directed-context blocks 4096 op))]
    (do
      (assert (= (.-strategy res) "agent-directed") "Strategy must be agent-directed")
      (assert (not (string-contains? (.-prompt-str res) "t-stale")) "t-stale must be evicted from prompt")
      (assert (string-contains? (.-prompt-str res) "(:prefetch-sym \"core/parser.asl\")") "Prefetched block must be injected")
      (assert (string-contains? (.-prompt-str res) "b-spec") "Retained b-spec must be present")
      (assert (= (.-retained-count res) 3) "Retained count should be 3 (b-spec, t-useful, prefetch)")
      (assert (>= (.-evicted-count res) 1) "Evicted count must be at least 1")
      true)))

(df test-assemble-prompt-dispatcher [] -> Bool
  :d "Verifies assemble-prompt dispatcher delegates to configured strategy."
  (let [(blocks (list (ca/make-context-block "b1" "sys-mandate" 50 "Sys")
                      (ca/make-context-block "t1" "history" 200 "Turn 1")))
        (cfg-b (ca/make-default-config "baseline"))
        (cfg-r (ca/make-default-config "receipts"))
        (cfg-j (ca/make-default-config "jit-memory"))
        (res-b (ca/assemble-prompt blocks cfg-b (none)))
        (res-r (ca/assemble-prompt blocks cfg-r (none)))
        (res-j (ca/assemble-prompt blocks cfg-j (none)))]
    (do
      (assert (= (.-strategy res-b) "baseline") "cfg-b must produce baseline")
      (assert (= (.-strategy res-r) "receipts") "cfg-r must produce receipts")
      (assert (= (.-strategy res-j) "jit-memory") "cfg-j must produce jit-memory")
      true)))

(df test-escaped-payload-serialization [] -> Bool
  :d "Verifies that quotes and backslashes in context block payloads are safely escaped."
  (let [(b (ca/make-context-block "raw1" "task-spec" 50 "echo \"hello world\" \\path"))
        (res (ca/assemble-baseline-context (list b) 1000))]
    (do
      (assert (string-contains? (.-prompt-str res) "\\\"hello world\\\"") "Quotes must be escaped with backslash")
      (assert (string-contains? (.-prompt-str res) "\\\\path") "Backslash must be escaped")
      true)))

(df test-watermark-compaction-assembly [] -> Bool
  :d "Verifies dynamic watermark context assembly and gateway JIT block hydration."
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 100 "System prompt"))
        (b-t1 (ca/make-context-block "t1" "history" 250 "fs-read: src/core.asl dumped 500 lines of file content"))
        (b-t2 (ca/make-context-block "t2" "history" 250 "exec-cmd: test gate passed with exit 0"))
        (b-t3 (ca/make-context-block "t3" "history" 250 "ast-patch: patched function token-stream"))
        (blocks (list b-sys b-t1 b-t2 b-t3))
        (res-watermark (ca/assemble-watermark-context blocks 1000))
        (jit-blocks (ca/hydrate-jit-blocks (list "make-engine") 2))]
    (do
      (assert (= (.-strategy res-watermark) "watermark") "Strategy must be watermark")
      (assert (> (list-length jit-blocks) 0) "JIT blocks must be hydrated via Engine Gateway")
      (assert (string-contains? (.-payload (option-or (list-head jit-blocks) (ca/make-context-block "" "" 0 ""))) ":jit-result") "JIT payload must contain :jit-result envelope")
      true)))

(df run-tests [] -> Bool
  :d "Executes full context assembler test suite."
  (and (test-context-block-creation)
       (and (test-strategy-1-baseline)
            (and (test-strategy-2-receipts-compaction)
                 (and (test-strategy-3-jit-working-memory)
                      (and (test-strategy-4-agent-ctx-op-parsing)
                           (and (test-strategy-4-self-directed-assembly)
                                (and (test-assemble-prompt-dispatcher)
                                     (and (test-escaped-payload-serialization)
                                          (test-watermark-compaction-assembly))))))))))
