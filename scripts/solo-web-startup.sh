#!/usr/bin/env bash
# solo-web-startup.sh — 健壮的 Solo Web 启动脚本
#
# 功能：
#   1. 检测 Hub 是否已运行
#   2. Hub 未运行则自动在 tmux 中启动
#   3. 等待 Hub 就绪
#   4. 输出 hub_port / agent_id（setup 由 Agent 侧 MCP 调用，默认不创建 prompt）
#
# 用法：
#   bash solo-web-startup.sh [hub-agent-N]
#   bash solo-web-startup.sh 1          # 指定 hub-agent 序号（默认 1）
#
# 环境变量：
#   PC_PROJECT_DIR   — 项目根目录（默认：当前目录）
#   PC_CORE_DIR      — polarcop core 目录（默认：~/.polarcop/core）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PC_PROJECT_DIR:-$(pwd)}"
CORE_DIR="${PC_CORE_DIR:-$HOME/.polarcop/core}"
AGENT_SLOT="${1:-1}"                          # hub-agent-N 的 N
HUB_AGENT_ROLE="${HUB_AGENT_ROLE:-hw}"        # Agent ID 前缀

# ── 项目 hash（用于 tmux session 名和日志文件）────────────
_PC_PROJ_HASH="$(python3 -c 'import hashlib,sys; print(hashlib.md5(sys.argv[1].encode()).hexdigest()[:4])' "$PROJECT_DIR" 2>/dev/null || echo "0000")"
TMUX_HUB_SESSION="pc-${_PC_PROJ_HASH}-hub"
HUB_LOG="/tmp/pc-hub-${_PC_PROJ_HASH}.log"
AGENT_STATE_DIR="$HOME/.cursor/hub-mcp-state/s"

# ── Hub 检测（用 /mcp initialize ping）────────────────────
hub_alive() {
  local port="$1"
  python3 "$SCRIPT_DIR/hub-check.py" "$port"
}

# ── Hub 端口发现 ──────────────────────────────────────────
discover_hub_port() {
  # 1. PolarPort（SSOT，11050）查询 service_name=polarcop-hub 并验证 Hub 实际在监听
  local port
  port=$(curl -s --max-time 2 "http://127.0.0.1:11050/api/list" 2>/dev/null \
    | python3 -c "
import sys,json
try:
    for p in json.loads(sys.stdin.read()):
        if p.get('service_name','') == 'polarcop-hub' and p.get('status','') == 'active':
            print(p['port']); break
except: pass
" 2>/dev/null)
  [ -n "$port" ] && hub_alive "$port" && echo "$port" && return 0

  # 2. 已知常用端口（兜底，按 PolarPort SSOT 优先顺序）
  for port in 8040 18789 3850 3851 3852 9020 3000 3001 8765; do
    if hub_alive "$port"; then
      echo "$port" && return 0
    fi
  done

  # 3. 推导端口（hash % 55535 + 10000）
  port=$(printf '%d' "$((16#${_PC_PROJ_HASH} % 55535 + 10000))" 2>/dev/null || echo "")
  [ -n "$port" ] && hub_alive "$port" && echo "$port" && return 0

  return 1
}

# ── 启动 Hub（在 tmux 中）─────────────────────────────────
start_hub() {
  local hub_port="${1:-8040}"

  # 检查 tmux session 是否已存在但 Hub 已崩溃
  if tmux has-session -t "$TMUX_HUB_SESSION" 2>/dev/null; then
    echo "[start_hub] tmux session $TMUX_HUB_SESSION 已存在，先杀掉" >&2
    tmux kill-session -t "$TMUX_HUB_SESSION" 2>/dev/null || true
    sleep 1
  fi

  mkdir -p "$(dirname "$HUB_LOG")" "$(dirname "$AGENT_STATE_DIR")" 2>/dev/null || true

  echo "[start_hub] 在 tmux session '$TMUX_HUB_SESSION' 启动 Hub（端口 $hub_port）..." >&2

  # Hub 位于 PolarCopilot/hub，PolarPort 分配端口 8040
  local hub_dir="$PROJECT_DIR/PolarCopilot/hub"
  if [ ! -d "$hub_dir" ]; then
    hub_dir="$HOME/Polarisor/PolarCopilot/hub"
  fi

  tmux new-session -d -s "$TMUX_HUB_SESSION" -x 200 -y 50
  tmux send-keys -t "$TMUX_HUB_SESSION" \
    "cd '$hub_dir' && PC_HUB_PORT=$hub_port node_modules/.bin/tsx src/server.ts 2>&1 | tee '$HUB_LOG'" Enter

  echo "[start_hub] 等待 Hub 启动..." >&2
}

# ── 等待 Hub 就绪 ─────────────────────────────────────────
wait_hub_ready() {
  local max_wait="${1:-20}"
  local port="$2"
  for i in $(seq 1 "$max_wait"); do
    sleep 1
    if hub_alive "$port"; then
      echo "[wait_hub_ready] Hub 就绪（${i}s）" >&2
      return 0
    fi
    [ $((i % 5)) -eq 0 ] && echo "[wait_hub_ready] 已等待 ${i}s，Hub 尚未就绪..." >&2
  done
  echo "[wait_hub_ready] 超时（${max_wait}s），Hub 未响应" >&2
  return 1
}

# ── MCP Server 名字（mcp.json 中的完整 identifier）─────────
MCP_SERVER_NAME="project-0-Polarisor-hub-agent-${AGENT_SLOT}"

# ── 主流程（仅直接运行时执行，source 时跳过）───────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  return 0 2>/dev/null || exit 0
fi

echo "=== Solo Web 启动 ===" >&2
echo "项目: $PROJECT_DIR" >&2
echo "Slot: hub-agent-$AGENT_SLOT" >&2
echo "MCP Server: $MCP_SERVER_NAME" >&2

# Step 1: 发现 Hub 端口
HUB_PORT="$(discover_hub_port)" || HUB_PORT=""
if [ -n "$HUB_PORT" ]; then
  echo "Hub 发现：端口 $HUB_PORT（已运行）" >&2
else
  echo "Hub 未运行，启动中..." >&2
  start_hub "${HUB_PORT:-8040}"
  HUB_PORT="$(discover_hub_port)" || true
  if [ -z "$HUB_PORT" ]; then
    # 启动后再次探测
    HUB_PORT="$(wait_hub_ready 20 8040 && echo 8040)" || true
  fi
fi

if [ -z "$HUB_PORT" ]; then
  echo "ERROR: 无法发现或启动 Hub" >&2
  exit 1
fi

# Step 2: 等待 Hub 完全就绪
wait_hub_ready 20 "$HUB_PORT" || {
  echo "ERROR: Hub 启动超时" >&2
  exit 1
}

echo "Hub 就绪，端口: $HUB_PORT" >&2

# Step 3: 输出环境变量（供后续 MCP tool call 使用）
# Hub-agent-N MCP Server 通过环境变量感知 Hub 端口
echo ""
echo ""
echo "=== Hub 已就绪 ==="
echo "HUB_PORT=$HUB_PORT"
echo "PC_PROJECT_DIR=$PROJECT_DIR"
echo "PC_PROJ_HASH=$_PC_PROJ_HASH"
echo "hub-agent-$AGENT_SLOT 已配置完成"
echo ""
echo "=== Cursor Agent 调用 ==="
echo "在 Skill 文档中，应该用以下完整 MCP identifier："
echo "  CallMcpTool('$MCP_SERVER_NAME', 'setup', {})"
echo ""
