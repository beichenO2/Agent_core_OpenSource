#!/usr/bin/env bash
# compile-gate-check.sh — 编译门控检查脚本
#
# 检查任务包是否满足编译质量要求，阻止未编译/编译不合格的任务包进入执行阶段。
#
# 用法：
#   bash compile-gate-check.sh <任务包路径>
#   bash compile-gate-check.sh 任务书/260518_反身性探查_compiled/PolarClaw.md
#
# 退出码：
#   0 — 全部通过
#   1 — 检查失败（输出失败项）
#   2 — 参数错误

set -uo pipefail

TASK_FILE="${1:-}"

if [[ -z "$TASK_FILE" ]]; then
  echo "ERROR: 缺少任务包路径参数" >&2
  echo "用法: bash compile-gate-check.sh <任务包.md>" >&2
  exit 2
fi

if [[ ! -f "$TASK_FILE" ]]; then
  echo "ERROR: 文件不存在: $TASK_FILE" >&2
  exit 2
fi

PASS=0
FAIL=0
WARN=0
FAILURES=()
WARNINGS=()

pass() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); FAILURES+=("$1"); }
warn() { WARN=$((WARN + 1)); WARNINGS+=("$1"); }

CONTENT=$(cat "$TASK_FILE")

# ── Gate 1: 路径检查 ──────────────────────────────────
if [[ "$TASK_FILE" == *"_compiled/"* ]]; then
  pass
else
  fail "G1-路径: 文件不在 _compiled/ 目录下 ($TASK_FILE)"
fi

# ── Gate 2: 14 项结构完整性检查 ──────────────────────────
REQUIRED_SECTIONS=(
  "用户最初始意见"
  "任务目标"
  "当前上下文"
  "Ownership.*边界"
  "白名单"
  "黑名单"
  "具体工作项"
  "目的.*方法.*步骤"
  "接口契约"
  "测试与验证"
  "文档同步"
  "清理要求"
  "执行顺序.*依赖"
  "完成定义"
)

SECTION_LABELS=(
  "1.用户最初始意见"
  "2.任务目标"
  "3.当前上下文"
  "4.Ownership边界"
  "5.白名单"
  "6.黑名单"
  "7.具体工作项"
  "8.目的方法步骤"
  "9.接口契约"
  "10.测试与验证"
  "11.文档同步"
  "12.清理要求"
  "13.执行顺序与依赖"
  "14.完成定义"
)

MISSING_SECTIONS=()
for i in "${!REQUIRED_SECTIONS[@]}"; do
  pattern="${REQUIRED_SECTIONS[$i]}"
  label="${SECTION_LABELS[$i]}"
  if echo "$CONTENT" | grep -qiE "(^#+.*${pattern}|^\*\*.*${pattern})"; then
    pass
  else
    MISSING_SECTIONS+=("$label")
  fi
done

if [[ ${#MISSING_SECTIONS[@]} -gt 0 ]]; then
  fail "G2-结构: 缺少 ${#MISSING_SECTIONS[@]} 项: ${MISSING_SECTIONS[*]}"
fi

# ── Gate 3: L1/L2/L4 测试分层检查 ────────────────────────
if echo "$CONTENT" | grep -qiE "L1.*契约|契约.*检查"; then
  pass
else
  fail "G3-L1: 缺少 L1 契约检查项"
fi

if echo "$CONTENT" | grep -qiE "L2.*环境|环境.*检查"; then
  pass
else
  fail "G3-L2: 缺少 L2 环境检查项"
fi

if echo "$CONTENT" | grep -qiE "L4.*部署|部署.*验证"; then
  pass
else
  fail "G3-L4: 缺少 L4 部署验证项"
fi

# ── Gate 4: 白名单质量检查 ──────────────────────────────
WL_START=$(echo "$CONTENT" | grep -n -iE "^#+.*白名单" | head -1 | cut -d: -f1)
if [[ -n "$WL_START" ]]; then
  WL_SECTION=$(echo "$CONTENT" | tail -n +"$WL_START" | head -30)
  PATH_ONLY_COUNT=$(echo "$WL_SECTION" | grep -cE "^- \`[^']+\`\s*$" || true)
  TOTAL_ITEMS=$(echo "$WL_SECTION" | grep -cE "^- " || true)

  if [[ "$TOTAL_ITEMS" -gt 0 && "$PATH_ONLY_COUNT" -eq "$TOTAL_ITEMS" ]]; then
    fail "G4-白名单: 所有项只写了路径，缺少改动目的说明"
  elif [[ "$TOTAL_ITEMS" -eq 0 ]]; then
    warn "G4-白名单: 白名单段为空或格式不标准"
  else
    pass
  fi
else
  warn "G4-白名单: 未找到白名单段"
fi

# ── Gate 5: 完成定义质量检查 ────────────────────────────
DONE_START=$(echo "$CONTENT" | grep -n -iE "^#+.*完成定义" | head -1 | cut -d: -f1)
if [[ -n "$DONE_START" ]]; then
  DONE_SECTION=$(echo "$CONTENT" | tail -n +"$DONE_START" | head -20)
  VAGUE_COUNT=$(echo "$DONE_SECTION" | grep -ciE "优化完成|适配完成|改进完成|基本完成|大致完成" || true)

  if [[ "$VAGUE_COUNT" -gt 0 ]]; then
    fail "G5-完成定义: 发现 $VAGUE_COUNT 处模糊表述（'优化完成'等）"
  else
    pass
  fi
else
  warn "G5-完成定义: 未找到完成定义段"
fi

# ── Gate 6: dep_type + merge_mode 检查 ───────────────────
if echo "$CONTENT" | grep -qiE "dep_type.*code|code.*dep_type"; then
  if echo "$CONTENT" | grep -qiE "merge_mode|merge.from.upstream|integration:|serial.in.same"; then
    pass
  else
    fail "G6-依赖: 存在 code 依赖但缺少 merge_mode 声明"
  fi
else
  pass
fi

# ── Gate 7: checklist 格式检查（具体工作项） ────────────
CHECKLIST_COUNT=$(echo "$CONTENT" | grep -cE "^- \[ \]" || true)
if [[ "$CHECKLIST_COUNT" -ge 2 ]]; then
  pass
else
  warn "G7-checklist: 具体工作项中 checklist 格式项少于 2（找到 $CHECKLIST_COUNT）"
fi

# ── 汇总输出 ────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
echo "  编译门控检查结果"
echo "  文件: $TASK_FILE"
echo "═══════════════════════════════════════════"
echo ""
echo "  通过: $PASS  |  失败: $FAIL  |  警告: $WARN"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "❌ 失败项:"
  for f in "${FAILURES[@]}"; do
    echo "   - $f"
  done
  echo ""
fi

if [[ $WARN -gt 0 ]]; then
  echo "⚠️  警告项:"
  for w in "${WARNINGS[@]}"; do
    echo "   - $w"
  done
  echo ""
fi

if [[ $FAIL -eq 0 ]]; then
  echo "✅ 编译门控通过 — 任务包可进入执行阶段"
  exit 0
else
  echo "🚫 编译门控未通过 — 请修复上述失败项后重新检查"
  exit 1
fi
