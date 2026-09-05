#!/usr/bin/env bash
# Native ASL Coding Harness Runner
set -eo pipefail

export LLM_GATEWAY_BASE_URL="${LLM_GATEWAY_BASE_URL:-https://api.llmgateway.io/v1}"
export LLM_GATEWAY_API_KEY="${LLM_GATEWAY_API_KEY:-llmgtwy_vLHJNl0D6XpsifrNXg2zKVtXDEX26m93H5E4g8RX}"
export TARGET_MODEL="gemma-4-31b-it"

echo "[*] Launching Native ASL Coding Harness..."
echo "    Model: $TARGET_MODEL"
echo "    Direct Tools: fs, exec, ast, intel, mem"
echo "    Features: ASN toolcall translation, hallucination normalizer, local Wasm execution"
