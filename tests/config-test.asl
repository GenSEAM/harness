(module asl-harness/config-test
  :d "Unit tests for ASL Harness Configurable Constructor, Model Profiles, and Worktree Scoping"
  :x [test-default-config test-toggle-features test-plugin-registration test-experimental-flags test-qwen-profile test-worktree-detection test-storage-routing test-cascaded-config run-tests]
  :i [(config :a cfg)])

(df test-default-config [] -> Bool
  :d "Verifies default harness configuration provides optimal settings for Gemma 31B."
  (let [(c (cfg/default-harness-config))
        (prof (.-profile c))]
    (and (= (.-name prof) "gemma-4-31b-it")
         (.-strict-firewall prof)
         (.-strict-normalizer prof)
         (.-in-memory-repl prof)
         (cfg/feature-enabled? c "firewall")
         (cfg/feature-enabled? c "fsm-normalizer")
         (cfg/feature-enabled? c "repl-in-memory")
         (not (cfg/feature-enabled? c "non-existent-flag")))))

(df test-toggle-features [] -> Bool
  :d "Verifies feature flag toggling."
  (let [(c0 (cfg/default-harness-config))
        (c1 (cfg/toggle-feature c0 "firewall" false))
        (c2 (cfg/toggle-feature c1 "custom-lens" true))]
    (and (cfg/feature-enabled? c0 "firewall")
         (not (cfg/feature-enabled? c1 "firewall"))
         (cfg/feature-enabled? c2 "custom-lens"))))

(df test-plugin-registration [] -> Bool
  :d "Verifies user-defined plugin registration into harness constructor."
  (let [(c0 (cfg/default-harness-config))
        (p1 (cfg/make-plugin "plugin-custom-smt" "Custom SMT Guard" "1.0.0" true "SMT verification plugin"))
        (c1 (cfg/register-plugin c0 p1))
        (plugins (.-plugins c1))]
    (and (= (list-len plugins) 1)
         (= (.-id (list-head plugins)) "plugin-custom-smt"))))

(df test-experimental-flags [] -> Bool
  :d "Verifies experimental feature flag isolation."
  (let [(c0 (cfg/default-harness-config))
        (c1 (cfg/enable-experimental c0 "exp-speculative-tokens"))]
    (and (not (cfg/experimental-enabled? c0 "exp-speculative-tokens"))
         (cfg/experimental-enabled? c1 "exp-speculative-tokens"))))

(df test-qwen-profile [] -> Bool
  :d "Verifies calibration profile for Qwen 2.5 0.5B."
  (let [(p (cfg/profile-qwen-05b))]
    (and (= (.-name p) "qwen-2.5-0.5b")
         (= (.-family p) "qwen")
         (.-strict-firewall p)
         (.-strict-normalizer p)
         (.-in-memory-repl p)
         (= (.-max-tokens p) 2048))))

(df test-worktree-detection [] -> Bool
  :d "Verifies gitdir parsing, repo kind classification, and worktree info resolution."
  (let [(main-kind (cfg/detect-repo-kind "dir" ""))
        (wt-content "gitdir: /Users/dev/repo/.git/worktrees/feat-x")
        (sub-content "gitdir: ../../.git/modules/submodule-a")
        (wt-kind (cfg/detect-repo-kind "file" wt-content))
        (sub-kind (cfg/detect-repo-kind "file" sub-content))
        (parsed-wt (cfg/parse-gitdir-file wt-content "/Users/dev/repo"))
        (wt-info (cfg/detect-worktree "file" wt-content "/Users/dev/repo"))]
    (and (.-is-worktree wt-info)
         (= (.-worktree-id wt-info) "feat-x")
         (option-is-some? parsed-wt))))

(df test-storage-routing [] -> Bool
  :d "Verifies dual-scope storage path resolution."
  (let [(storage (cfg/default-storage-config "/root/ws"))
        (res-path (cfg/route-storage-target ":research" "notes.md" storage))
        (scratch-path (cfg/route-storage-target ":scratch" "temp.json" storage))
        (wt-scratch (cfg/route-storage-target ":worktree-scratch" "log.txt" storage))]
    (and (= res-path "/root/ws/.research/notes.md")
         (= scratch-path "/root/ws/scratch/temp.json")
         (= wt-scratch "/root/ws/.worktree-scratch/log.txt"))))

(df test-cascaded-config [] -> Bool
  :d "Verifies monotonic feature flag cascading across tiers."
  (let [(cfg0 (cfg/default-harness-config))
        (cascaded (cfg/resolve-cascaded-config cfg0 "fsm-normalizer: false" "" "repl-in-memory: false"))]
    (and (not (cfg/feature-enabled? cascaded "fsm-normalizer"))
         (cfg/feature-enabled? cascaded "firewall")
         (not (cfg/feature-enabled? cascaded "repl-in-memory")))))

(df run-tests [] -> Bool
  :d "Executes complete config test suite."
  (and (test-default-config)
       (and (test-toggle-features)
            (and (test-plugin-registration)
                 (and (test-experimental-flags)
                      (and (test-qwen-profile)
                           (and (test-worktree-detection)
                                (and (test-storage-routing)
                                     (test-cascaded-config)))))))))
