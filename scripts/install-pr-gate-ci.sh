#!/bin/bash
# install-pr-gate-ci.sh — Install the SSOT PR Gate GitHub Actions workflow to all projects
#
# Usage: bash Agent_core/scripts/install-pr-gate-ci.sh [--dry-run]
#
# Copies the workflow file to each project's .github/workflows/ directory.
# Projects that use Agent_core as a submodule will reference its scripts directly.

set -euo pipefail

BASE="${HOME}/Polarisor"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

TEMPLATE="$BASE/Agent_core/.github/workflows/ssot-pr-gate.yml"

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: Template not found: $TEMPLATE" >&2
  exit 1
fi

PROJECTS=(SOTAgent PolarCopilot Clock KnowLever PolarDesign PolarMemory PolarPort PolarPrivate PolarProcess PolarBudget PolarFlow PolarSync tqsdk digist AutoOffice)

INSTALLED=0
for PROJECT in "${PROJECTS[@]}"; do
  TARGET="$BASE/$PROJECT/.github/workflows/ssot-pr-gate.yml"
  
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] Would install: $TARGET"
    INSTALLED=$((INSTALLED+1))
    continue
  fi
  
  mkdir -p "$(dirname "$TARGET")"
  cp "$TEMPLATE" "$TARGET"
  echo "✅ $PROJECT: installed"
  INSTALLED=$((INSTALLED+1))
done

echo ""
echo "Installed to $INSTALLED projects."
[ "$DRY_RUN" -eq 1 ] && echo "(dry-run mode — no files written)"
echo ""
echo "Next steps:"
echo "  1. Commit in each project: git add .github/ && git commit -m 'ci: add SSOT PR gate'"
echo "  2. Push to trigger on next PR"
