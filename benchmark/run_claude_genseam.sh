#!/usr/bin/env bash
# Claude Code + GenSEAM Tools Isolated Runner
set -eo pipefail

CONFIG_DIR="/tmp/claude-genseam-isolated"
rm -rf "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR"

export CLAUDE_CONFIG_DIR="$CONFIG_DIR"
export ANTHROPIC_BASE_URL="${LLM_GATEWAY_BASE_URL:-https://api.llmgateway.io/v1}"
export ANTHROPIC_API_KEY="${LLM_GATEWAY_API_KEY:-llmgtwy_vLHJNl0D6XpsifrNXg2zKVtXDEX26m93H5E4g8RX}"
export ANTHROPIC_MODEL="gemma-4-31b-it"

echo "[*] Launching Claude Code with GenSEAM Code Intelligence & Memory Tools..."
echo "    Config Directory: $CLAUDE_CONFIG_DIR"
echo "    Model: $ANTHROPIC_MODEL"
echo "    Tools: asl-intel, asl-mem, ast-search"
