#!/usr/bin/env bash
# /pc-yolo 标准工人 — 经 PolarProcess（见 Agent_core/scripts/polar-agent.sh）
set -euo pipefail
PROMPT_FILE="${1:?用法: agent-worker.sh <prompt.md>}"
exec bash "${HOME}/Polarisor/Agent_core/scripts/agent-worker.sh" "$PROMPT_FILE"
