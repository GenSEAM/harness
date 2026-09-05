(module asl-harness/config-test
  :d "Unit tests for ASL Harness Configurable Constructor and Plugin Registry"
  :x [test-default-config test-toggle-features test-plugin-registration test-experimental-flags]
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
