#!/usr/bin/env bash
# ui-prompt.sh — Agent-side helper to ask a question via Hub Web UI
# instead of Cursor's AskQuestion tool (avoids extra API requests).
#
# Usage:
#   answer=$(bash ui-prompt.sh "Which approach?" "Option A" "Option B" "Option C")
#   echo "User chose: $answer"
#
# Env:
#   GSD_HUB_PORT (default: from lib-isolate.sh or 9020)
#   GSD_UI_POLL_INTERVAL (default: 3 seconds)
#   GSD_UI_TIMEOUT (default: 300 seconds)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Try to source lib-isolate.sh for project-specific HUB_PORT
if [ -z "${GSD_HUB_PORT:-}" ] && [ -f "$SCRIPT_DIR/lib-isolate.sh" ]; then
  source "$SCRIPT_DIR/lib-isolate.sh" 2>/dev/null || true
  GSD_HUB_PORT="${HUB_PORT:-9020}"
fi

HUB_PORT="${GSD_HUB_PORT:-9020}"
POLL_INTERVAL="${GSD_UI_POLL_INTERVAL:-3}"
TIMEOUT="${GSD_UI_TIMEOUT:-300}"
PROMPT="${1:?Usage: ui-prompt.sh \"question\" \"opt1\" \"opt2\" [\"opt3\" ...]}"
shift

if [ $# -lt 2 ]; then
  echo "Error: need at least 2 options" >&2
  exit 1
fi

OPTIONS_JSON=$(printf '%s\n' "$@" | jq -R . | jq -s .)

PROMPT_JSON=$(printf '%s' "$PROMPT" | jq -Rs .)

RESPONSE=$(curl -sf -X POST "http://localhost:${HUB_PORT}/api/ui/prompts" \
  -H 'Content-Type: application/json' \
  -d "{\"prompt\":${PROMPT_JSON},\"options\":${OPTIONS_JSON}}")

PROMPT_ID=$(echo "$RESPONSE" | jq -r '.id')
if [ -z "$PROMPT_ID" ] || [ "$PROMPT_ID" = "null" ]; then
  echo "Error: failed to create prompt — Hub may not be running on port $HUB_PORT" >&2
  exit 1
fi

echo "⏳ Waiting for user response at http://localhost:${HUB_PORT}/ui" >&2

ELAPSED=0
while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  RESULT=$(curl -sf "http://localhost:${HUB_PORT}/api/ui/prompts/${PROMPT_ID}" 2>/dev/null || echo '{}')
  ANSWERED=$(echo "$RESULT" | jq -r '.answered // false')
  if [ "$ANSWERED" = "true" ]; then
    ANSWER=$(echo "$RESULT" | jq -r '.answer')
    echo "$ANSWER"
    exit 0
  fi
  sleep "$POLL_INTERVAL"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

echo "Error: timeout after ${TIMEOUT}s waiting for user response" >&2
exit 1
