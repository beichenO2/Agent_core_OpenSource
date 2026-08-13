#!/bin/bash
# ssot-soul-aggregate.sh — Generate PolarClaw/PolarSkills/SOUL.md from all projects' PolarSoul.md
#
# Usage: bash Agent_core/scripts/ssot-soul-aggregate.sh [--dry-run]
#
# Scans all Polarisor projects, extracts key info from each PolarSoul.md,
# and generates a unified ecosystem map for PolarClaw's system prompt.

set -euo pipefail

BASE_DIR="${HOME}/Polarisor"
TARGET="$BASE_DIR/PolarClaw/PolarSkills/SOUL.md"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

PROJECTS=(PolarClaw PolarCopilot PolarPrivate SOTAgent Clock AutoOffice KnowLever digist PolarSync PolarMemory PolarPort PolarOps PolarProcess PolarPilot)

GENERATED=$(date '+%Y-%m-%d %H:%M')

OUTPUT="# Polarisor 生态全景（自动生成）

> 本文件由 \`ssot-soul-aggregate.sh\` 自动从各项目 PolarSoul.md 聚合生成。
> 生成时间：$GENERATED
> 不要手动编辑——修改各项目的 PolarSoul.md 即可。

---

"

for PROJECT in "${PROJECTS[@]}"; do
  SOUL="$BASE_DIR/$PROJECT/PolarSoul.md"
  [ -f "$SOUL" ] || continue

  POLARIS="$BASE_DIR/$PROJECT/polaris.json"
  STATUS="unknown"
  DESC=""
  if [ -f "$POLARIS" ]; then
    STATUS=$(python3 -c "import json; d=json.load(open('$POLARIS')); print(d.get('status','unknown'))" 2>/dev/null || echo "unknown")
    DESC=$(python3 -c "import json; d=json.load(open('$POLARIS')); print(d.get('description','')[:100])" 2>/dev/null || echo "")
  fi

  # Extract ecosystem position (first bullet under "功能介绍" or "设计哲学")
  POSITION=$(python3 -c "
import re, sys
content = open('$SOUL').read()
# Try to find 生态位
match = re.search(r'\*\*生态位\*\*\s*[=:：]\s*(.+)', content)
if match:
    print(match.group(1).strip())
else:
    # Fallback to first line of design philosophy
    match = re.search(r'##\s*(设计哲学|Design)\s*\n+(.+)', content)
    if match:
        print(match.group(2).strip()[:80])
    else:
        print('')
" 2>/dev/null || echo "")

  OUTPUT+="## $PROJECT
- **状态**: $STATUS
- **定位**: ${POSITION:-$DESC}
"

  # Extract interfaces/ports if available
  PORTS=$(python3 -c "
import json
d = json.load(open('$POLARIS'))
contacts = d.get('contacts', {})
port = contacts.get('port', '')
if port:
    print(f'- **端口**: {port}')
" 2>/dev/null || echo "")
  [ -n "$PORTS" ] && OUTPUT+="$PORTS
"

  OUTPUT+="
"
done

OUTPUT+="---
*自动聚合自各项目 PolarSoul.md — 如需更新，请修改源项目的 PolarSoul.md*
"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "$OUTPUT"
  echo "---"
  echo "[DRY RUN] Would write to: $TARGET"
else
  echo "$OUTPUT" > "$TARGET"
  echo "✅ Generated: $TARGET ($(wc -c < "$TARGET") bytes)"
fi
