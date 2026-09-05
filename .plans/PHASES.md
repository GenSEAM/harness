# Master Roadmap: Autonomous Cognitive Gateway & Execution Harness Ecosystem

```mermaid
graph TD
    subgraph Wave0 ["Wave 0: Harness, Anti-Hallucination & Coding Tooling (P0)"]
        W0_1["harness-action-firewall"]
        W0_2["harness-grammar-fsm"]
        W0_3["coding-repl-inspector"]
    end

    subgraph Wave1 ["Wave 1: Blackboard DAG, Bus Backpressure & Lens (P1)"]
        W1_1["agent-core-blackboard-dag"]
        W1_2["bus-credit-backpressure"]
        W1_3["intel-lens-cartography"]
    end

    subgraph Wave2 ["Wave 2: VectorSlab SQ8 & Verifiable Contracts (P1)"]
        W2_1["mem-vectorslab-sq8"]
        W2_2["z3-smt-formal-verifier"]
        W2_3["wasm-stylus-target"]
    end

    subgraph Wave3 ["Wave 3: Agent Escrow, Web Cockpit & E2E SWE-bench (P1)"]
        W3_1["agent-escrow-benchmark"]
        W3_2["cockpit-visual-galaxy"]
        W3_3["e2e-swe-bench-verification"]
    end

    W0_1 --> W1_1
    W0_2 --> W1_2
    W0_3 --> W1_3
    W1_1 --> W2_1
    W1_1 --> W2_2
    W1_2 --> W2_3
    W2_1 --> W3_1
    W2_2 --> W3_1
    W1_3 --> W3_2
    W0_1 --> W3_3
    W0_2 --> W3_3
    W0_3 --> W3_3
```

## Phase DAG & Disjoint Ownership Table

| Phase ID | Wave | Priority | Dependencies | Owns (Exclusive Patterns) | Gate Command | Status |
|---|:---:|:---:|---|---|---|:---:|
| `harness-action-firewall` | **Wave 0** | **P0** | `[]` | `harness/src/firewall.asl`<br>`harness/tests/firewall-test.asl` | `asl test harness/tests/firewall-test.asl` | `done` |
| `harness-grammar-fsm` | **Wave 0** | **P0** | `[]` | `harness/src/fsm-normalizer.asl`<br>`harness/tests/fsm-normalizer-test.asl` | `asl test harness/tests/fsm-normalizer-test.asl` | `done` |
| `coding-repl-inspector` | **Wave 0** | **P0** | `[]` | `harness/src/repl.asl`<br>`harness/tests/repl-test.asl` | `asl test harness/tests/repl-test.asl` | `done` |
| `agent-core-blackboard-dag` | **Wave 1** | **P1** | `["harness-action-firewall"]` | `agent-core/src/blackboard.asl`<br>`agent-core/tests/blackboard-test.asl` | `asl test agent-core/tests/blackboard-test.asl` | `pending` |
| `bus-credit-backpressure` | **Wave 1** | **P1** | `["harness-grammar-fsm"]` | `agent-bus/src/backpressure.asl`<br>`agent-bus/tests/backpressure-test.asl` | `asl test agent-bus/tests/backpressure-test.asl` | `pending` |
| `intel-lens-cartography` | **Wave 1** | **P1** | `["coding-repl-inspector"]` | `intel/src/lens.asl`<br>`intel/tests/lens-test.asl` | `asl test intel/tests/lens-test.asl` | `pending` |
| `mem-vectorslab-sq8` | **Wave 2** | **P1** | `["agent-core-blackboard-dag"]` | `mem/src/vectorslab.asl`<br>`mem/tests/vectorslab-test.asl` | `asl test mem/tests/vectorslab-test.asl` | `pending` |
| `z3-smt-formal-verifier` | **Wave 2** | **P1** | `["agent-core-blackboard-dag"]` | `asl/packages/asl-contracts/src/smt.asl`<br>`asl/packages/asl-contracts/tests/smt_test.asl` | `asl test asl/packages/asl-contracts/tests/smt_test.asl` | `pending` |
| `wasm-stylus-target` | **Wave 2** | **P1** | `["bus-credit-backpressure"]` | `asl/packages/asl-contracts/src/stylus_abi.asl`<br>`asl/packages/asl-contracts/tests/stylus_test.asl` | `asl test asl/packages/asl-contracts/tests/stylus_test.asl` | `pending` |
| `agent-escrow-benchmark` | **Wave 3** | **P1** | `["z3-smt-formal-verifier", "wasm-stylus-target"]` | `asl/packages/asl-contracts/examples/escrow.asl`<br>`asl/packages/asl-contracts/tests/escrow_test.asl` | `asl test asl/packages/asl-contracts/tests/escrow_test.asl` | `pending` |
| `cockpit-visual-galaxy` | **Wave 3** | **P1** | `["intel-lens-cartography"]` | `web/src/components/CockpitGalaxy.asl`<br>`web/tests/cockpit-test.asl` | `asl test web/tests/cockpit-test.asl` | `pending` |
| `e2e-swe-bench-verification` | **Wave 3** | **P1** | `["harness-action-firewall", "coding-repl-inspector"]` | `harness/benchmark/run_e2e_verified.sh` | `zsh -c 'harness/benchmark/run_e2e_verified.sh --check'` | `pending` |
