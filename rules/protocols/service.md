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

**权威主体**：端口 = PolarPort（:11050）唯一；进程 = PolarProcess（:11055）唯一；SOTAgent 仅提供 console 前端展示（`/api/services/*` 是 facade 透传，新代码勿用）。

- 服务启/停/重启走 PolarProcess `/api/services/:id/start|stop|restart`，或项目内 `Start/start.sh`；禁止 `kill`/`pkill`/`node &`。
- 端口一律 `claim_port`（`Agent_core/scripts/port-claim.sh` 或 PolarPort SDK），preferred 必须以 0/5 结尾；勿硬编码端口。
- 诊断服务问题按 P26 优先级：实时 API → 进程状态 → launchctl → 日志尾部。
- 重启前确认 `polaris.json` 的 `health_endpoint` 与实际端口一致；Watchdog 连续失败才自动重启。
- crash loop 检测后停止机械重启，升级 PolarPilot Agentic 修复或 Hub 告警。
- 完整硬约束见 `Agent_core/principles/ADVANCED.md` P27；本地自主 Agent 挂载 `Agent_core/reference/SERVICE-PORT-MINIMAL.md`。
