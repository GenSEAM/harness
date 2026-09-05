#!/usr/bin/env bash
# Baseline Claude Code Isolated Runner
set -eo pipefail

CONFIG_DIR="/tmp/claude-baseline-isolated"
rm -rf "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR"

export CLAUDE_CONFIG_DIR="$CONFIG_DIR"
export ANTHROPIC_BASE_URL="${LLM_GATEWAY_BASE_URL:-https://api.llmgateway.io/v1}"
export ANTHROPIC_API_KEY="${LLM_GATEWAY_API_KEY:-llmgtwy_vLHJNl0D6XpsifrNXg2zKVtXDEX26m93H5E4g8RX}"
export ANTHROPIC_MODEL="gemma-4-31b-it"

echo "[*] Launching Isolated Baseline Claude Code (0 custom instructions, 0 external tools)..."
echo "    Config Directory: $CLAUDE_CONFIG_DIR"
echo "    Model: $ANTHROPIC_MODEL"
echo "    Endpoint: $ANTHROPIC_BASE_URL"
