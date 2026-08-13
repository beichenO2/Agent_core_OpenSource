#!/bin/bash
# deploy-and-restart.sh — 一键部署 v0.5.1 修复到所有项目并逐个重启
#
# 用法:
#   bash deploy-and-restart.sh              # 同步 + 重启全部项目
#   bash deploy-and-restart.sh --sync-only  # 只同步代码，不重启
#   bash deploy-and-restart.sh --restart-only  # 只重启（已经同步过）
#   bash deploy-and-restart.sh --dry-run    # 打印计划，不 rsync / 不启动集群
#   bash deploy-and-restart.sh --model claude-sonnet-4  # 指定模型
#
# 前置条件：
#   1. Cursor 账单已付清
#   2. 所有项目的 tmux sessions 已停止
#   3. 系统负载已恢复正常（< 10）
#
# 路径解析（R4.3）：本脚本位于 <Polarisor>/gsd-2/scripts/ 下，由此推导仓库根目录，
# 不再使用旧版 Tools/… 假设。可用环境变量覆盖：
#   POLARISOR_ROOT — 工作区根（默认：本脚本上两级目录）
#   GSD2_SRC       — gsd-2 源码根（默认：<POLARISOR_ROOT>/gsd-2）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_DEFAULT_GSD2="$(cd "$SCRIPT_DIR/.." && pwd)"
_DEFAULT_POLARISOR="$(cd "$SCRIPT_DIR/../.." && pwd)"
GSD2_SRC="${GSD2_SRC:-$_DEFAULT_GSD2}"
POLARISOR_ROOT="${POLARISOR_ROOT:-$_DEFAULT_POLARISOR}"

# ===== 配置 =====
AGENT_MODEL="claude-4.6-opus-max-thinking"
DO_SYNC=true
DO_RESTART=true
DRY_RUN=false
WORKERS_PER_PROJECT=3
RESTART_INTERVAL=30

PROJECTS=(
  "$POLARISOR_ROOT/Clock"
  "$POLARISOR_ROOT/InfoForge"
  "$POLARISOR_ROOT/PolarClaw"
  "$POLARISOR_ROOT/digist"
  "$POLARISOR_ROOT/AutoOffice"
  "$POLARISOR_ROOT/LLM-Wiki"
  "$POLARISOR_ROOT/KnowLever"
  "$POLARISOR_ROOT/tqsdk/刺客八号 期货量化"
  "$POLARISOR_ROOT/tqsdk/trading-platform"
)

# ===== 参数解析 =====
for arg in "$@"; do
  case "$arg" in
    --sync-only) DO_RESTART=false ;;
    --restart-only) DO_SYNC=false ;;
    --dry-run) DRY_RUN=true ;;
    --model) ;;
    *) ;;
  esac
done
for i in $(seq 1 $(($# - 1))); do
  arg="${!i}"
  next_i=$((i + 1))
  next_arg="${!next_i:-}"
  [ "$arg" = "--model" ] && [ -n "$next_arg" ] && AGENT_MODEL="$next_arg"
done

echo "╔══════════════════════════════════════════════╗"
echo "║   gsd-2 v0.5.1 部署与重启                   ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "工作区:  $POLARISOR_ROOT"
echo "源码:    $GSD2_SRC"
echo "模型:    $AGENT_MODEL"
echo "项目数:  ${#PROJECTS[@]}"
echo "同步:    $DO_SYNC"
echo "重启:    $DO_RESTART"
echo "dry-run: $DRY_RUN"
echo ""

# ===== 前置检查 =====
echo "=== 前置检查 ==="

LOAD=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}' || uptime | awk -F'load averages:' '{print $2}' | awk '{print $1}')
echo "系统负载: $LOAD"

EXISTING_SESSIONS=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^g-' | wc -l | tr -d ' ' || echo 0)
if [ "$EXISTING_SESSIONS" -gt 0 ]; then
  if $DRY_RUN; then
    echo "⚠️  dry-run: 检测到 $EXISTING_SESSIONS 个 g-* sessions（实际执行前须清空）"
  else
    echo "⚠️  仍有 $EXISTING_SESSIONS 个 g-* sessions 运行中"
    echo "   先运行: tmux list-sessions -F '#{session_name}' | grep '^g-' | xargs -I{} tmux kill-session -t {}"
    echo "   然后重新运行本脚本"
    exit 1
  fi
else
  echo "✓ 无残留 sessions"
fi

if ! command -v cursor &>/dev/null; then
  CURSOR_BIN=$(find /usr/local/bin /opt/homebrew/bin "$HOME/.cursor" /Applications -name "cursor" -type f 2>/dev/null | head -1)
  if [ -z "$CURSOR_BIN" ]; then
    echo "✗ 找不到 Cursor CLI"
    exit 1
  fi
else
  CURSOR_BIN="cursor"
fi
echo "✓ Cursor CLI: $CURSOR_BIN"

if [ ! -d "$GSD2_SRC" ]; then
  echo "✗ 源码目录不存在: $GSD2_SRC"
  exit 1
fi
SRC_VERSION=$(python3 -c "import json; print(json.load(open('$GSD2_SRC/package.json'))['version'])" 2>/dev/null)
echo "✓ 源码版本: v$SRC_VERSION"

# Skills 软链接同步
echo -n "Skills 软链接: "
if bash "$GSD2_SRC/scripts/sync-skills.sh" --verify >/dev/null 2>&1; then
  echo "✓ 已同步"
else
  if $DRY_RUN; then
    echo "[dry-run] 需要同步（运行 bash scripts/sync-skills.sh）"
  else
    bash "$GSD2_SRC/scripts/sync-skills.sh"
  fi
fi

# Handoff rule 同步
echo -n "Handoff rule: "
if bash "$GSD2_SRC/scripts/sync-handoff-rule.sh" --verify >/dev/null 2>&1; then
  echo "✓ 已同步"
else
  if $DRY_RUN; then
    echo "[dry-run] 需要同步（运行 bash scripts/sync-handoff-rule.sh）"
  else
    bash "$GSD2_SRC/scripts/sync-handoff-rule.sh"
  fi
fi
echo ""

# ===== 第 1 步：同步代码 =====
if $DO_SYNC; then
  echo "=== 同步 v$SRC_VERSION 到所有项目 ==="
  if $DRY_RUN; then
    echo "  [dry-run] 不会执行 rsync / npm install"
  fi
  SYNCED=0
  for proj in "${PROJECTS[@]}"; do
    target="$proj/gsd-2"
    if [ -d "$target" ] || [ -L "$target" ]; then
      # 如果是符号链接，跳过
      if [ -L "$target" ]; then
        echo "  ⊘ $(basename "$proj")/gsd-2 — 已是符号链接，跳过"
        continue
      fi
      if $DRY_RUN; then
        echo "  → $(basename "$proj")/gsd-2 ... [dry-run] rsync $GSD2_SRC/ → $target/"
      else
        echo -n "  → $(basename "$proj")/gsd-2 ... "
        rsync -a --delete \
          --exclude '.git' \
          --exclude 'node_modules' \
          --exclude '.planning' \
          --exclude 'dist' \
          "$GSD2_SRC/" "$target/"
        # 确保 node_modules 存在
        if [ ! -d "$target/node_modules" ]; then
          echo -n "(npm install) "
          cd "$target" && npm install --silent 2>/dev/null
        fi
        NEW_VER=$(python3 -c "import json; print(json.load(open('$target/package.json'))['version'])" 2>/dev/null)
        echo "v$NEW_VER ✓"
      fi
      SYNCED=$((SYNCED + 1))
    else
      echo "  ⊘ $(basename "$proj") — 无 gsd-2 目录，跳过"
    fi
  done
  echo "同步完成: $SYNCED 个项目"
  echo ""
fi

# ===== 第 2 步：逐个重启 =====
if $DO_RESTART; then
  echo "=== 逐个重启项目（每个间隔 ${RESTART_INTERVAL}s）==="
  if $DRY_RUN; then
    echo "  [dry-run] 不会执行 launch-cluster / sleep"
  fi
  STARTED=0
  for proj in "${PROJECTS[@]}"; do
    gsd2_dir="$proj/gsd-2"
    launch_script="$gsd2_dir/scripts/launch-cluster.sh"

    if [ ! -f "$launch_script" ]; then
      echo "  ⊘ $(basename "$proj") — 无 launch-cluster.sh，跳过"
      continue
    fi

    echo ""
    echo "--- [$(( STARTED + 1 ))/${#PROJECTS[@]}] $(basename "$proj") ---"

    export GSD_PROJECT_DIR="$proj"
    export CURSOR_BIN="$CURSOR_BIN"
    if $DRY_RUN; then
      echo "  [dry-run] bash $launch_script $WORKERS_PER_PROJECT --model $AGENT_MODEL"
    else
      bash "$launch_script" "$WORKERS_PER_PROJECT" --model "$AGENT_MODEL" 2>&1 | sed 's/^/  /'
    fi

    STARTED=$((STARTED + 1))

    # 验证是否正常启动
    if ! $DRY_RUN; then
      sleep 5
    fi
    LOAD_NOW=$(uptime | awk -F'load averages:' '{print $2}' | awk '{print $1}' | tr -d ' ')
    echo "  负载: $LOAD_NOW"

    if [ $STARTED -lt ${#PROJECTS[@]} ] && ! $DRY_RUN; then
      echo "  等待 ${RESTART_INTERVAL}s 后启动下一个项目..."
      sleep "$RESTART_INTERVAL"
    elif [ $STARTED -lt ${#PROJECTS[@]} ] && $DRY_RUN; then
      echo "  [dry-run] 将等待 ${RESTART_INTERVAL}s 后启动下一个项目"
    fi
  done

  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║   部署完成                                   ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""
  echo "已启动项目: $STARTED"
  echo "总 sessions: $(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^g-' | wc -l | tr -d ' ')"
  echo ""
  echo "监控命令:"
  echo "  tmux list-sessions | grep '^g-'          # 查看所有 sessions"
  echo "  uptime                                    # 查看系统负载"
  echo "  tmux attach -t <session-name>             # 查看具体 agent"
  echo ""
  echo "如果某个项目有问题，单独停止:"
  echo "  GSD_PROJECT_DIR='<项目路径>' bash <gsd-2>/scripts/stop-cluster.sh"
fi
