#!/bin/bash
# sync-handoff-rule.sh — Sync handoff-format.md to projects with own .cursor/rules/
#
# Projects that symlink .cursor/rules → gsd-2 inherit it automatically.
# Projects with independent .cursor/rules/ need their copy kept in sync.
#
# Usage:
#   bash sync-handoff-rule.sh              # sync
#   bash sync-handoff-rule.sh --verify     # check only (exit 1 if stale)
#   bash sync-handoff-rule.sh --dry-run    # preview changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GSD2_SRC="${GSD2_SRC:-$(cd "$SCRIPT_DIR/.." && pwd)}"
POLARISOR_ROOT="${POLARISOR_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
SOURCE="$GSD2_SRC/.cursor/rules/handoff-format.md"

DRY_RUN=false
VERIFY_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --verify)  VERIFY_ONLY=true ;;
  esac
done

if [ ! -f "$SOURCE" ]; then
  echo "ERROR: Source not found: $SOURCE"
  exit 1
fi

synced=0
stale=0
skipped=0
issues=()

for proj_dir in "$POLARISOR_ROOT"/*/; do
  [ -d "$proj_dir" ] || continue
  name="$(basename "$proj_dir")"
  rules_dir="$proj_dir/.cursor/rules"

  # Skip projects that symlink rules (they inherit automatically)
  [ -L "$rules_dir" ] && { skipped=$((skipped + 1)); continue; }

  # Skip projects without own rules dir
  [ -d "$rules_dir" ] || continue

  # Skip gsd-2 itself (it's the source)
  [ "$name" = "gsd-2" ] && continue

  target="$rules_dir/handoff-format.md"

  if [ -f "$target" ] && diff -q "$SOURCE" "$target" >/dev/null 2>&1; then
    synced=$((synced + 1))
  else
    stale=$((stale + 1))
    if [ -f "$target" ]; then
      issues+=("STALE: $name/.cursor/rules/handoff-format.md")
    else
      issues+=("MISSING: $name/.cursor/rules/handoff-format.md")
    fi

    if ! $VERIFY_ONLY && ! $DRY_RUN; then
      cp "$SOURCE" "$target"
      issues+=("  FIXED: copied from source")
    elif $DRY_RUN; then
      issues+=("  WOULD COPY from $SOURCE")
    fi
  fi
done

echo "=== Handoff Rule Sync Report ==="
echo "Source:    $SOURCE"
echo "In sync:  $synced"
echo "Stale:    $stale"
echo "Skipped:  $skipped (symlinked)"

if [ ${#issues[@]} -gt 0 ]; then
  echo ""
  echo "--- Issues ---"
  for issue in "${issues[@]}"; do
    echo "  $issue"
  done
fi

if $VERIFY_ONLY && [ "$stale" -gt 0 ]; then
  exit 1
fi

echo ""
echo "Done."
