---
id: protocols/tech-choice
level: protocol
triggers:
  - "选型"
  - "推荐"
  - "模型"
  - "框架"
  - "\\b库\\b"
  - "版本"
  - "用什么"
  - "哪个好"
  - "对比"
  - "技术栈"
  - "工具"
  - "\\bSDK\\b"
  - "\\bAPI\\b"
priority: 10
---

# 协议：技术选型（P14/P23）

- 技术/模型/框架判断前必须 **联网验证** 当前活跃度与版本。
- 名称解析 5 级降级：精确→别名→部分匹配→外部搜索→候选清单。
- 禁止仅凭训练知识断言「不存在」或推荐过时方案。
- 生态内 LLM 指 PolarPrivate Proxy（按次计费）；VLM/ASR 默认本机 Ollama。
