---
name: asl-slm
description: Small Language Model (SLM) local inference engine, Apple Silicon M1 unified memory telemetry, thinking vs non-thinking benchmarking, and offline evaluation.
---

# asl-slm: Native Tooling & Verification Guide

> [!IMPORTANT]
> Deterministically compiled from canonical ASN specification (`./asl/.agents/skills/asl-slm/skill.asn`).

## Rules of Engagement & Invariants

- **[mandatory]**: Run quantized local models (qwen2.5-coder:3b-instruct) within <2GB unified memory ceiling.
- **[workflow]**: Track time-to-first-token (TTFT), throughput (tok/s), and memory telemetry across reasoning traces.
- **[negative]**: FORBIDDEN: Never invoke cloud APIs during airgap offline SLM benchmarks.

## Tool Suite Reference

| Command | Purpose | Token Savings |
| :--- | :--- | :--- |
| `asl test harness/tests/m1-telemetry-test.asl` | Verify SLM local inference and unified memory telemetry | **90%** |
| `ASL_AIRGAP=1 node harness/benchmarks/runners/eval-models.mjs` | Execute local SLM benchmark evaluation | **88%** |

## Supported Agent Harnesses

- `claude-code`
- `factory-droid`
- `antigravity`
- `cursor`
- `windsurf`
- `universal-agents`
