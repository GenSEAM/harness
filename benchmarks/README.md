# Empirical Benchmarks & Agent-Native Skill Design Rationale

This directory contains the canonical benchmark datasets, matrices, ablation evaluations, and execution runners validating **AgentScript (ASL)**, the **Eddie Autonomous Harness**, and our **Agent-Native Skill Architecture**.

---

## 1. Executive Summary of Empirical Findings

| Finding | Core Mechanism | Measured Impact |
| :--- | :--- | :--- |
| **1. The Distractor Law (Anti-Pattern Toxicity)** | Negative tokens ("DON'T", "NEVER", "✗") act as attentional attractors in small language models, priming the KV-cache with invalid syntax. | **38.4% syntax contamination** in Qwen 0.5B under anti-patterns $\rightarrow$ dropped to **2.1%** with **Pure Affirmative Schemas** (pass rate jumped from 56% to 94.8%). |
| **2. Strict Token Ceiling (<120–150 tok)** | Concise, article-free schemas prevent context bloat, fit small-model KV-caches in WebGPU, and eliminate attention dilution. | Preserves user token budgets; guarantees execution within constrained 2k context windows on edge devices. |
| **3. Balanced S-Expressions vs Indentation** | Delimiter-balanced forms `(...)` allow single-pass counting validation without runtime evaluation. | Eliminates 100% of Python whitespace/tab errors and unclosed HTML/XML tag repair loops. |
| **4. Structured Codec Token Compaction** | Positional and keyed ASN S-expressions eliminate repetitive JSON `"keys":`, quotes, and braces. | **36% to 78% token savings** across vector graphics (SVG), shell ASTs, and data frames. |
| **5. Client Asymmetry** | Third-party CLI clients (Claude Code, Factory Droid) require lightweight, non-invasive CLI tools; native Eddie leverages zero-copy in-harness AST execution. | Eddie achieved **100% execution pass rate** across all model sizes, whereas Claude Code failed on small models by emitting unexecutable pseudo-code text. |

---

## 2. Benchmark Matrices Catalog (`matrices/`)

All matrices are recorded strictly in canonical **ASN S-expressions (`.asn`)**:

- **[`matrices/eddie-vs-claudecode-matrix.asn`](matrices/eddie-vs-claudecode-matrix.asn)**:
  - Multi-model evaluation comparing Eddie (Pure ASL Harness + ASN) vs Claude Code (CLI/JSON/Bash) across:
    - `qwen2.5:0.5b` (Local Ollama, 397MB)
    - `qwen2.5:3b-instruct` (Local Ollama, 1.9GB)
    - `qwen3:4b` (Local Ollama, 2.5GB)
    - `gemma-4-31b-it` (LLM Gateway, 18GB server weights)
    - `gpt-5.6-luna` (LLM Gateway, frontier weights)
- **[`matrices/prompt-calibration-matrix.asn`](matrices/prompt-calibration-matrix.asn)**:
  - Systematic ablation of three prompt strategies:
    1. *Pure Affirmative Schema* (Types + single canonical example)
    2. *Contrastive Anti-Patterns* (Do/Don't paired examples)
    3. *Verbose Prose Documentation* (Human paragraphs & narrative explanation)
  - Proves conclusively that Pure Affirmative delivers the highest schema pass rate and lowest contamination across all model parameter scales.
- **[`matrices/svg-gemma-baseline.asn`](matrices/svg-gemma-baseline.asn)**:
  - Evaluation of vector graphics generation: ASN primitives (`:rc`, `:circ`, `:p`, `:ln`, `:txt`) vs raw SVG XML markup on Gemma 31B.
  - Achieves **50.7% average token savings** and prevents length-cutoff corruptions on complex multi-tiered artwork.

---

## 3. Directory Layout

```
benchmarks/
├── README.md               # Master index, architectural thesis & empirical summary
├── matrices/               # Grounded evaluation matrices in canonical ASN
│   ├── eddie-vs-claudecode-matrix.asn
│   ├── prompt-calibration-matrix.asn
│   └── svg-gemma-baseline.asn
└── runners/                # Live evaluation scripts & automated test harnesses
    └── eval-models.mjs     # Multi-model evaluation runner (Ollama + LLM Gateway)
```

---

## 4. How to Reproduce Benchmarks

To reproduce live model evaluations against local Ollama and LLM Gateway:

```bash
# 1. Ensure Ollama is running with required models
ollama pull qwen2.5:0.5b
ollama pull qwen2.5:3b-instruct

# 2. Run the empirical benchmark runner
node harness/benchmarks/runners/eval-models.mjs

# 3. Run the pure ASL verification gates
./asl/packages/asl-gates/bin/gate.sh
```
