#!/bin/bash
# ssot-freshness-check.sh — 检查 polaris.json 与实际项目状态的偏差
# 用法：bash Agent_core/scripts/ssot-freshness-check.sh [--verbose]
# 输出：每个项目的健康状态报告

set -euo pipefail

POLARISOR_ROOT="${POLARISOR_ROOT:-$HOME/Polarisor}"
VERBOSE="${1:-}"
NOW_EPOCH=$(date +%s)
WARN_DAYS=30
ISSUES=0
CHECKED=0

echo "═══════════════════════════════════════════"
echo " SSoT Freshness Check — $(date '+%Y-%m-%d %H:%M')"
echo "═══════════════════════════════════════════"
echo ""

for proj_dir in "$POLARISOR_ROOT"/*/; do
  [ -d "$proj_dir" ] || continue
  proj_name=$(basename "$proj_dir")
  polaris_file="$proj_dir/polaris.json"

  # Skip non-project directories
  [[ "$proj_name" == .* ]] && continue
  [[ "$proj_name" == "tmp" ]] && continue
  [[ "$proj_name" == "input" ]] && continue
  [[ "$proj_name" == "output" ]] && continue
  [[ "$proj_name" == "knowledge" ]] && continue
  [[ "$proj_name" == "Reference" ]] && continue
  [[ "$proj_name" == "test-project" ]] && continue
  [[ "$proj_name" == "vitest-test-project" ]] && continue
  [[ "$proj_name" == *"worktrees"* ]] && continue

  if [ ! -f "$polaris_file" ]; then
    continue
  fi

  CHECKED=$((CHECKED + 1))
  proj_issues=""

  # Check 1: polaris.json last modified vs last commit
  polaris_mtime=$(stat -f %m "$polaris_file" 2>/dev/null || stat -c %Y "$polaris_file" 2>/dev/null)
  days_since_polaris=$(( (NOW_EPOCH - polaris_mtime) / 86400 ))

  if [ "$days_since_polaris" -gt "$WARN_DAYS" ]; then
    proj_issues="${proj_issues}  ⚠️  polaris.json 未更新 ${days_since_polaris} 天\n"
  fi

  # Check 2: roadmap.md existence for active projects
  status=$(python3 -c "import json; d=json.load(open('$polaris_file')); print(d.get('status',''))" 2>/dev/null || echo "")
  if [ "$status" = "active" ] && [ ! -f "${proj_dir}roadmap.md" ] && [ ! -f "${proj_dir}ROADMAP.md" ]; then
    proj_issues="${proj_issues}  ⚠️  active 项目缺少 roadmap.md\n"
  fi

  # Check 3: PolarSoul.md existence
  if [ ! -f "${proj_dir}PolarSoul.md" ]; then
    proj_issues="${proj_issues}  ⚠️  缺少 PolarSoul.md\n"
  fi

  # Check 4: features with done status but not_tested
  not_tested_count=$(python3 -c "
import json
with open('$polaris_file') as f:
    d = json.load(f)
count = 0
for r in d.get('requirements', []):
    for feat in r.get('features', []):
        if feat.get('status') == 'done' and feat.get('test_status') == 'not_tested':
            count += 1
print(count)
" 2>/dev/null || echo "0")

  if [ "$not_tested_count" -gt 0 ]; then
    proj_issues="${proj_issues}  ⚠️  ${not_tested_count} 个 done feature 未测试 (test_status=not_tested)\n"
  fi

  # Check 5: Skills coverage (3 standard skills expected)
  skills_count=$(find "${proj_dir}.cursor/skills/" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
  usage_exists=$(find "${proj_dir}.cursor/skills/" -name "SKILL.md" -path "*usage*" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$usage_exists" -eq 0 ]; then
    proj_issues="${proj_issues}  ⚠️  缺少 usage Skill\n"
  fi

  # Output per project
  if [ -n "$proj_issues" ]; then
    ISSUES=$((ISSUES + 1))
    echo "❌ $proj_name ($status)"
    echo -e "$proj_issues"
  elif [ "$VERBOSE" = "--verbose" ]; then
    echo "✅ $proj_name ($status) — polaris ${days_since_polaris}d ago, ${skills_count} skills"
  fi
done

echo "───────────────────────────────────────────"
echo "检查完成: ${CHECKED} 个项目, ${ISSUES} 个有问题"
if [ "$ISSUES" -eq 0 ]; then
  echo "✅ 所有项目文档状态健康"
else
  echo "⚠️  有 ${ISSUES} 个项目需要关注"
fi
echo ""
