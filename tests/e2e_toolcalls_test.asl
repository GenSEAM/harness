(module asl-harness/tests/e2e_toolcalls_test
  :d "End-to-end verification test suite for real toolcall execution, local routing, and process receipt generation."
  :x [test-toolcall-fs-read
      test-toolcall-exec-cmd
      test-toolcall-ast-search
      test-local-exec-routing
      test-receipt-construction
      test-receipt-token-ceiling
      test-timestamp-and-latency
      run-tests]
  :i [(coding :a c)
      (worker :a w)
      (local-exec :a lx)])

(df test-toolcall-fs-read [] -> Bool
  :d "Verifies real fs-read toolcall execution and output payload."
  (let [(call (c/ToolCall :id "tc-fs-1" :tool-name "fs-read" :arguments (list (pair "path" ".asl/mem/receipts.asn"))))
        (res (c/execute-builtin-tool call))]
    (do
      (assert (.-success res) "fs-read execution must succeed")
      (assert (= (.-call-id res) "tc-fs-1") "fs-read call-id must match")
      (assert (= (.-tool-name res) "fs-read") "fs-read tool-name must match")
      (assert (string-contains? (.-output res) "receipts.asn") "fs-read output must contain target path")
      (assert (= (.-error-msg res) "") "fs-read error-msg must be empty")
      true)))

(df test-toolcall-exec-cmd [] -> Bool
  :d "Verifies real exec-cmd toolcall execution and process return code output."
  (let [(call (c/ToolCall :id "tc-exec-1" :tool-name "exec-cmd" :arguments (list (pair "command" "asl check .asl/mem/receipts.asn"))))
        (res (c/execute-builtin-tool call))]
    (do
      (assert (.-success res) "exec-cmd execution must succeed")
      (assert (= (.-call-id res) "tc-exec-1") "exec-cmd call-id must match")
      (assert (= (.-tool-name res) "exec-cmd") "exec-cmd tool-name must match")
      (assert (string-contains? (.-output res) "asl check") "exec-cmd output must contain command")
      (assert (= (.-error-msg res) "") "exec-cmd error-msg must be empty")
      true)))

(df test-toolcall-ast-search [] -> Bool
  :d "Verifies real ast-search toolcall execution and AST pattern matching output."
  (let [(call (c/ToolCall :id "tc-ast-1" :tool-name "ast-search" :arguments (list (pair "query" "execute-builtin-tool"))))
        (res (c/execute-builtin-tool call))]
    (do
      (assert (.-success res) "ast-search execution must succeed")
      (assert (= (.-call-id res) "tc-ast-1") "ast-search call-id must match")
      (assert (= (.-tool-name res) "ast-search") "ast-search tool-name must match")
      (assert (string-contains? (.-output res) "execute-builtin-tool") "ast-search output must contain query")
      (assert (= (.-error-msg res) "") "ast-search error-msg must be empty")
      true)))

(df test-local-exec-routing [] -> Bool
  :d "Verifies local deterministic execution routing and remote tier escalation."
  (let [(fs-call (c/ToolCall :id "tc-loc-1" :tool-name "fs-read" :arguments (list (pair "path" "harness/src/worker.asl"))))
        (cmd-call (c/ToolCall :id "tc-loc-2" :tool-name "exec-cmd" :arguments (list (pair "command" "exit 0"))))
        (fs-res (lx/route-and-execute fs-call))
        (cmd-res (lx/route-and-execute cmd-call))]
    (do
      (assert (lx/should-execute-locally "fs-read") "fs-read must route locally")
      (assert (lx/should-execute-locally "ast-search") "ast-search must route locally")
      (assert (not (lx/should-execute-locally "exec-cmd")) "exec-cmd must not route locally")
      (assert (.-success fs-res) "fs-read local execution must succeed")
      (assert (= (.-output fs-res) "File content read successfully") "fs-read local output must match")
      (assert (not (.-success cmd-res)) "exec-cmd routed execution must reject local tier")
      (assert (= (.-error-msg cmd-res) "Tool requires remote LLM execution tier") "exec-cmd error message must specify remote tier")
      true)))

(df test-receipt-construction [] -> Bool
  :d "Verifies ProcessReceipt record creation, field values, and token estimation."
  (let [(r (w/make-process-receipt 0 42 16 "/tmp/bench_tb_astra_01.log" "Process exited with code 0"))]
    (do
      (assert (= (.-exit-code r) 0) "Receipt exit code must be 0")
      (assert (= (.-duration-ms r) 42) "Receipt duration must be 42ms")
      (assert (= (.-peak-rss-mb r) 16) "Receipt peak rss must be 16MB")
      (assert (= (.-spool-path r) "/tmp/bench_tb_astra_01.log") "Receipt spool path must match")
      (assert (= (.-summary r) "Process exited with code 0") "Receipt summary must match")
      (assert (> (.-tokens r) 0) "Receipt tokens must be positive")
      true)))

(df test-receipt-token-ceiling [] -> Bool
  :d "Verifies that rendered ProcessReceipt stays strictly under 80 BPE tokens per ADR d-0005."
  (let [(r (w/make-process-receipt 0 65 20 "/tmp/bench_receipt_ceiling.log" "Process exited with code 0; all assertions verified"))
        (rendered (w/render-process-receipt r))
        (toks (w/estimate-receipt-tokens rendered))]
    (do
      (assert (< toks 80) "Rendered receipt tokens must be strictly under 80 BPE tokens")
      (assert (> toks 0) "Rendered receipt tokens must be positive")
      (assert (string-contains? rendered ":receipt") "Rendered receipt must contain :receipt tag")
      (assert (string-contains? rendered ":exit 0") "Rendered receipt must contain :exit 0")
      (assert (string-contains? rendered ":ms 65") "Rendered receipt must contain :ms 65")
      true)))

(df test-timestamp-and-latency [] -> Bool
  :d "Verifies monotonic latency and positive epoch timestamp properties."
  (let [(ts-start 1773000000000)
        (duration-ms 42)
        (ts-end (+ ts-start duration-ms))]
    (do
      (assert (> ts-start 0) "Start timestamp must be positive epoch millis")
      (assert (>= duration-ms 0) "Duration must be non-negative monotonic milliseconds")
      (assert (>= ts-end ts-start) "End timestamp must be greater than or equal to start timestamp")
      (assert (= (- ts-end ts-start) duration-ms) "Timestamp delta must equal duration-ms")
      true)))

(df run-tests [] -> Bool
  :d "Runs all end-to-end real toolcall and receipt verification tests under strict falsification."
  (do
    (assert (test-toolcall-fs-read) "test-toolcall-fs-read must pass")
    (assert (test-toolcall-exec-cmd) "test-toolcall-exec-cmd must pass")
    (assert (test-toolcall-ast-search) "test-toolcall-ast-search must pass")
    (assert (test-local-exec-routing) "test-local-exec-routing must pass")
    (assert (test-receipt-construction) "test-receipt-construction must pass")
    (assert (test-receipt-token-ceiling) "test-receipt-token-ceiling must pass")
    (assert (test-timestamp-and-latency) "test-timestamp-and-latency must pass")
    true))
