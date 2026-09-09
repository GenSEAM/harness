(module asl-harness/config-plugin-test
  :d "Unit verification test suite for config-driven extensibility, HookPredicate, and direct ASL typed struct reuse in ASN."
  :x [test-model-profile-roundtrip
      test-storage-config-roundtrip
      test-harness-config-tree
      test-hook-predicate-evaluation
      test-plugin-guard-evaluation
      test-cascaded-config-ast
      test-malformed-asn-nodes
      run-tests]
  :i [(config :a cfg)
      (plugin :a plug)])

(df test-model-profile-roundtrip [] -> Bool
  :d "Verifies lossless serialization and deserialization of ModelProfile directly to/from ASN AST nodes without DTO mapping."
  (let [(p0 (cfg/profile-gemma-31b))
        (node (cfg/model-profile-to-asn-node p0))
        (p-opt (cfg/model-profile-from-asn-node node))]
    (do
      (assert (option-is-some? p-opt))
      (let [(p1 (option-unwrap p-opt))]
        (do
          (assert (= (.-name p1) (.-name p0)))
          (assert (= (.-family p1) (.-family p0)))
          (assert (.-strict-firewall p1))
          (assert (.-strict-normalizer p1))
          (assert (.-in-memory-repl p1))
          (assert (= (.-max-tokens p1) 8192))
          (assert (not (= (.-max-tokens p1) 0)))))
      true)))

(df test-storage-config-roundtrip [] -> Bool
  :d "Verifies lossless serialization and deserialization of StorageConfig directly to/from ASN constructor nodes."
  (let [(s0 (cfg/default-storage-config "/Users/dev/workspace"))
        (node (cfg/storage-config-to-asn-node s0))
        (s-opt (cfg/storage-config-from-asn-node node))]
    (do
      (assert (option-is-some? s-opt))
      (let [(s1 (option-unwrap s-opt))]
        (do
          (assert (= (.-master-research-root s1) "/Users/dev/workspace/.research"))
          (assert (= (.-master-scratch-root s1) "/Users/dev/workspace/scratch"))
          (assert (= (.-worktree-scratch-root s1) "/Users/dev/workspace/.worktree-scratch"))
          (assert (= (.-local-repo-root s1) "/Users/dev/workspace"))
          (assert (not (string-empty? (.-local-repo-root s1))))))
      true)))

(df test-harness-config-tree [] -> Bool
  :d "Verifies direct instantiation of HarnessConfig from structured ASN configuration tree."
  (let [(tree (cfg/asn-ctor "HarnessConfig"
                (list (cfg/AsnField :key ":firewall" :val (cfg/asn-bool true))
                      (cfg/AsnField :key ":fsm-normalizer" :val (cfg/asn-bool false))
                      (cfg/AsnField :key ":repl-in-memory" :val (cfg/asn-bool false)))))
        (cfg-opt (cfg/harness-config-from-asn-tree tree))]
    (do
      (assert (option-is-some? cfg-opt))
      (let [(c (option-unwrap cfg-opt))]
        (do
          (assert (cfg/feature-enabled? c "firewall"))
          (assert (not (cfg/feature-enabled? c "fsm-normalizer")))
          (assert (not (cfg/feature-enabled? c "repl-in-memory")))))
      true)))

(df test-hook-predicate-evaluation [] -> Bool
  :d "Verifies HookPredicate condition evaluation on target tool name and context tag."
  (let [(pred-deny (cfg/HookPredicate
                     :hook-type (cfg/hook-pre-call)
                     :name "guard-destructive-ops"
                     :target-pattern "rm_rf"
                     :action-override "deny"))
        (pred-allow (cfg/HookPredicate
                      :hook-type (cfg/hook-pre-call)
                      :name "guard-read-ops"
                      :target-pattern "read_file"
                      :action-override "allow"))]
    (do
      (assert (cfg/evaluate-hook-predicate pred-deny "rm_rf" "guard"))
      (assert (not (cfg/evaluate-hook-predicate pred-deny "read_file" "guard")))
      (assert (cfg/evaluate-hook-predicate pred-allow "read_file" "guard"))
      (assert (not (cfg/evaluate-hook-predicate pred-allow "write_file" "guard")))
      true)))

(df test-plugin-guard-evaluation [] -> Bool
  :d "Verifies evaluate-plugin-guards enforcing hook predicates and blocking denied tools."
  (let [(pred-block-terminal (cfg/HookPredicate
                               :hook-type (cfg/hook-pre-call)
                               :name "block-shell-subprocesses"
                               :target-pattern "exec_command"
                               :action-override "deny"))
        (cap (plug/PluginCapability
               :provided-tools (list "read_file" "exec_command")
               :system-prompts (list "Enforce strict security boundaries.")
               :hooks (list (cfg/hook-pre-call))
               :dependencies (list)
               :conflicts (list)
               :predicates (list pred-block-terminal)))
        (plugin (plug/create-plugin "sec-guard" "Security Guard" "1.0.0" 1 cap))]
    (do
      (assert (not (plug/evaluate-plugin-guards plugin (cfg/hook-pre-call) "exec_command")))
      (assert (plug/evaluate-plugin-guards plugin (cfg/hook-pre-call) "read_file"))
      (assert (plug/evaluate-plugin-guards plugin (cfg/hook-post-call) "exec_command"))
      true)))

(df test-cascaded-config-ast [] -> Bool
  :d "Verifies robust cascaded configuration resolution across tiers with both structured ASN and backward-compatible strings."
  (let [(c0 (cfg/default-harness-config))
        (c1 (cfg/resolve-cascaded-config c0 "(:fsm-normalizer false)" "" "(:repl-in-memory false)"))]
    (do
      (assert (not (cfg/feature-enabled? c1 "fsm-normalizer")))
      (assert (cfg/feature-enabled? c1 "firewall"))
      (assert (not (cfg/feature-enabled? c1 "repl-in-memory")))
      true)))

(df test-malformed-asn-nodes [] -> Bool
  :d "Verifies graceful rejection and error handling for malformed ASN nodes."
  (let [(malformed (cfg/asn-nil))
        (p-res (cfg/model-profile-from-asn-node malformed))
        (s-res (cfg/storage-config-from-asn-node malformed))
        (c-res (cfg/harness-config-from-asn-tree malformed))]
    (do
      (assert (option-is-none? p-res))
      (assert (option-is-none? s-res))
      (assert (option-is-none? c-res))
      (assert (not (option-is-some? p-res)))
      true)))

(df run-tests [] -> Bool
  :d "Executes all config plugin unit assertions."
  (do
    (assert (test-model-profile-roundtrip))
    (assert (test-storage-config-roundtrip))
    (assert (test-harness-config-tree))
    (assert (test-hook-predicate-evaluation))
    (assert (test-plugin-guard-evaluation))
    (assert (test-cascaded-config-ast))
    (assert (test-malformed-asn-nodes))))
