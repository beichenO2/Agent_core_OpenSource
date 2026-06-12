---
id: protocols/service
level: protocol
triggers:
  - "服务"
  - "进程"
  - "启动"
  - "停止"
  - "重启"
  - "\\bkill\\b"
  - "SOTAgent"
  - "sotctl"
  - "端口"
  - "launchd"
  - "崩溃"
  - "挂了"
  - "不响应"
  - "超时"
priority: 10
---

# 协议：服务与进程（P26/P27）

- 诊断服务问题优先查 **launchd 日志** 与 PolarProcess `/api/services`。
- 端口冲突用 PolarPort `/api/list` 查询，勿硬编码端口。
- 重启前确认 `health_endpoint`；Watchdog 连续失败才自动重启。
- crash loop 检测后停止机械重启，升级 PolarPilot Agentic 修复或 Hub 告警。
