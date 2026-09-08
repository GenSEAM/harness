(module asl-harness/tests/knowledge-mount-test
  :d "Unit and falsifiable verification suite for pluggable knowledge mount engine and universal golden default canvas."
  :x [test-mount-and-unmount-lifecycle
      test-knowledge-clamping-and-pointer
      test-knowledge-to-context-blocks
      test-universal-canvas-composition
      test-mounted-knowledge-asn-formatting
      test-universal-canvas-with-other-blocks
      run-tests]
  :i [(knowledge_mount :a km)
      (context_assembler :a ca)])

(df test-mount-and-unmount-lifecycle [] -> Bool
  :d "Verifies mounting, active lookup, and unmounting with zero residue."
  (let [(src1 (km/make-knowledge-source "api-spec" "api-doc" "specs/api.asn" "(:endpoints [/auth /query])" 200))
        (src2 (km/make-knowledge-source "mem-facts" "mem-fact" ".asl/mem/intent.asn" "(:intent :grounded true)" 150))
        (mounted0 (list))
        (mounted1 (km/mount-knowledge-source mounted0 src1))
        (mounted2 (km/mount-knowledge-source mounted1 src2))
        (unmounted (km/unmount-knowledge-source mounted2 "api-spec"))]
    (do
      (assert (= (list-length mounted1) 1) "Mounted list after src1 must have length 1")
      (assert (= (list-length mounted2) 2) "Mounted list after src2 must have length 2")
      (assert (km/is-knowledge-mounted? mounted2 "api-spec") "api-spec must be mounted in mounted2")
      (assert (km/is-knowledge-mounted? mounted2 "mem-facts") "mem-facts must be mounted in mounted2")
      (assert (not (km/is-knowledge-mounted? unmounted "api-spec")) "api-spec must be unmounted in unmounted list")
      (assert (km/is-knowledge-mounted? unmounted "mem-facts") "mem-facts must remain mounted in unmounted list")
      (assert (= (list-length unmounted) 1) "Unmounted list must have length 1")
      true)))

(df test-knowledge-clamping-and-pointer [] -> Bool
  :d "Verifies bulky knowledge (>1000 tokens) is clamped to budget and emits perceptual pointer."
  (let [(bulky-line "0123456789012345678901234567890123456789\n")
        (bulky-doc (string-repeat bulky-line 100))
        (src (km/make-knowledge-source "bulky-api" "api-doc" "docs/bulky-api.md" bulky-doc 300))
        (mounted (km/mount-knowledge-source (list) src))
        (found-opt (km/find-mounted-knowledge mounted "bulky-api"))]
    (mt found-opt
      ((some mk)
       (do
         (assert (<= (.-tokens mk) 350) "Clamped tokens must be within ceiling bound")
         (assert (string-contains? (.-clamped-payload mk) "[TRUNCATED") "Payload must indicate truncation")
         (assert (not (string-empty? (.-pointer-uri mk))) "Pointer URI must be present for clamped doc")
         (assert (string-contains? (.-pointer-uri mk) "(:ptr :uri \"docs/bulky-api.md\"") "Pointer must reference source URI")
         true))
      ((none)
       (do
         (assert false "Mounted item bulky-api must be found")
         false)))))

(df test-knowledge-to-context-blocks [] -> Bool
  :d "Verifies transpilation from mounted knowledge into ContextBlock records."
  (let [(src (km/make-knowledge-source "types-ast" "interface-contract" "src/types.asl" "(:types [User Session])" 100))
        (mounted (km/mount-knowledge-source (list) src))
        (blocks (km/to-context-blocks mounted))]
    (do
      (assert (= (list-length blocks) 1) "Context blocks count must equal 1")
      (let [(default-b (ca/make-context-block "" "" 0 ""))
            (b (option-or (list-head blocks) default-b))]
        (do
          (assert (= (.-id b) "k-types-ast") "Block ID must match k- prefix")
          (assert (= (.-kind b) "knowledge") "Block kind must equal knowledge")
          (assert (> (.-tokens b) 0) "Block tokens must be positive")
          (assert (string-contains? (.-payload b) "User Session") "Payload must match source content")
          true)))))

(df test-universal-canvas-composition [] -> Bool
  :d "Verifies Layer 1-5 composition in Universal Golden Default canvas."
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 60 "You are Implementer"))
        (b-task (ca/make-context-block "spec" "task-spec" 100 "Mount external knowledge and verify gate"))
        (k-src (km/make-knowledge-source "api" "api-doc" "specs/api.asn" "(:endpoints [/status /ping])" 80))
        (k-blocks (km/to-context-blocks (km/mount-knowledge-source (list) k-src)))
        (b-know (option-or (list-head k-blocks) (ca/make-context-block "k-api" "knowledge" 80 "(:endpoints [/status /ping])")))
        (b-h1 (ca/make-context-block "t1" "history" 250 "fs-read: read slice at step 1"))
        (b-h2 (ca/make-context-block "t2" "history" 200 "exec-cmd: verify baseline run completed"))
        (b-delta (ca/make-context-block "delta1" "delta" 70 "Assertion diff: expected green got red"))
        (all-blocks (list b-sys b-task b-know b-h1 b-h2 b-delta))
        (cfg (ca/ContextAssemblyConfig :strategy "universal-default" :token-ceiling 4096 :keep-recent 1))
        (res (ca/assemble-prompt all-blocks cfg (none)))]
    (do
      (assert (= (.-strategy res) "universal-default") "Strategy must be universal-default")
      (assert (= (.-retained-count res) 6) "All 6 blocks should be retained within 4096 ceiling")
      (assert (= (.-evicted-count res) 0) "Zero blocks evicted")
      (assert (string-contains? (.-prompt-str res) "sys-mandate") "Prompt must contain sys-mandate")
      (assert (string-contains? (.-prompt-str res) "task-spec") "Prompt must contain task-spec")
      (assert (string-contains? (.-prompt-str res) "knowledge") "Prompt must contain knowledge")
      (assert (string-contains? (.-prompt-str res) "receipt") "Older history block t1 must be converted to receipt")
      (assert (string-contains? (.-prompt-str res) "delta") "Prompt must contain reactive delta")
      true)))

(df test-mounted-knowledge-asn-formatting [] -> Bool
  :d "Verifies ASN formatting of mounted knowledge escapes quotes safely."
  (let [(mk (km/make-mounted-knowledge "doc-1" "api-doc" "specs/doc.asn" true "payload" 50 "(:ptr :uri \"specs/doc.asn\" :tokens 100)"))
        (asn (km/format-mounted-knowledge-asn mk))]
    (do
      (assert (string-contains? asn ":source-id \"doc-1\"") "ASN must contain source-id")
      (assert (string-contains? asn "\\\"specs/doc.asn\\\"") "Nested quotes in pointer-uri must be escaped")
      true)))

(df test-universal-canvas-with-other-blocks [] -> Bool
  :d "Verifies that unclassified or working-set blocks are retained in universal default canvas."
  (let [(b-sys (ca/make-context-block "sys" "sys-mandate" 50 "Sys"))
        (b-task (ca/make-context-block "task" "task-spec" 50 "Task"))
        (b-ast (ca/make-context-block "ast1" "working-set" 80 "(:sym tokenize)"))
        (b-hist (ca/make-context-block "h1" "history" 100 "history turn"))
        (all-blocks (list b-sys b-task b-ast b-hist))
        (cfg (ca/ContextAssemblyConfig :strategy "universal-default" :token-ceiling 1000 :keep-recent 1))
        (res (ca/assemble-prompt all-blocks cfg (none)))]
    (do
      (assert (= (.-retained-count res) 4) "All 4 blocks including working-set must be retained")
      (assert (string-contains? (.-prompt-str res) "working-set") "Prompt must contain working-set block")
      true)))

(df run-tests [] -> Bool
  :d "Executes full knowledge mount test suite."
  (and (test-mount-and-unmount-lifecycle)
       (and (test-knowledge-clamping-and-pointer)
            (and (test-knowledge-to-context-blocks)
                 (and (test-universal-canvas-composition)
                      (and (test-mounted-knowledge-asn-formatting)
                           (test-universal-canvas-with-other-blocks)))))))
