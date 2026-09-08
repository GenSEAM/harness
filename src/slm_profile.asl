(module asl-harness/slm-profile
  :d "SLM compact tooling profile and gateway driver with constrained decoding"
  :x [SlmTool
      SlmRequest
      make-slm-essential-tools
      filter-tool-schema
      format-slm-request]
  :i [])

(dfs SlmTool
  (:f name Str "Tool identifier e.g. probe, patch, gate, done")
  (:f description Str "Compact description of tool functionality")
  (:f parameters-summary Str "Compact parameter schema signature"))

(dfs SlmRequest
  (:f model Str "Target SLM gateway model identifier")
  (:f system-prompt Str "Constrained system prompt directive")
  (:f tools (List SlmTool) "List of active essential tools")
  (:f temperature F64 "Decoding temperature")
  (:f max-tokens I64 "Token generation budget"))

(df make-slm-essential-tools [] -> (List SlmTool)
  :d "Packages the minimal 4-tool essential schema for small language models."
  (let [(t-probe (SlmTool
                   :name "probe"
                   :description "Inspect symbols, outlines, and file content"
                   :parameters-summary "(:path Str [:symbol Str])"))
        (t-patch (SlmTool
                   :name "patch"
                   :description "Stage surgical in-memory AST or text replacements"
                   :parameters-summary "(:path Str :old Str :new Str)"))
        (t-gate (SlmTool
                  :name "gate"
                  :description "Run verification gate command or test suite"
                  :parameters-summary "(:cmd Str)"))
        (t-done (SlmTool
                  :name "done"
                  :description "Declare task complete with physical receipt"
                  :parameters-summary "(:receipt Str)"))]
    (list t-probe t-patch t-gate t-done)))

(df filter-tool-schema [(tools (List SlmTool)) (allowed-names (List Str))] -> (List SlmTool)
  :d "Filters tools keeping only those present in allowed names list."
  (fold (fn [(acc (List SlmTool)) (t SlmTool)] -> (List SlmTool)
          (if (list-contains? allowed-names (.-name t))
            (list-append acc (list t))
            acc))
        (list)
        tools))

(df format-slm-request [(req SlmRequest)] -> Str
  :d "Formats an SLM request into a compact ASN representation for gateway dispatch."
  (let [(tools-list (.-tools req))
        (tools-formatted (fold (fn [(acc Str) (t SlmTool)] -> Str
                                 (let [(line (str "    (:tool :name \"" (.-name t) "\" :params \"" (.-parameters-summary t) "\")"))]
                                   (if (string-empty? acc) line (str acc "\n" line))))
                               ""
                               tools-list))]
    (str "(:slm-request\n"
         "  :model \"" (.-model req) "\"\n"
         "  :system \"" (.-system-prompt req) "\"\n"
         "  :temperature " (string-from-float64 (.-temperature req)) "\n"
         "  :max-tokens " (string-from-int64 (.-max-tokens req)) "\n"
         "  :tools [\n"
         tools-formatted "\n"
         "  ])")))
