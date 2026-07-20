#!/usr/bin/env bash
# port-claim.sh — Shared port allocation via PolarPort API.
#
# Source this file from any Start/start.sh to replace hardcoded ports
# with dynamic allocation from PolarPort (:11050).
#
# Usage:
#   source "$(dirname "$0")/../../Agent_core/scripts/port-claim.sh"
#   PORT=$(claim_port "service-name" "ProjectName" 3910)
#
# Failure semantics (fixed 2026-07-20, was: silent fallback in all cases):
#   - PolarPort UNREACHABLE  -> fall back to preferred port (needed for
#     PolarPort's own bootstrap; callers wanting strict governance should
#     health-gate PolarPort before calling, or set PORT_CLAIM_STRICT=1).
#   - PolarPort REJECTS (4xx/5xx, e.g. "port not compliant: must end with
#     0 or 5") -> print error to stderr and return non-zero. NO fallback:
#     with `set -e`, PORT=$(claim_port ...) aborts the launcher, so a
#     service can never run on a port PolarPort refused to register.

POLARPORT_URL="${POLARPORT_URL:-http://127.0.0.1:11050}"
_PORT_CLAIM_TIMEOUT="${PORT_CLAIM_TIMEOUT:-6}"

claim_port() {
  local service_name="$1"
  local project="$2"
  local preferred_port="$3"

  if [ -z "$service_name" ] || [ -z "$project" ] || [ -z "$preferred_port" ]; then
    echo "$preferred_port"
    return 0
  fi

  local raw http_code body
  raw=$(curl -s --max-time "$_PORT_CLAIM_TIMEOUT" \
    -w '\n%{http_code}' \
    -X POST "${POLARPORT_URL}/api/allocate" \
    -H "Content-Type: application/json" \
    -d "{\"service_name\":\"${service_name}\",\"project\":\"${project}\",\"preferred_port\":${preferred_port}}" \
    2>/dev/null)

  http_code="${raw##*$'\n'}"
  body="${raw%$'\n'*}"

  if [ -z "$raw" ] || [ "$http_code" = "000" ] || [ -z "$http_code" ]; then
    # PolarPort unreachable (connection refused / timeout) — curl reports code 000
    if [ "${PORT_CLAIM_STRICT:-0}" = "1" ]; then
      echo "[port-claim] PolarPort unreachable at ${POLARPORT_URL} (strict mode, refusing fallback)" >&2
      return 1
    fi
    echo "[port-claim] warn: PolarPort unreachable, falling back to preferred port ${preferred_port}" >&2
    echo "$preferred_port"
    return 0
  fi

  if [ "$http_code" -ge 200 ] 2>/dev/null && [ "$http_code" -lt 300 ] 2>/dev/null; then
    local allocated
    allocated=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('port',''))" 2>/dev/null)
    if [ -n "$allocated" ]; then
      echo "$allocated"
      return 0
    fi
    echo "[port-claim] PolarPort returned 2xx but no port field: ${body}" >&2
    return 1
  fi

  # PolarPort is alive and explicitly rejected the claim — never fall back.
  echo "[port-claim] PolarPort rejected allocation (HTTP ${http_code}): ${body}" >&2
  return 1
}

release_port() {
  local port="$1"
  curl -sf --max-time "$_PORT_CLAIM_TIMEOUT" \
    -X POST "${POLARPORT_URL}/api/release" \
    -H "Content-Type: application/json" \
    -d "{\"port\":${port}}" \
    >/dev/null 2>&1 || true
}
