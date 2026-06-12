#!/bin/bash
# ssot-drift-check.sh — Check SSOT freshness across all projects
#
# Usage: bash Agent_core/scripts/ssot-drift-check.sh [--json]
#
# Compares polaris.json _meta.last_synced_at against latest src/ commit time.
# Reports drift levels: OK (≤7d), WARN (7-14d), ALERT (>14d)

set -euo pipefail

BASE_DIR="${HOME}/Polarisor"
JSON_MODE=0
[ "${1:-}" = "--json" ] && JSON_MODE=1

PROJECTS=(PolarClaw PolarCopilot PolarPrivate SOTAgent Clock AutoOffice KnowLever digist PolarSync PolarMemory PolarPort PolarOps PolarProcess PolarPilot)

NOW_EPOCH=$(date +%s)
RESULTS=()

for PROJECT in "${PROJECTS[@]}"; do
  DIR="$BASE_DIR/$PROJECT"
  [ -d "$DIR" ] || continue

  POLARIS="$DIR/polaris.json"
  [ -f "$POLARIS" ] || continue

  LAST_SYNCED=$(python3 -c "
import json, sys
with open('$POLARIS') as f:
    d = json.load(f)
print(d.get('_meta', {}).get('last_synced_at', ''))
" 2>/dev/null || echo "")

  if [ -z "$LAST_SYNCED" ]; then
    DRIFT_DAYS=999
    LEVEL="ALERT"
    LAST_SYNCED="(no _meta)"
  else
    SYNC_EPOCH=$(python3 -c "
from datetime import datetime
import sys
ts = '$LAST_SYNCED'
try:
    dt = datetime.fromisoformat(ts)
    print(int(dt.timestamp()))
except:
    print(0)
" 2>/dev/null || echo "0")

    LATEST_SRC_COMMIT=$(cd "$DIR" && git log -1 --format=%at -- 'src/' 'lib/' 'backend/' 'frontend/' '*.ts' '*.js' '*.py' 2>/dev/null || echo "$SYNC_EPOCH")
    [ -z "$LATEST_SRC_COMMIT" ] && LATEST_SRC_COMMIT="$SYNC_EPOCH"

    if [ "$LATEST_SRC_COMMIT" -gt "$SYNC_EPOCH" ]; then
      DRIFT_SECS=$((LATEST_SRC_COMMIT - SYNC_EPOCH))
    else
      DRIFT_SECS=0
    fi
    DRIFT_DAYS=$((DRIFT_SECS / 86400))

    if [ "$DRIFT_DAYS" -le 7 ]; then
      LEVEL="OK"
    elif [ "$DRIFT_DAYS" -le 14 ]; then
      LEVEL="WARN"
    else
      LEVEL="ALERT"
    fi
  fi

  if [ "$JSON_MODE" -eq 1 ]; then
    RESULTS+=("{\"project\":\"$PROJECT\",\"drift_days\":$DRIFT_DAYS,\"level\":\"$LEVEL\",\"last_synced\":\"$LAST_SYNCED\"}")
  else
    case "$LEVEL" in
      OK)    ICON="✅" ;;
      WARN)  ICON="⚠️ " ;;
      ALERT) ICON="🚨" ;;
    esac
    printf "%s %-14s  drift=%dd  synced=%s\n" "$ICON" "$PROJECT" "$DRIFT_DAYS" "${LAST_SYNCED:0:10}"
  fi
done

if [ "$JSON_MODE" -eq 1 ]; then
  echo "[$(IFS=,; echo "${RESULTS[*]}")]"
fi
