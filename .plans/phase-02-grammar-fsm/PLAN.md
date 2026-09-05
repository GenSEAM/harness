# Phase Plan: Grammar FSM Normalizer & Constrained Decoder (`harness-grammar-fsm`)

## Objective
Implement an algebraic Finite State Machine (FSM) grammar normalizer and constrained decoding validator:
- Pure FSM transition table: `(step-fsm ParserState Token -> (Pair ParserState FsmAction))`.
- Deterministic repair: Converts hallucinated keywords (`defun`, `lambda`, `defn`, `struct`) into canonical ASL.
- Delimiter closure: Completes truncated LLM outputs, guaranteeing zero unbalanced delimiters with 100% 1-pass validity.
- 100% pure AgentScript implementation in `harness/src/fsm-normalizer.asl`.

## Work Items
1. **FSM Normalizer Engine (`harness/src/fsm-normalizer.asl`)**:
   - `FsmState` (`idle`, `in-form`, `in-string`, `in-list`, `in-error`).
   - `FsmTransition` table mapping tokens to valid next states.
   - `normalize-token-stream`: Stream processor transforming token sequences.
   - `repair-syntax-fsm`: High-level wrapper returning validated canonical ASL.
2. **Grammar Registration**:
   - Register all types and functions in `harness/grammar.asn` with rationales for $> 2$ tokens.
3. **Verification Suite (`harness/tests/fsm-normalizer-test.asl`)**:
   - Test FSM state transitions on complex nested forms.
   - Test auto-repair of mixed Clojure/Python hallucinations.
   - Test truncated stream auto-completion.
4. **Gate Command**:
   - `asl test harness/tests/fsm-normalizer-test.asl`
