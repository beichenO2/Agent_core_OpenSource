#!/usr/bin/env bash
# /pc-yolo CLI 就绪探针 — 区分「已登录」与「headless 可执行」
# 用法：bash scripts/pc-yolo/cli-probe.sh [workspace]
# 退出码：0=就绪  1=未登录  2=执行超时/无 assistant 响应  3=配置错误
set -euo pipefail

WS="${1:-${PC_PROJECT_DIR:-$(pwd)}}"
AGENT="${AGENT_BIN:-$(command -v agent || true)}"
TIMEOUT_SEC="${PC_YOLO_PROBE_TIMEOUT:-45}"

if [[ -z "$AGENT" ]]; then
  echo "FAIL: agent 不在 PATH"
  exit 3
fi

echo "=== L1 认证 ==="
if ! "$AGENT" whoami 2>&1; then
  echo "FAIL: 未登录 — 运行 agent login"
  exit 1
fi

echo "=== 清理僵尸 agent -p ==="
pkill -f "cursor-agent.*index.js -p" 2>/dev/null || true
sleep 1

echo "=== L2 执行探针 via polar-agent / PolarProcess (${TIMEOUT_SEC}s) ==="
export PC_PROJECT_DIR="$WS"
PROBE_ROOT="$(cd "$(dirname "$0")" && pwd)"
POLAR_AGENT="${PROBE_ROOT}/polar-agent.sh"
if [[ ! -x "$POLAR_AGENT" ]]; then
  echo "FAIL: polar-agent.sh missing at $POLAR_AGENT"
  exit 3
fi

set +e
OUT="$(POLAR_AGENT_TIMEOUT_SEC="$TIMEOUT_SEC" "$POLAR_AGENT" --workspace "$WS" --prompt "Reply with exactly: OK" 2>&1)"
CODE=$?
set -e
echo "$OUT" | tail -n 40

if echo "$OUT" | grep -q 'PolarProcess unreachable'; then
  echo "FAIL: PolarProcess 未运行 — 无法做 L2（先启动 PolarProcess）"
  exit 4
fi

# polar-agent uses --output-format json; accept assistant/result/OK text
if echo "$OUT" | grep -Eqi '"type"[[:space:]]*:[[:space:]]*"assistant"|Reply with exactly: OK|^OK$|"result"'; then
  echo "PASS: polar-agent / PolarProcess headless 响应已收到 (exit=$CODE)"
  exit 0
fi

if [[ "$CODE" -eq 0 ]]; then
  echo "PASS: polar-agent exit 0"
  exit 0
fi

echo "FAIL: polar-agent 无有效 assistant/OK 响应 (exit=$CODE)"
exit 2
