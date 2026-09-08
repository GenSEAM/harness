(module asl-harness/config-test
  :d "Unit tests for ASL Harness Configurable Constructor, Model Profiles, and Worktree Scoping"
  :x [test-default-config test-toggle-features test-plugin-registration test-experimental-flags test-qwen-profile test-worktree-detection test-storage-routing test-cascaded-config test-coverage-config test-dual-harness-profiles run-tests]
  :i [(config :a cfg)])

(df test-default-config [] -> Bool
  :d "Verifies default harness configuration provides optimal settings for Gemma 31B."
  (let [(c (cfg/default-harness-config))
        (prof (.-profile c))]
    (assert (= (.-name prof) "gemma-4-31b-it") "profile name gemma-4-31b-it")
    (assert (.-strict-firewall prof) "strict firewall enabled")
    (assert (.-strict-normalizer prof) "strict normalizer enabled")
    (assert (.-in-memory-repl prof) "in memory repl enabled")
    (assert (cfg/feature-enabled? c "firewall") "firewall feature enabled")
    (assert (cfg/feature-enabled? c "fsm-normalizer") "fsm-normalizer feature enabled")
    (assert (cfg/feature-enabled? c "repl-in-memory") "repl-in-memory feature enabled")
    (assert (not (cfg/feature-enabled? c "non-existent-flag")) "non-existent flag disabled")
    true))

(df test-toggle-features [] -> Bool
  :d "Verifies feature flag toggling."
  (let [(c0 (cfg/default-harness-config))
        (c1 (cfg/toggle-feature c0 "firewall" false))
        (c2 (cfg/toggle-feature c1 "custom-lens" true))]
    (assert (cfg/feature-enabled? c0 "firewall") "c0 firewall enabled")
    (assert (not (cfg/feature-enabled? c1 "firewall")) "c1 firewall disabled")
    (assert (cfg/feature-enabled? c2 "custom-lens") "c2 custom-lens enabled")
    true))

(df test-plugin-registration [] -> Bool
  :d "Verifies user-defined plugin registration into harness constructor."
  (let [(c0 (cfg/default-harness-config))
        (p1 (cfg/make-plugin "plugin-custom-smt" "Custom SMT Guard" "1.0.0" true "SMT verification plugin"))
        (c1 (cfg/register-plugin c0 p1))
        (plugins (.-plugins c1))
        (p0 (option-or (list-head plugins) (cfg/make-plugin "" "" "" false "")))]
    (assert (= (list-length plugins) 1) "one plugin registered")
    (assert (= (.-id p0) "plugin-custom-smt") "plugin id matches")
    true))

(df test-experimental-flags [] -> Bool
  :d "Verifies experimental feature flag isolation."
  (let [(c0 (cfg/default-harness-config))
        (c1 (cfg/enable-experimental c0 "exp-speculative-tokens"))]
    (assert (not (cfg/experimental-enabled? c0 "exp-speculative-tokens")) "c0 experimental disabled")
    (assert (cfg/experimental-enabled? c1 "exp-speculative-tokens") "c1 experimental enabled")
    true))

(df test-qwen-profile [] -> Bool
  :d "Verifies calibration profile for Qwen 2.5 0.5B."
  (let [(p (cfg/profile-qwen-05b))]
    (assert (= (.-name p) "qwen-2.5-0.5b") "qwen profile name")
    (assert (= (.-family p) "qwen") "qwen family")
    (assert (.-strict-firewall p) "qwen firewall")
    (assert (.-strict-normalizer p) "qwen normalizer")
    (assert (.-in-memory-repl p) "qwen repl")
    (assert (= (.-max-tokens p) 2048) "qwen max tokens")
    true))

(df test-worktree-detection [] -> Bool
  :d "Verifies gitdir parsing, repo kind classification, and worktree info resolution."
  (let [(main-kind (cfg/detect-repo-kind "dir" ""))
        (wt-content "gitdir: /Users/dev/repo/.git/worktrees/feat-x")
        (sub-content "gitdir: ../../.git/modules/submodule-a")
        (wt-kind (cfg/detect-repo-kind "file" wt-content))
        (sub-kind (cfg/detect-repo-kind "file" sub-content))
        (parsed-wt (cfg/parse-gitdir-file wt-content "/Users/dev/repo"))
        (wt-info (cfg/detect-worktree "file" wt-content "/Users/dev/repo"))]
    (assert (.-is-worktree wt-info) "is worktree")
    (assert (= (.-worktree-id wt-info) "feat-x") "worktree id matches")
    (assert (option-is-some? parsed-wt) "parsed-wt is some")
    true))

(df test-storage-routing [] -> Bool
  :d "Verifies dual-scope storage path resolution."
  (let [(storage (cfg/default-storage-config "/root/ws"))
        (res-path (cfg/route-storage-target ":research" "notes.md" storage))
        (scratch-path (cfg/route-storage-target ":scratch" "temp.json" storage))
        (wt-scratch (cfg/route-storage-target ":worktree-scratch" "log.txt" storage))]
    (assert (= res-path "/root/ws/.research/notes.md") "research path routed")
    (assert (= scratch-path "/root/ws/scratch/temp.json") "scratch path routed")
    (assert (= wt-scratch "/root/ws/.worktree-scratch/log.txt") "worktree scratch path routed")
    true))

(df test-cascaded-config [] -> Bool
  :d "Verifies monotonic feature flag cascading across tiers."
  (let [(cfg0 (cfg/default-harness-config))
        (cascaded (cfg/resolve-cascaded-config cfg0 "fsm-normalizer: false" "" "repl-in-memory: false"))]
    (assert (not (cfg/feature-enabled? cascaded "fsm-normalizer")) "fsm-normalizer disabled by cascade")
    (assert (cfg/feature-enabled? cascaded "firewall") "firewall remains enabled")
    (assert (not (cfg/feature-enabled? cascaded "repl-in-memory")) "repl-in-memory disabled by cascade")
    true))

(df test-coverage-config [] -> Bool
  :d "Verifies default coverage configuration, serialization to ASN node, and parsing."
  (let [(c (cfg/default-harness-config))
        (cov (.-coverage c))
        (serialized (cfg/coverage-config-to-asn-node cov))
        (parsed (cfg/coverage-config-from-asn-node serialized))]
    (assert (= (.-desired-coverage cov) 80.0) "desired coverage is 80.0")
    (assert (= (.-min-assertions-per-test cov) 2) "min assertions per test is 2")
    (assert (.-discount-zero-asserts cov) "discount zero asserts is true")
    (assert (option-is-some? parsed) "parsed coverage config is some")
    (let [(p (option-unwrap parsed))]
      (assert (= (.-desired-coverage p) 80.0) "parsed desired coverage matches")
      (assert (= (.-min-assertions-per-test p) 2) "parsed min assertions matches")
      (assert (.-discount-zero-asserts p) "parsed discount zero asserts matches"))
    true))

(df test-dual-harness-profiles [] -> Bool
  :d "Verifies Benchmark vs Production dual harness profiles and gateway routing."
  (let [(b-cfg (cfg/benchmark-harness-config))
        (p-cfg (cfg/production-harness-config))
        (b-gw (option-or (map-get (.-custom-settings b-cfg) "gateway-url") ""))
        (p-gw (option-or (map-get (.-custom-settings p-cfg) "gateway-url") ""))]
    (assert (cfg/feature-enabled? b-cfg "airgap") "benchmark airgap active")
    (assert (cfg/feature-enabled? b-cfg "strict-falsification") "benchmark strict falsification active")
    (assert (cfg/feature-enabled? b-cfg "ctrf-tracking") "benchmark ctrf tracking active")
    (assert (= b-gw "http://127.0.0.1:8765/v1") "benchmark gateway is 127.0.0.1:8765")
    (assert (not (cfg/feature-enabled? p-cfg "airgap")) "production airgap disabled")
    (assert (cfg/feature-enabled? p-cfg "epistemic-cycle") "production epistemic cycle active")
    (assert (cfg/feature-enabled? p-cfg "git-worktrees") "production git worktrees active")
    (assert (cfg/feature-enabled? p-cfg "compiler-feedback") "production compiler feedback active")
    (assert (= p-gw "http://127.0.0.1:8765/v1") "production gateway is 127.0.0.1:8765")
    true))

(df run-tests [] -> Bool
  :d "Executes complete config test suite."
  (do
    (test-default-config)
    (test-toggle-features)
    (test-plugin-registration)
    (test-experimental-flags)
    (test-qwen-profile)
    (test-worktree-detection)
    (test-storage-routing)
    (test-cascaded-config)
    (test-coverage-config)
    (test-dual-harness-profiles)
    true))
