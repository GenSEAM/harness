(module asl-harness/pre-mortem
  :d "Stage 4 Pre-Mortem reasoning engine: evaluates consequence risks against architectural invariants, enforces 2-hop speculation ceiling, and generates falsification triggers."
  :x [ConsequenceRisk
      PreMortemVerdict
      evaluate-pre-mortem
      generate-falsification-trigger]
  :i [])

(dfs ConsequenceRisk
  (:f description Str "Human-readable description of potential consequence or failure mode")
  (:f hop-count I64 "Speculative reasoning depth / causal chain distance (must be <= 2)")
  (:f falsification-trigger Str "Executable assertion command that fails if the risk manifests")
  (:f severity Str "Severity rating: low | medium | high | critical")
  (:f is-grounded Bool "True if hop-count <= 2 and supported by workspace AST/facts"))

(dfs PreMortemVerdict
  (:f passed Bool "True if all hypothesized consequences are grounded (hop-count <= 2) and no critical unmitigated risks")
  (:f consequences (List ConsequenceRisk) "List of evaluated consequence risks")
  (:f blocked-reasons (List Str) "Reasons for pre-mortem gate failure (e.g. speculation ceiling exceeded, missing trigger)"))

(dfs PreMortemAcc
  (:f evaluated (List ConsequenceRisk) "Evaluated consequence risks")
  (:f reasons (List Str) "Accumulated failure reasons"))

(df generate-falsification-trigger [(risk-name Str) (target-file Str) (assertion-condition Str)] -> Str
  :d "Generates a deterministic, executable falsification trigger command string that falsifies the hypothesized risk."
  (str "asl test --strict-falsify " target-file " --assert \"" risk-name ":" assertion-condition "\""))

(df evaluate-pre-mortem [(action-description Str) (risks (List ConsequenceRisk)) (max-hops I64)] -> PreMortemVerdict
  :d "Evaluates consequence risks against architectural invariants and enforces the strict 2-hop speculation ceiling (max-hops <= 2). Flags any risk with hop-count > max-hops as ungrounded hallucination, populating blocked-reasons and setting passed to false."
  (let [(effective-max (if (> max-hops 2) 2 (if (< max-hops 0) 0 max-hops)))
        (initial-acc (PreMortemAcc :evaluated (list) :reasons (list)))
        (final-acc (fold (fn [(acc PreMortemAcc) (r ConsequenceRisk)] -> PreMortemAcc
                           (let [(desc (.-description r))
                                 (hops (.-hop-count r))
                                 (trig (.-falsification-trigger r))
                                 (sev (.-severity r))
                                 (init-grounded (.-is-grounded r))
                                 (exceeds-ceiling (> hops effective-max))
                                 (missing-trigger (string-empty? trig))
                                 (is-critical (= sev "critical"))
                                 (unanchored (not init-grounded))
                                 (now-grounded (and (not exceeds-ceiling) (and (not missing-trigger) init-grounded)))
                                 (eval-risk (ConsequenceRisk
                                              :description desc
                                              :hop-count hops
                                              :falsification-trigger trig
                                              :severity sev
                                              :is-grounded now-grounded))
                                 (r1 (if exceeds-ceiling
                                         (list-concat (.-reasons acc) (list (str "Speculation ceiling exceeded for '" desc "': hop-count " (string-from-int64 hops) " exceeds ceiling " (string-from-int64 effective-max))))
                                         (.-reasons acc)))
                                 (r2 (if missing-trigger
                                         (list-concat r1 (list (str "Missing falsification trigger for consequence: '" desc "'")))
                                         r1))
                                 (r3 (if is-critical
                                         (list-concat r2 (list (str "Critical unmitigated consequence risk: '" desc "'")))
                                         r2))
                                 (r4 (if (and unanchored (not exceeds-ceiling))
                                         (list-concat r3 (list (str "Ungrounded consequence risk: '" desc "'")))
                                         r3))]
                             (PreMortemAcc
                               :evaluated (list-concat (.-evaluated acc) (list eval-risk))
                               :reasons r4)))
                         initial-acc
                         risks))
        (all-reasons (.-reasons final-acc))
        (passed (= (list-length all-reasons) 0))]
    (PreMortemVerdict
      :passed passed
      :consequences (.-evaluated final-acc)
      :blocked-reasons all-reasons)))
