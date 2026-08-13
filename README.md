# Agent_core — Agent 设计规则与协议

> **一句话**：Polarisor 生态所有 Agent 形态的**统一逻辑源（SSoA）**，解决 Agent 行为约束分散在多个 Skill 中、复制粘贴导致规则漂移的问题——用 P 原则 + 嵌入式协议 + 引用语法，让 PolarCopilot、PolarPilot、PolarClaw 共享同一套可版本化的设计依赖。

GitHub: https://github.com/beichenO2/Agent_core

---

## 安装

**Polarisor 生态（推荐）**

```bash
git clone https://github.com/beichenO2/Polarisor.git && cd Polarisor && ./install.sh ai-agent
```

**独立 clone**

```bash
git clone https://github.com/beichenO2/Agent_core.git
cd Agent_core && npm install   # 契约测试依赖
```

其他项目引用规则时，只需在文档中使用 `[Agent_core:RuleID]` 语法，并在本地 clone 本仓库或通过 Polarisor 安装对应 Skill。

---

## 设计思考

### 为什么用 P 系列原则，而不是每个 Skill 各自写约束？

Agent 行为约束曾分散在 pc-solo-web、pc-yolo、pc-main 等多个 Skill 中，改一条规则要同步 N 处。P0–P24 共享准则层（`principles/CORE.md` + `ADVANCED.md`）是所有 pc-* Skill 的唯一逻辑源，语义零损失迁移，变更一处、全局生效。

### 为什么用 `[Agent_core:P4a]` 引用语法，而不是复制规则全文？

复制全文会在各项目间产生**静默漂移**——A 项目更新了 P8，B 项目仍用旧版。引用语法 + `REGISTRY.md` 注册表 + JSON Schema 校验（`contracts/rule-reference.schema.json`）保证规则 ID 永久不变、内容只维护一份。

### 为什么协议外置到 `protocols/`，而不是内嵌在 Skill 里？

Hub 初始化（Proto-A）、Agent 注册（Proto-B）、Git 交付（Proto-C）、YOLO 对齐（Proto-G）等 **11** 个协议被 PolarCopilot / PolarPilot / PolarClaw 共用。外置后 Skill 只引用 `[Agent_core:Proto-C]`，bash 实现统一在 `scripts/`，避免 N 份复制。

---

## 核心亮点

| 维度 | 数据 |
|------|------|
| P 原则 | **32** 条活跃规则（P0–P24 + P4a / P5a / P5b / P13.3 / P21a–c） |
| 嵌入式协议 | **11** 个协议（Proto-A ~ Proto-N，Hub / commit / YOLO / SSoT …） |
| W 工作流规则 | **20** 条可执行规则（DEV / DELETE / REPORT / HONESTY / TEST …） |
| RetryLoop | 默认 **max_retries=7**；轮内迭代 + 轮间刷新，Validator 对齐用户需求 SSOT |
| 共享脚本 | **42** 个（SSoT 漂移检查、port-claim、precommit、Hub 调用 …） |
| 契约 | **10** 个 Schema / 规范文件（rule-reference / checkup-event / thinking-pattern …） |
| 适配器 | **3** 种 Agent 形态（Copilot / Pilot / Claw）via `adapters/` |
| 需求完成度 | R1–R4 共 **4** 个需求域 **100%** 完成（SSoT: `polaris.json` v1.0.0） |

---

## 架构

```
Agent_core/
├── principles/              # P 原则（共享约束）
│   ├── CORE.md              # P0–P12 + P4a + P5a + P5b
│   ├── ADVANCED.md          # P13–P24 + P21a–c
│   ├── SSOT-CONSISTENCY.md  # SSoT 一致性规范
│   ├── SSOT-DOCS.md         # 文档新鲜度规范
│   └── CHANGELOG.md         # 规则变更历史
├── protocols/               # Proto-A ~ Proto-N
│   ├── PROTOCOLS.md         # 全部协议定义（Hub / commit / YOLO …）
│   └── examples/            # 协议用法示例
├── workflows/               # W 规则（8 个文件，20 条规则）
│   ├── DEV.md               # W-DEV-1/2（毕业测试三件套 / 禁桩实现）
│   ├── DELETE.md            # W-DEL-1/2/3（删除验证三件套）
│   ├── REPORT.md            # W-REP-1（四列状态表）
│   ├── HONESTY.md           # W-HON-1（test_status 枚举）
│   ├── TECH_SOTA.md         # W-SOTA-1（技术时效阈值）
│   ├── COMPAT.md            # W-COMPAT-1（零兼容性最高优先级）
│   ├── PROMPT_ENGINEERING.md# W-PROMPT-1
│   └── TEST.md              # W-TEST-1 ~ W-TEST-10
├── rules/                   # Cursor Rules 生成源（protocols / norms / skills）
├── scripts/                 # 42 个共享脚本
│   ├── ssot-drift-check.sh  # SSoT 漂移检查
│   ├── ssot-freshness-check.sh
│   ├── ssot-pr-gate.sh      # PR 门禁
│   ├── port-claim.sh        # PolarPort 端口声明
│   └── pc-precommit-check.sh
├── adapters/                # 各 Agent 形态适配配置
├── contracts/               # JSON Schema 与接口契约
│   ├── rule-reference.schema.json
│   ├── checkup-event.schema.json
│   └── thinking-pattern.schema.json
├── architecture/            # 跨项目架构文档（billing-model 等）
├── knowledge/               # 已验证方法与审计记录
├── tests/                   # 契约验证测试（Vitest + Ajv）
├── REGISTRY.md              # 规则注册表（P / Proto / W 三张表）
├── polaris.json             # SSoT
├── roadmap.md               # 进度摘要
└── PolarSoul.md             # 设计哲学
```

---

## 快速开始

**1. 阅读核心规范**

```bash
cat principles/CORE.md       # P0–P12：身份驱动、复杂度控制、RetryLoop …
cat principles/ADVANCED.md   # P13–P24：SSoT、覆盖检测、Prompt 独立性 …
cat protocols/PROTOCOLS.md   # Proto-A ~ Proto-N 完整定义
```

**2. SSoT 一致性检查**

```bash
./scripts/ssot-drift-check.sh      # 检测 polaris.json 与代码/doc 漂移
./scripts/ssot-freshness-check.sh  # 检测文档新鲜度
./scripts/ssot-pr-gate.sh          # PR 门禁（CI 同款）
```

**3. 契约测试**

```bash
npm install
npx vitest run tests/
```

**4. 规则引用示例**

```markdown
按 [Agent_core:P8] 修改优先于重写。
毕业测试三件套见 [Agent_core:W-DEV-1]。
commit+push 流程见 [Agent_core:Proto-C]。
YOLO 对齐与 RetryLoop 见 [Agent_core:Proto-G]。
```

---

## 生态依赖

| 项目 | 角色 | 说明 |
|------|------|------|
| 所有 Polarisor 项目 | 规则消费者 | 通过 `[Agent_core:RuleID]` 引用，禁止复制全文 |
| [PolarCopilot](https://github.com/beichenO2/PolarCopilot) | IDE Agent 形态 | `adapters/` + pc-* Skills 引用 P 原则 |
| [PolarPilot](https://github.com/beichenO2/PolarPilot) | 自主规划形态 | thinking-pattern schema 校验 |
| [PolarClaw](https://github.com/beichenO2/PolarClaw) | 龙虾 Agent 形态 | Lobster 事件契约对齐 |
| [PolarPort](https://github.com/beichenO2/PolarPort) | 端口分配 | `scripts/port-claim.sh` 共享 |

> Agent_core 本身**无外部项目依赖**（规范层），但被生态内所有 Agent 形态消费。

---

## License

MIT
