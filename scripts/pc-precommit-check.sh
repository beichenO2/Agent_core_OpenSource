#!/bin/bash
# pc-precommit-check.sh — Check for remote conflicts before committing
#
# Usage:
#   source pc-precommit-check.sh
#   pc_precommit_check && git commit -m "..." && git push
#
# Returns:
#   0 — No conflicts, safe to commit
#   1 — Conflicts detected, sends prompt to Hub for user decision
#
# Environment:
#   AGENT_ID      — Current agent's ID
#   PC_HUB_PORT   — Hub port
#
set -euo pipefail

pc_send_precommit_prompt() {
  local PROMPT="$1"
  local OPTIONS_JSON="${2:-[\"我知道了\"]}"

  if [ -z "${PC_HUB_PORT:-}" ] || [ -z "${AGENT_ID:-}" ]; then
    return 0
  fi

  python3 - "$PC_HUB_PORT" "$AGENT_ID" "$PROMPT" "$OPTIONS_JSON" <<'PY' 2>/dev/null || true
import json
import sys
import urllib.request

port, agent_id, prompt, options_raw = sys.argv[1:5]
try:
    options = json.loads(options_raw)
except Exception:
    options = ["我知道了"]

payload = json.dumps({"agent_id": agent_id, "prompt": prompt, "options": options}, ensure_ascii=False).encode("utf-8")
req = urllib.request.Request(
    f"http://127.0.0.1:{port}/api/ui/prompts",
    data=payload,
    method="POST",
    headers={"Content-Type": "application/json"},
)
urllib.request.urlopen(req, timeout=3).read()
PY
}

pc_ssot_precommit_check() {
  local TOP
  TOP=$(git rev-parse --show-toplevel 2>/dev/null) || return 0

  local POLARIS_PATH=""
  if [ -f "$TOP/polaris.json" ]; then
    POLARIS_PATH="polaris.json"
  fi

  if [ -z "$POLARIS_PATH" ]; then
    return 0
  fi

  local CHANGED
  CHANGED=$(git diff --cached --name-only 2>/dev/null || true)
  if [ -z "$CHANGED" ]; then
    CHANGED=$(git diff --name-only 2>/dev/null || true)
  fi
  if [ -z "$CHANGED" ]; then
    return 0
  fi

  local HAS_POLARIS=0
  local HAS_SRC_CHANGE=0
  local SRC_FILES=""
  while IFS= read -r FILE_PATH; do
    [ -z "$FILE_PATH" ] && continue
    if [ "$FILE_PATH" = "$POLARIS_PATH" ]; then
      HAS_POLARIS=1
      continue
    fi

    case "$FILE_PATH" in
      .planning/diff/*|*.log|*.jsonl|package-lock.json|pnpm-lock.yaml|yarn.lock|*.gitkeep)
        ;;
      src/*|lib/*|backend/*|frontend/*|*.ts|*.js|*.py)
        HAS_SRC_CHANGE=1
        SRC_FILES="$SRC_FILES $FILE_PATH"
        ;;
      *)
        ;;
    esac
  done <<< "$CHANGED"

  if [ "$HAS_POLARIS" -eq 1 ]; then
    if command -v node >/dev/null 2>&1; then
      node -e "const fs=require('fs'); JSON.parse(fs.readFileSync(process.argv[1], 'utf8'))" "$TOP/$POLARIS_PATH" 2>/dev/null || {
        echo "SSOT: $POLARIS_PATH is not valid JSON" >&2
        pc_send_precommit_prompt "SSoT 检查失败：$POLARIS_PATH 不是合法 JSON，请先修复再提交。" "[\"修复 polaris.json\",\"跳过本次提交\"]"
        return 1
      }
    fi
    # polaris.json included — auto-update _meta.last_synced_at
    _pc_ssot_touch_meta "$TOP/$POLARIS_PATH"
  fi

  if [ "$HAS_SRC_CHANGE" -eq 1 ] && [ "$HAS_POLARIS" -eq 0 ]; then
    echo "SSOT-WARN: source changes without polaris.json update:$SRC_FILES" >&2
    echo "  (non-blocking — remember to sync polaris.json before PR merge)" >&2
  fi

  local AUDIT_SCRIPT="$HOME/Polarisor/PolarCopilot/hub/scripts/ssot-audit.mjs"
  if [ -f "$AUDIT_SCRIPT" ] && command -v node >/dev/null 2>&1; then
    node "$AUDIT_SCRIPT" >/dev/null 2>&1 || true
  fi

  return 0
}

_pc_ssot_touch_meta() {
  local POLARIS_FILE="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$POLARIS_FILE" <<'PY' 2>/dev/null || true
import json, sys
from datetime import datetime, timezone, timedelta
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
tz = timezone(timedelta(hours=8))
now = datetime.now(tz).isoformat(timespec='seconds')
if '_meta' not in d:
    d['_meta'] = {}
d['_meta']['last_synced_at'] = now
d['_meta']['schema_version'] = d['_meta'].get('schema_version', '1.0')
with open(path, 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
    f.write('\n')
PY
    git add "$POLARIS_FILE" 2>/dev/null || true
  fi
}

ssot_deep_precommit_check() {
  local TOP
  TOP=$(git rev-parse --show-toplevel 2>/dev/null) || return 0

  # 获取本次 commit 变更中的 SSoT 文件
  local CHANGED_SSoT
  CHANGED_SSoT=$(git diff --cached --name-only 2>/dev/null | grep -E '(polaris\.json|PolarSoul\.md|capabilities\.json)' | sed "s|^${TOP#/}/||" || true)

  if [ -z "$CHANGED_SSoT" ]; then
    return 0
  fi

  local PRECOMMIT_SCRIPT="$HOME/Polarisor/Agent_core/scripts/ssot-precommit.mjs"
  if [ -f "$PRECOMMIT_SCRIPT" ] && command -v node >/dev/null 2>&1; then
    node "$PRECOMMIT_SCRIPT" --check-files "$CHANGED_SSoT"
    return $?
  fi

  return 0
}

pc_precommit_check() {
  git fetch origin --quiet 2>/dev/null || return 0

  local BRANCH
  BRANCH=$(git branch --show-current 2>/dev/null)
  if [ -z "$BRANCH" ]; then
    return 0
  fi

  if ! git rev-parse "origin/$BRANCH" >/dev/null 2>&1; then
    return 0
  fi

  local BASE
  BASE=$(git merge-base HEAD "origin/$BRANCH" 2>/dev/null) || return 0

  local CONFLICT_FILES
  CONFLICT_FILES=$(git diff --name-only HEAD "origin/$BRANCH" 2>/dev/null | while read -r f; do
    git diff --name-only HEAD -- "$f" 2>/dev/null | grep -q . && echo "$f"
  done)

  local CONFLICT_COUNT
  CONFLICT_COUNT=$(echo "$CONFLICT_FILES" | grep -c . 2>/dev/null || echo 0)

  if [ "${CONFLICT_COUNT:-0}" -gt 0 ]; then
    if [ -n "${PC_HUB_PORT:-}" ] && [ -n "${AGENT_ID:-}" ]; then
      curl -s "http://127.0.0.1:${PC_HUB_PORT}/api/ui/prompts" -X POST \
        -H "Content-Type: application/json" \
        -d "{\"agent_id\":\"$AGENT_ID\",\"prompt\":\"检测到 $CONFLICT_COUNT 个文件与远端存在重叠修改，可能冲突：\\n$(echo "$CONFLICT_FILES" | head -5 | sed 's/^/- /')\\n\\n建议操作：\",\"options\":[\"强制 push 我的版本\",\"拉取合并后再 push\",\"创建协作分支\"]}" \
        2>/dev/null || true
    fi
    echo "CONFLICT: $CONFLICT_COUNT files overlap with remote" >&2
    return 1
  fi

  pc_ssot_precommit_check || return 1
  ssot_deep_precommit_check || return 1
  return 0
}
