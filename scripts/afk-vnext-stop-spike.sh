#!/usr/bin/env bash
# AFK vNext stop-hook spike (synthetic). NOT installed into ~/.cursor/hooks.json by default.
# Proves: on stop+completed+gate unmet → emit followup_message keyed by conversation_id + cwd.
set -u
input=$(cat)
command -v jq >/dev/null 2>&1 || { printf '{}\n'; exit 0; }
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
status=$(printf '%s' "$input" | jq -r '.status // empty')
conv=$(printf '%s' "$input" | jq -r '.conversation_id // empty')
cwd=$(printf '%s' "$input" | jq -r '.workspace_roots[0] // empty')
loop_count=$(printf '%s' "$input" | jq -r '.loop_count // 0')
gate_pass=$(printf '%s' "$input" | jq -r '.afk_gate_pass // false')
case "$event" in
  stop)
    [ "$status" = "completed" ] || { printf '{}\n'; exit 0; }
    [ "$gate_pass" = "true" ] && { printf '{}\n'; exit 0; }
    [ -n "$conv" ] || { printf '{}\n'; exit 0; }
    case "$loop_count" in ''|*[!0-9]*) loop_count=0 ;; esac
    if [ "$loop_count" -ge 50 ]; then printf '{}\n'; exit 0; fi
    msg="[AFK_SPIKE] conversation=${conv} cwd=${cwd} — gate not met; continue from CRITERIA/TODO/EVIDENCE (not MCP sessionId)."
    jq -n --arg msg "$msg" '{followup_message: $msg}'
    ;;
  *) printf '{}\n' ;;
esac
