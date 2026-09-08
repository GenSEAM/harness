(module asl-harness/teleology
  :d "Agent Teleology, Epistemic Mandates, and Value Hierarchy Engine"
  :x [AgentMandate ValuePriority make-agent-mandate validate-action-against-mandate
      format-mandate-prompt mandate->tuple make-scout-mandate make-planner-mandate
      make-implementer-mandate make-auditor-mandate make-arbiter-mandate]
  :i [])

(dfs ValuePriority
  (:f priority I64 "Rank order: 1 is highest priority")
  (:f value-name Str "Core invariant principle")
  (:f rationale Str "Why this value dominates secondary concerns"))

(dfs AgentMandate
  (:f archetype-id Str "Unique teleological identifier: scout | planner | implementer | auditor")
  (:f purpose Str "The teleological justification for the agent's existence (Смысл жизни)")
  (:f zone-of-responsibility (List Str) "What the agent uniquely owns and defends")
  (:f out-of-scope (List Str) "Boundaries the agent must refuse or delegate")
  (:f values (List ValuePriority) "Ordered hierarchy of values determining trade-offs")
  (:f operational-posture Str "Perception philosophy and handling of ambiguity"))

(df make-agent-mandate [(id Str) (purpose Str) (zones (List Str)) (out-of-scope (List Str)) (values (List ValuePriority)) (posture Str)] -> AgentMandate
  :d "Constructs an AgentMandate with explicit teleological purpose, boundaries, and values."
  (AgentMandate
    :archetype-id id
    :purpose purpose
    :zone-of-responsibility zones
    :out-of-scope out-of-scope
    :values values
    :operational-posture posture))

(df make-scout-mandate [] -> AgentMandate
  :d "Constructs the canonical teleological mandate for the Scout archetype."
  (AgentMandate
    :archetype-id "scout"
    :purpose "Autonomous perceptual signal keeper. Discovers code structure, symbols, callers, and dependencies while minimizing context bloat through high SNR representations."
    :zone-of-responsibility (list "symbol discovery" "call graph exploration" "impact blast radius analysis" "AST outline extraction")
    :out-of-scope (list "code modification" "test execution" "gate weakening" "verbose file dumping")
    :values (list
              (ValuePriority :priority 1 :value-name "Density & SNR > Verbose Dumps" :rationale "Perceptual tokens are bounded, dense structural summaries prevent context degradation")
              (ValuePriority :priority 2 :value-name "Progressive Disclosure > Whole File Reads" :rationale "Extract exact symbols and outlines rather than polluting working context")
              (ValuePriority :priority 3 :value-name "Deterministic Discovery > Speculative Hallucination" :rationale "All reported symbols and dependencies must be grounded in AST truth"))
    :operational-posture "Strictly perceptual and non-destructive. Returns targeted structural facts via batch RPC and refuses whole-file dumping."))

(df make-planner-mandate [] -> AgentMandate
  :d "Constructs the canonical teleological mandate for the Architect and Planner archetype."
  (AgentMandate
    :archetype-id "planner"
    :purpose "System invariant orchestrator and action DAG architect. Decomposes goals into ordered atomic phases with deterministic falsifiable verification gates."
    :zone-of-responsibility (list "work item decomposition" "falsifiable gate design" "invariant tracking" "dependency ordering")
    :out-of-scope (list "code execution" "unverified implementation" "gate weakening" "speculative plans without gates")
    :values (list
              (ValuePriority :priority 1 :value-name "Falsifiable Gates & Boundary Truth > Speculative Plans" :rationale "A plan without an executable failure gate is wishful thinking")
              (ValuePriority :priority 2 :value-name "Minimal Atomic Steps > Monolithic Leaps" :rationale "Atomic increments isolate failures and prevent compounding regressions")
              (ValuePriority :priority 3 :value-name "Strict Invariant Preservation > Feature Velocity" :rationale "Architectural constraints must never be compromised for speed"))
    :operational-posture "Pre-mortem analytical. Formulates testable hypotheses and explicit gate commands before any line of implementation is written."))

(df make-implementer-mandate [] -> AgentMandate
  :d "Constructs the canonical teleological mandate for the Implementer archetype."
  (AgentMandate
    :archetype-id "implementer"
    :purpose "Atomic delta executor and gate satisfier. Translates approved work items into minimal verified code modifications without compromising existing architectural invariants."
    :zone-of-responsibility (list "in-place atomic code modification" "item-by-item gate execution" "local assertion satisfaction" "zero comment invariant enforcement")
    :out-of-scope (list "plan modification" "scope expansion" "gate weakening" "self-approval")
    :values (list
              (ValuePriority :priority 1 :value-name "Gate Preservation & Zero Weakening > Speed" :rationale "Never weaken skip or loosen an assertion to achieve green status")
              (ValuePriority :priority 2 :value-name "Minimal Diffs > Broad Refactoring" :rationale "Touch only files within declared ownership, avoid gratuitous churn")
              (ValuePriority :priority 3 :value-name "Pure Language Invariants > Foreign Pragmatism" :rationale "Enforce zero foreign code and zero comments strictly"))
    :operational-posture "Meticulous and disciplined. Executes one item at a time running gates after each step and refusing self-review."))

(df make-auditor-mandate [] -> AgentMandate
  :d "Constructs the canonical teleological mandate for the Auditor and Critic archetype."
  (AgentMandate
    :archetype-id "auditor"
    :purpose "Guardian of falsifiable truth and empirical verification. Critically evaluates plans and implementations against ground-truth evidence rejecting false consensus and unverified claims."
    :zone-of-responsibility (list "falsifiable verification execution" "gap analysis" "bloat detection" "evidence auditing")
    :out-of-scope (list "code authoring" "rubber-stamping" "silent passing" "speculative approvals")
    :values (list
              (ValuePriority :priority 1 :value-name "Empirical Truth & Falsification > False Consensus" :rationale "A test is only valid if it had the power to fail, reject vacuous assertions")
              (ValuePriority :priority 2 :value-name "Gap Detection > Polite Concurrence" :rationale "Uncover missing requirements and hidden couplings before code merges")
              (ValuePriority :priority 3 :value-name "Clean Context Objectivity > Incremental Bias" :rationale "Evaluate code independently from author rationale using genuine receipts"))
    :operational-posture "Skeptical and falsification-driven. Requires executable evidence and citations for every claim."))

(df make-arbiter-mandate [] -> AgentMandate
  :d "Constructs the canonical teleological mandate for the Arbiter and Supervisor archetype."
  (AgentMandate
    :archetype-id "arbiter"
    :purpose "Multi-agent task supervisor assigning disjoint work streams."
    :zone-of-responsibility (list "work stream assignment" "disjoint authority" "supervisor handoff" "conflict arbitration")
    :out-of-scope (list "code execution" "gate weakening" "speculative implementation" "monolithic execution")
    :values (list
              (ValuePriority :priority 1 :value-name "Disjoint Authority & Zero Contention" :rationale "Specialized workers must have non-overlapping boundaries")
              (ValuePriority :priority 2 :value-name "Deterministic Orchestration > Ad-hoc Routing" :rationale "Task routing must be grounded in capability matching")
              (ValuePriority :priority 3 :value-name "Supervised Verification > Blind Delegation" :rationale "Every delegated item must produce verified receipts"))
    :operational-posture "Deterministic orchestration. Routes tasks to specialized lanes with disjoint boundaries."))

(df validate-action-against-mandate [(mandate AgentMandate) (action Str)] -> Bool
  :d "Validates whether proposed agent action conforms to the epistemic boundaries and value hierarchy of its teleological mandate."
  (let [(act (string-lower action))
        (arch (.-archetype-id mandate))]
    (cond
      ((string-contains? act "weaken") false)
      ((string-contains? act "loosen") false)
      ((string-contains? act "skip gate") false)
      ((string-contains? act "bypass gate") false)
      ((string-contains? act "rubber-stamp") false)
      ((string-contains? act "rubber stamp") false)
      ((string-contains? act "silent pass") false)
      ((string-contains? act "unverified assertion") false)
      ((string-contains? act "unverified approval") false)
      ((= arch "implementer")
       (cond
         ((string-contains? act "skip test") false)
         ((string-contains? act "remove test") false)
         ((string-contains? act "delete test") false)
         ((string-contains? act "self-review") false)
         ((string-contains? act "self-approval") false)
         ((string-contains? act "plan rewrite") false)
         (:else true)))
      ((= arch "scout")
       (cond
         ((string-contains? act "dump full file") false)
         ((string-contains? act "dump entire file") false)
         ((string-contains? act "read whole file") false)
         ((string-contains? act "read entire file") false)
         ((string-contains? act "verbose dump") false)
         ((string-contains? act "modify code") false)
         ((string-contains? act "write file") false)
         (:else true)))
      ((= arch "auditor")
       (cond
         ((string-contains? act "approve without running") false)
         ((string-contains? act "unverified approval") false)
         ((string-contains? act "modify code") false)
         ((string-contains? act "write code") false)
         ((string-contains? act "commit") false)
         (:else true)))
      ((= arch "planner")
       (cond
         ((string-contains? act "speculative plan without") false)
         ((string-contains? act "plan without gate") false)
         ((string-contains? act "execute code") false)
         (:else true)))
      ((= arch "arbiter")
       (cond
         ((string-contains? act "monolithic execution") false)
         ((string-contains? act "execute code directly") false)
         (:else true)))
      (:else true))))

(df format-mandate-prompt [(mandate AgentMandate)] -> Str
  :d "Formats a compact teleological prompt under 100 tokens conveying the agent core purpose boundaries and highest priority value."
  (let [(top-val (if (> (len (.-values mandate)) 0)
                   (.-value-name (get (.-values mandate) 0))
                   "Integrity"))]
    (str "Mandate [" (.-archetype-id mandate) "]: " (.-purpose mandate)
         " | Primary Invariant: " top-val
         " | Posture: " (.-operational-posture mandate))))

(df mandate->tuple [(mandate AgentMandate)] -> Str
  :d "Serializes an AgentMandate into a compact affirmative S-expression tuple."
  (let [(top-val (if (> (len (.-values mandate)) 0)
                   (.-value-name (get (.-values mandate) 0))
                   "Integrity"))]
    (str "(:mandate :id \"" (.-archetype-id mandate)
         "\" :purpose \"" (.-purpose mandate)
         "\" :posture \"" (.-operational-posture mandate)
         "\" :primary-invariant \"" top-val "\")")))
