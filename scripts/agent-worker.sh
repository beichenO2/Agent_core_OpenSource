#!/usr/bin/env bash
# /pc-yolo 标准工人调用 — 总控 MUST 用此脚本，禁止裸 agent -p
# 用法：bash scripts/pc-yolo/agent-worker.sh /path/to/prompt.md
set -euo pipefail

PROMPT_FILE="${1:?用法: agent-worker.sh <prompt.md>}"
WS="${PC_PROJECT_DIR:-$(pwd)}"
AGENT="${AGENT_BIN:-$(command -v agent)}"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "FAIL: prompt 文件不存在: $PROMPT_FILE" >&2
  exit 3
fi

pkill -f "cursor-agent.*index.js -p" 2>/dev/null || true
sleep 1

unset CURSOR_AGENT VSCODE_IPC_HOOK VSCODE_CODE_CACHE_PATH CURSOR_EXTENSION_HOST_ROLE 2>/dev/null || true
export PC_PROJECT_DIR="$WS"

exec "$AGENT" -p --trust --force --yolo --approve-mcps --sandbox disabled \
  --output-format json \
  --model composer-2.5-fast \
  --workspace "$WS" \
  "$(cat "$PROMPT_FILE")"
