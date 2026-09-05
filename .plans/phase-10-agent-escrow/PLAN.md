# Phase Plan: Verifiable Agent-to-Agent Escrow Contract Benchmark (`agent-escrow-benchmark`)

## Objective
Build and benchmark a reference Agent Escrow Contract in pure AgentScript:
- Use Case: Agent A deposits bounty (e.g. 0.05 ETH) for context digest task. Agent B submits hash receipt. Timeout refunds Agent A.
- Demonstrate mathematical proof: Zero funds can be locked indefinitely or drained by unauthorized parties.
- Benchmark: Compare gas/token efficiency vs Solidity equivalent on Arbitrum Stylus and EVM.

## Measurable Baseline for Gemma 31B
- SMT proof resolution: 100% mathematical guarantee of no reentrancy or fund freeze.
- Contract code density: ~15 lines of ASL vs 85+ lines of Solidity (-82% token size).

## Work Items
1. **Reference Escrow Contract (`asl/packages/asl-contracts/examples/escrow.asl`)**:
   - Escrow State: `(dfe EscrowState [created funded completed refunded])`.
   - Pure transitions: `deposit`, `submit-proof`, `claim`, `timeout-refund`.
2. **End-to-End Escrow & Safety Proof Test Suite (`asl/packages/asl-contracts/tests/escrow_test.asl`)**:
   - Run full lifecycle (deposit -> proof -> claim), verify timeout logic, and verify that SMT safety theorem passes.
3. **Gate Command**:
   - `asl test asl/packages/asl-contracts/tests/escrow_test.asl`
