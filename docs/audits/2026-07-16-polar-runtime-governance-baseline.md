# Polar Runtime Governance Baseline — 2026-07-16

## 审计边界

- 目标：`~/Polarisor`
- PolarPort：健康，`http://127.0.0.1:11050`
- PolarProcess：健康，`http://127.0.0.1:11055`
- 审计方式：只读文件检查与 HTTP GET
- 自动修复：未启用
- 服务影响：未执行 allocate、release、reserve、start、stop、restart 或信号操作；复测前后 PolarProcess 的 `id/status/pid/port/restart_count` 摘要无差异

## 基线结果

审计返回码为 `1`，按端口与服务身份双重匹配的最终快照共发现 32 项历史漂移。注册表会随服务心跳变化，本报告记录的是验证完成时快照。

| 类别 | 数量 | 项目或服务 |
|---|---:|---|
| `service_management` 缺失 | 4 | PolarDesign、PolarMemory、PolarOps、PolarUI |
| 缺少根级 `Start/*.sh` 生命周期入口 | 6 | Clock、PolarClaw、PolarCopilot、PolarPilot、PolarPrivate、SOTAgent |
| Start 脚本仍含直接后台或 kill 控制 | 4 | AutoOffice、KnowLever、digist、tqsdk |
| PolarProcess 运行服务缺少同端口、同身份的 PolarPort active 记录 | 14 | ai-daily-digest:8785、claude-code-vis:19120、digist:3800、digist-engine:8015、polarclaw:3910、polarflow-editor:8125、polarpilot:4900、privportal-backend:12790、privportal-frontend:12795、polarui:5170、sotagent-console:4880、tqsdk-data-collector:18900、web-market-truth-cs-api:3925、web-support-triage-api:3920 |
| PolarPort active 记录缺少同端口、同身份的运行 PolarProcess 服务 | 4 | PolarMemory/polarmemory-api:3100、digist/digist-api:3800、PolarMemory/polar-memory:8035、PolarPrivate/polarprivate:12790 |

PolarPort 与 PolarProcess 自身通过 launchd 引导，适用基础设施自举例外，不计入普通项目的后台进程违规。

## 迁移顺序

1. 先补齐 4 个项目的 `service_management`，只改声明，不动运行态。
2. 为 6 个项目增加根级前台 launcher，保留原脚本作为内部实现，暂不切换服务。
3. 对 4 个直接后台控制项目逐个建立 PolarProcess 前台托管路径，每次只迁移一个服务并验证回滚。
4. 对 18 条双向注册表漂移逐条确认服务身份、端口所有权和心跳来源；同端口不同 ID（如 `digist`/`digist-api`）必须先统一身份，再决定补登记或释放陈旧记录。
5. 每个项目迁移后单独运行项目审计、健康检查和 SSoT 更新；禁止批量重启。

## 本轮结论

本轮只建立统一治理规范、Codex Skill 和只读审计能力。历史漂移已形成可执行清单，但不属于本轮自动修复范围。
