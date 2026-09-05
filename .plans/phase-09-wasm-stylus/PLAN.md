# Phase Plan: Arbitrum Stylus Wasm ABI Target (`wasm-stylus-target`)

## Objective
Generate EVM-compatible Arbitrum Stylus WebAssembly interfaces:
- Declare standard Stylus entrypoint `user_entrypoint(len: usize) -> usize`.
- Map ASL contract methods to 4-byte EVM function selectors (`keccak256("transfer(address,uint256)")`).
- Provide calldata decoder and returndata encoder in pure ASL.

## Measurable Baseline for Gemma 31B
- ABI conformance: 100% compatibility with standard Ethereum JSON-RPC and Foundry client calls.
- Gas savings: ~90% lower execution gas cost compared to Solidity equivalents running on EVM.

## Work Items
1. **Stylus ABI Generator (`asl/packages/asl-contracts/src/stylus_abi.asl`)**:
   - `FunctionSelector`: 4-byte hex prefix for EVM dispatch.
   - `CalldataDecoder`: Extracts typed arguments from raw hex/bytes.
   - `StylusExport`: Generates Wasm component bindings for Arbitrum Stylus VM.
2. **Grammar Registration Update (`asl/packages/asl-contracts/grammar.asn`)**:
   - Register Stylus ABI types and functions.
3. **Verification Suite (`asl/packages/asl-contracts/tests/stylus_test.asl`)**:
   - Verify function selector calculation, calldata unpacking, and ABI dispatch.
4. **Gate Command**:
   - `asl test asl/packages/asl-contracts/tests/stylus_test.asl`
