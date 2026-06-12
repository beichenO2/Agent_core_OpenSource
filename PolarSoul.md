# Agent_core 灵魂

> Agent 运行期规范与协议。Agent 修改本项目前，必须阅读并遵守以下核心特质。

---

## 核心特质

| 特质 | 与社区同类项目的差异 |
|------|----------------------|
| **P 系列原则** | P0-P21 共享约束准则，所有 pc-* Skill 必须遵守 |
| **嵌入式协议** | A-G 协议（Hub 初始化、注册、commit、check_hub、Slave 发现、命名、YOLO 对齐） |
| **SSoT 引用格式** | `[SSoT:Project/Req/Feature]` 3 段精确格式，支持跳转高亮 |

---

## 外部合作

### 依赖

- 无外部项目依赖（规范层）

### 被依赖

- 所有 Polarisor Agent：运行期行为约束

### 接口契约

- `principles/CORE.md`：核心原则 P0-P12
- `principles/ADVANCED.md`：高级原则 P13-P21
- `contracts/*.schema.json`：事件 schema

---

## 设计决策

### 为什么用 P 系列原则？

**问题**：Agent 行为约束分散在多个 Skill 中，难以统一管理。

**决策**：P 系列原则是共享准则层，所有 pc-* Skill 引用其中的协议。

**不可妥协**：P0（先充分讨论与规划，再一次性执行）是最高优先级。

### 为什么用嵌入式协议？

**问题**：协议逻辑写在 Skill 中，难以复用。

**决策**：协议抽取为独立文件（如 `protocols/hub-init.md`），Skill 引用而非复制。

**不可妥协**：协议变更必须同步所有引用的 Skill。

---

## 详情入口

- [SSoT](polaris.json)
- [核心原则](principles/CORE.md)
- [高级原则](principles/ADVANCED.md)
