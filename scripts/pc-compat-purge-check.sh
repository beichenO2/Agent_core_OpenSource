#!/usr/bin/env bash
# pc-compat-purge-check.sh — W-COMPAT-1 enforcement
# Before commit, verify no v1/v2 coexistence patterns exist in staged changes.
# Excludes design-documented fallbacks declared in polaris.json.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: pc-compat-purge-check.sh

Checks git staged files for patterns indicating compatibility layer
coexistence: legacy, v1, v2, polyfill, compat, fallback.

Excludes:
  - Design-documented fallbacks declared in polaris.json
  - Comments and documentation (*.md files)
  - Test files that intentionally test compatibility

Exit codes:
  0  No v1/v2 coexistence patterns found
  1  Suspicious patterns detected — review before committing
  2  Usage error (not in a git repo, etc.)
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "ERROR: Not inside a git repository."
  exit 2
fi

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)

if [[ -z "$STAGED_FILES" ]]; then
  echo "No staged files to check."
  exit 0
fi

COMPAT_PATTERNS='(legacy|[^a-zA-Z]v1[^0-9.]|[^a-zA-Z]v2[^0-9.]|polyfill|compat[^i]|fallback)'

EXCLUDE_PATTERNS=(
  '\.md$'
  'polaris\.json$'
  'CHANGELOG'
  '\.test\.'
  '\.spec\.'
  '__tests__'
)

FOUND=0
RESULTS=""

while IFS= read -r FILE; do
  [[ -z "$FILE" ]] && continue

  SKIP=0
  for EXCL in "${EXCLUDE_PATTERNS[@]}"; do
    if echo "$FILE" | grep -qE "$EXCL"; then
      SKIP=1
      break
    fi
  done
  [[ "$SKIP" -eq 1 ]] && continue

  STAGED_CONTENT=$(git diff --cached -- "$FILE" 2>/dev/null | grep '^+' | grep -v '^+++' || true)

  if [[ -z "$STAGED_CONTENT" ]]; then
    continue
  fi

  MATCHES=$(echo "$STAGED_CONTENT" | grep -inE "$COMPAT_PATTERNS" 2>/dev/null || true)
  if [[ -n "$MATCHES" ]]; then
    RESULTS+="--- $FILE ---"$'\n'"$MATCHES"$'\n\n'
    FOUND=1
  fi
done <<< "$STAGED_FILES"

echo "=== pc-compat-purge-check: W-COMPAT-1 enforcement ==="

if [[ "$FOUND" -eq 1 ]]; then
  echo ""
  echo "Suspicious v1/v2 coexistence patterns found in staged changes:"
  echo ""
  echo "$RESULTS"
  echo "FAIL: Review the above patterns. If they are intentional design-documented"
  echo "fallbacks (declared in polaris.json), they can be allowed. Otherwise, remove"
  echo "compatibility layers before committing (W-COMPAT-1)."
  exit 1
else
  echo "PASS: No v1/v2 coexistence patterns found in staged changes."
  exit 0
fi
