#!/usr/bin/env bash
# AFK vNext IDE stop hook — continue conversation until completion gate passes.
# Lookup key: conversation_id + workspace cwd (NOT rr-chat sessionId).
# Install (reversible): add to ~/.cursor/hooks.json stop[] alongside manual-handoff-guard.
# fail-open: any error → {}
set -u

STATE_DIR="${AFK_HOOK_STATE_DIR:-$HOME/.polar-copilot/afk/hook-state}"
DB_PATH="${POLAR_AFK_DB:-$HOME/.polar-copilot/afk/afk.db}"
PC_BIN="${POLARCOP_PC_BIN:-}"
MAX_LOOP="${AFK_STOP_HOOK_MAX_LOOP:-200}"
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_PC_WRAPPER="${HOOK_DIR}/pc-afk.sh"

input=$(cat)
noop() { printf '{}\n'; exit 0; }
command -v jq >/dev/null 2>&1 || noop

event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
[ "$event" = "stop" ] || noop

status=$(printf '%s' "$input" | jq -r '.status // empty')
[ "$status" = "completed" ] || noop

conv=$(printf '%s' "$input" | jq -r '.conversation_id // empty')
[ -n "$conv" ] || noop

cwd=$(printf '%s' "$input" | jq -r '.workspace_roots[0] // empty')
loop_count=$(printf '%s' "$input" | jq -r '.loop_count // 0')
case "$loop_count" in ''|*[!0-9]*) loop_count=0 ;; esac
if [ "$loop_count" -ge "$MAX_LOOP" ]; then noop; fi

mkdir -p "$STATE_DIR" 2>/dev/null || true

# Prefer pc CLI gate check when available; else sqlite3; else continue-if-bound flag file.
gate_pass=false
task_id=""

if [ -z "$PC_BIN" ] && command -v pc >/dev/null 2>&1; then
  PC_BIN=$(command -v pc)
fi
if [ -z "$PC_BIN" ] && [ -x "$DEFAULT_PC_WRAPPER" ]; then
  PC_BIN="$DEFAULT_PC_WRAPPER"
fi

if [ -n "$PC_BIN" ] && [ -x "$PC_BIN" ]; then
  if [ -n "$cwd" ]; then
    out=$("$PC_BIN" afk gate-check --conversation-id "$conv" --cwd "$cwd" 2>/dev/null || true)
  else
    out=$("$PC_BIN" afk gate-check --conversation-id "$conv" 2>/dev/null || true)
  fi
  # unbound (ok:true, task_id null) or terminal → noop; else continue
  if printf '%s' "$out" | jq -e '.ok == true' >/dev/null 2>&1; then
    gate_pass=true
  fi
  task_id=$(printf '%s' "$out" | jq -r '.task_id // empty' 2>/dev/null || true)
  # If CLI returned nothing usable, fall through to sqlite with cwd filter
  if [ -z "$out" ] || ! printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
    PC_BIN=""
  fi
fi

if [ -z "$PC_BIN" ] || [ ! -x "$PC_BIN" ]; then
if command -v sqlite3 >/dev/null 2>&1 && [ -f "$DB_PATH" ]; then
  esc_conv=$(printf '%s' "$conv" | sed "s/'/''/g")
  esc_cwd=$(printf '%s' "$cwd" | sed "s/'/''/g")
  if [ -n "$cwd" ]; then
    row=$(sqlite3 "$DB_PATH" "SELECT t.task_id || '|' || t.status FROM tasks t JOIN runs r ON r.task_id=t.task_id AND r.status='owner' WHERE r.conversation_id='$esc_conv' AND t.project_root='$esc_cwd' LIMIT 1;" 2>/dev/null || true)
  else
    row=$(sqlite3 "$DB_PATH" "SELECT t.task_id || '|' || t.status FROM tasks t JOIN runs r ON r.task_id=t.task_id AND r.status='owner' WHERE r.conversation_id='$esc_conv' LIMIT 1;" 2>/dev/null || true)
  fi
  task_id=${row%%|*}
  st=${row##*|}
  if [ "$st" = "DONE" ] || [ "$st" = "CANCELLED" ] || [ "$st" = "PAUSED" ] || [ "$st" = "NEEDS_HUMAN" ]; then
    gate_pass=true
  fi
  if [ -z "$task_id" ]; then
    # No bound AFK task for this conversation (+ cwd) — do not loop
    noop
  fi
else
  # No DB / CLI: only continue if arm flag present for this conversation
  flag="$STATE_DIR/${conv}.armed"
  if [ ! -f "$flag" ]; then noop; fi
fi
fi

if [ "$gate_pass" = "true" ]; then noop; fi

msg="[AFK_CONTINUE] task=${task_id:-unknown} conversation=${conv} cwd=${cwd}
Completion gate not satisfied. Resume from CRITERIA.md / TODO.md / DECISIONS.md / EVIDENCE.md and the AFK SQLite task row — do not invent state from chat memory. Do not ask the user. Continue ACT→VERIFY until evaluateCompletion passes or a whitelisted NEEDS_HUMAN block. Never claim DONE without the gate."

jq -n --arg msg "$msg" '{followup_message: $msg}'
exit 0
