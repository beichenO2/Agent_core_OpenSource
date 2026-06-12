# Principles & Protocols Changelog

## 2026-05-13 — P10 强制 Push 补充 (gap.md)

**背景**：用户发现本地 commit 不 push 时，其他项目 Revert 后本地 commit 仍可通过 reflog 恢复，但流程上存在协作风险。

**改动**：P10（临时性与永久性的有意识区分）补充一条 bullet：

- **强制 Push 到 GitHub**：commit 之后必须立即 push 到 GitHub。本地未推送的 commit 在其他项目通过 Revert 合并后，虽可通过 reflog 恢复，但流程上不应依赖事后补救

## 2026-05-03 — Initial Migration (Agent_core_1_1)

Migration from `~/.codex/skills/pc-principles/` to `Agent_core/principles/` and `Agent_core/protocols/`. Zero semantic changes.

### Files migrated

| Source | Target | Content |
|--------|--------|---------|
| `~/.codex/skills/pc-principles/SKILL.md` | `Agent_core/principles/CORE.md` | P0–P12 + P4a, P5a, P5b (16 P-rules) |
| `~/.codex/skills/pc-principles/ADVANCED.md` | `Agent_core/principles/ADVANCED.md` | P13–P24 + P21a, P21b, P21c (15 P-rules) |
| `~/.codex/skills/pc-principles/PROTOCOLS.md` | `Agent_core/protocols/PROTOCOLS.md` | Protocols A, B, C, D, F, G, J (7 protocols) |

### Path changes

Only self-referencing paths updated in CORE.md:
- `~/.codex/skills/pc-principles/ADVANCED.md` → `~/Polarisor/Agent_core/principles/ADVANCED.md`
- `~/.codex/skills/pc-principles/PROTOCOLS.md` → `~/Polarisor/Agent_core/protocols/PROTOCOLS.md`

### Backward compatibility

- `~/.codex/skills/pc-principles/` → symlink to `Agent_core/principles/`
- `Agent_core/principles/SKILL.md` → symlink to `CORE.md`
- Old prompt "按 pc-principles 处理" resolves via symlink chain

### Backup

Originals backed up to `~/Desktop/ClawBin/Agent_core_1_1_backup/`

## 2026-05-03 — Scripts Migration (Agent_core_1_3)

- Migrated all 18 protocol scripts from `~/.polarcop/core/scripts/` to `Agent_core/scripts/`
- Created symlink `~/.polarcop/core/scripts` → `Agent_core/scripts/` for backward compatibility
- Original scripts backed up to `~/Desktop/ClawBin/Agent_core_1_3_backup/`
- Created 3 new enforcement scripts:
  - `pc-regex-purge.sh` — W-DEL-1 enforcement (reference search before delete)
  - `pc-tech-vintage-check.sh` — W-SOTA-1 enforcement (technology age verification)
  - `pc-compat-purge-check.sh` — W-COMPAT-1 enforcement (v1/v2 coexistence detection)
- Created `Agent_core/scripts/README.md` with full script inventory
- `sotctl` not found in source directory — documented as absent, not fabricated
