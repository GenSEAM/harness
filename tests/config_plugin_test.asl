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
    (and (option-is-some? p-opt)
         (let [(p1 (option-unwrap p-opt))]
           (and (= (.-name p1) (.-name p0))
                (and (= (.-family p1) (.-family p0))
                     (and (.-strict-firewall p1)
                          (and (.-strict-normalizer p1)
                               (and (.-in-memory-repl p1)
                                    (= (.-max-tokens p1) 8192))))))))))

(df test-storage-config-roundtrip [] -> Bool
  :d "Verifies lossless serialization and deserialization of StorageConfig directly to/from ASN constructor nodes."
  (let [(s0 (cfg/default-storage-config "/Users/dev/workspace"))
        (node (cfg/storage-config-to-asn-node s0))
        (s-opt (cfg/storage-config-from-asn-node node))]
    (and (option-is-some? s-opt)
         (let [(s1 (option-unwrap s-opt))]
           (and (= (.-master-research-root s1) "/Users/dev/workspace/.research")
                (and (= (.-master-scratch-root s1) "/Users/dev/workspace/scratch")
                     (and (= (.-worktree-scratch-root s1) "/Users/dev/workspace/.worktree-scratch")
                          (= (.-local-repo-root s1) "/Users/dev/workspace"))))))))

(df test-harness-config-tree [] -> Bool
  :d "Verifies direct instantiation of HarnessConfig from structured ASN configuration tree."
  (let [(tree (cfg/asn-ctor "HarnessConfig"
                (list (cfg/AsnField :key ":firewall" :val (cfg/asn-bool true))
                      (cfg/AsnField :key ":fsm-normalizer" :val (cfg/asn-bool false))
                      (cfg/AsnField :key ":repl-in-memory" :val (cfg/asn-bool false)))))
        (cfg-opt (cfg/harness-config-from-asn-tree tree))]
    (and (option-is-some? cfg-opt)
         (let [(c (option-unwrap cfg-opt))]
           (and (cfg/feature-enabled? c "firewall")
                (and (not (cfg/feature-enabled? c "fsm-normalizer"))
                     (not (cfg/feature-enabled? c "repl-in-memory"))))))))

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
    (and (cfg/evaluate-hook-predicate pred-deny "rm_rf" "guard")
         (and (not (cfg/evaluate-hook-predicate pred-deny "read_file" "guard"))
              (and (cfg/evaluate-hook-predicate pred-allow "read_file" "guard")
                   (not (cfg/evaluate-hook-predicate pred-allow "write_file" "guard")))))))

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
    (and (not (plug/evaluate-plugin-guards plugin (cfg/hook-pre-call) "exec_command"))
         (and (plug/evaluate-plugin-guards plugin (cfg/hook-pre-call) "read_file")
              (plug/evaluate-plugin-guards plugin (cfg/hook-post-call) "exec_command")))))

(df test-cascaded-config-ast [] -> Bool
  :d "Verifies robust cascaded configuration resolution across tiers with both structured ASN and backward-compatible strings."
  (let [(c0 (cfg/default-harness-config))
        (c1 (cfg/resolve-cascaded-config c0 "(:fsm-normalizer false)" "" "(:repl-in-memory false)"))]
    (and (not (cfg/feature-enabled? c1 "fsm-normalizer"))
         (and (cfg/feature-enabled? c1 "firewall")
              (not (cfg/feature-enabled? c1 "repl-in-memory"))))))

(df test-malformed-asn-nodes [] -> Bool
  :d "Verifies graceful rejection and error handling for malformed ASN nodes."
  (let [(malformed (cfg/asn-nil))
        (p-res (cfg/model-profile-from-asn-node malformed))
        (s-res (cfg/storage-config-from-asn-node malformed))
        (c-res (cfg/harness-config-from-asn-tree malformed))]
    (and (option-is-none? p-res)
         (and (option-is-none? s-res)
              (option-is-none? c-res)))))

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
