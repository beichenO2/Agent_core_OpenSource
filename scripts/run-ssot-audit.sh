#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y-%m-%dT%H-%M-%S)
OUTBOX_DIR="$HOME/Polarisor/SOTAgent/.sotagent-outbox/ssot-audit"
mkdir -p "$OUTBOX_DIR"

AUDIT_OUT="$OUTBOX_DIR/audit-${TIMESTAMP}.json"
DRIFT_OUT="$OUTBOX_DIR/drift-${TIMESTAMP}.json"

# Run ssot-audit
node "$HOME/Polarisor/Agent_core/scripts/ssot-audit.mjs" \
  --strict \
  --output-file "$AUDIT_OUT"

# Run drift evidence
python3 "$HOME/Polarisor/Agent_core/scripts/audit-ssot-drift-evidence.py" \
  --output-file "$DRIFT_OUT"

# Commit audit results to SOTAgent project for peer_sync synchronization
cd "$HOME/Polarisor/SOTAgent"
git add .sotagent-outbox/
git commit -m "ssot-audit: automated audit results ${TIMESTAMP}" || true
git push || true

echo "SSoT audit completed at $TIMESTAMP"
