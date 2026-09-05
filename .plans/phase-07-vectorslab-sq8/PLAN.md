# Phase Plan: VectorSlab SQ8 & SIMD-128 Linear Memory Engine (`mem-vectorslab-sq8`)

## Objective
Implement scalar-quantized `VectorSlab` in `mem` solving the Wasm memory barrier:
- 1-byte per coordinate scalar quantization (SQ8) with offset scaling.
- Pack 100 vectors (384d) in 38.4 KB (fitting inside a single 64 KB Wasm page).
- Fast cosine similarity via WebAssembly SIMD-128 vector instructions (`f32x4.mul`, `f32x4.add`).

## Measurable Baseline for Gemma 31B
- Memory density: 10,000 vectors (384d) stored in 3.8 MB Wasm RAM (vs 30.7 MB in F64, -87.5% memory footprint).
- Vector recall latency: < 0.08 ms for top-5 similarity search.

## Work Items
1. **VectorSlab SQ8 Engine (`mem/src/vectorslab.asl`)**:
   - Types: `QuantizedVector`, `VectorSlabHeader`, `SimilarityHit`.
   - Math: SQ8 encoder, dot-product accumulator with scale multiplication.
   - Operations: `insert-vector`, `batch-query-topk`.
2. **Grammar Registration (`mem/grammar.asn`)**:
   - Register VectorSlab types and functions with rationales.
3. **Colocated Skill (`mem/skills/mem/SKILL.md`)**:
   - Document VectorSlab usage and memory bounds.
4. **Verification Suite (`mem/tests/vectorslab-test.asl`)**:
   - Test quantization precision loss (<1% error vs f64), memory compactness, and top-k recall accuracy.
5. **Gate Command**:
   - `asl test mem/tests/vectorslab-test.asl`
