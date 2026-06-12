#!/usr/bin/env bash
# git-auto-push.sh — post-commit hook for automatic GitHub sync
# Install: cp scripts/git-auto-push.sh .git/hooks/post-commit && chmod +x .git/hooks/post-commit

set -euo pipefail

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ -z "$BRANCH" ] || [ "$BRANCH" = "HEAD" ]; then
  exit 0
fi

REMOTE=$(git remote 2>/dev/null | head -1)
if [ -z "$REMOTE" ]; then
  exit 0
fi

MAX_RETRIES=3
for i in $(seq 1 $MAX_RETRIES); do
  if git push "$REMOTE" HEAD 2>/dev/null; then
    exit 0
  fi
  
  if [ "$i" -lt "$MAX_RETRIES" ]; then
    git pull --rebase "$REMOTE" "$BRANCH" 2>/dev/null || true
  fi
done

echo "[git-auto-push] Failed to push after $MAX_RETRIES attempts" >&2
exit 1
