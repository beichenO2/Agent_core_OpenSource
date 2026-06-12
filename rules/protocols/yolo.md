---
id: protocols/yolo
level: protocol
triggers:
  - "YOLO"
  - "全自动"
  - "不要问我"
  - "自动做完"
  - "直接做"
  - "一键"
  - "不管了"
priority: 10
---

# 协议：YOLO 对齐与自动执行（协议 G）

- YOLO 是 Solo 模式开关，非独立模式；核心价值是 **三维对齐**（极限目标 + 工作逻辑 + 用户预期体验）。
- 对齐方案须引用 SSoT：`[SSoT:Project/R/feature]`；提交后检查 coverage API。
- 自动执行：Debug > Test > Dev；每步测试、Bug 立修、按协议 C commit。
- 完成后仍回到 Hub 循环，不得 dead-end 结束。
