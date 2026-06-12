#!/usr/bin/env bash
# migrate-planning.sh — .planning/ 格式检测与迁移（GSD v1 / Polarisor flat → PolarCopilot v2）
#
# 用法：
#   bash migrate-planning.sh [目标项目路径]
#   bash migrate-planning.sh --dry-run [目标项目路径]
#   bash migrate-planning.sh --check [目标项目路径]
#
# 不传路径则使用当前目录

set -euo pipefail

DRY_RUN=false
CHECK_ONLY=false
TARGET_DIR=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --check) CHECK_ONLY=true ;;
    *) TARGET_DIR="$arg" ;;
  esac
done

TARGET_DIR="${TARGET_DIR:-.}"
PLANNING_DIR="$TARGET_DIR/.planning"

if [ ! -d "$PLANNING_DIR" ]; then
  echo "❌ $PLANNING_DIR 不存在"
  exit 1
fi

detect_format() {
  if [ -f "$PLANNING_DIR/version.json" ]; then
    FORMAT=$(python3 -c "
import json
with open('$PLANNING_DIR/version.json') as f:
    d = json.load(f)
print(d.get('format', 'unknown'))
" 2>/dev/null || echo "unknown")
    echo "$FORMAT"
  elif [ -f "$PLANNING_DIR/PROJECT.md" ]; then
    if [ -f "$PLANNING_DIR/agent-protocol.md" ] || [ -d "$PLANNING_DIR/signals" ] || [ -d "$PLANNING_DIR/research" ]; then
      echo "gsd-v1"
    else
      echo "polarisor-flat"
    fi
  elif [ -f "$PLANNING_DIR/project.md" ]; then
    if [ -f "$PLANNING_DIR/version.json" ]; then
      echo "polarcop-v2"
    else
      echo "polarcop-v2-partial"
    fi
  else
    echo "unknown"
  fi
}

FORMAT=$(detect_format)
echo "📋 检测到格式: $FORMAT ($PLANNING_DIR)"

if [ "$CHECK_ONLY" = true ]; then
  case "$FORMAT" in
    polarcop-v2) echo "✅ 已是 PolarCopilot v2 格式"; exit 0 ;;
    gsd-v1) echo "⚠️  GSD v1 格式，需要迁移"; exit 1 ;;
    polarisor-flat) echo "⚠️  Polarisor 扁平格式，需要迁移"; exit 1 ;;
    *) echo "❓ 未知格式: $FORMAT"; exit 1 ;;
  esac
fi

if [ "$FORMAT" = "polarcop-v2" ]; then
  echo "✅ 已是 PolarCopilot v2 格式，无需迁移"
  exit 0
fi

if [ "$FORMAT" = "unknown" ]; then
  echo "❓ 无法识别格式，跳过迁移"
  exit 1
fi

PROJECT_NAME=$(basename "$(cd "$TARGET_DIR" && pwd)")
BACKUP_DIR="$PLANNING_DIR/_backup_pre_v2"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

safe_move() {
  local src="$1" dst="$2"
  if [ ! -e "$src" ]; then return; fi
  local dst_dir
  dst_dir=$(dirname "$dst")
  if [ "$DRY_RUN" = true ]; then
    echo "  📁 MOVE: $src → $dst"
  else
    mkdir -p "$dst_dir"
    mv "$src" "$dst"
    echo "  ✅ $src → $dst"
  fi
}

safe_copy_to_backup() {
  local src="$1"
  if [ ! -e "$src" ]; then return; fi
  local rel="${src#$PLANNING_DIR/}"
  local dst="$BACKUP_DIR/$rel"
  local dst_dir
  dst_dir=$(dirname "$dst")
  if [ "$DRY_RUN" = true ]; then
    echo "  💾 BACKUP: $src"
  else
    mkdir -p "$dst_dir"
    cp -r "$src" "$dst"
  fi
}

echo ""
echo "🔄 开始迁移: $FORMAT → polarcop-v2"
echo "   项目: $PROJECT_NAME"
echo "   路径: $PLANNING_DIR"
[ "$DRY_RUN" = true ] && echo "   模式: DRY RUN（不实际修改）"
echo ""

# Phase 1: Backup
echo "--- Phase 1: 备份 ---"
if [ "$DRY_RUN" = false ]; then
  mkdir -p "$BACKUP_DIR"
fi
for f in "$PLANNING_DIR"/*.md "$PLANNING_DIR"/*.json; do
  [ -e "$f" ] && safe_copy_to_backup "$f"
done
for d in "$PLANNING_DIR"/research "$PLANNING_DIR"/signals; do
  [ -d "$d" ] && safe_copy_to_backup "$d"
done

# Phase 2: Create new directories
echo ""
echo "--- Phase 2: 创建新目录结构 ---"
for dir in knowledge/research knowledge/design agents/prompts agents/state diff/intents reports/audits reports/bugs reports/handoff hub signals logs/agents; do
  full="$PLANNING_DIR/$dir"
  if [ "$DRY_RUN" = true ]; then
    [ ! -d "$full" ] && echo "  📁 MKDIR: $full"
  else
    mkdir -p "$full"
  fi
done

# Phase 3: Move files
echo ""
echo "--- Phase 3: 移动文件 ---"

# Core files: uppercase → lowercase
# macOS HFS+/APFS is case-insensitive: PROJECT.md and project.md share inode
# Use two-step rename: UPPER → .tmp → lower
for f in PROJECT STATE ROADMAP REQUIREMENTS; do
  upper="$PLANNING_DIR/${f}.md"
  lower_name="$(echo "$f" | tr '[:upper:]' '[:lower:]').md"
  lower="$PLANNING_DIR/$lower_name"
  if [ -f "$upper" ]; then
    upper_inode=$(stat -f '%i' "$upper" 2>/dev/null || stat -c '%i' "$upper" 2>/dev/null)
    lower_inode=$(stat -f '%i' "$lower" 2>/dev/null || stat -c '%i' "$lower" 2>/dev/null)
    if [ "$upper_inode" = "$lower_inode" ]; then
      # Same file (case-insensitive FS) — two-step rename
      if [ "$DRY_RUN" = true ]; then
        echo "  📁 RENAME: ${f}.md → $lower_name (case-insensitive FS)"
      else
        mv "$upper" "$PLANNING_DIR/.tmp_${f}.md"
        mv "$PLANNING_DIR/.tmp_${f}.md" "$lower"
        echo "  ✅ ${f}.md → $lower_name"
      fi
    elif [ ! -f "$lower" ]; then
      safe_move "$upper" "$lower"
    else
      echo "  ⚠️  $upper 和 $lower 都存在（不同文件），保留 $lower"
    fi
  fi
done

# Knowledge files
safe_move "$PLANNING_DIR/RESEARCH.md" "$PLANNING_DIR/knowledge/research/RESEARCH.md"
safe_move "$PLANNING_DIR/DESIGN-V2.md" "$PLANNING_DIR/knowledge/design/DESIGN-V2.md"
safe_move "$PLANNING_DIR/PACKET-CONTRACT.md" "$PLANNING_DIR/knowledge/design/PACKET-CONTRACT.md"

# Reports
safe_move "$PLANNING_DIR/HANDOFF.md" "$PLANNING_DIR/reports/handoff/HANDOFF.md"
safe_move "$PLANNING_DIR/BUG-REPORT.md" "$PLANNING_DIR/reports/bugs/BUG-REPORT.md"
safe_move "$PLANNING_DIR/AUDIT-REPORT.md" "$PLANNING_DIR/reports/audits/AUDIT-REPORT.md"

# Agent files
safe_move "$PLANNING_DIR/agent-protocol.md" "$PLANNING_DIR/agents/protocol.md"
for f in "$PLANNING_DIR"/agent-*-prompt.md "$PLANNING_DIR"/phase-*-prompt.md; do
  [ -e "$f" ] && safe_move "$f" "$PLANNING_DIR/agents/prompts/$(basename "$f")"
done

# Research directory
if [ -d "$PLANNING_DIR/research" ] && [ ! -d "$PLANNING_DIR/knowledge/research/stack" ]; then
  for f in "$PLANNING_DIR/research"/*; do
    [ -e "$f" ] && safe_move "$f" "$PLANNING_DIR/knowledge/research/$(basename "$f")"
  done
  [ "$DRY_RUN" = false ] && rmdir "$PLANNING_DIR/research" 2>/dev/null || true
fi

# Phase 4: Augment config.json
echo ""
echo "--- Phase 4: 更新 config.json ---"
if [ -f "$PLANNING_DIR/config.json" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "  📝 ADD system fields to config.json"
  else
    python3 -c "
import json
with open('$PLANNING_DIR/config.json') as f:
    cfg = json.load(f)
if 'system' not in cfg:
    cfg['system'] = {
        'copilot_or_pilot': 'copilot',
        'identity': 'PolarCopilot'
    }
with open('$PLANNING_DIR/config.json', 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write('\n')
" 2>/dev/null && echo "  ✅ config.json 已更新" || echo "  ⚠️  config.json 更新失败"
  fi
fi

# Phase 5: Write version.json
echo ""
echo "--- Phase 5: 写入 version.json ---"
if [ "$DRY_RUN" = true ]; then
  echo "  📝 WRITE: $PLANNING_DIR/version.json"
else
  python3 -c "
import json
v = {
    'format': 'polarcop-v2',
    'migrated_from': '$FORMAT',
    'migrated_at': '$NOW',
    'project': '$PROJECT_NAME',
    'created_at': '$NOW'
}
with open('$PLANNING_DIR/version.json', 'w') as f:
    json.dump(v, f, indent=2, ensure_ascii=False)
    f.write('\n')
" && echo "  ✅ version.json 已写入"
fi

echo ""
echo "🎉 迁移完成！"
echo "   格式: $FORMAT → polarcop-v2"
echo "   备份: $BACKUP_DIR"
