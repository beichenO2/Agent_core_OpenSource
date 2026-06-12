---
id: protocols/task
level: protocol
triggers:
  - "任务书"
  - "编译"
  - "规划"
  - "执行"
  - "任务包"
  - "compiled"
  - "工作事项"
  - "checklist"
priority: 10
---

# 协议：任务书体系（协议 M）

- 三层：规划（设计期）→ 编译（`_compiled/` 14 项）→ 执行（代码 + SSoT）。
- 执行任务包前运行 `compile-gate-check.sh`；未编译则拒绝执行。
- 执行时 TodoWrite 映射任务包 checklist；不得跳过或擅自增删大步骤。
- 完成后归档到 `任务书/Done/`，禁止删除历史任务书。
