# Phase Plan: Web Cockpit Architecture Galaxy & Time-Travel Tree (`cockpit-visual-galaxy`)

## Objective
Implement pure ASL web components for the Web Cockpit dashboard:
- Interactive Architecture Galaxy: Visual representation of modules, code volume, and live SSE message traffic.
- Task-Premise DAG & Time-Travel Tree: Visualizes branched tasks and invalidated hypotheses with 1-click state rollback.
- Epistemic HUD: Real-time telemetry on blocked hallucinations (TSH, TCH, AST mutations).

## Measurable Baseline for Gemma 31B
- Real-time rendering latency: < 16 ms (60 FPS smooth web update via ASL DOM diffing).
- State rollback latency: < 2 ms on user-triggered premise invalidation.

## Work Items
1. **Cockpit UI Components (`web/src/components/CockpitGalaxy.asl`)**:
   - `GalaxyNode`: Visual node representation with health indicator.
   - `TimeTravelTree`: Visual DAG tree renderer.
   - `EpistemicHud`: Metric counters for active security firewalls.
2. **Verification Suite (`web/tests/cockpit-test.asl`)**:
   - Verify declarative DOM tree generation and reactive state updates.
3. **Gate Command**:
   - `asl test web/tests/cockpit-test.asl`
