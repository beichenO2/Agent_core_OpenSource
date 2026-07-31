#!/usr/bin/env bash
# Local `pc afk …` entry for stop-hook / agents when `pc` is not on PATH.
set -euo pipefail
HUB_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${HUB_ROOT}/node_modules/.bin:${PATH}"
exec node "${HUB_ROOT}/node_modules/tsx/dist/cli.mjs" "${HUB_ROOT}/src/pc-cli.ts" "$@"
