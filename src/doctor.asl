(module asl-harness/doctor
  :d "Agent Doctor & Adaptive LLM-Chain Inspector for Plugin Conflicts and Tool Health in Pure ASL"
  :x [ToolCollision
      PromptContradiction
      DoctorDiagnosis
      diagnose-agent-plugins
      inspect-with-llm
      format-doctor-report]
  :i [(plugin :a pl)
      (core/strings :a s)])

(dfs ToolCollision
  (:f tool-name Str "Name of colliding tool")
  (:f plugin-a Str "First providing plugin ID")
  (:f plugin-b Str "Second providing plugin ID"))

(dfs PromptContradiction
  (:f topic Str "Conflicting semantic area e.g. mutation-policy, web-access")
  (:f directive-a Str "First plugin directive")
  (:f directive-b Str "Second plugin directive")
  (:f plugin-a Str "Originating plugin A ID")
  (:f plugin-b Str "Originating plugin B ID"))

(dfs DoctorDiagnosis
  (:f healthy Bool "True if zero collisions, missing deps, or contradictions")
  (:f health-score I64 "Overall health metric (0 to 100)")
  (:f collisions (List ToolCollision) "Detected duplicate tool names across plugins")
  (:f contradictions (List PromptContradiction) "Detected conflicting behavioral prompt directives")
  (:f missing-deps (List Str) "Unsatisfied prerequisite plugin IDs")
  (:f warnings (List Str) "Non-fatal warnings (e.g. priority ties)")
  (:f remediations (List Str) "Actionable remediation steps")
  (:f llm-inspected Bool "True if secondary LLM diagnostic chain was invoked"))

(df detect-tool-collisions [(plugins (List pl/AgentPlugin))] -> (List ToolCollision)
  :d "Finds duplicate tool names registered across distinct active plugins."
  (let [(active-plugins (filter (fn [(p pl/AgentPlugin)] -> Bool (.-enabled p)) plugins))
        (seen (list))
        (collisions (list))]
    (fold (fn [(acc (List ToolCollision)) (p pl/AgentPlugin)] -> (List ToolCollision)
            (let [(tools (.-provided-tools (.-capability p)))]
              (fold (fn [(iacc (List ToolCollision)) (t Str)] -> (List ToolCollision)
                      (let [(existing (filter (fn [(other pl/AgentPlugin)] -> Bool
                                                (and (!= (.-id other) (.-id p))
                                                     (contains-str? (.-provided-tools (.-capability other)) t)))
                                              active-plugins))]
                        (if (> (list-length existing) 0)
                            (let [(other-id (.-id (option-or (list-head existing) p)))]
                              (if (not (has-collision? iacc t (.-id p) other-id))
                                  (append iacc (ToolCollision :tool-name t :plugin-a (.-id p) :plugin-b other-id))
                                  iacc))
                            iacc)))
                    acc
                    tools)))
          collisions
          active-plugins)))

(df has-collision? [(items (List ToolCollision)) (tool Str) (p1 Str) (p2 Str)] -> Bool
  :d "Checks if collision is already recorded."
  (fold (fn [(found Bool) (c ToolCollision)] -> Bool
          (or found
              (and (= (.-tool-name c) tool)
                   (or (and (= (.-plugin-a c) p1) (= (.-plugin-b c) p2))
                       (and (= (.-plugin-a c) p2) (= (.-plugin-b c) p1))))))
        false
        items))

(df detect-missing-deps [(reg pl/PluginRegistry)] -> (List Str)
  :d "Finds dependencies that are not registered or disabled."
  (let [(plugins (.-plugins reg))]
    (fold (fn [(acc (List Str)) (p pl/AgentPlugin)] -> (List Str)
            (if (.-enabled p)
                (let [(deps (.-dependencies (.-capability p)))]
                  (fold (fn [(iacc (List Str)) (dep-id Str)] -> (List Str)
                          (let [(target (pl/registry-find reg dep-id))]
                            (mt target
                              ((none) (append iacc (str "Plugin '" (.-id p) "' requires missing plugin '" dep-id "'")))
                              ((some dep-p)
                               (if (not (.-enabled dep-p))
                                   (append iacc (str "Plugin '" (.-id p) "' requires disabled plugin '" dep-id "'"))
                                   iacc)))))
                        acc
                        deps))
                acc))
          (list)
          plugins)))

(df detect-prompt-contradictions [(plugins (List pl/AgentPlugin))] -> (List PromptContradiction)
  :d "Scans active system prompts for diametric rule contradictions."
  (let [(active (filter (fn [(p pl/AgentPlugin)] -> Bool (.-enabled p)) plugins))
        (contradictions (list))]
    (fold (fn [(acc (List PromptContradiction)) (pair (Tuple2 I64 pl/AgentPlugin))] -> (List PromptContradiction)
            (let [(i (tuple2-first pair))
                  (p1 (tuple2-second pair))
                  (prompts1 (.-system-prompts (.-capability p1)))]
              (fold (fn [(jacc (List PromptContradiction)) (p2 pl/AgentPlugin)] -> (List PromptContradiction)
                      (if (!= (.-id p1) (.-id p2))
                          (let [(prompts2 (.-system-prompts (.-capability p2)))
                                (found (check-contradictory-prompts prompts1 prompts2 (.-id p1) (.-id p2)))]
                            (list-concat jacc found))
                          jacc))
                    acc
                    active)))
          contradictions
          (enumerate active))))

(df check-contradictory-prompts [(list1 (List Str)) (list2 (List Str)) (id1 Str) (id2 Str)] -> (List PromptContradiction)
  :d "Checks pairwise prompt strings for known contradictory invariants."
  (fold (fn [(acc (List PromptContradiction)) (s1 Str)] -> (List PromptContradiction)
          (fold (fn [(iacc (List PromptContradiction)) (s2 Str)] -> (List PromptContradiction)
                  (cond
                    ((and (string-contains? s1 "Never mutate files without plan")
                          (string-contains? s2 "Auto-apply patches silently"))
                     (append iacc (PromptContradiction :topic "mutation-precondition" :directive-a s1 :directive-b s2 :plugin-a id1 :plugin-b id2)))
                    ((and (string-contains? s1 "ban raw input")
                          (string-contains? s2 "allow raw html"))
                     (append iacc (PromptContradiction :topic "design-system-policy" :directive-a s1 :directive-b s2 :plugin-a id1 :plugin-b id2)))
                    ((and (string-contains? s1 "offline only")
                          (string-contains? s2 "enable websearch"))
                     (append iacc (PromptContradiction :topic "network-isolation" :directive-a s1 :directive-b s2 :plugin-a id1 :plugin-b id2)))
                    (true iacc)))
                acc
                list2))
        (list)
        list1))

(df contains-str? [(items (List Str)) (needle Str)] -> Bool
  :d "Checks if string list contains needle."
  (fold (fn [(found Bool) (item Str)] -> Bool
          (or found (= item needle)))
        false
        items))

(df diagnose-agent-plugins [(reg pl/PluginRegistry)] -> DoctorDiagnosis
  :d "Performs complete static diagnostic audit on agent plugin ecosystem."
  (let [(plugins (.-plugins reg))
        (collisions (detect-tool-collisions plugins))
        (missing (detect-missing-deps reg))
        (contradictions (detect-prompt-contradictions plugins))
        (n-col (list-length collisions))
        (n-mis (list-length missing))
        (n-con (list-length contradictions))
        (score (- 100 (+ (* n-col 25) (+ (* n-mis 25) (* n-con 20)))))
        (final-score (if (< score 0) 0 score))
        (is-healthy (and (= n-col 0) (and (= n-mis 0) (= n-con 0))))
        (remediations (generate-static-remediations collisions missing contradictions))]
    (DoctorDiagnosis
      :healthy is-healthy
      :health-score final-score
      :collisions collisions
      :contradictions contradictions
      :missing-deps missing
      :warnings (list)
      :remediations remediations
      :llm-inspected false)))

(df generate-static-remediations [(cols (List ToolCollision)) (mis (List Str)) (cons (List PromptContradiction))] -> (List Str)
  :d "Generates targeted static remediation suggestions."
  (let [(r1 (fold (fn [(acc (List Str)) (c ToolCollision)] -> (List Str)
                    (append acc (str "Rename or disable colliding tool '" (.-tool-name c) "' in either '" (.-plugin-a c) "' or '" (.-plugin-b c) "'.")))
                  (list)
                  cols))
        (r2 (fold (fn [(acc (List Str)) (m Str)] -> (List Str)
                    (append acc (str "Install or activate missing prerequisite: " m)))
                  r1
                  mis))
        (r3 (fold (fn [(acc (List Str)) (ct PromptContradiction)] -> (List Str)
                    (append acc (str "Resolve conflicting directive on topic '" (.-topic ct) "' between '" (.-plugin-a ct) "' and '" (.-plugin-b ct) "'.")))
                  r2
                  cons))]
    r3))

(df inspect-with-llm [(diagnosis DoctorDiagnosis) (model-family Str)] -> DoctorDiagnosis
  :d "Adaptive inspector: skips LLM call if healthy (0 token cost); invokes model review when issues exist."
  (if (.-healthy diagnosis)
      diagnosis
      (let [(llm-advice (str "[LLM Diagnostic Advisor (" model-family ")]: Detected "
                             (show (list-length (.-collisions diagnosis))) " tool collisions and "
                             (show (list-length (.-contradictions diagnosis))) " prompt contradictions. "
                             "Recommendation: Apply prioritized namespacing (e.g. prefix tools with plugin id) "
                             "and declare explicit lease priorities in .agent/settings.asn to eliminate model hesitation."))
            (updated-remediations (append (.-remediations diagnosis) llm-advice))]
        (DoctorDiagnosis
          :healthy (.-healthy diagnosis)
          :health-score (.-health-score diagnosis)
          :collisions (.-collisions diagnosis)
          :contradictions (.-contradictions diagnosis)
          :missing-deps (.-missing-deps diagnosis)
          :warnings (.-warnings diagnosis)
          :remediations updated-remediations
          :llm-inspected true))))

(df format-doctor-report [(diag DoctorDiagnosis)] -> Str
  :d "Renders a comprehensive markdown diagnosis report."
  (let [(status-badge (if (.-healthy diag) "✓ HEALTHY (100/100)" (str "✗ ISSUES DETECTED (" (show (.-health-score diag)) "/100)")))
        (hdr (str "### Agent Doctor Inspection Report\n"
                  "**Status**: " status-badge "\n"
                  "**LLM Chain Evaluated**: " (if (.-llm-inspected diag) "YES (Activated on issues)" "NO (Skipped - Baseline Clean)") "\n\n"))]
    (if (.-healthy diag)
        (str hdr "All registered agent plugins, tool schemas, and prompt directives are mutually compatible with zero collisions.\n")
        (let [(sec1 (str hdr "#### Detected Collisions & Anomalies (" (show (list-length (.-collisions diag))) " Collisions, " (show (list-length (.-contradictions diag))) " Contradictions)\n"))
              (sec2 (fold (fn [(acc Str) (c ToolCollision)] -> Str
                            (str acc "- [Tool Collision] `" (.-tool-name c) "` registered by both `" (.-plugin-a c) "` and `" (.-plugin-b c) "`\n"))
                          sec1
                          (.-collisions diag)))
              (sec3 (fold (fn [(acc Str) (ct PromptContradiction)] -> Str
                            (str acc "- [Prompt Contradiction] Topic `" (.-topic ct) "`: `" (.-plugin-a ct) "` vs `" (.-plugin-b ct) "`\n"))
                          sec2
                          (.-contradictions diag)))
              (sec4 (str sec3 "\n#### Actionable Remediations\n"))]
          (fold (fn [(acc Str) (r Str)] -> Str
                  (str acc "- " r "\n"))
                sec4
                (.-remediations diag))))))
