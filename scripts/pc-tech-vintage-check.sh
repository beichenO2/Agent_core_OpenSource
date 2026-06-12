#!/usr/bin/env bash
# pc-tech-vintage-check.sh — W-SOTA-1 enforcement
# Check whether a technology/library meets the SoTA age threshold.
# AI-category: must be < 1 year old. Other: must be < 2 years old.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: pc-tech-vintage-check.sh <tech_name> <category>

  <tech_name>   Name of the technology or library
  <category>    "ai" or "other"

Age thresholds:
  ai     — Must be less than 1 year old (maintained by major company)
  other  — Must be less than 2 years old (maintained by major company)

The script prints the threshold and prompts the operator to verify.

Exit codes:
  0  PASS — operator confirmed the tech meets the threshold
  1  FAIL — operator indicated the tech does NOT meet the threshold
  2  Usage error
EOF
}

if [[ $# -lt 2 ]]; then
  usage
  exit 2
fi

TECH_NAME="$1"
CATEGORY="$2"

case "$CATEGORY" in
  ai|AI)
    THRESHOLD="1 year"
    ;;
  other|OTHER)
    THRESHOLD="2 years"
    ;;
  *)
    echo "ERROR: category must be 'ai' or 'other', got '$CATEGORY'"
    exit 2
    ;;
esac

echo "=== pc-tech-vintage-check: $TECH_NAME ==="
echo "Category: $CATEGORY"
echo "Age threshold: < $THRESHOLD"
echo ""
echo "Verification required:"
echo "  1. Is '$TECH_NAME' less than $THRESHOLD old (initial release or latest major version)?"
echo "  2. Is '$TECH_NAME' maintained by a major company or active community?"
echo ""

if [[ -t 0 ]]; then
  read -rp "Does '$TECH_NAME' meet both criteria? [y/N]: " ANSWER
  case "$ANSWER" in
    y|Y|yes|YES)
      echo "PASS: '$TECH_NAME' confirmed as meeting W-SOTA-1 threshold."
      exit 0
      ;;
    *)
      echo "FAIL: '$TECH_NAME' does NOT meet W-SOTA-1 threshold ($CATEGORY: < $THRESHOLD)."
      exit 1
      ;;
  esac
else
  echo "Non-interactive mode: printing threshold info only."
  echo "Operator must verify: '$TECH_NAME' < $THRESHOLD old, maintained by major company."
  echo "VERDICT: MANUAL_CHECK_REQUIRED"
  exit 0
fi
