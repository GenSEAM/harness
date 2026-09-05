---
name: asl-harness
description: Autonomous Agent Coding Harness with in-memory deterministic execution routing, hallucination normalization, and SWE-bench multi-arm benchmark evaluations on Gemma 31B. Use when benchmarking models, normalizing LLM syntax drift, or executing tools locally without LLM roundtrips.
---

# ASL Agent Coding Harness Skill

`asl-harness` provides a lightweight, sub-millisecond execution engine for autonomous coding agents.

## Core Capabilities
- **Local Execution Router**: Routes deterministic tools (`fs-read`, `fs-list`, `ast-search`, `intel-query`, `git-status`) directly to local execution tier, saving ~6,500 tokens per session.
- **Hallucination Normalizer**: Auto-repairs snake_case identifiers, maps keywords (`defun` -> `df`), and auto-balances unclosed parentheses.
- **SWE-bench Multi-Arm Evaluation**: Compares baseline Claude Code, Claude Code + GenSEAM tools, and native ASL harness.

## Running Verification
```bash
# Run harness test suite
asl test harness/tests/coding-test.asl

# Run SWE-bench comparison dry-run
harness/benchmark/run_comparison.sh --dry-run
```
