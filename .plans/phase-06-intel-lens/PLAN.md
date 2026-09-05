# Phase Plan: Lens Architecture Cartography & Impact Radius (`intel-lens-cartography`)

## Objective
Implement `lens` cartography inside `intel`:
- `lens:inspect-topology`: Generates ultra-compact (~150 tokens) ASN architecture snapshot for agents.
- `get_impact_radius`: Calculates transitive callers, callees, and broken invariant blast-radius before edits.
- `simulate_intent`: Pre-execution gate policy simulator allowing agents to test mutations before committing errors.

## Measurable Baseline for Gemma 31B
- Context consumption for repository navigation: ~150 tokens (vs 8,000+ tokens for full file reads, -98% reduction).
- Regression rate on cross-module edits: Reduced by 80% via impact radius awareness.

## Work Items
1. **Lens Engine (`intel/src/lens.asl`)**:
   - `TopologySummary`: Compact module map with health and drift indicators.
   - `ImpactRadius`: Set of transitive dependent symbols and test suites.
   - `simulate-intent`: Rehearsal runner evaluating candidate diffs against gates.
2. **Grammar Registration (`intel/grammar.asn`)**:
   - Register lens symbols with token counts and rationales.
3. **Colocated Skill (`intel/skills/intel/SKILL.md`)**:
   - Document `lens:inspect-topology` and `get_impact_radius`.
4. **Verification Suite (`intel/tests/lens-test.asl`)**:
   - Test topology compression, impact analysis on recursive modules, and policy simulation.
5. **Gate Command**:
   - `asl test intel/tests/lens-test.asl`
