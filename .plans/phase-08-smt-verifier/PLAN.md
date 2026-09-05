# Phase Plan: SMT-LIB2 Z3 Formal Theorem Prover (`z3-smt-formal-verifier`)

## Objective
Implement native S-expression to SMT-LIB2 theorem translator for contract safety verification:
- Prove conservation of balance: `sum(balances_after) == sum(balances_before) + msg.value - transfers_out`.
- Prove no unauthorized balance mutation (only sender or owner can mutate).
- Prove termination (total functional transitions with no unbounded iteration).
- Emit standardized SMT-LIB2 queries readable by Z3 and CVC5.

## Measurable Baseline for Gemma 31B
- Zero false proofs: 100% detection of reentrancy or balance-drain bugs in synthetic contract test suite.
- Verification turnaround latency: < 25 ms per contract function.

## Work Items
1. **SMT-LIB2 AST & Emitter (`asl/packages/asl-contracts/src/smt.asl`)**:
   - `SmtSort`: Int, Bool, BitVec256.
   - `SmtExpr`: `(assert ...)`, `(check-sat)`, `(declare-const ...)`.
   - Invariant Generator: Translates contract transitions and asserts safety invariants.
2. **Grammar Registration Update (`asl/packages/asl-contracts/grammar.asn`)**:
   - Register SMT types and functions.
3. **Verification Suite (`asl/packages/asl-contracts/tests/smt_test.asl`)**:
   - Test generation of conservation invariants, integer overflow checks, and check-sat generation.
4. **Gate Command**:
   - `asl test asl/packages/asl-contracts/tests/smt_test.asl`
