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
# If PolarPort is unreachable, falls back to the preferred port.

POLARPORT_URL="${POLARPORT_URL:-http://127.0.0.1:11050}"
_PORT_CLAIM_TIMEOUT=2

claim_port() {
  local service_name="$1"
  local project="$2"
  local preferred_port="$3"

  if [ -z "$service_name" ] || [ -z "$project" ] || [ -z "$preferred_port" ]; then
    echo "$preferred_port"
    return 0
  fi

  local response
  response=$(curl -sf --max-time "$_PORT_CLAIM_TIMEOUT" \
    -X POST "${POLARPORT_URL}/api/allocate" \
    -H "Content-Type: application/json" \
    -d "{\"service_name\":\"${service_name}\",\"project\":\"${project}\",\"preferred_port\":${preferred_port}}" \
    2>/dev/null)

  if [ $? -eq 0 ] && [ -n "$response" ]; then
    local allocated
    allocated=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('port',''))" 2>/dev/null)
    if [ -n "$allocated" ] && [ "$allocated" != "" ]; then
      echo "$allocated"
      return 0
    fi
  fi

  # Fallback: PolarPort unreachable, use preferred port directly
  echo "$preferred_port"
  return 0
}

release_port() {
  local port="$1"
  curl -sf --max-time "$_PORT_CLAIM_TIMEOUT" \
    -X POST "${POLARPORT_URL}/api/release" \
    -H "Content-Type: application/json" \
    -d "{\"port\":${port}}" \
    >/dev/null 2>&1 || true
}
