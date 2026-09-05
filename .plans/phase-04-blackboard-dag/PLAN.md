# Phase Plan: Blackboard Memory & Task-Premise DAG (`agent-core-blackboard-dag`)

## Objective
Implement Blackboard Memory, Task-Premise DAG $G = (V, E, P, H)$, and Falsified Premise Registry in `agent-core`:
- Formal graph structure $G = (V, E, P, H)$ where tasks $V$ depend on truth predicates $P$.
- O(1) cascade invalidation: when premise $p_x$ is refuted, dependent task subtrees transition to `Invalidated`.
- Falsified Premise Registry prevents Gemma 31B from falling into repetitive reasoning loops (Context Rot).
- Distributed Wait-For Graph (DWFG) detects cross-agent deadlocks and aborts low-priority cycles with `DEADLOCK_DETECTED`.

## Measurable Baseline for Gemma 31B
- Loop recurrence rate: 0% repeated attempts on refuted premises (vs ~35% baseline).
- Context token consumption: -45% reduction by offloading state history to Blackboard.
- Deadlock detection latency: < 1 ms.

## Work Items
1. **Blackboard & Premise Engine (`agent-core/src/blackboard.asl`)**:
   - Types: `TaskNode`, `PremisePredicate`, `PremiseRegistry`, `BlackboardGraph`.
   - Operations: `add-task`, `invalidate-premise`, `record-falsified-premise`, `detect-dwfg-deadlock`.
2. **Grammar Registration (`agent-core/grammar.asn`)**:
   - Register all exported symbols with `:rationale` for $> 2$ tokens.
3. **Colocated Skill (`agent-core/skills/agent-core/SKILL.md`)**:
   - Skill documentation for blackboard memory and task DAG transitions.
4. **Verification Suite (`agent-core/tests/blackboard-test.asl`)**:
   - Unit tests for cascade invalidation, premise blacklisting, and DWFG deadlock detection.
5. **Gate Command**:
   - `asl test agent-core/tests/blackboard-test.asl`
