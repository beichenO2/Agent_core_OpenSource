#!/bin/bash
# sync-skills.sh — Skills 单向同步（SSoT → 消费方加载点）
#
# 使用方式：bash Agent_core/scripts/sync-skills.sh
# 执行位置：Polarisor 根目录
#
# SSoT 规则：
#   改 Skill = 改 Git 仓库内的原文件 → commit+push → 跑本脚本
#   SSoT: PolarCopilot/.cursor/skills/  （PC Agent 模式）
#         Agent_core/principles/         （共享约束）
#   派生: ~/.codex/skills/ (symlink)、PolarUI/skills/ (备份复制)

set -eo pipefail

POLARISOR_ROOT="${POLARISOR_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CODEX_SKILLS="$HOME/.codex/skills"
PC_SKILLS="$POLARISOR_ROOT/PolarCopilot/.cursor/skills"
AGENT_CORE_PRINCIPLES="$POLARISOR_ROOT/Agent_core/principles"

echo "=== Skills SSoT 同步 ==="
echo "SSoT 源: $PC_SKILLS"
echo "同步目标: $CODEX_SKILLS"
echo ""

# ──────────────────────────────────────────────────
# 1. 确保 ~/.codex/skills 中的 symlink 与 SSoT 对齐
# ──────────────────────────────────────────────────

mkdir -p "$CODEX_SKILLS"

SKILL_NAMES="pc pc-principles pc-solo-web pc-solo-qa pc-yolo-confirm pc-yolo-execute pc-project-scan rr-orchestrator"
skill_target() {
  case "$1" in
    pc-principles) echo "$AGENT_CORE_PRINCIPLES" ;;
    *)             echo "$PC_SKILLS/$1" ;;
  esac
}

synced=0
for skill_name in $SKILL_NAMES; do
  target=$(skill_target "$skill_name")
  link="$CODEX_SKILLS/$skill_name"

  if [ ! -e "$target" ]; then
    echo "  WARN: SSoT 不存在 $target，跳过"
    continue
  fi

  if [ -L "$link" ]; then
    current_target=$(readlink "$link")
    if [ "$current_target" = "$target" ]; then
      continue
    fi
    rm "$link"
  elif [ -e "$link" ]; then
    rm -rf "$link"
  fi

  ln -s "$target" "$link"
  echo "  LINK: $skill_name → $target"
  ((synced++)) || true
done

# pc-main 是独立实体（不在 PolarCopilot 中），保持不动
if [ -d "$CODEX_SKILLS/pc-main" ] && [ ! -L "$CODEX_SKILLS/pc-main" ]; then
  echo "  KEEP: pc-main (独立实体)"
fi

# ──────────────────────────────────────────────────
# 2. 清理断链 symlink
# ──────────────────────────────────────────────────

broken=0
for link in "$CODEX_SKILLS"/*; do
  if [ -L "$link" ] && [ ! -e "$link" ]; then
    echo "  CLEAN: 断链 $(basename "$link") → $(readlink "$link")"
    rm "$link"
    ((broken++))
  fi
done

# ──────────────────────────────────────────────────
# 3. PolarUI skills/ 备份同步（.cursor/skills → skills/）
# ──────────────────────────────────────────────────

POLARUI_SSOT="$POLARISOR_ROOT/PolarUI/.cursor/skills"
POLARUI_BACKUP="$POLARISOR_ROOT/PolarUI/skills"

if [ -d "$POLARUI_SSOT" ] && [ -d "$POLARUI_BACKUP" ]; then
  ui_synced=0
  for skill_dir in "$POLARUI_SSOT"/*/; do
    skill_name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
      mkdir -p "$POLARUI_BACKUP/$skill_name"
      if ! diff -q "$skill_dir/SKILL.md" "$POLARUI_BACKUP/$skill_name/SKILL.md" >/dev/null 2>&1; then
        cp "$skill_dir/SKILL.md" "$POLARUI_BACKUP/$skill_name/SKILL.md"
        echo "  UI-SYNC: $skill_name"
        ((ui_synced++))
      fi
    fi
  done
  [ $ui_synced -eq 0 ] && echo "  PolarUI 备份已同步，无变化"
fi

echo ""
echo "=== 完成 ==="
echo "  Symlinks 更新: $synced"
echo "  断链清理: $broken"
