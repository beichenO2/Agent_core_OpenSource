# Agent_core Workflow: Zero Compatibility

**Aggregated P-rules**: P8 (修改优先于重写), P13.3 (兼容性维度)

---

## W-COMPAT-1: Zero Compatibility — Highest Priority Rule

**Refined-by**: [Agent_core:P8]
**Superseded-by**: [Agent_core:P13.3] (dimension 3: 兼容性 → deprecated by this rule)

Zero compatibility means: when new design replaces old design, the old implementation is **uprooted in the same PR**. No coexistence, no graceful migration, no version compatibility layers.

### Four Pillars

#### (a) No Surprise Fallbacks

Fallback behavior that exists by design (explicitly declared in `polaris.json` features) is allowed. All other fallbacks are forbidden:
- ⛔ Silent fallback to old API version
- ⛔ Try-new-catch-old patterns without explicit declaration
- ⛔ Feature flags that keep old code paths alive indefinitely

#### (b) No Version Compatibility Layers

The following are forbidden:
- Polyfills for deprecated APIs
- Legacy adapters (v1 → v2 translation layers)
- v1/v2 coexistence in the same codebase
- "Compatibility mode" that preserves old behavior alongside new

#### (c) Working Code Affected by New Design → Uproot in Same PR

When new design changes the behavior or interface of existing working code, the old implementation must be removed in the **same PR** that introduces the new design.

**Exclusions** (these are NOT "working code" subject to uprooting):
- `~/Desktop/ClawBin/` archive files
- `.bk` suffixed files
- `任务书/Done/` historical archives
- Files explicitly marked as `deprecated` in SSoT

#### (d) Priority Over Other Rules

W-COMPAT-1 takes priority over:
- [Agent_core:P8] (modification over rewrite) — when zero-compat requires it, full replacement is correct
- [Agent_core:P13.3] (compatibility dimension of deletion check) — compatibility preservation is superseded by zero-compat; the relevant deletion check dimension becomes "deprecated"

### Applies to Executing Agent

This rule applies to the Agent doing the work — there is no "I'm just writing design, not code" exemption. If an Agent creates a new design that conflicts with existing implementation, the Agent must also uproot the old implementation.

### Enforcement

- PR review must check: does this PR introduce new patterns while leaving old patterns alive?
- If yes → reject unless old patterns are explicitly excluded (ClawBin, .bk, Done/)
- W-COMPAT-1 violations in the same PR as new feature code are blocking — the PR cannot merge
