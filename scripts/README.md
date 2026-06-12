# Agent_core/scripts/

Canonical location for all PolarCopilot protocol and enforcement scripts.

Legacy path `~/.polarcop/core/scripts/` is a symlink pointing here. All existing `source ~/.polarcop/core/scripts/...` calls continue to work.

## Script Inventory

### Migrated Scripts (from ~/.polarcop/core/scripts/)

| Script | Description |
|---|---|
| `pc-safe-write.sh` | Safe file write with backup and lock |
| `pc-precommit-check.sh` | Pre-commit verification (conflict detection) |
| `hub-call.sh` | Hub MCP communication |
| `hub-watchdog.sh` | Hub health monitoring |
| `deploy.sh` | Deployment script |
| `deploy-and-restart.sh` | Deploy and restart services |
| `git-auto-push.sh` | Automated git push |
| `global-lock.sh` | Global lock mechanism |
| `lib-isolate.sh` | Library isolation |
| `migrate-planning.sh` | Planning directory migration utility |
| `run-phase.sh` | Phase execution runner |
| `smoke-test.sh` | Smoke test runner |
| `ssot-audit.mjs` | SSoT audit (Node.js) |
| `sync-handoff-rule.sh` | Handoff rule synchronization |
| `sync-skills.sh` | Skills synchronization |
| `ui-prompt.sh` | UI prompt utility |
| `counting-e2e-test.ts` | E2E test counter (TypeScript) |

### Enforcement Scripts (new)

| Script | W-Rule | Description |
|---|---|---|
| `pc-regex-purge.sh` | W-DEL-1 | Search for references before delete/archive operations |
| `pc-tech-vintage-check.sh` | W-SOTA-1 | Verify technology/library meets SoTA age threshold |
| `pc-compat-purge-check.sh` | W-COMPAT-1 | Block v1/v2 coexistence patterns in staged commits |
| `pc-env-sync.sh` | — | Environment sync: install deps, run migrations, restart services, health check, forbidden output detection |

### Audit Scripts (cross-project, added 2026-05-03)

These are Polarisor-wide ecosystem audit tools used during cross-project residual cleanup sessions. See `knowledge/2026-05-03-cross-project-audit-and-residual-cleanup.md` for the playbook.

| Script | Purpose | Usage |
|---|---|---|
| `audit-polaris-deepscan.py` | Per-project polaris.json field check + git branch state (off-main / uncommitted / origin) | `python3 ./scripts/audit-polaris-deepscan.py` |
| `audit-ssot-drift-evidence.py` | (1) `_Polarisor/projects.md` ↔ actual `polaris.json` drift; (2) evidence/interfaces field reality check (W-HON-1) | `python3 ./scripts/audit-ssot-drift-evidence.py` |
| `audit-notdone-features.py` | Enumerate every feature with `status` ≠ `done` across all projects (Top-N todo backlog) | `python3 ./scripts/audit-notdone-features.py` |

**When to run**: any session that intends to claim "全库收口" / "整库审计" / "SSoT 0 漂移". Combine with the W-COMPAT-1 / W-DEV-2 strict-grep recipes in the knowledge playbook.

## Hub MCP Server

Hub 通信使用 `~/.cursor/hub-mcp-server/index.mjs`（MCP Server），处理 Hub 发现、
Agent 注册和 SSE/HTTP 长轮询。配置在 `.cursor/mcp.json` 中为 `hub-agent-1` 至 `hub-agent-20`。
详见 `~/.cursor/hub-mcp-server/README.md`。

旧脚本 `pc-solo-web-start.sh` 已归档至 ClawBin（2026-06-10）。

## Notes

- `sotctl`: Referenced in design docs but not found in the source directory as of 2026-05-02. Not migrated.
- All `.sh` scripts have executable permissions (`+x`).
- Non-shell scripts (`.ts`, `.mjs`) are run via their respective runtimes.
