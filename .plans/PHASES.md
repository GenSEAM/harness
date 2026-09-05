# Master Roadmap: Unified GenSEAM Autonomous Agent Ecosystem

```mermaid
graph TD
    subgraph Wave0 ["Wave 0: Harness, Anti-Hallucination & Coding Tooling (P0)"]
        W0_1["harness-action-firewall"]
        W0_2["harness-grammar-fsm"]
        W0_3["coding-repl-inspector"]
    end

    subgraph Wave1 ["Wave 1: Agent Core & Bus Streaming Integration (P1)"]
        W1_1["agent-core-asn-registry"]
        W1_2["bus-warm-agent-streaming"]
    end

    subgraph Wave2 ["Wave 2: Verifiable Contracts & Formal Proofs (P1)"]
        W2_1["z3-smt-formal-verifier"]
        W2_2["wasm-stylus-target"]
    end

    subgraph Wave3 ["Wave 3: End-to-End Escrow & SWE-bench Convergence (P1)"]
        W3_1["agent-escrow-benchmark"]
        W3_2["e2e-swe-bench-verification"]
    end

    W0_1 --> W1_1
    W0_2 --> W1_2
    W0_3 --> W1_2
    W1_1 --> W2_1
    W1_2 --> W2_2
    W2_1 --> W3_1
    W2_2 --> W3_1
    W0_1 --> W3_2
    W0_3 --> W3_2
```

## Phase DAG & Disjoint Ownership Table

| Phase ID | Wave | Priority | Dependencies | Owns (Exclusive Patterns) | Gate Command | Status |
|---|:---:|:---:|---|---|---|:---:|
| `harness-action-firewall` | **Wave 0** | **P0** | `[]` | `harness/src/firewall.asl`<br>`harness/tests/firewall-test.asl` | `asl test harness/tests/firewall-test.asl` | `ready` |
| `harness-grammar-fsm` | **Wave 0** | **P0** | `[]` | `harness/src/fsm-normalizer.asl`<br>`harness/tests/fsm-normalizer-test.asl` | `asl test harness/tests/fsm-normalizer-test.asl` | `ready` |
| `coding-repl-inspector` | **Wave 0** | **P0** | `[]` | `harness/src/repl.asl`<br>`harness/tests/repl-test.asl` | `asl test harness/tests/repl-test.asl` | `ready` |
| `agent-core-asn-registry` | **Wave 1** | **P1** | `["harness-action-firewall"]` | `agent-core/grammar.asn`<br>`agent-core/skills/agent-core/SKILL.md` | `asl test` | `pending` |
| `bus-warm-agent-streaming` | **Wave 1** | **P1** | `["harness-grammar-fsm", "coding-repl-inspector"]` | `agent-bus/src/stream.asl`<br>`agent-bus/tests/stream_test.asl` | `asl test agent-bus/tests/stream_test.asl` | `pending` |
| `z3-smt-formal-verifier` | **Wave 2** | **P1** | `["agent-core-asn-registry"]` | `asl/packages/asl-contracts/src/smt.asl`<br>`asl/packages/asl-contracts/tests/smt_test.asl` | `asl test asl/packages/asl-contracts/tests/smt_test.asl` | `pending` |
| `wasm-stylus-target` | **Wave 2** | **P1** | `["bus-warm-agent-streaming"]` | `asl/packages/asl-contracts/src/stylus_abi.asl`<br>`asl/packages/asl-contracts/tests/stylus_test.asl` | `asl test asl/packages/asl-contracts/tests/stylus_test.asl` | `pending` |
| `agent-escrow-benchmark` | **Wave 3** | **P1** | `["z3-smt-formal-verifier", "wasm-stylus-target"]` | `asl/packages/asl-contracts/examples/escrow.asl`<br>`asl/packages/asl-contracts/tests/escrow_test.asl` | `asl test asl/packages/asl-contracts/tests/escrow_test.asl` | `pending` |
| `e2e-swe-bench-verification` | **Wave 3** | **P1** | `["harness-action-firewall", "coding-repl-inspector"]` | `harness/benchmark/run_e2e_verified.sh` | `zsh -c 'harness/benchmark/run_e2e_verified.sh --check'` | `pending` |
