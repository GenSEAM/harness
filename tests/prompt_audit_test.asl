(module asl-harness/tests/prompt-audit-test
  :d "Unit verification test suite for dual-budget prompt accounting and headroom calculation"
  :x [test-simple-token-estimation
      test-single-budget-audit
      test-dual-budget-decoupled-within-limits
      test-dual-budget-static-overflow
      test-dual-budget-payload-overflow
      test-registry-string-audit
      run-tests]
  :i [(prompt_audit :a pa)])

(df test-simple-token-estimation [] -> Bool
  :d "Verifies token estimation heuristic for empty and non-empty strings"
  (do
    (assert (= (pa/estimate-tokens-simple "") 0) "Empty string must yield 0 tokens")
    (assert (= (pa/estimate-tokens-simple "abc") 1) "Short string must yield minimum 1 token")
    (assert (= (pa/estimate-tokens-simple "12345678") 2) "8-char string must yield 2 tokens")
    (assert (= (pa/estimate-tokens-simple "1234567890123456") 4) "16-char string must yield 4 tokens")
    true))

(df test-single-budget-audit [] -> Bool
  :d "Verifies legacy single-budget prompt metric calculation"
  (let [(p-under (pa/PromptDef
                   :id "p-under"
                   :role "implementer"
                   :budget-tokens 100
                   :system "short system"
                   :template "short template"))
        (res-under (pa/audit-prompt-tokens p-under))]
    (do
      (assert (is-ok? res-under) "audit-prompt-tokens must succeed")
      (let [(metric (result-or res-under (pa/TokenMetric :estimated-tokens 0 :budget-tokens 0 :headroom 0 :over-budget true)))]
        (assert (not (.-over-budget metric)) "Under budget prompt must not be over-budget")
        (assert (> (.-headroom metric) 0) "Under budget prompt must have positive headroom")
        (assert (pa/validate-prompt-budget p-under) "validate-prompt-budget must return true")
        true))))

(df test-dual-budget-decoupled-within-limits [] -> Bool
  :d "Verifies decoupled dual-budget audit when both static prefix and payload are within budgets"
  (let [(sys-prefix "(:mandate :id \"implementer\" :purpose \"delta executor\" :posture \"disciplined\" :primary-invariant \"Gate Preservation\")")
        (payload "Task: task-345-4\nFiles: [harness/src/prompt_audit.asl]\nInvariants: [c-0001]")
        (report (pa/audit-prompt-budgets "task-prompt" sys-prefix payload 60 1600))]
    (do
      (assert (.-valid report) "Report must be valid when both budgets are respected")
      (assert (= (.-error-code report) "") "Error code must be empty on valid audit")
      (assert (= (.-prompt-id report) "task-prompt") "Prompt id must match")
      (assert (> (.-static-headroom report) 0) "Static headroom must be positive")
      (assert (> (.-payload-headroom report) 0) "Payload headroom must be positive")
      (assert (<= (.-static-tokens report) 60) "Static tokens must be <= static budget")
      (assert (<= (.-payload-tokens report) 1600) "Payload tokens must be <= payload budget")
      true)))

(df test-dual-budget-static-overflow [] -> Bool
  :d "Verifies rejection when static system prefix exceeds static prefix token ceiling"
  (let [(sys-prefix-bloated "You are an autonomous AI coding assistant designed by Google Deepmind team working on Advanced Agentic Coding. You should follow all instructions carefully and behave with extreme politeness and elaborate personas that consume hundreds of tokens needlessly.")
        (payload "Task: task-1")
        (report (pa/audit-prompt-budgets "bloated-prompt" sys-prefix-bloated payload 30 1600))]
    (do
      (assert (not (.-valid report)) "Report must be invalid on static prefix overflow")
      (assert (= (.-error-code report) "STATIC_PREFIX_OVERFLOW") "Error code must be STATIC_PREFIX_OVERFLOW")
      (assert (< (.-static-headroom report) 0) "Static headroom must be negative")
      (assert (> (.-payload-headroom report) 0) "Payload headroom must remain positive")
      true)))

(df test-dual-budget-payload-overflow [] -> Bool
  :d "Verifies rejection when dynamic turn payload exceeds payload token ceiling"
  (let [(sys-prefix "(:mandate :id \"scout\")")
        (payload-bloated (fold (fn [(acc Str) (_ I64)] -> Str (str acc "excessive payload token bloat that repeats over and over again to exhaust dynamic budget ceiling entirely ")) "" (list 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)))
        (report (pa/audit-prompt-budgets "payload-bloat" sys-prefix payload-bloated 60 100))]
    (do
      (assert (not (.-valid report)) "Report must be invalid on dynamic payload overflow")
      (assert (= (.-error-code report) "PAYLOAD_BUDGET_OVERFLOW") "Error code must be PAYLOAD_BUDGET_OVERFLOW")
      (assert (> (.-static-headroom report) 0) "Static headroom must remain positive")
      (assert (< (.-payload-headroom report) 0) "Payload headroom must be negative")
      true)))

(df test-registry-string-audit [] -> Bool
  :d "Verifies audit of prompt definitions parsed from ASN registry text"
  (let [(reg-text "(:prompts-registry :version \"1.2.0\" :prompts [ (:prompt :id \"p1\" :role \"r1\" :budget-tokens 500 :system \"sys1\" :template \"tpl1\") (:prompt :id \"p2\" :role \"r2\" :budget-tokens 600 :system \"sys2\" :template \"tpl2\") ])")
        (reg-res (pa/audit-registry-string reg-text))]
    (do
      (assert (is-ok? reg-res) "Registry audit must succeed with ok")
      (let [(items (result-or reg-res (list)))]
        (assert (= (list-length items) 2) "Registry audit must find 2 items")
        true))))

(df run-tests [] -> Bool
  :d "Executes all prompt audit test assertions under strict falsification"
  (do
    (assert (test-simple-token-estimation))
    (assert (test-single-budget-audit))
    (assert (test-dual-budget-decoupled-within-limits))
    (assert (test-dual-budget-static-overflow))
    (assert (test-dual-budget-payload-overflow))
    (assert (test-registry-string-audit))
    true))
