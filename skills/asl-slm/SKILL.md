---
name: asl-slm
description: Small Language Model (SLM) local inference engine, Apple Silicon M1 unified memory telemetry, thinking vs non-thinking benchmarking, and offline evaluation. Use when running local models, measuring tokens/sec, or benchmarking without external API dependencies.
---

# ASL-SLM (Small Language Model Inference & Telemetry)

`asl-slm` provides a lightweight, pure ASL interface for orchestrating and evaluating Small Language Models (SLMs) locally on Apple Silicon and unified memory hardware.

## Core Capabilities
- **Unified Memory Local Inference**: Runs quantized local models (Qwen 2.5 Coder 0.5B/7B, Gemma 31B) with zero cloud API dependencies.
- **Thinking vs Non-Thinking Telemetry**: Measures time-to-first-token, generation throughput (tok/s), and cognitive overhead across thinking models.
- **Strict Offline Benchmark Policy**: Mandates offline execution (`websearch-enabled: false`) to eliminate contamination and cheating on coding evaluations.

## Verification & Benchmarks
```bash
# Run local model telemetry verification
asl test harness/tests/m1-telemetry-test.asl

# Run offline benchmark evaluation
asl test harness/tests/swe-bench-test.asl
```
