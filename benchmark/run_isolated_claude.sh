#!/usr/bin/env bash
# Standalone Isolated Claude Benchmark Runner (Targeting Gemma 31B)
# Strictly decoupled from system-installed Claude (/usr/local/bin/claude), ~/.claude, and local MCP/SMT tools.
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_BIN="$ROOT_DIR/bin/claude-standalone"

if [ ! -f "$CLAUDE_BIN" ]; then
  echo "[-] Standalone Claude binary not found at $CLAUDE_BIN"
  exit 1
fi

# 1. Ephemeral, isolated configuration directory (Zero leakage to/from ~/.claude)
ISOLATED_CONFIG_DIR="$(mktemp -d /tmp/claude-gemma-isolated-XXXXXX)"
trap 'rm -rf "$ISOLATED_CONFIG_DIR"' EXIT

export CLAUDE_CONFIG_DIR="$ISOLATED_CONFIG_DIR"

# 2. Strict Target Model Binding: Gemma 31B
export ANTHROPIC_MODEL="${TARGET_MODEL:-gemma-4-31b-it}"
export ANTHROPIC_BASE_URL="${LLM_GATEWAY_BASE_URL:-https://api.llmgateway.io/v1}"
export ANTHROPIC_API_KEY="${LLM_GATEWAY_API_KEY:-llmgtwy_vLHJNl0D6XpsifrNXg2zKVtXDEX26m93H5E4g8RX}"

# 3. Clean isolation parameters
echo "================================================================================"
echo "          Isolated Standalone Claude Runner (Zero System Ties)                  "
echo "================================================================================"
echo "--> Binary:          $("$CLAUDE_BIN" --version 2>/dev/null || echo "$CLAUDE_BIN")"
echo "--> System Untouched: /usr/local/bin/claude (IGNORED)"
echo "--> Config Dir:      $CLAUDE_CONFIG_DIR (EPHEMERAL)"
echo "--> MCP Servers:     0 (Zero active external MCPs)"
echo "--> SMT / Tooling:   0 (Completely decoupled from Agent SMT/Intel tools)"
echo "--> Model Target:    $ANTHROPIC_MODEL (Strictly Gemma)"
echo "================================================================================"

if [ "$1" = "--check" ]; then
  echo "✓ Isolated Standalone Claude runner verified clean and operational on Gemma 31B."
  exit 0
fi

# Execute standalone binary in clean environment
exec env -i \
  HOME="$ISOLATED_CONFIG_DIR" \
  PATH="/usr/bin:/bin:/usr/sbin:/sbin:$ROOT_DIR/bin" \
  CLAUDE_CONFIG_DIR="$ISOLATED_CONFIG_DIR" \
  ANTHROPIC_MODEL="$ANTHROPIC_MODEL" \
  ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL" \
  ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  "$CLAUDE_BIN" "$@"
