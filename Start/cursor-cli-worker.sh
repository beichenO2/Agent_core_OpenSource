#!/usr/bin/env bash
# PolarProcess-managed Cursor Agent CLI worker (foreground).
# Invoked only via PolarProcess register-and-start — inherits HTTP_PROXY from PolarProcess.
# Job contract: $CURSOR_CLI_JOB_DIR/job.json + prompt.txt → output.log + exit_code
set -euo pipefail

AGENT_CORE_ROOT=$(cd "$(dirname "$0")/.." && pwd)
JOB_DIR="${CURSOR_CLI_JOB_DIR:-}"

if [[ -z "$JOB_DIR" || ! -d "$JOB_DIR" ]]; then
  echo "cursor-cli-worker: CURSOR_CLI_JOB_DIR missing or not a directory" >&2
  exit 3
fi

JOB_JSON="$JOB_DIR/job.json"
PROMPT_FILE="$JOB_DIR/prompt.txt"
OUTPUT_LOG="$JOB_DIR/output.log"
EXIT_FILE="$JOB_DIR/exit_code"

if [[ ! -f "$JOB_JSON" || ! -f "$PROMPT_FILE" ]]; then
  echo "cursor-cli-worker: job.json or prompt.txt missing under $JOB_DIR" >&2
  exit 3
fi

# Drop IDE-nested env that breaks headless agent -p
unset CURSOR_AGENT VSCODE_IPC_HOOK VSCODE_CODE_CACHE_PATH CURSOR_EXTENSION_HOST_ROLE 2>/dev/null || true

eval "$(python3 - "$JOB_JSON" <<'PY'
import json, shlex, sys
job = json.load(open(sys.argv[1], encoding="utf-8"))
ws = job.get("workspace") or ""
model = job.get("model") or "composer-2.5-fast"
agent = job.get("agent_bin") or ""
print(f"WS={shlex.quote(ws)}")
print(f"MODEL={shlex.quote(model)}")
print(f"AGENT_BIN={shlex.quote(agent)}")
PY
)"

if [[ -z "${AGENT_BIN}" ]]; then
  AGENT_BIN="$(command -v agent || true)"
fi
if [[ -z "${AGENT_BIN}" || ! -x "${AGENT_BIN}" ]]; then
  echo "cursor-cli-worker: agent binary not found" >&2
  echo 127 >"$EXIT_FILE"
  exit 127
fi
if [[ -z "${WS}" || ! -d "${WS}" ]]; then
  echo "cursor-cli-worker: workspace missing: ${WS:-}" >&2
  echo 3 >"$EXIT_FILE"
  exit 3
fi

export PC_PROJECT_DIR="$WS"

# Prove PolarProcess proxy inheritance in the job artifact (no secrets).
{
  echo "=== polar-cursor-cli worker ==="
  echo "workspace=$WS"
  echo "model=$MODEL"
  echo "agent=$AGENT_BIN"
  echo "HTTP_PROXY=${HTTP_PROXY:-}"
  echo "HTTPS_PROXY=${HTTPS_PROXY:-}"
  echo "NODE_USE_ENV_PROXY=${NODE_USE_ENV_PROXY:-}"
  echo "NO_PROXY=${NO_PROXY:-}"
  echo "=== agent output ==="
} >"$OUTPUT_LOG"

set +e
"$AGENT_BIN" -p --trust --force --yolo --approve-mcps --sandbox disabled \
  --output-format json \
  --model "$MODEL" \
  --workspace "$WS" \
  "$(cat "$PROMPT_FILE")" >>"$OUTPUT_LOG" 2>&1
code=$?
set -e

echo "$code" >"$EXIT_FILE"
exit "$code"
