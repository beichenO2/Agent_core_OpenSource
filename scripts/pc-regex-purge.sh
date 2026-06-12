#!/usr/bin/env bash
# pc-regex-purge.sh — W-DEL-1 enforcement
# Before any delete/archive operation, search for references to the target
# across the Polarisor ecosystem. Exits 1 if references still exist.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: pc-regex-purge.sh <target>

  <target>   Path or name of the item being deleted/archived.

Searches ~/Polarisor/ for references to the target's name, path fragments,
and import references. Excludes ClawBin, .bk* backups, and 任務書/Done/.

Exit codes:
  0  No references found — safe to delete
  1  References found — review before deleting
  2  Usage error
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

TARGET="$1"
BASENAME=$(basename "$TARGET")
SEARCH_ROOT="${HOME}/Polarisor"

EXCLUDE_ARGS=(
  --glob '!**/ClawBin/**'
  --glob '!**/*.bk*'
  --glob '!**/任务书/Done/**'
  --glob '!**/.git/**'
  --glob '!**/node_modules/**'
)

echo "=== pc-regex-purge: Searching for references to '$BASENAME' ==="
echo "Search root: $SEARCH_ROOT"
echo ""

FOUND=0

for PATTERN in "$BASENAME" "$TARGET"; do
  RESULTS=$(rg --no-heading --line-number "${EXCLUDE_ARGS[@]}" -F "$PATTERN" "$SEARCH_ROOT" 2>/dev/null || true)
  if [[ -n "$RESULTS" ]]; then
    echo "--- References matching '$PATTERN' ---"
    echo "$RESULTS"
    echo ""
    FOUND=1
  fi
done

if [[ "$FOUND" -eq 1 ]]; then
  echo "FAIL: References to '$BASENAME' still exist. Review and clean up before deleting."
  exit 1
else
  echo "PASS: No references to '$BASENAME' found. Safe to delete."
  exit 0
fi
