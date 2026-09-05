# Phase Plan: Credit-Based Backpressure & ASN Binary Streaming (`bus-credit-backpressure`)

## Objective
Implement flow-control and binary streaming in `agent-bus`:
- Eliminate Silent Drops in IPC message queues via Credit-Based Backpressure (`:stalled`, `:retry true`).
- Native streaming S-expression frames (`STREAM_CHUNK`, `STREAM_END`) eliminating JSON stringify/parse in agent transport.
- Sub-millisecond Unix Domain Socket and in-memory ring buffer transport.

## Measurable Baseline for Gemma 31B
- Zero lost messages (0% packet drop) under 1,000 msg/sec synthetic flood.
- Wire serialization overhead: -64% token reduction vs JSON transport.
- Round-trip delivery latency: < 0.04 ms.

## Work Items
1. **Backpressure & Streaming Core (`agent-bus/src/backpressure.asl`)**:
   - `FlowCreditManager`: Tracks credits per connected subagent session.
   - `StreamingFrame`: `STREAM_CHUNK` and `STREAM_END` serializers.
   - `dispatch-with-backpressure`: Handles `:stalled` status when receiver queue is full.
2. **Grammar Update (`agent-bus/grammar.asn`)**:
   - Register backpressure symbols with token counts and rationales.
3. **Verification Suite (`agent-bus/tests/backpressure-test.asl`)**:
   - Test queue saturation, credit exhaustion, and resume signaling.
4. **Gate Command**:
   - `asl test agent-bus/tests/backpressure-test.asl`
