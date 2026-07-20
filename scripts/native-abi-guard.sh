#!/usr/bin/env bash
# native-abi-guard.sh — Self-healing ABI preflight for native Node addons.
#
# Problem this solves: V8-ABI native addons (better-sqlite3) compiled under
# Node X crash the service with ERR_DLOPEN_FAILED (NODE_MODULE_VERSION
# mismatch) when the launcher later runs Node Y. Any `npm install` done in a
# shell whose default node differs from the service's pinned node silently
# reintroduces the mismatch, producing PolarProcess crash loops.
#
# Usage (source from a Start/*.sh launcher BEFORE claiming ports):
#   source "$HOME/Polarisor/Agent_core/scripts/native-abi-guard.sh"
#   ensure_native_abi "$PROJECT_DIR" "$NODE_BIN" better-sqlite3 || exit 1
#
# Behavior per module:
#   1. Probe with the SAME node binary the service will run with. For
#      better-sqlite3 the probe constructs a real Database(':memory:') —
#      a bare require() does NOT dlopen the addon and passes even when the
#      binary is incompatible (proven 2026-07-20 on polarcop-hub).
#   2. On probe failure, run `npm rebuild <module>` with that node's own
#      toolchain (PATH-prefixed), then re-probe.
#   3. Refuse to start (return 1) only if the rebuild cannot heal it.

ensure_native_abi() {
  local project_dir="$1" node_bin="$2"
  shift 2
  local mod probe node_abi

  if [ ! -d "$project_dir" ] || [ ! -x "$node_bin" ]; then
    echo "native-abi-guard: bad args (dir=$project_dir node=$node_bin)" >&2
    return 1
  fi

  for mod in "$@"; do
    case "$mod" in
      better-sqlite3) probe='new (require("better-sqlite3"))(":memory:").close()' ;;
      *) probe="require(\"$mod\")" ;;
    esac

    if (cd "$project_dir" && "$node_bin" -e "$probe" >/dev/null 2>&1); then
      continue
    fi

    node_abi=$("$node_bin" -p 'process.versions.modules' 2>/dev/null || echo '?')
    echo "native-abi-guard: $mod does not load under $node_bin (requires NODE_MODULE_VERSION $node_abi); rebuilding with matching toolchain" >&2

    if ! (cd "$project_dir" && PATH="$(dirname "$node_bin"):$PATH" npm rebuild "$mod" >&2); then
      echo "native-abi-guard: npm rebuild $mod failed in $project_dir; refusing to start" >&2
      return 1
    fi
    if ! (cd "$project_dir" && "$node_bin" -e "$probe" >/dev/null 2>&1); then
      echo "native-abi-guard: $mod still fails to load after rebuild; manual fix required" >&2
      return 1
    fi
    echo "native-abi-guard: $mod rebuilt for NODE_MODULE_VERSION $node_abi" >&2
  done
  return 0
}
