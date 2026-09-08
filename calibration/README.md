# Sovereign Model Calibration Registry & Knowledge Base

Canonical empirical registry for model calibration, stratified canary benchmarks, parameter sweeps, and harness steering profiles in AgentScript.

---

## 1. Epistemic Separation of Duties

To eliminate confusion between historical benchmark evaluation dumps and model calibration registries, the repository enforces a strict two-pillar architecture:

| Pillar | Directory | Purpose | Primary Artifacts |
| :--- | :--- | :--- | :--- |
| **Model Calibration Registry** | `harness/calibration/` | Model calibration configurations, optimal sampling parameters, context strategies, and canary task performance. | `model-calibration-registry.asn`<br>`canary-tasks.asn`<br>`knowledge-base/models.asn`<br>`prompt-calibration-matrix.asn`<br>`context-assembly-matrix.asn` |
| **Benchmark Execution Results** | `harness/results/` | Raw empirical outputs, transcripts, trace logs, and execution diffs from external benchmark suites. | `terminal-bench-4/`<br>`swe-bench/`<br>`svg-vector/`<br>`eddie-vs-claudecode-matrix.asn` |

---

## 2. Model Calibration Registry (`model-calibration-registry.asn`)

The master machine-readable ledger tracking:
1. **Calibrated Model Configurations**:
   - `model-id`: Exact family and scale (e.g. `qwen2.5:0.5b`, `qwen2.5:14b-instruct`, `gemini-2.5-flash`, `gemma-4-31b-it`, `claude-3-7-sonnet`).
   - `temperature`: Optimal sampling temperature (0.0 to 0.2).
   - `strategy`: Context assembly mode (`S1-baseline`, `S2-receipts`, `S3-jit-memory`, `S4-agent-directed`).
   - `budget-ceiling`: Enforced context token cap.
   - `pareto-score`: Scalar efficiency metric balancing solve rate, tokens, and latency.
2. **Stratified Canary Results**:
   - Continuous subtest progress (`ctrf-progress`).
   - Binary pass rate on tier canaries.
   - Amnesia detection.
3. **Pareto Frontier**:
   - Best-in-tier configuration recommendation across Micro-SLM, Small-SLM, Medium, Frontier, and Horizon.
4. **Active System Invariants**:
   - Verification status of `c-0001` (zero comments), `c-0002` (zero emojis), `c-0003` (boundary universalism), `l7-cot` (reasoning quarantine), `l7-esh` (verbal execution ban), `l7-gateway` (single LLM nexus).

---

## 3. Stratified Calibration Challenge Suite (`canary-tasks.asn`)

A 17-task continuous spectrum eliminating artificial binary score ceilings and plateaus:

- **Tier 1: Micro-SLM Invariants (0.5B - 3B)**:
  5 tasks (`SLM-DELIM-01` .. `SLM-DELIM-05`) evaluating delimiter balance, keyword arguments, affirmative schemas, monomorphic typestates, and token eviction.
- **Tier 2: Medium SLM & Flash Models (7B - 14B)**:
  5 tasks (`MED-PARSE-01` .. `MED-PARSE-05`) evaluating AST form patching, staged edit reconciliation, BM25 spool search, worktree routing, and receipt spooling.
- **Tier 3: Frontier Reasoning (31B - Frontier)**:
  5 tasks (`FRONT-HEAP-01` .. `FRONT-HEAP-05`) evaluating linear memory heap crash diagnosis, blast-radius graph cycles, verbal ESH interception, and LCS grounding.
- **Tier 4: Horizon Impossible Ceiling**:
  2 tasks (`IMPOSSIBLE-DISTRIB-CONSENSUS-01`, `IMPOSSIBLE-ZERO-ALLOC-GC-02`) with a known 0.0% baseline solve rate, preserving continuous discriminative headroom.

---

## 4. Model Profile Cards (`knowledge-base/models.asn`)

Ground-truth profiles utilized by `calibration_kb.asl` and Eddie's auto-configuration engine to mount knowledge, clamp context tokens, and set sampling hyperparameters dynamically upon model selection.
