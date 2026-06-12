#!/bin/bash
# hub-call.sh — Call PolarCopilot Hub MCP tools via curl with persistent sessions
#
# Usage:
#   ./hub-call.sh <agent_id> <tool_name> '<json_args>'
#
# Examples:
#   ./hub-call.sh proxy-001 hub_register '{"agent_id":"proxy-001"}'
#   ./hub-call.sh proxy-001 hub_get_roles '{}'
#   ./hub-call.sh worker-001 hub_claim_task '{"agent_id":"worker-001"}'
#
# The agent_id is used to persist the session ID across calls.
# Session files are stored in /tmp/pc-<PROJECT_HASH>-<agent_id>.
#
# Environment:
#   PC_HUB_PORT      — Hub port (default: auto-derived from PC_PROJECT_HASH, fallback 8765)
#   PC_PROJECT_HASH  — 4-char project isolation prefix (auto-derived from pwd if unset)
#   HUB_URL          — Full Hub endpoint (overrides port)
#
set -euo pipefail

# Project isolation: derive a 4-char hash from project dir for unique namespacing
if [ -z "${PC_PROJECT_HASH:-}" ]; then
  _proj_dir="${PC_PROJECT_DIR:-$(pwd)}"
  PC_PROJECT_HASH=$(printf '%s' "$_proj_dir" | md5 -q 2>/dev/null | cut -c1-4 || printf '%s' "$_proj_dir" | md5sum 2>/dev/null | cut -c1-4 || echo "0000")
fi
export PC_PROJECT_HASH

# Port resolution order: env var > port-sdk discovery > deterministic hash derivation
if [ -z "${PC_HUB_PORT:-}" ]; then
  PC_HUB_PORT=$(curl -s --max-time 2 "http://127.0.0.1:4800/api/ports" 2>/dev/null \
    | python3 -c "
import sys,json
try:
    for p in json.loads(sys.stdin.read()):
        proj = p.get('project','').lower()
        if 'polarcop' in proj: print(p['port']); break
except: pass
" 2>/dev/null)
  if [ -z "${PC_HUB_PORT:-}" ]; then
    PC_HUB_PORT=$(printf '%d' "$((16#${PC_PROJECT_HASH} % 55535 + 10000))" 2>/dev/null || echo "8765")
  fi
fi

HUB_URL="${HUB_URL:-http://127.0.0.1:${PC_HUB_PORT}/mcp}"
AGENT_KEY="${1:?Usage: hub-call.sh <agent_id> <tool_name> '<json_args>'}"
TOOL_NAME="${2:?Usage: hub-call.sh <agent_id> <tool_name> '<json_args>'}"
TOOL_ARGS="${3:-\{\}}"
MAX_RETRIES="${PC_HUB_RETRIES:-5}"
CONNECT_TIMEOUT=3
MAX_TIME=30

ACCEPT="application/json, text/event-stream"
SESSION_FILE="/tmp/pc-${PC_PROJECT_HASH}-${AGENT_KEY}"

get_session() {
  if [ -f "$SESSION_FILE" ]; then
    cat "$SESSION_FILE"
    return
  fi

  local INIT_RESP
  INIT_RESP=$(curl -si "$HUB_URL" -X POST \
    --connect-timeout "$CONNECT_TIMEOUT" \
    --max-time "$MAX_TIME" \
    -H "Content-Type: application/json" \
    -H "Accept: $ACCEPT" \
    -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"'"$AGENT_KEY"'","version":"1.0"}},"id":0}' 2>/dev/null)

  local SID
  SID=$(echo "$INIT_RESP" | grep -i '^mcp-session-id:' | tr -d '\r\n' | awk '{print $2}')

  if [ -z "$SID" ]; then
    return 1
  fi

  echo "$SID" > "$SESSION_FILE"
  echo "$SID"
}

call_tool() {
  local SID="$1"
  curl -s "$HUB_URL" -X POST \
    --connect-timeout "$CONNECT_TIMEOUT" \
    --max-time "$MAX_TIME" \
    -H "Content-Type: application/json" \
    -H "Accept: $ACCEPT" \
    -H "mcp-session-id: $SID" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"$TOOL_NAME\",\"arguments\":$TOOL_ARGS},\"id\":1}" 2>/dev/null
}

auto_register() {
  local SID="$1"
  curl -s "$HUB_URL" -X POST \
    --connect-timeout "$CONNECT_TIMEOUT" \
    --max-time "$MAX_TIME" \
    -H "Content-Type: application/json" \
    -H "Accept: $ACCEPT" \
    -H "mcp-session-id: $SID" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"hub_register\",\"arguments\":{\"agent_id\":\"$AGENT_KEY\"}},\"id\":2}" >/dev/null 2>&1
}

_SKIP_SESSION_DELETE=0

needs_retry() {
  local RESP="$1"
  _SKIP_SESSION_DELETE=0
  [ -z "$RESP" ] && return 0
  case "$RESP" in
    *'Session not found'*) return 0 ;;
    *'ECONNREFUSED'*|*'connection refused'*) return 0 ;;
    *'not_registered'*)
      rm -f "$SESSION_FILE"
      local RE_SID
      RE_SID=$(get_session 2>/dev/null) && auto_register "$RE_SID"
      _SKIP_SESSION_DELETE=1
      return 0 ;;
  esac
  [[ "$RESP" == *"data: "* ]] && return 1
  return 0
}

ATTEMPT=0
TOOL_RESP=""

while [ $ATTEMPT -lt $MAX_RETRIES ]; do
  ATTEMPT=$((ATTEMPT + 1))

  SESSION_ID=$(get_session) || {
    rm -f "$SESSION_FILE"
    [ $ATTEMPT -lt $MAX_RETRIES ] && sleep "$((ATTEMPT))" && continue
    echo '{"ok":false,"error":"failed_to_initialize_session","port":'$PC_HUB_PORT',"attempts":'$ATTEMPT'}' >&2
    exit 1
  }

  TOOL_RESP=$(call_tool "$SESSION_ID")

  if needs_retry "$TOOL_RESP"; then
    [ "$_SKIP_SESSION_DELETE" -eq 0 ] && rm -f "$SESSION_FILE"
    [ $ATTEMPT -lt $MAX_RETRIES ] && sleep "$((ATTEMPT))" && continue
  else
    break
  fi
done

DATA_LINE="${TOOL_RESP#*data: }"
DATA_LINE="${DATA_LINE%%$'\n'*}"

if [ -z "$DATA_LINE" ]; then
  echo '{"ok":false,"error":"empty_response_after_retries","attempts":'$ATTEMPT',"raw":"'"${TOOL_RESP:0:200}"'"}' >&2
  exit 1
fi

python3 -c "
import sys,json
try:
    d=json.loads(sys.argv[1])
except json.JSONDecodeError as e:
    print(json.dumps({'ok':False,'error':'invalid_json','detail':str(e)}))
    sys.exit(1)
r=d.get('result',{})
for c in r.get('content',[]):
    if c.get('type')=='text':
        try:
            print(json.dumps(json.loads(c['text']),indent=2,ensure_ascii=False))
        except json.JSONDecodeError:
            print(c['text'])
        sys.exit(0)
if 'error' in d:
    print(json.dumps(d['error'],indent=2,ensure_ascii=False))
    sys.exit(1)
print(json.dumps(d,indent=2,ensure_ascii=False))
" "$DATA_LINE"
