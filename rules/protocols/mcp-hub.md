---
id: protocols/mcp-hub
level: protocol
triggers:
  - "\\bMCP\\b"
  - "hub-agent"
  - "check_hub"
  - "send_prompt"
  - "唐僧"
  - "插件"
  - "侧栏"
priority: 10
---

# 协议：Hub / MCP 多会话

- 侧栏会话与 `my-mcp-N` 一一对应；增删会话后须重新「开始配置」。
- Web 模式：`setup` 不创建首条 prompt；任务完成后 `send_prompt` → `check_hub` 阻塞等待（turn 最后一步）。
- 用户可见内容写在 Cursor 对话窗口；默认不向插件传 `reply` 代替实质回答。
