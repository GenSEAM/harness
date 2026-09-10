(module asl-harness/configurable-browser-harness-test
  :d "Test suite for Configurable Browser Harness and Preset Engine"
  :x [test-browser-execution-context-instantiation
      test-dynamic-harness-routing
      test-specialized-harness-preset
      test-preset-execution-plan-generation
      test-thread-profile-evaluation
      test-transpile-preset-to-browser
      test-canonical-asn-formatting
      run-tests]
  :i [(configurable_browser_harness :a cbh)])

(df test-browser-execution-context-instantiation [] -> Bool
  :d "Verifies construction of browser execution contexts"
  (let [(ctx-single (cbh/make-browser-execution-context "single-thread" "main" 0 false))
        (ctx-multi (cbh/make-browser-execution-context "multi-thread" "worker-1" 4 true))]
    (assert (= (.-mode ctx-single) "single-thread") "Single thread mode must match")
    (assert (= (.-thread-id ctx-single) "main") "Main thread ID must match")
    (assert (not (.-shared-buffer-supported ctx-single)) "Shared buffer false in single thread")
    (assert (= (.-mode ctx-multi) "multi-thread") "Multi thread mode must match")
    (assert (= (.-worker-count ctx-multi) 4) "Worker count must be 4")
    (assert (.-shared-buffer-supported ctx-multi) "Shared buffer true in multi thread")
    true))

(df test-dynamic-harness-routing [] -> Bool
  :d "Verifies dynamic routing across capability categories"
  (let [(r-toys (cbh/route-dynamic-harness "toys"))
        (r-web (cbh/route-dynamic-harness "websites"))
        (r-svg (cbh/route-dynamic-harness "svgs"))
        (r-nano (cbh/route-dynamic-harness "nano"))
        (r-micro (cbh/route-dynamic-harness "micro"))]
    (assert (= (.-model-id r-toys) "qwen2.5:3b-instruct") "Toys must route to 3B ceiling")
    (assert (= (.-tier r-toys) "browser-ceiling-slm") "Toys tier must be browser-ceiling-slm")
    (assert (= (.-fsm-depth r-toys) 16) "Toys FSM depth must be 16")
    (assert (= (.-execution-mode r-toys) "multi-thread") "Toys execution must be multi-thread")
    (assert (= (.-model-id r-web) "qwen2.5:1.5b") "Websites must route to 1.5B")
    (assert (= (.-model-id r-svg) "qwen2.5:1.5b") "SVGs must route to 1.5B")
    (assert (= (.-execution-mode r-svg) "single-thread") "SVGs can run single-thread")
    (assert (= (.-model-id r-nano) "hanse-nano:100m") "Nano must route to 100M")
    (assert (= (.-schema-tokens r-nano) 30) "Nano schema overhead must be 30 tokens")
    (assert (= (.-model-id r-micro) "qwen2.5:0.5b") "Micro must route to 0.5B")
    true))

(df test-specialized-harness-preset [] -> Bool
  :d "Verifies construction of specialized harness preset specifications"
  (let [(preset (cbh/make-specialized-harness-preset
                  "preset-01"
                  "cat-svgs"
                  "small-slm-edge"
                  "qwen2.5:1.5b"
                  "single-thread"
                  "Emit standard ASN vector representation. Never emit markdown."
                  8))]
    (assert (= (.-preset-id preset) "preset-01") "Preset ID must match")
    (assert (= (.-category preset) "cat-svgs") "Category must match")
    (assert (= (.-target-tier preset) "small-slm-edge") "Tier must match")
    (assert (= (.-fsm-mask-depth preset) 8) "FSM mask depth must match")
    true))

(df test-preset-execution-plan-generation [] -> Bool
  :d "Verifies execution plan synthesis with token budgets"
  (let [(plan-toy (cbh/generate-preset-execution-plan "p-1" "toy-life" "toys" "(:step 1)" "application/json"))
        (plan-svg (cbh/generate-preset-execution-plan "p-2" "svg-badge" "svgs" "(:badge)" "image/svg+xml"))]
    (assert (= (.-plan-id plan-toy) "p-1") "Plan ID must match")
    (assert (= (.-max-tokens plan-toy) 512) "Toy max tokens must be 512")
    (assert (= (.-expected-format plan-toy) "application/json") "Toy format must match")
    (assert (= (.-max-tokens plan-svg) 256) "SVG max tokens must be 256")
    (assert (= (.-expected-format plan-svg) "image/svg+xml") "SVG format must match")
    true))

(df test-thread-profile-evaluation [] -> Bool
  :d "Verifies performance profile evaluation across single and multi-thread modes"
  (let [(prof-multi (cbh/evaluate-execution-thread-profile "multi-thread" "browser-ceiling-slm"))
        (prof-single-ceil (cbh/evaluate-execution-thread-profile "single-thread" "browser-ceiling-slm"))
        (prof-nano (cbh/evaluate-execution-thread-profile "single-thread" "nano-slm"))]
    (assert (.-fps60-guaranteed prof-multi) "Multi-thread must guarantee 60fps")
    (assert (= (.-ui-frame-drop-risk prof-multi) "none") "Multi-thread frame drop risk is none")
    (assert (= (.-memory-overhead-mb prof-multi) 32) "Multi-thread memory overhead is 32MB")
    (assert (not (.-fps60-guaranteed prof-single-ceil)) "Single-thread 3B cannot guarantee 60fps")
    (assert (= (.-ui-frame-drop-risk prof-single-ceil) "high") "Single-thread 3B risk is high")
    (assert (.-fps60-guaranteed prof-nano) "Single-thread nano guarantees 60fps")
    (assert (= (.-estimated-latency-ms prof-nano) 12) "Nano latency must be 12ms")
    true))

(df test-transpile-preset-to-browser [] -> Bool
  :d "Verifies transpilation into browser markup"
  (let [(out-svg (cbh/transpile-preset-to-browser "out-1" "vector-diagram" "(:rc :x 0 :y 0 :w 10 :h 10)"))
        (out-vdom (cbh/transpile-preset-to-browser "out-2" "vdom-page" "(:tag \"main\")"))
        (out-toy (cbh/transpile-preset-to-browser "out-3" "cellular-automata" "(:grid [1 0])"))]
    (assert (.-success out-svg) "SVG transpilation must succeed")
    (assert (= (.-target-format out-svg) "image/svg+xml") "SVG MIME format must match")
    (assert (string-contains? (.-rendered-output out-svg) "<svg xmlns=") "Must contain SVG tag")
    (assert (.-success out-vdom) "VDOM transpilation must succeed")
    (assert (= (.-target-format out-vdom) "text/html") "HTML MIME format must match")
    (assert (string-contains? (.-rendered-output out-vdom) "<div class=\"vdom-container\">") "Must wrap in container")
    (assert (.-success out-toy) "Toy transpilation must succeed")
    (assert (= (.-target-format out-toy) "application/json") "JSON MIME format must match")
    true))

(df test-canonical-asn-formatting [] -> Bool
  :d "Verifies canonical ASN formatting functions"
  (let [(route (cbh/route-dynamic-harness "nano"))
        (plan (cbh/generate-preset-execution-plan "p-1" "toy-1" "toys" "input" "json"))
        (prof (cbh/evaluate-execution-thread-profile "multi-thread" "small-slm-edge"))
        (str-route (cbh/format-dynamic-route-asn route))
        (str-plan (cbh/format-preset-plan-asn plan))
        (str-prof (cbh/format-thread-profile-asn prof))]
    (assert (string-contains? str-route ":capability \"nano\"") "Route ASN must contain capability")
    (assert (string-contains? str-route ":schema-tokens 30") "Route ASN must contain tokens")
    (assert (string-contains? str-plan ":plan-id \"p-1\"") "Plan ASN must contain plan-id")
    (assert (string-contains? str-prof ":mode \"multi-thread\"") "Profile ASN must contain mode")
    (assert (string-contains? str-prof ":fps60-guaranteed true") "Profile ASN must contain 60fps flag")
    true))

(df run-tests [] -> Bool
  :d "Runs all test cases for configurable browser harness"
  (and (test-browser-execution-context-instantiation)
       (and (test-dynamic-harness-routing)
            (and (test-specialized-harness-preset)
                 (and (test-preset-execution-plan-generation)
                      (and (test-thread-profile-evaluation)
                           (and (test-transpile-preset-to-browser)
                                (test-canonical-asn-formatting))))))))
