# Agent_core — Single Source of Agent Logic (SSoA)

Agent_core is the canonical source for all Agent behavior rules shared across PolarCopilot, PolarPilot, and PolarClaw. Every Agent form inherits its principles, protocols, and workflows from this project.

## Rule Reference Syntax

Other projects reference Agent_core rules using bracket notation. **Never copy full rule text** — always use rule ID references:

| Prefix | Example | Scope |
|--------|---------|-------|
| `P` | `[Agent_core:P4a]` | Principles (shared constraints) |
| `W-*` | `[Agent_core:W-DEV-1]` | Workflow rules (executable guidance) |
| `Proto-X` | `[Agent_core:Proto-C]` | Protocols (Hub/commit/check_hub etc.) |

Usage in documents:

```markdown
按 [Agent_core:P8] 修改优先于重写。
毕业测试三件套见 [Agent_core:W-DEV-1]。
commit+push 流程见 [Agent_core:Proto-C]。
```

## Directory Layout

```
Agent_core/
├── principles/       P-rules: P0–P24 (shared constraints)
│   ├── CORE.md       P0–P12 + P4a (core rules)
│   ├── ADVANCED.md   P13–P24 (advanced rules)
│   └── CHANGELOG.md  Rule change history
├── protocols/        Proto-A through Proto-J (Hub, commit, YOLO etc.)
│   ├── PROTOCOLS.md  All protocol definitions
│   └── examples/     Protocol usage examples
├── workflows/        W-rules: executable guidance derived from P-rules
│   ├── DEV.md        W-DEV-1, W-DEV-2 (dev + test)
│   ├── DELETE.md     W-DEL-1/2/3 (deletion verification)
│   ├── REPORT.md     W-REP-1 (progress reporting)
│   ├── HONESTY.md    W-HON-1 (test honesty)
│   ├── TECH_SOTA.md  W-SOTA-1 (tech age thresholds)
│   └── COMPAT.md     W-COMPAT-1 (zero compatibility)
├── scripts/          Shared Agent scripts
├── adapters/         Per-Agent-form adapter configs
├── contracts/        Schemas and interface contracts
├── tests/            Validation tests for contracts
├── reference/        External references and SOTA comparisons
└── knowledge/        Verified methods and lessons learned
```

## How Other Projects Should Reference Agent_core

1. Use `[Agent_core:RuleID]` in your documents — never copy rule text
2. If you need runtime access to a rule definition, read from `Agent_core/` paths
3. Adapter configs in `adapters/` customize rule application per Agent form
4. W-rules supplement P-rules — they add executable detail without changing the principle
