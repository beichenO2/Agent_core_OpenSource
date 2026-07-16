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

## 迁移进度

### 2026-07-16 — PolarDesign

- 已把内嵌、硬编码 `7700` 的预览 listener 拆为独立前台服务。
- `Start/start.sh` 已改为 PolarPort 申领 + PolarProcess 前台托管，不再使用 nohup、PID 文件或 kill。
- PolarProcess 已注册 `polardesign-preview`，保持 `stopped`、`pid=null`、`auto_start=false`。
- PolarPort 未创建 active 记录，7700 未监听，未影响运行服务。
- 项目审计从 drift 变为 compliant；生态审计快照从 32 项降至 31 项。
- `service_management` 缺失项目剩余：PolarMemory、PolarOps、PolarUI。

### 2026-07-16 — PolarOps

- 已删除 `src/server.ts` 的 PolarPort 直连分配与 `11065` 静默 fallback；server 只校验并消费 launcher 注入的 `PORT`。
- 新增根级前台 `Start/start.sh`：先检查 PolarPort，再申领并校验 `polarops / PolarOps / 11065`，最后 `exec node dist/server.js`；不含后台化、PID 文件或 kill。
- PolarProcess 已注册 `polarops`，保持 `stopped`、`pid=null`、`auto_start=false`，未调用 start/restart。
- PolarPort 未创建 active 记录，11065 未监听，未影响运行服务。
- canonical main 的 3 个测试文件、24 项测试全部通过，TypeScript build 和项目治理审计通过。
- PolarOps 的项目级 `service_management` 漂移已消除；生态审计合入后首次快照为 30 项，SSoT 落盘复测为 31 项，差异来自动态恢复的 `PolarMemory/polarmemory-api:3100` active 记录，不归因于 PolarOps。
- `service_management` 缺失项目剩余：PolarMemory、PolarUI。

### 2026-07-16 — PolarMemory

- 迁移前 `polar-memory:8035` 的 PolarProcess 记录为异常自启，曾处于 `starting/error`、PID 为空并累计大量失败重试；已通过同一服务 ID 精确关闭 auto-start 并收敛为 stopped。
- 已把 `polarmemory-api:3100` 与 `polar-memory:8035` 双身份统一为 `polar-memory / PolarMemory / 8035`。
- `src/api_server.ts` 不再使用 `POLARMEMORY_PORT` 或 3100 fallback，只校验并消费 launcher 注入的 `PORT`。
- `Start/start.sh` 已删除 nohup、PID 文件、lsof 与 kill，自身只检查 PolarPort、申领并校验 8035，最后前台 `exec node dist/api_server.js`。
- 项目 README、capabilities 和 `polarmemory-ops` Skill 已统一为 PolarProcess 生命周期与 PolarPort 端口权威。
- canonical main 的 BlockManager 88 项断言、runtime governance contract、TypeScript build 和项目审计全部通过。
- PolarProcess 最终记录为 `stopped`、`pid=null`、`auto_start=false`；PolarPort 无 PolarMemory active 记录，3100/8035 无 listener。
- 项目级 `service_management` 漂移和两条 PolarMemory 注册表漂移均已消除；本次生态审计动态快照为 28 项。
- `service_management` 缺失项目剩余：PolarUI。
