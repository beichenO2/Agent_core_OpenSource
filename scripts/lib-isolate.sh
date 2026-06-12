#!/bin/bash
# lib-isolate.sh — Project isolation primitives for gsd-2
#
# Source this file to get project-scoped tmux prefix and Hub port.
# Prevents cross-project session/port collisions.
#
# Usage:
#   source "$(dirname "$0")/lib-isolate.sh"
#   echo "$TMUX_PREFIX"  # e.g. g-a1b2
#   echo "$HUB_PORT"     # e.g. 14523

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GSD2_DIR="$(dirname "$SCRIPT_DIR")"

# If GSD_PROJECT_DIR is set, use it. Otherwise derive from GSD2_DIR, but
# guard against the case where gsd-2 is a global install (e.g. ~/.gsd2/core)
# rather than a project-local copy.
if [ -n "${GSD_PROJECT_DIR:-}" ]; then
  PROJECT_DIR="$GSD_PROJECT_DIR"
elif [[ "$GSD2_DIR" == */.gsd2/* ]]; then
  PROJECT_DIR="$(pwd)"
else
  PROJECT_DIR="$(dirname "$GSD2_DIR")"
fi

# Deterministic 4-char hash from project path
if command -v md5 >/dev/null 2>&1; then
  GSD_PROJECT_HASH=$(printf '%s' "$PROJECT_DIR" | md5 -q | cut -c1-4)
elif command -v md5sum >/dev/null 2>&1; then
  GSD_PROJECT_HASH=$(printf '%s' "$PROJECT_DIR" | md5sum | cut -c1-4)
else
  GSD_PROJECT_HASH=$(printf '%s' "$PROJECT_DIR" | cksum | cut -d' ' -f1 | cut -c1-4)
fi

# Port allocation: prefer SOTAgent API, fallback to deterministic hash (compliant with 5/0 rule)
if [ -z "${GSD_HUB_PORT:-}" ]; then
  _SOTAGENT_PORT=$(cat "$HOME/.sotagent/ports.json" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('sotagent_api',''))" 2>/dev/null || echo "")
  if [ -n "$_SOTAGENT_PORT" ]; then
    _ALLOC=$(curl -s --max-time 3 "http://127.0.0.1:${_SOTAGENT_PORT}/api/ports/allocate" \
      -X POST -H "Content-Type: application/json" \
      -d "{\"service_name\":\"gsd2-hub-${GSD_PROJECT_HASH}\",\"project\":\"$(basename "$PROJECT_DIR")\",\"range_start\":10000,\"range_end\":65530}" 2>/dev/null || echo "")
    _ALLOC_PORT=$(echo "$_ALLOC" | python3 -c "import sys,json; print(json.load(sys.stdin).get('port',''))" 2>/dev/null || echo "")
  fi
  if [ -n "${_ALLOC_PORT:-}" ]; then
    HUB_PORT="$_ALLOC_PORT"
  else
    # Fallback: deterministic hash rounded to nearest 5 (compliant)
    _raw=$((16#${GSD_PROJECT_HASH} % 55535 + 10000))
    HUB_PORT=$((_raw - _raw % 5))
  fi
else
  HUB_PORT="$GSD_HUB_PORT"
fi

TMUX_PREFIX="g-${GSD_PROJECT_HASH}"
# Embed port & hash so Cursor agent shells (which lack exported env vars) use the correct Hub
HUB_CALL="GSD_HUB_PORT=$HUB_PORT GSD_PROJECT_HASH=$GSD_PROJECT_HASH $SCRIPT_DIR/hub-call.sh"
CURSOR_BIN=""
PROMPT_DIR="/tmp/gsd2-${GSD_PROJECT_HASH}-prompts"

# Detect Cursor CLI
for p in \
  /Applications/Cursor.app/Contents/Resources/app/bin/cursor \
  "$HOME/.local/bin/cursor" \
  /usr/local/bin/cursor \
  "$(command -v cursor 2>/dev/null || true)"; do
  [ -n "$p" ] && [ -x "$p" ] && { CURSOR_BIN="$p"; break; }
done

# Export for child processes (hub-call.sh reads GSD_HUB_PORT)
export GSD_HUB_PORT="$HUB_PORT"
export GSD_PROJECT_HASH
export GSD_PROJECT_DIR="$PROJECT_DIR"

# Convenience: check if Hub is reachable
hub_alive() {
  curl -s --max-time 3 "http://127.0.0.1:$HUB_PORT/mcp" -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"lib","version":"1.0"}},"id":0}' 2>/dev/null | grep -q 'gsd-2-hub'
}

# Convenience: count sessions matching our prefix
our_sessions() {
  tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^${TMUX_PREFIX}-" | wc -l | tr -d ' '
}

# Convenience: kill all our sessions except hub
kill_our_agents() {
  for s in $(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^${TMUX_PREFIX}-" | grep -v "^${TMUX_PREFIX}-hub$" || true); do
    tmux kill-session -t "$s" 2>/dev/null || true
  done
}

# Kill orphan processes belonging to this project (PPID=1, escaped from tmux)
kill_orphans() {
  local KILLED=0

  # Method 1: pidfile-based cleanup
  for pidfile in /tmp/gsd2-${GSD_PROJECT_HASH}-*.pid; do
    [ -f "$pidfile" ] || continue
    local PID
    PID=$(cat "$pidfile" 2>/dev/null) || continue
    if kill -0 "$PID" 2>/dev/null; then
      kill -- -"$PID" 2>/dev/null || kill "$PID" 2>/dev/null || true
      KILLED=$((KILLED + 1))
    fi
    rm -f "$pidfile"
  done

  # Method 2: pattern-match orphan loops (PPID=1) tied to our project hash
  # Exclude server.ts (Hub process managed by launchctl — not an orphan)
  local ORPHAN_PIDS
  ORPHAN_PIDS=$(ps -eo pid,ppid,command | awk '$2==1' | \
    grep -E "(gsd2-${GSD_PROJECT_HASH}|GSD_PROJECT_HASH=${GSD_PROJECT_HASH})" | \
    grep -v grep | grep -v 'server\.ts' | awk '{print $1}')
  if [ -n "$ORPHAN_PIDS" ]; then
    echo "$ORPHAN_PIDS" | xargs kill -TERM 2>/dev/null || true
    sleep 1
    echo "$ORPHAN_PIDS" | xargs kill -9 2>/dev/null || true
    KILLED=$((KILLED + $(echo "$ORPHAN_PIDS" | wc -l | tr -d ' ')))
  fi

  [ $KILLED -gt 0 ] && echo "  清理了 $KILLED 个孤儿进程"
  return 0
}

# Kill ALL orphan gsd-2 processes across all projects (nuclear option)
kill_all_gsd2_orphans() {
  local ORPHAN_PIDS
  # Exclude server.ts (Hub process managed by launchctl — intentional daemon, not orphan)
  ORPHAN_PIDS=$(ps -eo pid,ppid,command | awk '$2==1' | \
    grep -E "(standby-|hub-loop|hub_claim|hub_poll|hub_heartbeat|ctrl-hub-loop|super-hub-loop|gsd2-)" | \
    grep -v grep | grep -v 'server\.ts' | awk '{print $1}')
  if [ -n "$ORPHAN_PIDS" ]; then
    local COUNT
    COUNT=$(echo "$ORPHAN_PIDS" | wc -l | tr -d ' ')
    echo "$ORPHAN_PIDS" | xargs kill -TERM 2>/dev/null || true
    sleep 2
    echo "$ORPHAN_PIDS" | xargs kill -9 2>/dev/null || true
    echo "  清理了 $COUNT 个全局孤儿进程"
  else
    echo "  无孤儿进程"
  fi
}
