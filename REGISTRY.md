# Agent_core Rule Registry

All rules must be registered here before being referenced anywhere. Rule IDs are permanent — once assigned, never renumbered.

## ID Convention

| Prefix | Format | Scope | Example |
|--------|--------|-------|---------|
| P | `P0`–`P24`, `P4a` | Principles (shared constraints) | `[Agent_core:P8]` |
| W-* | `W-{CATEGORY}-{N}` | Workflow rules (executable guidance) | `[Agent_core:W-DEV-1]` |
| Proto-X | `Proto-{LETTER}` | Protocols (Hub, commit, YOLO) | `[Agent_core:Proto-C]` |

## Relationship Types

Rules can have relationships with other rules. Exactly four types are permitted:

| Type | Meaning | Example |
|------|---------|---------|
| `overrides` | Completely replaces the target rule in its domain | W-X overrides P-Y |
| `superseded-by` | Target rule is deprecated in favor of the referencing rule | P13.3 superseded-by W-COMPAT-1 |
| `refined-by` | Target rule's scope is narrowed or differentiated | P14 refined-by W-SOTA-1 |
| `supplements` | Adds executable detail without changing the principle | W-DEV-1 supplements P21b |

## P-rules Table

| ID | Status | Category | File | Migration Notes | Relationships |
|----|--------|----------|------|-----------------|---------------|
| P0 | active | Identity | CORE.md | from SKILL.md | — |
| P1 | active | Complexity | CORE.md | from SKILL.md | — |
| P2 | active | Traceability | CORE.md | from SKILL.md | — |
| P3 | active | Privacy | CORE.md | from SKILL.md | — |
| P4 | active | Design-first | CORE.md | from SKILL.md | — |
| P4a | active | Design-first | CORE.md | from SKILL.md | — |
| P5 | active | Clarification | CORE.md | from SKILL.md | — |
| P5a | active | Clarification | CORE.md | from SKILL.md | — |
| P5b | active | Clarification | CORE.md | from SKILL.md | — |
| P6 | active | Scope | CORE.md | from SKILL.md | — |
| P7 | active | Uncertainty | CORE.md | from SKILL.md | — |
| P8 | active | Modification | CORE.md | from SKILL.md | refined-by W-COMPAT-1 |
| P9 | active | Naming | CORE.md | from SKILL.md | — |
| P10 | active | Persistence | CORE.md | from SKILL.md | — |
| P11 | active | Reporting | CORE.md | from SKILL.md | — |
| P12 | active | Constraints | CORE.md | from SKILL.md | — |
| P13 | active | Archival | ADVANCED.md | from ADVANCED.md | — |
| P13.3 | active | Archival/Compat | ADVANCED.md | dim 3 of P13 | superseded-by W-COMPAT-1 |
| P14 | active | Tech-selection | ADVANCED.md | from ADVANCED.md | refined-by W-SOTA-1 |
| P15 | active | Language | ADVANCED.md | from ADVANCED.md | — |
| P16 | active | Estimation | ADVANCED.md | from ADVANCED.md | — |
| P17 | active | Canvas | ADVANCED.md | from ADVANCED.md | — |
| P18 | active | Diff-first | ADVANCED.md | from ADVANCED.md | — |
| P19 | active | Consistency | ADVANCED.md | from ADVANCED.md | supplemented-by W-REP-1 |
| P20 | active | SSoT | ADVANCED.md | from ADVANCED.md | — |
| P21 | active | SSoT-sync | ADVANCED.md | from ADVANCED.md | — |
| P21a | active | SSoT-format | ADVANCED.md | from ADVANCED.md | — |
| P21b | active | SSoT-lifecycle | ADVANCED.md | from ADVANCED.md | supplemented-by W-DEV-1, W-HON-1 |
| P21c | active | SSoT-rollback | ADVANCED.md | from ADVANCED.md | supplemented-by W-HON-1 |
| P22 | active | Coverage-detect | ADVANCED.md | from ADVANCED.md | — |
| P23 | active | Cross-validation | ADVANCED.md | from ADVANCED.md | — |
| P24 | active | Prompt-independence | ADVANCED.md | from ADVANCED.md | — |

## Protocol Table

| ID | Status | File | Migration Notes |
|----|--------|------|-----------------|
| Proto-A | active | PROTOCOLS.md | Hub 环境初始化 |
| Proto-B | active | PROTOCOLS.md | Agent 注册（含碰撞重试） |
| Proto-C | active | PROTOCOLS.md | 自动 Commit 流程 |
| Proto-D | active | PROTOCOLS.md | check_hub（Web 模式专用） |
| Proto-F | active | PROTOCOLS.md | Agent 动态命名 |
| Proto-G | active | PROTOCOLS.md | YOLO 对齐与自动执行 |
| Proto-J | active | PROTOCOLS.md | SOTAgent 守护进程自动恢复 |
| Proto-K | active | PROTOCOLS.md | Polarisor 生态定义与文档体系 |
| Proto-L | active | PROTOCOLS.md | PolarSoul 维护规范 |
| Proto-M | active | PROTOCOLS.md | 任务书体系规范 |
| Proto-N | active | PROTOCOLS.md | 生态常识（LLM 工具链、端口约定） |

## W-rules Table

| ID | Status | File | P-rule Relationships | Relationship Type |
|----|--------|------|---------------------|-------------------|
| W-DEV-1 | active | DEV.md | P21b | supplements |
| W-DEV-2 | active | DEV.md | — | overrides (tqsdk stubs practice) |
| W-DEL-1 | active | DELETE.md | P13 | supplements |
| W-DEL-2 | active | DELETE.md | P13 | supplements |
| W-DEL-3 | active | DELETE.md | P13 | supplements |
| W-REP-1 | active | REPORT.md | P19 | supplements |
| W-HON-1 | active | HONESTY.md | P21b, P21c | supplements |
| W-SOTA-1 | active | TECH_SOTA.md | P14 | refined-by |
| W-COMPAT-1 | active | COMPAT.md | P8, P13.3 | refined-by P8, superseded-by P13.3 |
| W-PROMPT-1 | active | PROMPT_ENGINEERING.md | P24 | supplements |
| W-TEST-1 | active | TEST.md | P21b | supplements |
| W-TEST-2 | active | TEST.md | P21b | supplements |
| W-TEST-3 | active | TEST.md | — | — |
| W-TEST-4 | active | TEST.md | — | — |
| W-TEST-5 | active | TEST.md | — | — |
| W-TEST-6 | active | TEST.md | P24 | supplements |
| W-TEST-7 | active | TEST.md | — | — |
| W-TEST-8 | active | TEST.md | P21b | supplements |
| W-TEST-9 | active | TEST.md | P21b, W-DEV-1 | supplements |
| W-TEST-10 | active | TEST.md | P21b, W-TEST-2 | supplements |
