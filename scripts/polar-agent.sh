#!/usr/bin/env bash
# polar-agent — run Cursor Agent CLI via PolarProcess (proxy + lifecycle authority).
#
# Usage:
#   polar-agent.sh --prompt-file /path/to/prompt.md
#   polar-agent.sh --prompt "Reply with exactly: OK"
#   echo "..." | polar-agent.sh --prompt-file -
#
# Env:
#   PC_PROJECT_DIR / --workspace   workspace (default: cwd)
#   POLARPROCESS_URL               default http://127.0.0.1:11055
#   AGENT_BIN                      default: $(command -v agent)
#   CURSOR_CLI_MODEL               default: composer-2.5-fast
#   CURSOR_CLI_JOB_ROOT            default: ~/.cursor-cli/jobs
#   POLAR_AGENT_TIMEOUT_SEC        default: 900
set -euo pipefail

AGENT_CORE_ROOT=$(cd "$(dirname "$0")/.." && pwd)
POLARPROCESS_URL="${POLARPROCESS_URL:-http://127.0.0.1:11055}"
POLARPROCESS_URL="${POLARPROCESS_URL%/}"
JOB_ROOT="${CURSOR_CLI_JOB_ROOT:-$HOME/.cursor-cli/jobs}"
MODEL="${CURSOR_CLI_MODEL:-composer-2.5-fast}"
TIMEOUT_SEC="${POLAR_AGENT_TIMEOUT_SEC:-900}"
WS="${PC_PROJECT_DIR:-}"
PROMPT_FILE=""
PROMPT_TEXT=""
SERVICE_PREFIX="cursor-cli-"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt-file) PROMPT_FILE="${2:?}"; shift 2 ;;
    --prompt) PROMPT_TEXT="${2:?}"; shift 2 ;;
    --workspace) WS="${2:?}"; shift 2 ;;
    --model) MODEL="${2:?}"; shift 2 ;;
    --timeout) TIMEOUT_SEC="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *)
      if [[ -z "$PROMPT_FILE" && -z "$PROMPT_TEXT" && -f "$1" ]]; then
        PROMPT_FILE="$1"; shift
      else
        echo "unknown arg: $1" >&2
        usage
      fi
      ;;
  esac
done

WS="${WS:-$(pwd)}"
WS="$(cd "$WS" && pwd)"

if [[ -n "$PROMPT_FILE" ]]; then
  if [[ "$PROMPT_FILE" == "-" ]]; then
    PROMPT_TEXT="$(cat)"
  else
    PROMPT_TEXT="$(cat "$PROMPT_FILE")"
  fi
fi
if [[ -z "${PROMPT_TEXT// }" ]]; then
  echo "FAIL: empty prompt (use --prompt-file or --prompt)" >&2
  exit 3
fi

AGENT_BIN="${AGENT_BIN:-$(command -v agent || true)}"
if [[ -z "$AGENT_BIN" ]]; then
  echo "FAIL: agent not in PATH" >&2
  exit 3
fi

if ! curl -fsS --max-time 3 "$POLARPROCESS_URL/api/health" >/dev/null; then
  echo "FAIL: PolarProcess unreachable at $POLARPROCESS_URL — start it before polar-agent" >&2
  echo "hint: bash ~/Polarisor/PolarProcess/Start/start.sh restart" >&2
  exit 4
fi

PROXY_JSON="$(curl -fsS --max-time 3 "$POLARPROCESS_URL/api/runtime/proxy" || true)"
if [[ -n "$PROXY_JSON" ]]; then
  echo "polar-agent: PolarProcess proxy → $(echo "$PROXY_JSON" | python3 -c 'import sys,json; d=json.load(sys.stdin); p=d.get("proxy") or d; print("applied=%s source=%s http=%s" % (p.get("applied"), p.get("source"), p.get("httpProxy") or "-"))' 2>/dev/null || echo ok)"
fi

JOB_ID="$(python3 - <<'PY'
import secrets, time
print(time.strftime("%Y%m%dT%H%M%S") + "-" + secrets.token_hex(3))
PY
)"
SERVICE_ID="${SERVICE_PREFIX}${JOB_ID}"
JOB_DIR="$JOB_ROOT/$JOB_ID"
mkdir -p "$JOB_DIR"
chmod 700 "$JOB_ROOT" "$JOB_DIR" 2>/dev/null || true

printf '%s' "$PROMPT_TEXT" >"$JOB_DIR/prompt.txt"
python3 - "$JOB_DIR/job.json" "$WS" "$MODEL" "$AGENT_BIN" "$SERVICE_ID" <<'PY'
import json, sys
path, ws, model, agent, sid = sys.argv[1:6]
json.dump({
  "workspace": ws,
  "model": model,
  "agent_bin": agent,
  "service_id": sid,
}, open(path, "w", encoding="utf-8"), indent=2)
open(path, "a", encoding="utf-8").write("\n")
PY

# Expanded env path — no shell metacharacters for command-guard.
WORKER_CMD="CURSOR_CLI_JOB_DIR=${JOB_DIR} bash Start/cursor-cli-worker.sh"

PAYLOAD="$(python3 - "$SERVICE_ID" "$JOB_ID" "$WORKER_CMD" "$AGENT_CORE_ROOT" <<'PY'
import json, sys
sid, jid, cmd, root = sys.argv[1:5]
print(json.dumps({
  "id": sid,
  "name": f"Cursor CLI · {jid}",
  "command": cmd,
  "work_dir": root,
  "device_id": "any",
  "auto_start": False,
  "restart_on_failure": False,
  "max_restarts": 0,
  "port": None,
  "health_check_url": None,
  "start_script_dir": "-",
}))
PY
)"

curl -fsS -X POST "$POLARPROCESS_URL/api/services/${SERVICE_ID}/stop" >/dev/null 2>&1 || true

START_RESP="$(curl -fsS -X POST "$POLARPROCESS_URL/api/services/register-and-start" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD")" || {
  echo "FAIL: register-and-start request failed" >&2
  exit 5
}

echo "polar-agent: started service=$SERVICE_ID job=$JOB_DIR"
echo "$START_RESP" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("polar-agent: ok=%s pid=%s msg=%s" % (d.get("ok"), d.get("pid"), d.get("message","")))' 2>/dev/null || echo "$START_RESP"

if ! echo "$START_RESP" | python3 -c 'import sys,json; raise SystemExit(0 if json.load(sys.stdin).get("ok") else 1)'; then
  echo "FAIL: PolarProcess refused start" >&2
  echo "$START_RESP" >&2
  exit 5
fi

deadline=$(( $(date +%s) + TIMEOUT_SEC ))
status="starting"
while (( $(date +%s) < deadline )); do
  svc_json="$(curl -fsS --max-time 3 "$POLARPROCESS_URL/api/services/${SERVICE_ID}" 2>/dev/null || true)"
  if [[ -n "$svc_json" ]]; then
    status="$(echo "$svc_json" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status",""))' 2>/dev/null || echo "")"
    if [[ "$status" == "stopped" || "$status" == "error" ]]; then
      break
    fi
  fi
  sleep 1
done

if [[ "$status" == "running" || "$status" == "starting" ]]; then
  echo "FAIL: timed out after ${TIMEOUT_SEC}s (service=$SERVICE_ID status=$status)" >&2
  curl -fsS -X POST "$POLARPROCESS_URL/api/services/${SERVICE_ID}/stop" >/dev/null 2>&1 || true
  [[ -f "$JOB_DIR/output.log" ]] && cat "$JOB_DIR/output.log"
  exit 2
fi

curl -fsS -X POST "$POLARPROCESS_URL/api/services/${SERVICE_ID}/stop" >/dev/null 2>&1 || true

if [[ -f "$JOB_DIR/output.log" ]]; then
  cat "$JOB_DIR/output.log"
else
  echo "WARN: no output.log (status=$status)" >&2
fi

code=1
if [[ -f "$JOB_DIR/exit_code" ]]; then
  code="$(tr -d '[:space:]' <"$JOB_DIR/exit_code")"
elif [[ "$status" == "stopped" ]]; then
  code=0
fi

echo "polar-agent: finished status=$status exit=$code service=$SERVICE_ID"
echo "polar-agent: job_dir=$JOB_DIR"
exit "$code"
