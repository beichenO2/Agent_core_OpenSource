#!/usr/bin/env bash
# pc-env-sync.sh - Environment synchronization script for PolarCopilot
#
# Reads service_management from polaris.json and executes:
#   1. Dependency installation
#   2. Database migrations
#   3. Service restart
#   4. Health check
#   5. Forbidden output detection (standalone)
#
# Usage:
#   source pc-env-sync.sh
#   pc_env_sync /path/to/project          # run full sync pipeline
#   pc_check_forbidden_output "text"       # check forbidden phrases
#
# Graceful degradation: missing polaris.json fields produce warnings,
# not errors. The script never exits on missing configuration.

set -euo pipefail

# --- Internal: read service_management from polaris.json ---
#
# Arguments:
#   $1  project directory containing polaris.json
#   $2  dot-separated key path inside service_management (e.g. install_command)
#
# Outputs the value to stdout; empty string if field missing or file absent.
_read_service_management() {
  local PROJECT_DIR="$1"
  local KEY_PATH="$2"
  local POLARIS="$PROJECT_DIR/polaris.json"

  if [ ! -f "$POLARIS" ]; then
    echo "[pc-env-sync] WARN: $POLARIS not found" >&2
    return 0
  fi

  python3 -c "
import sys, json
with open(sys.argv[1]) as f:
    d = json.load(f)
sm = d.get('service_management', {})
val = sm
for k in sys.argv[2].split('.'):
    if isinstance(val, dict):
        val = val.get(k, None)
    else:
        val = None
        break
if val is not None:
    print(val)
" "$POLARIS" "$KEY_PATH" 2>/dev/null || true
}

# --- pc_install_deps ---
#
# Install project dependencies.
# Reads install_command from polaris.json service_management.
# Falls back to auto-detection: package.json -> npm ci,
# requirements.txt -> pip install -r, pyproject.toml -> pip install -e .
pc_install_deps() {
  local PROJECT_DIR="${1:?Usage: pc_install_deps <project_dir>}"
  local CMD
  CMD=$(_read_service_management "$PROJECT_DIR" "install_command")

  if [ -z "$CMD" ]; then
    # Auto-detect based on project files
    if [ -f "$PROJECT_DIR/package.json" ]; then
      CMD="npm ci"
      echo "[pc-env-sync] INFO: auto-detected Node.js project, using: npm ci"
    elif [ -f "$PROJECT_DIR/requirements.txt" ]; then
      CMD="pip install -r requirements.txt"
      echo "[pc-env-sync] INFO: auto-detected Python (requirements.txt), using: pip install -r requirements.txt"
    elif [ -f "$PROJECT_DIR/pyproject.toml" ]; then
      CMD="pip install -e ."
      echo "[pc-env-sync] INFO: auto-detected Python (pyproject.toml), using: pip install -e ."
    else
      echo "[pc-env-sync] SKIP: no install_command in polaris.json and no recognized project files"
      return 0
    fi
  fi

  echo "[pc-env-sync] Installing dependencies: $CMD"
  if (cd "$PROJECT_DIR" && eval "$CMD"); then
    echo "[pc-env-sync] OK: dependencies installed"
    return 0
  else
    echo "[pc-env-sync] FAIL: dependency installation failed (exit code: $?)"
    return 1
  fi
}

# --- pc_run_migrations ---
#
# Run database migrations.
# Reads migration_command from polaris.json service_management.
# Skips if no migration command configured.
pc_run_migrations() {
  local PROJECT_DIR="${1:?Usage: pc_run_migrations <project_dir>}"
  local CMD
  CMD=$(_read_service_management "$PROJECT_DIR" "migration_command")

  if [ -z "$CMD" ]; then
    echo "[pc-env-sync] SKIP: no migration_command in polaris.json, migrations not applicable"
    return 0
  fi

  echo "[pc-env-sync] Running migrations: $CMD"
  if (cd "$PROJECT_DIR" && eval "$CMD"); then
    echo "[pc-env-sync] OK: migrations completed"
  else
    echo "[pc-env-sync] FAIL: migration failed (exit code: $?)"
    return 1
  fi

  # Optional: verify db-version if health_endpoint contains db-version path
  local HEALTH_EP
  HEALTH_EP=$(_read_service_management "$PROJECT_DIR" "health_endpoint")
  if [ -n "$HEALTH_EP" ]; then
    local DB_VERSION_EP=""
    case "$HEALTH_EP" in
      */api/health/db-version*) DB_VERSION_EP="$HEALTH_EP" ;;
      */api/health) DB_VERSION_EP="${HEALTH_EP}/db-version" ;;
      *) DB_VERSION_EP="" ;;
    esac
    if [ -n "$DB_VERSION_EP" ]; then
      local DB_VER
      DB_VER=$(curl -s --max-time 5 "$DB_VERSION_EP" 2>/dev/null || true)
      if [ -n "$DB_VER" ]; then
        echo "[pc-env-sync] DB version: $DB_VER"
      else
        echo "[pc-env-sync] WARN: could not fetch db-version from $DB_VERSION_EP"
      fi
    fi
  fi

  return 0
}

# --- pc_restart_services ---
#
# Restart project services.
# Reads restart_command from polaris.json service_management.
# Falls back to start_command (kill existing process, then start).
# Waits up to 30s for service readiness.
pc_restart_services() {
  local PROJECT_DIR="${1:?Usage: pc_restart_services <project_dir>}"
  local SERVICE_ID POLARPROCESS_URL
  POLARPROCESS_URL="${POLARPROCESS_URL:-http://127.0.0.1:11055}"
  SERVICE_ID=$(_read_service_management "$PROJECT_DIR" "service_id")

  if [ -n "$SERVICE_ID" ]; then
    if curl -fsS --max-time 3 "$POLARPROCESS_URL/api/health" >/dev/null 2>&1; then
      echo "[pc-env-sync] Restarting via PolarProcess: $SERVICE_ID"
      if curl -fsS -X POST "$POLARPROCESS_URL/api/services/${SERVICE_ID}/restart"; then
        echo "[pc-env-sync] OK: PolarProcess restart invoked"
      else
        echo "[pc-env-sync] FAIL: PolarProcess restart failed (exit code: $?)"
        return 1
      fi
    else
      echo "[pc-env-sync] FAIL: PolarProcess unavailable; refusing pkill/kill fallback for $SERVICE_ID" >&2
      return 1
    fi
  else
    local CMD
    CMD=$(_read_service_management "$PROJECT_DIR" "restart_command")
    if [ -z "$CMD" ]; then
      echo "[pc-env-sync] SKIP: no service_id or restart_command in polaris.json"
      return 0
    fi
    echo "[pc-env-sync] Restarting services (legacy restart_command): $CMD"
    if (cd "$PROJECT_DIR" && eval "$CMD"); then
      echo "[pc-env-sync] OK: restart command executed"
    else
      echo "[pc-env-sync] FAIL: restart command failed (exit code: $?)"
      return 1
    fi
  fi

  # Wait for service readiness (up to 30s)
  local HEALTH_EP
  HEALTH_EP=$(_read_service_management "$PROJECT_DIR" "health_endpoint")
  if [ -n "$HEALTH_EP" ]; then
    echo "[pc-env-sync] Waiting for service readiness (max 30s)..."
    local i=0
    while [ $i -lt 30 ]; do
      if curl -s --max-time 2 "$HEALTH_EP" >/dev/null 2>&1; then
        echo "[pc-env-sync] OK: service ready after $((i+1))s"
        return 0
      fi
      sleep 1
      i=$((i+1))
    done
    echo "[pc-env-sync] WARN: service not ready after 30s"
  else
    echo "[pc-env-sync] INFO: no health_endpoint configured, skipping readiness wait"
  fi

  return 0
}

# --- pc_health_check ---
#
# Check service health via HTTP GET.
# Reads health_endpoint from polaris.json service_management.
# Falls back to probing common ports (3000, 8000, 8080) at /api/health.
pc_health_check() {
  local PROJECT_DIR="${1:?Usage: pc_health_check <project_dir>}"
  local HEALTH_EP
  HEALTH_EP=$(_read_service_management "$PROJECT_DIR" "health_endpoint")

  if [ -z "$HEALTH_EP" ]; then
    echo "[pc-env-sync] INFO: no health_endpoint in polaris.json, probing common ports..."
    local PORTS=(3000 8000 8080)
    for PORT in "${PORTS[@]}"; do
      local PROBE_URL="http://127.0.0.1:$PORT/api/health"
      local RESP
      RESP=$(curl -s --max-time 3 -w '\n%{http_code}' "$PROBE_URL" 2>/dev/null || true)
      local HTTP_CODE
      HTTP_CODE=$(echo "$RESP" | tail -1)
      if [ "$HTTP_CODE" = "200" ]; then
        local BODY
        BODY=$(echo "$RESP" | sed '$d')
        echo "[pc-env-sync] OK: health check passed at $PROBE_URL"
        echo "[pc-env-sync] Response: $BODY"
        return 0
      fi
    done
    echo "[pc-env-sync] SKIP: no health_endpoint and no service found on common ports"
    return 0
  fi

  echo "[pc-env-sync] Checking health: $HEALTH_EP"
  local RESP
  RESP=$(curl -s --max-time 5 -w '\n%{http_code}' "$HEALTH_EP" 2>/dev/null || true)
  local HTTP_CODE
  HTTP_CODE=$(echo "$RESP" | tail -1)
  local BODY
  BODY=$(echo "$RESP" | sed '$d')

  if [ "$HTTP_CODE" = "200" ]; then
    echo "[pc-env-sync] OK: health check passed (HTTP 200)"
    echo "[pc-env-sync] Response: $BODY"
    return 0
  else
    echo "[pc-env-sync] FAIL: health check returned HTTP $HTTP_CODE"
    echo "[pc-env-sync] Response: $BODY"
    return 1
  fi
}

# --- pc_env_sync ---
#
# Main orchestrator: runs all sync steps in sequence.
# Each step failure is recorded but does not abort subsequent steps.
# Final verdict: all passed / some failures.
pc_env_sync() {
  local PROJECT_DIR="${1:?Usage: pc_env_sync <project_dir>}"
  local FAIL_COUNT=0

  echo ""
  echo "========================================"
  echo "  pc-env-sync: $PROJECT_DIR"
  echo "========================================"
  echo ""

  # Step 1: Install dependencies
  echo "=== pc_install_deps ==="
  if ! pc_install_deps "$PROJECT_DIR"; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo ""

  # Step 2: Run migrations
  echo "=== pc_run_migrations ==="
  if ! pc_run_migrations "$PROJECT_DIR"; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo ""

  # Step 3: Restart services
  echo "=== pc_restart_services ==="
  if ! pc_restart_services "$PROJECT_DIR"; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo ""

  # Step 4: Health check
  echo "=== pc_health_check ==="
  if ! pc_health_check "$PROJECT_DIR"; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo ""

  # Final verdict
  echo "========================================"
  if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "  VERDICT: ALL PASSED"
  else
    echo "  VERDICT: $FAIL_COUNT FAILURE(S) DETECTED"
  fi
  echo "========================================"
  echo ""

  return $FAIL_COUNT
}

# --- pc_check_forbidden_output ---
#
# Check Agent output text for forbidden phrases.
# Forbidden phrases: phrases that instruct the user to perform
# actions manually instead of the Agent doing them automatically.
#
# Forbidden list:
#   - "请手动" (please manually)
#   - "请重启" (please restart)
#   - "请运行" (please run)
#   - "你需要" (you need to)
#   - "建议你" (suggest you)
#
# Arguments:
#   $1  text to check (or -f <filepath> to read from file)
#
# Returns 0 if clean, 1 if forbidden phrases found.
pc_check_forbidden_output() {
  local TEXT=""
  if [ "${1:-}" = "-f" ]; then
    local FILEPATH="${2:?Usage: pc_check_forbidden_output [-f <file>] <text>}"
    if [ ! -f "$FILEPATH" ]; then
      echo "[pc-env-sync] ERROR: file not found: $FILEPATH" >&2
      return 1
    fi
    TEXT=$(cat "$FILEPATH")
  else
    TEXT="${1:-}"
  fi

  if [ -z "$TEXT" ]; then
    echo "[pc-env-sync] INFO: empty input, nothing to check"
    return 0
  fi

  local FORBIDDEN=("请手动" "请重启" "请运行" "你需要" "建议你")
  local FOUND=()
  local COUNT=0

  for phrase in "${FORBIDDEN[@]}"; do
    if echo "$TEXT" | grep -qF "$phrase"; then
      FOUND+=("$phrase")
      COUNT=$((COUNT + 1))
    fi
  done

  echo "[pc-env-sync] Forbidden output check:"
  echo "  Forbidden phrases detected: $COUNT"
  if [ ${#FOUND[@]} -gt 0 ]; then
    echo "  Found:"
    for f in "${FOUND[@]}"; do
      echo "    - $f"
    done
    echo "  VERDICT: FAILED (forbidden phrases present)"
    return 1
  else
    echo "  VERDICT: PASSED (no forbidden phrases)"
    return 0
  fi
}
