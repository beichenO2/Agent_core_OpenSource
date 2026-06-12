#!/bin/bash
# pc-safe-write.sh — Acquire file lease before writing, with cross-project handling
#
# Usage:
#   source pc-safe-write.sh
#   LOCK=$(pc_safe_write "/path/to/file" "change description")
#   ... edit file ...
#   pc_release_lock "$LOCK"
#
# Returns via stdout:
#   LOCK_ID:<lease_id>     — Lock acquired on own project
#   LOCK_ID:OVERRIDE       — Target project owner offline, locked directly
#   LOCK_ID:DELEGATED      — Owner will handle the change
#   LOCK_ID:BRANCH:<name>  — Written to collaboration branch
#
# Environment:
#   AGENT_ID      — Current agent's ID
#   PC_HUB_PORT   — Hub port
#   HUB_CALL      — Path to hub-call.sh
#   PROJECT_NAME  — Current agent's project name (optional, auto-detected)
#
set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_CALL="${HUB_CALL:-$_SCRIPT_DIR/hub-call.sh}"

pc_safe_write() {
  local FILE_PATH="$1"
  local CHANGE_DESC="${2:-change}"

  if [ -z "${AGENT_ID:-}" ] || [ -z "${PC_HUB_PORT:-}" ]; then
    echo "ERROR: AGENT_ID and PC_HUB_PORT must be set" >&2
    return 1
  fi

  local dir FILE_PROJECT=""
  dir=$(dirname "$FILE_PATH")
  while [ "$dir" != "/" ] && [ -z "$FILE_PROJECT" ]; do
    if [ -f "$dir/polaris.json" ] || [ -f "$dir/package.json" ]; then
      FILE_PROJECT=$(basename "$dir")
    fi
    dir=$(dirname "$dir")
  done

  local CURRENT_PROJECT="${PROJECT_NAME:-}"
  if [ -z "$FILE_PROJECT" ] || [ "$FILE_PROJECT" = "$CURRENT_PROJECT" ]; then
    _pc_acquire_lease "$FILE_PATH"
    return $?
  fi

  local OWNER_JSON OWNER_ID OWNER_ALIVE
  OWNER_JSON=$(curl -s "http://127.0.0.1:${PC_HUB_PORT}/api/ownership/$FILE_PROJECT" 2>/dev/null)
  OWNER_ID=$(echo "$OWNER_JSON" | python3 -c "import sys,json;print(json.loads(sys.stdin.read()).get('agent_id',''))" 2>/dev/null)
  OWNER_ALIVE=$(echo "$OWNER_JSON" | python3 -c "import sys,json;print(json.loads(sys.stdin.read()).get('alive',False))" 2>/dev/null)

  if [ -z "$OWNER_ID" ] || [ "$OWNER_ALIVE" != "True" ]; then
    echo "XPCP:OVERRIDE - $FILE_PROJECT owner offline, proceeding directly" >&2
    _pc_acquire_lease "$FILE_PATH"
    return $?
  fi

  local XPCP_ID="xpcp-$(date +%s)-$$"
  "$HUB_CALL" "$AGENT_ID" hub_publish \
    "{\"agent_id\":\"$AGENT_ID\",\"type\":\"xpcp_request\",\"payload\":{\"xpcp_id\":\"$XPCP_ID\",\"from\":\"$AGENT_ID\",\"to\":\"$OWNER_ID\",\"project\":\"$FILE_PROJECT\",\"file\":\"$FILE_PATH\",\"description\":\"$CHANGE_DESC\"}}" \
    2>/dev/null || true
  echo "XPCP:SENT to $OWNER_ID (id=$XPCP_ID) - waiting up to 5 min..." >&2

  local DECISION="" COUNT=0
  while [ $COUNT -lt 300 ]; do
    COUNT=$((COUNT + 1))
    sleep 1
    local EVENTS
    EVENTS=$("$HUB_CALL" "$AGENT_ID" hub_poll_events "{\"agent_id\":\"$AGENT_ID\"}" 2>/dev/null || echo '{}')
    DECISION=$(echo "$EVENTS" | python3 -c "
import sys,json
d=json.loads(sys.stdin.read())
for e in d.get('events',d.get('result',{}).get('events',[])):
    p=e.get('payload',{})
    if isinstance(p,str):
        try: p=json.loads(p)
        except: pass
    if isinstance(p,dict) and p.get('type')=='xpcp_decision' and p.get('xpcp_id')=='$XPCP_ID':
        print(p.get('decision','timeout')); break
" 2>/dev/null)
    [ -n "$DECISION" ] && break
  done

  case "${DECISION:-timeout}" in
    borrow)
      _pc_acquire_lease "$FILE_PATH"
      ;;
    delegate)
      echo "LOCK_ID:DELEGATED"
      ;;
    branch|timeout|*)
      local COLLAB_BRANCH="collab/${AGENT_ID}+${OWNER_ID}/$(date +%Y%m%d-%H%M%S)"
      git checkout -b "$COLLAB_BRANCH" 2>/dev/null || git checkout "$COLLAB_BRANCH" 2>/dev/null
      echo "XPCP:BRANCH - writing to $COLLAB_BRANCH" >&2
      echo "LOCK_ID:BRANCH:$COLLAB_BRANCH"
      ;;
  esac
}

_pc_acquire_lease() {
  local FILE_PATH="$1"
  local LOCK_RESULT STATUS LEASE_ID

  LOCK_RESULT=$("$HUB_CALL" "$AGENT_ID" hub_acquire_lease \
    "{\"agent_id\":\"$AGENT_ID\",\"path\":\"$FILE_PATH\",\"ttl_ms\":300000}" 2>/dev/null)
  STATUS=$(echo "$LOCK_RESULT" | python3 -c "import sys,json;print(json.loads(sys.stdin.read()).get('status',''))" 2>/dev/null)

  if [ "$STATUS" = "conflict" ]; then
    local HOLDER
    HOLDER=$(echo "$LOCK_RESULT" | python3 -c "import sys,json;print(json.loads(sys.stdin.read()).get('holder',{}).get('agent_id','?'))" 2>/dev/null)
    echo "LOCK_CONFLICT: $FILE_PATH held by $HOLDER, retrying in 30s..." >&2
    sleep 30
    LOCK_RESULT=$("$HUB_CALL" "$AGENT_ID" hub_acquire_lease \
      "{\"agent_id\":\"$AGENT_ID\",\"path\":\"$FILE_PATH\",\"ttl_ms\":300000}" 2>/dev/null)
  fi

  LEASE_ID=$(echo "$LOCK_RESULT" | python3 -c "import sys,json;d=json.loads(sys.stdin.read());print(d.get('lease',{}).get('lease_id',''))" 2>/dev/null)
  echo "LOCK_ID:${LEASE_ID}"
}

pc_release_lock() {
  local LOCK_VALUE="$1"
  if echo "$LOCK_VALUE" | grep -q "^LOCK_ID:[a-zA-Z0-9_-]"; then
    local LEASE_ID
    LEASE_ID=$(echo "$LOCK_VALUE" | cut -d: -f2)
    "$HUB_CALL" "$AGENT_ID" hub_release_lease \
      "{\"agent_id\":\"$AGENT_ID\",\"lease_id\":\"$LEASE_ID\"}" 2>/dev/null || true
  fi
}
