(module asl-harness/plugin-host-test
  :d "Falsifiable Unit and Integration Test Suite for Harness Step Plugins and Onion Middleware."
  :x [test-plugin-manifest-loading
      test-priority-and-dependency-ordering
      test-pre-step-mutation
      test-pre-tool-security-blocking-abort
      test-post-tool-payload-redaction
      test-step-hook-adapter-wiring-and-dispatch
      run-tests]
  :i [(onion :a on)
      (plugin_host :a host)
      (step_middleware :a sm)])

(df test-plugin-manifest-loading [] -> Bool
  :d "Verifies plugin manifest loading from valid and invalid source paths."
  (let [(res1 (host/load-plugin-from-source ".asl/plugins/guard.asl"))
        (res2 (host/load-plugin-from-source "plugins/custom-tool.asl"))
        (res-err (host/load-plugin-from-source "nonexistent/path.asl"))
        (res-empty (host/load-plugin-from-source ""))]
    (do
      (assert (mt res1 ((ok _) true) ((err _) false)) "Valid plugin source path must load successfully")
      (assert (mt res1 ((ok m) (= (.-id m) "guard")) ((err _) false)) "Extracted plugin id must equal guard")
      (assert (mt res1 ((ok m) (.-compiled m)) ((err _) false)) "Pre-compilation flag must be true")
      (assert (mt res2 ((ok m) (= (.-id m) "custom-tool")) ((err _) false)) "Extracted plugin id must equal custom-tool")
      (assert (mt res-err ((ok _) false) ((err _) true)) "Nonexistent plugin source must return error")
      (assert (mt res-empty ((ok _) false) ((err _) true)) "Empty plugin path must return error")
      true)))

(df test-priority-and-dependency-ordering [] -> Bool
  :d "Verifies numeric priority ordering and topological sort resolution of plugins."
  (let [(p-telemetry (host/make-plugin-config "mw-telemetry" ".asl/plugins/telemetry.asl" "telemetry" (list ":step:post") 100))
        (p-jail (host/make-plugin-config "mw-jail" ".asl/plugins/jail.asl" "jail" (list ":step:pre") 10))
        (p-audit (host/make-plugin-config "mw-audit" ".asl/plugins/audit.asl" "audit" (list ":step:pre") 50))
        (pipe (host/build-plugin-pipeline (list p-telemetry p-jail p-audit)))
        (sorted-mws (.-sorted pipe))
        (m0 (option-or (list-head sorted-mws) (on/make-middleware "" "" (on/kind-step-pre) 0 (list) (list))))
        (tail1 (option-or (list-tail sorted-mws) (list)))
        (m1 (option-or (list-head tail1) (on/make-middleware "" "" (on/kind-step-pre) 0 (list) (list))))
        (tail2 (option-or (list-tail tail1) (list)))
        (m2 (option-or (list-head tail2) (on/make-middleware "" "" (on/kind-step-pre) 0 (list) (list))))]
    (do
      (assert (= (list-length (.-middlewares pipe)) 3) "Pipeline must contain 3 registered middlewares")
      (assert (= (list-length sorted-mws) 3) "Sorted pipeline must contain 3 middlewares")
      (assert (= (.-id m0) "mw-jail") "Highest precedence middleware with priority 10 must execute first")
      (assert (= (.-id m1) "mw-audit") "Intermediate middleware with priority 50 must execute second")
      (assert (= (.-id m2) "mw-telemetry") "Lowest precedence middleware with priority 100 must execute last")
      true)))

(df test-pre-step-mutation [] -> Bool
  :d "Verifies step:pre hook inspects and mutates turn input."
  (let [(p-mutate (host/make-plugin-config "mw-transform" ".asl/plugins/transform.asl" "transform" (list ":step:pre") 20))
        (pipe (host/build-plugin-pipeline (list p-mutate)))
        (ctx (on/make-step-context "step-101" "sess-test" 0 "input-raw" "payload-raw"))
        (dec (host/execute-step-pipeline pipe ctx))]
    (do
      (assert (.-proceed dec) "Decision must allow turn execution to proceed")
      (assert (.-mutate dec) "Decision mutate flag must be asserted true")
      (assert (= (.-action dec) "mutate") "Decision action must be mutate")
      (assert (not (.-abort dec)) "Decision abort flag must be false")
      (assert (string-contains? (.-input (.-context dec)) "mw-transform") "Context input must carry transformed payload from middleware")
      true)))

(df test-pre-tool-security-blocking-abort [] -> Bool
  :d "Verifies tool:pre hook asserts security boundaries and aborts on dangerous invocations."
  (let [(p-guard (host/make-plugin-config "mw-jail" ".asl/plugins/jail.asl" "jail" (list ":tool:pre") 10))
        (pipe (host/build-plugin-pipeline (list p-guard)))
        (ctx-safe (on/make-step-context "step-sec-1" "sess-sec" 1 "read safe file" "cat safe.txt"))
        (dec-safe (host/execute-step-pipeline pipe ctx-safe))
        (ctx-block (on/make-step-context "step-sec-2" "sess-sec" 2 "run destructive shell" "blocked: rm -rf /"))
        (dec-block (host/execute-step-pipeline pipe ctx-block))]
    (do
      (assert (.-proceed dec-safe) "Safe invocation must proceed through tool guard")
      (assert (not (.-abort dec-safe)) "Safe invocation must not be aborted")
      (assert (not (.-proceed dec-block)) "Dangerous invocation must be halted")
      (assert (.-abort dec-block) "Dangerous invocation must assert abort flag")
      (assert (= (.-action dec-block) "abort") "Dangerous invocation action must equal abort")
      (assert (string-contains? (.-reason dec-block) "Aborted by middleware") "Decision reason must cite middleware abort")
      true)))

(df test-post-tool-payload-redaction [] -> Bool
  :d "Verifies tool:post hook sanitizes secrets and redacts sensitive payload tokens."
  (let [(p-redact (host/make-plugin-config "mw-redact" ".asl/plugins/redact.asl" "redact" (list ":tool:post") 30))
        (pipe (host/build-plugin-pipeline (list p-redact)))
        (ctx (on/make-step-context "step-red-1" "sess-red" 3 "get credentials" "token=secret_value_xyz"))
        (dec (host/execute-step-pipeline pipe ctx))]
    (do
      (assert (.-proceed dec) "Redaction middleware must allow execution to proceed")
      (assert (.-mutate dec) "Redaction middleware must mark context as mutated")
      (assert (not (.-abort dec)) "Redaction middleware must not abort safe turns")
      (assert (not (string-contains? (.-payload (.-context dec)) "secret")) "Payload must not contain raw secret token")
      (assert (string-contains? (.-payload (.-context dec)) "[REDACTED]") "Payload must contain redacted marker")
      true)))

(df test-step-hook-adapter-wiring-and-dispatch [] -> Bool
  :d "Verifies StepHookAdapter aggregates active hooks and dispatches interceptors."
  (let [(p-pre (host/make-plugin-config "mw-pre" ".asl/plugins/pre.asl" "pre" (list ":step:pre") 10))
        (p-post (host/make-plugin-config "mw-post" ".asl/plugins/post.asl" "post" (list ":step:post") 90))
        (pipe (host/build-plugin-pipeline (list p-pre p-post)))
        (adapter (sm/wire-step-plugins pipe))
        (ctx (on/make-step-context "step-ad-1" "sess-ad" 4 "clean turn" "payload ok"))
        (dec (sm/dispatch-step-interceptors adapter ctx))]
    (do
      (assert (= (.-adapter-name adapter) "asl-step-hook-adapter") "Adapter name must match standard identifier")
      (assert (> (sm/adapter-active-count adapter) 0) "Adapter active hook count must be greater than zero")
      (assert (sm/adapter-has-hook? adapter "kind-step-pre") "Adapter must report active kind-step-pre hook")
      (assert (sm/adapter-has-hook? adapter "kind-step-post") "Adapter must report active kind-step-post hook")
      (assert (not (sm/adapter-has-hook? adapter "nonexistent-hook")) "Adapter must not report unregistered hooks")
      (assert (.-proceed dec) "Adapter interceptor dispatch must proceed on clean input")
      (assert (not (.-abort dec)) "Adapter interceptor dispatch must not abort on clean input")
      true)))

(df run-tests [] -> Bool
  :d "Runs all harness step plugin host and onion middleware unit tests."
  (and (test-plugin-manifest-loading)
       (and (test-priority-and-dependency-ordering)
            (and (test-pre-step-mutation)
                 (and (test-pre-tool-security-blocking-abort)
                      (and (test-post-tool-payload-redaction)
                           (test-step-hook-adapter-wiring-and-dispatch)))))))
