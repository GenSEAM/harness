(module asl-harness/engine-gateway-test-proxy
  :d "Unit test suite for engine_gateway_test alias."
  :x [test-airgap-assertions run-tests]
  :i [(engine-gateway :a eg)])

(df test-airgap-assertions [] -> Bool
  :d "Verifies engine gateway airgap behavior with non-vacuous assertions."
  (let [(res-t0 (eg/query-gateway "sym" "tier-0-ast" 1 true))
        (res-air (eg/query-gateway "ext" "tier-2-web" 1 true))]
    (assert (= (list-length res-t0) 1) "tier-0 single result")
    (assert (= (.-source (option-or (list-head res-air) (eg/EngineResult :tier "" :source "" :score 0.0 :title "" :snippet ""))) "airgap-policy") "airgap policy intercepted")
    true))

(df run-tests [] -> Bool
  :d "Runs engine gateway proxy tests."
  (test-airgap-assertions))
