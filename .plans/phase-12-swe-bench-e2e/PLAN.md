# Phase Plan: SWE-bench Verified E2E Integration & Benchmark (`e2e-swe-bench-verification`)

## Objective
Implement and verify the full end-to-end autonomous coding evaluation pipeline integrating the Wave 0 Cognitive Gateways (Action Firewall, Grammar FSM Normalizer, Coding REPL) with the SWE-bench Verified task harness:
- Run verified golden tasks through the full sensory and action pipeline.
- Verify that every tool execution, AST patch, and file edit passes through the Action Firewall and FSM normalizer.
- Establish empirical benchmark reporting measuring token consumption, execution latency, and resolve rates specifically calibrated for Gemma 31B (`gemma-4-31b-it`).

## Measurable Baseline for Gemma 31B
- **Token Efficiency**: $\ge 65\%$ token savings per issue turnaround using ASN Perceptual Pointers vs raw text dumping.
- **Hallucination Prevention**: 100% of out-of-contract file edits, illegal deletes, and syntax deviations blocked prior to workspace mutation.
- **Syntactic Correctness**: 100% valid ASN syntax emitted after single-pass FSM normalization.
- **SWE-bench Verified Resolve Rate**: $\ge 42\%$ on targeted verified subset with cost $< \$1.00$ per resolved instance.
- **Evaluation Turnaround**: $< 120$ seconds total turnaround per verified issue attempt.

## Work Items
1. **E2E Benchmark Runner (`harness/benchmark/run_e2e_verified.sh`)**:
   - Supports `--check` mode for automated fast CI/gate validation.
   - Orchestrates task instantiation, harness isolation, AST mutation validation, and test pass/fail grading.
   - Outputs standardized JSON/ASN benchmark telemetry report with Gemma 31B calibration fields.
2. **Benchmark Golden Test Suite (`harness/benchmark/test_suite.asl`)**:
   - Pure ASL test driver validating end-to-end execution of a synthetic multi-file refactor task.
   - Asserts firewall boundary checks, normalizer recovery, and REPL evaluation.
3. **Gate Command**:
   - `zsh -c 'harness/benchmark/run_e2e_verified.sh --check'`
