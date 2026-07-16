# Polarisor Project Inventory — 2026-07-16

## 统计口径

- 生态根：`~/Polarisor`
- 正式项目：顶层目录中包含 `polaris.json` 的目录
- 独立 Git 项目：项目根存在 `.git`
- 根仓库项目：没有独立 `.git`，由 `~/Polarisor/.git` 管理
- 运行时状态：`polar-runtime-governance` 只读生态审计快照

## 总览

- 顶层非隐藏目录：32
- 正式项目：19
- 独立 Git 项目：17
- 根仓库项目：2（PolarFlow、PolarUI）
- 项目级 `PolarSoul.md`：16；缺失 PolarFlow、PolarUI、_Polarisor
- 生态根 `PolarSoul.md`：缺失
- 已完成运行时迁移：PolarDesign、PolarOps、PolarMemory、Clock、PolarCopilot、SOTAgent、PolarPrivate、digist、KnowLever、PolarClaw、PolarPilot、AutoOffice、tqsdk、PolarUI、PolarFlow
- 权威服务自举例外：PolarPort、PolarProcess
- 无持久运行时：Agent_core、_Polarisor
- 仍需正式项目运行时检查/迁移：0
- 当前生态治理漂移动态快照：0

## 正式项目清单

| 项目 | SSoT 状态 | 仓库归属 | 运行时治理 | 工作树 | 下一步 |
|---|---|---|---|---:|---|
| Agent_core | active 1.0.0 | 独立 Git | 无持久运行时 | 4 | 保留规范权威，持续记录迁移证据 |
| AutoOffice | active 0.4.0 | 独立 Git | compliant | 1 | 已迁移；API canonical owner，双 cron 原样保留 |
| Clock | active 1.1.0 | 独立 Git | compliant | 2 | 已迁移；双服务 stopped，用户 Timer 改动保留 |
| KnowLever | active 2.0.0 | 独立 Git | compliant | 2 | 已迁移；live Reader 原位收编，旧 RAG/Wiki 保持 archived |
| PolarClaw | active 0.1.0 | 独立 Git | compliant | 1 | 已迁移；launchd 退役，PolarProcess/PolarPort canonical owner |
| PolarCopilot | active 0.1.0 | 独立 Git | compliant | 0 | 已迁移；Hub live PID 保持不变 |
| PolarDesign | active 0.1.0 | 独立 Git | compliant | 0 | 已迁移 |
| PolarFlow | active 0.2.0-beta.1 | 根仓库 | compliant | 0 | 已迁移；API/Editor 双 canonical owner |
| PolarMemory | active 0.1.0 | 独立 Git | compliant | 1 | 已迁移；用户数据改动保留 |
| PolarOps | archived 0.1.0 | 独立 Git | compliant | 1 | 已迁移；用户截图删除保留 |
| PolarPilot | active 0.1.0 | 独立 Git | compliant | 1 | 已迁移；AutoOffice guard canonical owner，observer 边界保留 |
| PolarPort | active 0.1.0 | 独立 Git | authority bootstrap | 2 | 权威服务，不按普通项目迁移 |
| PolarPrivate | active 0.5.0 | 独立 Git | compliant | 0 | 已迁移；双服务 canonical owner，4Taoci 外部边界保留 |
| PolarProcess | active 0.1.0 | 独立 Git | authority bootstrap | 0 | 权威服务，不按普通项目迁移 |
| PolarUI | active 0.1.0 | 根仓库 | compliant | 根仓库大量 active 改动 | 已迁移稳定 GUI；Native/QA feature 边界原样保留 |
| SOTAgent | active 0.1.0 | 独立 Git | compliant | 0 | 已迁移；API/Console 双服务归一 |
| _Polarisor | active 1.0.0 | 独立 Git | 无持久运行时 | 0 | 补 PolarSoul；检查元项目边界 |
| digist | active 0.1.0 | 独立 Git | compliant | 0 | 已迁移；API 与无端口 worker canonical 身份归一 |
| tqsdk | active 3.0 | 独立 Git | compliant | 1 | 已迁移；collector canonical owner，gateway 保持 stopped |

## 安全迁移队列

迁移只在目标项目内执行；每个项目完成测试、审计、stopped 注册与 SSoT 更新后，才进入下一个。

正式项目迁移队列已清空。后续按独立仓库边界处理 registry 剩余漂移，不跨项目批量修复。

## 已完成迁移记录

### PolarFlow

- registry 残余归属审计发现静态扫描漏掉 live Editor；补迁后项目审计 `compliant`，R4 `runtime_governance` = `done`，生态 drift 从 10 降为 9。
- `polarflow-api` 与 `polarflow-editor` 均改为 PolarPort claim + PolarProcess foreground launcher；旧 `polarflow-editor-dev:8125` reservation 精确迁移为 canonical `polarflow-editor:8125`。
- 仅调用两个精确 service ID restart。最终 API PID 18202/8120、Editor PID 18478/8125，均 `pid_verified=true`、单 listener、canonical active owner、HTTP 200。
- 验证：治理合同、root 52 files / 511 tests、Editor 18 files / 129 tests、production build、shell/JSON 与项目 audit 通过；`polarflow-authoring` Skill 已写入双权威规则。

### PolarUI

- 项目审计：`compliant`；R12 `runtime_governance` = `done`；生态 drift 从 11 降为 10。
- 稳定 GUI `polarui` 从 literal-port npm preview（listener PID 87502、wrapper PPID 1）切换为 `Start/gui.sh` 前台 Vite launcher。最终 PID 85284、PPID 为 PolarProcess、`pid_verified=true`；5170 只有一个 listener、一个 canonical active owner `PolarUI/polarui:5170`，HTTP 200。
- 重复 preferred reservation `PolarUI/polarui-dev:5170` 已精确退役。注册脚本只更新 `polarui`，随后只调用 `polarui/restart`；旧 npm wrapper PID 87477 正常退出。
- 当前 `dev/polarui-ui` 的 Native Web release/QA 功能改动全部保留且未纳入迁移提交。受保护服务规范化哈希 `e6667c11…`、端口哈希 `4736d6ea…` 在切换前后完全一致；`polarui-native-web-preview` 保持 stopped/auto_start=false。
- 14945 是 PP-managed Mailpit PID 2506 的 SMTP 次 listener，PolarPort owner 为 `polarui-native-web-qa-smtp`；现有单端口 PolarProcess schema/auditor 无法把同一 PID 的第二端口表达为同一服务，因此仍计一条 registry drift。本次不通过重复注册同一 PID 伪造第二生命周期 owner。
- `polarui-usage`、`polarui-deploy`、`polarui-troubleshoot`、README 与 FRONTEND 已统一为 PolarPort/PolarProcess 唯一权威。验证：治理合同、shell/JSON/Vite CLI、项目 audit、单 listener/owner/health 与 protected-boundary hash 全部通过。

### tqsdk

- 项目审计：`compliant`；R12 `runtime_governance` = `done`；生态 drift 从 13 降为 11。
- 迁移前 `tqsdk-data-collector` 由 PolarProcess 运行 direct Python command，但 18900 没有 PolarPort active owner；根 `Start/start.sh` 实际指向过时的 trading API，并使用 nohup、后台进程、PID 文件、lsof 与直接信号。`tqsdk-gateway` 只有 preferred reservation，12890 无 listener。
- collector 与 gateway 均改为 PolarPort claim + 前台 exec launcher；旧 preferred reservation `tqsdk/tqsdk-collector:18900` 精确迁移为 canonical `tqsdk/tqsdk-data-collector:18900`。注册脚本不调用生命周期端点。
- 仅调用 `tqsdk-data-collector/restart` 完成切换：最终 PID 52760、PPID 为 PolarProcess、`pid_verified=true`，18900 只有一个 listener 与一个 canonical active owner。health 如实返回 `initializing/credentials=false/collecting=false`，因为依赖 gateway 按策略离线。
- `tqsdk-gateway` 注册为 `stopped/pid=null/auto_start=false`，12890 保持无 listener；迁移没有请求 D-class 凭证。首次切换暴露 PolarProcess 在 launcher 执行前把记录置为 running 的竞态，已用 TDD 将受管窗口收敛为 `starting|running`，仍拒绝 stopped/error。
- 验证：治理合同、collector 7/7、gateway session-lock 3/3、shell/JSON/diff、项目审计与复合 runtime gate 通过；gateway 全套仍是既有 Starlette/httpx TestClient 兼容问题 4 fail + 3 pass。用户 `reference/Vibe-Trading` 嵌套仓库状态全程保留。

### AutoOffice

- 项目审计：`compliant`；R7 `runtime_governance` = `done`；生态 drift 从 14 降为 13。
- 迁移前 API PID 25503/3900 虽登记在 PolarProcess，但由旧 `Start/start.sh` 通过 nohup 脱离为 PPID 1；`Start/stop.sh` 直接发送信号。PolarPort preferred reservation 与 active owner `AutoOffice/autooffice:3900` 已 canonical，无需换身份。
- 新增 production serve managed-port guard（测试直连仅允许 `NODE_ENV=test`）、Node 22 前台 launcher、三阶段注册、权威 status/stop clients，并同步 README、capability 与 `autooffice-ops` Skill/部署/排障规范。
- prepare/cutover 保持 PID 25503 不动；仅调用 `autooffice/restart` 切换到 governed PID 79249，finalize 后 `auto_start=true`、health=`/health`。3900 只有一个 listener 和一个 canonical active owner，完整 health status 为 ok。
- `autooffice-auto-evolve` 与 `autooffice-sota-radar` 的规范化快照哈希迁移前后分别保持 `73c37c3b…`、`bb55a7f7…`，没有被触发或修改。PolarPilot 仍 healthy、`projects_monitored=1`，AutoOffice 无 `lobster/daemon-config.json`；同步 status 读取因 377k pending events 超过 20 秒，恢复后 health 正常。
- 验证：TypeScript build、50 test files / 394 tests、治理合同、Shell/JSON/diff、项目审计与 fresh runtime gate 通过。全量 CLI 测试会向 tracked `lobster-events.jsonl` 追加一条模拟 bug，三次验证产物均在 worktree/main 精确移除，真实事件历史未改。依赖审计 12 项既有风险仅记录。用户 `reports/auto-evolve-202607152000.md` 保持未跟踪。

### PolarPilot

- 项目审计：`compliant`；R8 `runtime_governance` = `done`；生态 drift 从 16 降为 14。
- 迁移前 PolarProcess 已运行 direct command `node dist/cli.mjs --daemon --project AutoOffice`（PID 59629/4900），PolarPort 只有 canonical preferred reservation、没有 active owner；本地忽略的 `Start/.pid=52900` 是陈旧文件且未参与生命周期管理。
- 新增 managed daemon port guard、Node 22 前台 `Start/start.sh`、三阶段注册与精确 `polarpilot` client。prepare/cutover 保持 PID 59629 不动，随后仅调用 `polarpilot/restart` 切换到 PID 15593，再 finalize auto-start 与 health。
- PolarProcess 最终为 `polarpilot running/pid=15593/port=4900/auto_start=true`，command=`bash Start/start.sh`；PolarPort 唯一 active owner 为 `PolarPilot/polarpilot:4900`，4900 只有一个 listener。
- `/api/pilot/health` 为 healthy 且 `projects_monitored=1`；`/api/pilot/status` 只返回 `AutoOffice`，状态 dormant，未扩大 SelfHealer/Agentic Healer 范围。用户删除的 `screenshots/polarpilot-status.png` 未纳入迁移提交。
- 验证：20 test files / 179 tests、production build、治理合同、Shell/JSON/diff 检查、项目审计与 fresh runtime gate 通过；typecheck 只保留既有跨仓库声明与 pattern-router fixture 类型错误，新增 runtime 文件无类型错误。依赖审计 2 项既有风险仅记录，未自动改写。

### PolarClaw

- 项目审计：`compliant`；R9 `runtime_governance` = `done`；生态 drift 从 18 降为 16。
- 迁移前 `com.polarclaw.web` launchd KeepAlive/RunAtLoad 独占 PID 20539 与 3910；PolarProcess 仅 adopted 该 PID，PolarPort 没有 active owner。切换只 disabled/bootout 此 label，旧 PID 退出后通过精确 `polarclaw/stop` 清理 adopted 残留，再由 PolarProcess 启动 canonical launcher。
- 首次 governed start 被启动器安全拒绝：PolarPort 的旧 preferred reservation `PolarClaw/polarclaw-web:3910` 阻止 canonical ID 并返回 8000。仅将该项目内预留迁移为 `PolarClaw/polarclaw:3910` 后重试，没有接受漂移端口。
- PolarProcess 最终为 `polarclaw running/pid=47140/port=3910/auto_start=true`，command=`bash Start/start.sh`，health=`/api/status`；PolarPort 在 3910 只有一个 active owner `PolarClaw/polarclaw`，3910 只有一个 listener。
- 旧 `com.polarclaw.web` 已保持 disabled、卸载并删除唯一 plist；用户原有 `PolarSkills/SOUL.md` 改动未纳入任何迁移提交。
- 验证：Node 20.20.2；37 test files / 320 tests、typecheck、root build、Web production build、治理合同、Shell/JSON/diff 检查、项目审计与 fresh runtime gate 均通过。根依赖 39 项、Web 依赖 5 项既有审计风险仅记录，未自动改写依赖树。

### KnowLever

- 项目审计：`compliant`；R16 `runtime_governance` = `done`；生态 drift 从 20 降为 18。
- 扫描时发现未登记 live Reader PID 12619 自 7 月 13 日在 18095 服务 `futures-tqsdk/admin/phase1-demo`；页面 200、旧 `/api/health` 404，PolarProcess 与 PolarPort 均无记录。迁移保留该真实 view，没有创建或改写保护数据。
- `prepare` 注册用旧命令签名让 PolarProcess 原位 adopt PID 12619；`cutover` 仅替换 command；随后只调用 `knowlever-reader/restart`，由 PolarProcess 将其切换到新前台 launcher PID 67887；`finalize` 启用 auto-start 与 health。
- PolarProcess 最终为 `knowlever-reader running/pid=67887/port=18095/pid_verified=true/auto_start=true`，command=`bash Start/reader.sh`；PolarPort 唯一 active owner 为 `KnowLever/knowlever-reader:18095`；health 返回对应 topic/user/view。
- `knowlever-rag` 与 `knowlever-wiki` 全程保持 `stopped/pid=null/auto_start=false`。两个用户 scratch 路径未纳入迁移提交，`.runtime/reader.env` 被忽略并仅保存原 live view 选择。
- 验证：Vitest 从 8 files / 91 tests 增长为 10 files / 95 tests 并全过；Reader 相关 22/22、治理合同、Shell/JSON/diff 检查和项目审计通过。restart 后首次即时 health 探测发生短暂启动竞态，PID 始终存活，条件复查后 listener 与 health 正常。

### digist

- 项目审计：`compliant`；R6 `runtime_governance` = `done`；生态 drift 从 24 降为 20。
- API 统一为 `digist-api`：PolarProcess `running/pid=97931/port=3800/pid_verified=true/auto_start=true`，PolarPort 唯一 active owner 为 `digist-api/digist:3800`，`/api/health` 正常。
- 无端口 Engine 统一为 `digist-engine-worker`：PolarProcess `running/pid=13598/port=null/pid_verified=true/auto_start=true`；旧 `digist-engine` 因注册 API 无法清空历史 8015，精确停止后作为 `auto_start=false` tombstone 保留，8015 无监听。
- 旧 API `digist` 已精确归一为 `stopped/pid=null/auto_start=false`，8045 无监听；首次 stop 因历史 `start_script_dir=Start` 调用了已切换的 canonical 客户端而未命中 PID 2565，后续用 prepare/finalize 两阶段注册完成切换，全程未直接发送信号。
- 迁移窗口中 `digist-daily-digest` 按自身 cron 于 23:00 启动 PID 7594，未被停止、重启或修改；auto-evolve、to-knowlever-sync、summarize 保持 stopped。
- 验证：隔离 SQLite 在线备份上的 45 edge + 45 all + 18 scraper、性能基准、TypeScript build、治理合同、Shell 语法和 Web production build 均通过；Web 仅保留既有 PolarClaw dynamic dependency warning。

### PolarPrivate

- 项目审计：`compliant`；R10 `runtime_governance` = `done`。
- 新增 `Start/backend.sh` 与 `Start/frontend.sh` 前台 launcher；旧 `backend/Start` 入口改为精确 `privportal-backend` PolarProcess 客户端，移除被跟踪的 PID 文件、后台化、直接信号与备份脚本。
- PolarProcess：Backend `running/pid=34141/12790`，Frontend `running/pid=34874/12795`，两者 `pid_verified=true`、`auto_start=true`；命令均为根级前台 launcher。
- PolarPort：首选预留与 active owner 统一为 `privportal-backend/PolarPrivate:12790`、`privportal-frontend/PolarPrivate:12795`；旧 `polarprivate` 与 `polarprivate-frontend` 预留已退役。
- `polarprivate4taoci` 属于独立 `~/Desktop/Server` 仓库，迁移期间保持 `running/pid=29654/12800` 不变；`privportal-vault-sync` cron 未执行。
- 迁移窗口中原 Frontend PID 23965 独立退出；旧 preferred reservation 使 governed launcher 两次拒绝 fallback 8000。完成 target-only reservation 换代与精确 Backend restart 后，双服务按 canonical owner 收敛，过程已写入项目 SSoT。
- 验证：治理契约、shell 语法、CLI 5/5、Frontend build、TypeScript SDK 21/21、Python SDK 17/17、双 health 与治理审计通过；Backend 全量 316/328，12 个既有非迁移失败与基线一致。

### SOTAgent

- 项目审计：`compliant`；R6 `runtime_governance` = `done`。
- API 与 Console 拆分为 `sotagent`、`sotagent-console` 两个前台 launcher；旧根 `start.sh` 不再后台启动或直接发送信号。
- PolarProcess：API `running/pid=78575/4800`，Console `running/pid=87073/4880`，两者 `pid_verified=true`、`auto_start=true`。
- PolarPort：唯一 active owner 分别为 `sotagent/SOTAgent:4800` 与 `sotagent-console/SOTAgent:4880`。
- 旧 `com.sotagent.web` launchd KeepAlive 已卸载、禁用并删除 plist；API handoff 的 PID 变化及首次 adopt 失配已如实写入项目 SSoT。
- 验证：治理契约、Start 自托管 6/6、根 TypeScript build、API/Console health 与治理审计通过；全量测试 98/102，4 个既有非迁移失败保留；Console build 仍有 1 个既有未使用 import 错误。

### PolarCopilot

- 项目审计：`compliant`；R9 `runtime_governance` = `done`。
- `polarcop-hub` 原位注册为前台 command `bash Start/hub.sh`，`auto_start=true`；迁移前后均为 `running/pid=13289/port=8040`，健康检查持续通过。
- PolarPort 保持唯一 active owner `PolarCopilot/polarcop-hub:8040`，迁移没有重启 Hub。
- `polarcop-web-dev` 原位注册为 `bash Start/web-dev.sh`，通过精确 PolarProcess stop 从陈旧 `starting/pid=null` 归一为 `stopped/pid=null/auto_start=false`；5180 无监听和 active 端口记录。
- 治理契约、shell 语法、Web Vitest 23/23、Vite build、VSCode compile 通过；Hub 全测保持迁移前 177/191（14 个既有失败），Hub build 的 10 个既有非迁移错误已记录在项目 SSoT。

### Clock

- 项目审计：`compliant`。
- 原有服务 ID 原地收敛：`polarclock-backend`、`polarclock-frontend`。
- PolarProcess：两个服务均 `stopped`、`pid=null`、`auto_start=false`，前台 command 分别为 `bash Start/backend.sh` 与 `bash Start/frontend.sh`。
- PolarPort：无 Clock active 记录；4555/15550 无监听。
- 旧 `nohup`/PID/直接信号与普通项目 launchd 路径已退役；本机 PID 文件保留但退出版本控制。
- clean checkout 缺失的 `frontend/src/data` 构建源码已纳入版本控制。
- 验证：canonical Vitest 37 passed、pytest 108 passed、Vite build passed、治理契约与仓库完整性契约通过。
- Clock SSoT：R11 `runtime_governance` = `done`。

## 结构风险

- [SSoT 缺口] 生态根缺少 `PolarSoul.md`，与 `pc-project-scan` 的前置契约不一致。
- [SSoT 缺口] PolarFlow、PolarUI、_Polarisor 缺少项目级 `PolarSoul.md`。
- [仓库边界] PolarFlow 与 PolarUI 没有独立 Git 仓库，修改会进入当前高度活跃的根仓库分支。
- [统计兼容] 各项目 `polaris.json` 的 feature/status schema 并非完全一致；完成度数字只作扫描提示，迁移验收以项目原生测试和明确 evidence 为准。
- [运行态动态性] PolarPort 与 PolarProcess 注册表随心跳变化；全局漂移数是快照，项目是否 compliant 才是迁移完成判据。

## 剩余项目运行态复扫（22:01）

复扫只读取 Git、SSoT、PolarProcess、PolarPort 与监听状态，没有启停或重注册服务。

| 项目 | 项目审计 | 工作树 | 当前运行态 | 迁移保护边界 |
|---|---|---:|---|---|
| PolarCopilot | compliant | 0 | `polarcop-hub` running/pid=13289/8040 且 PolarPort 唯一 active；`polarcop-web-dev` stopped/pid=null | 已迁移封口 |
| SOTAgent | compliant | 0 | API running/pid=78575/4800；Console running/pid=87073/4880；双 PolarPort active owner | 已迁移封口 |
| PolarPrivate | compliant | 0 | backend 34141/12790、frontend 34874/12795、4Taoci 29654/12800 均 verified running；双 canonical active owner | 已迁移封口；4Taoci 与 vault-sync 边界保留 |
| digist | drift=1 | 0 | API 3800 与 engine 8015 running；另有 digest/evolve/sync 任务 | 移除 Start 后台/kill；统一 `digist`/`digist-api` 身份 |
| KnowLever | drift=2 | 2 | RAG/Wiki 均 archived + stopped | 保留用户改动；先确定当前唯一持久服务边界和 health |
| PolarClaw | drift=1 | 1 | `polarclaw` running/3910，缺 PolarPort active | 保持 live Agent；补根级 launcher 与 active owner |
| PolarPilot | drift=1 | 2 | `polarpilot` running/4900，缺 PolarPort active | 保持 AutoOffice guard；前台化 daemon 入口 |
| AutoOffice | drift=1 | 1 | `autooffice` running/3900 且 PolarPort active；另有两个 cron | 保持 live API 与 cron；移除 Start 后台/kill |
| tqsdk | compliant | 1 | collector running/18900 且 canonical PolarPort active；gateway stopped/12890 无 listener | 已迁移封口；gateway 凭证边界保留 |
| PolarUI | compliant | active feature 改动保留 | GUI 85284/5170 canonical active；native preview stopped；QA/brainstorm/Web release hash 未变 | 已迁移封口；14945 多端口表达缺口单列 |

### 复扫结论

- 19 个正式项目均已定位到明确的 Git/SSoT/服务/端口边界；普通项目迁移队列为 0。
- PolarUI 已完成运行态身份验收；active feature 与多端口 QA 次 listener 边界均有独立证据。
- live 项目优先采用“代码与注册原地收敛、当前 PID 不动”；必须切换新代码时，先 adopt 再仅对目标 service ID 做精确 restart。

## Registry 根外迁移记录（2026-07-17）

### ai-daily-digest

- 仓库边界：`~/clawd` monorepo；仅提交 `ai-daily-digest` 治理文件，用户现有 topN 配置、生成内容与其他 `clawd` 改动全部保留。
- 新增项目 `polaris.json`、前台 `Start/start.sh`、只注册不启停的 `Start/register.sh`、定时任务 wrapper 与治理契约测试；未改服务页面和摘要生成逻辑。
- `ai-daily-digest` 最终为 PolarProcess `running/pid=65274/port=8785/pid_verified=true/auto_start=true`，PID 的 PPID 为 PolarProcess；PolarPort 唯一 active owner 为 `ai-daily-digest/ai-daily-digest:8785`，HTTP health 为 `ok`。
- 每日 03:00 调度已注册为 PolarProcess `ai-daily-digest-job`，保持 `stopped/pid=null/auto_start=false/cron_schedule="0 3 * * *"`；唯一用户 crontab 条目精确退役，旧 launchd plist 未加载且已删除。
- 首次切换误将前台 launcher 注册为 script mode，触发一个 60 秒受管窗口；根据 PolarUI/tqsdk canonical 模式改为 `start_script_dir="-"`，等待旧窗口自然结束后仅调用目标 service start，未直接发送信号。治理测试同时修复 Bash `! grep` 在 `set -e` 下的假绿断言。
- 验证：治理合同、Shell/JSON、项目审计、单 listener/PID/owner/health、scheduler 边界通过；全局 registry drift 从 9 降为 8。提交：`387b2da`。

### claude-code-vis

- 仓库边界：`~/workplace/claude-code-vis-server`，当前不是 Git 仓库；仅新增治理文件，`site/` 内容哈希保持 `7a5feb94…`。
- 新增 `polaris.json`、PolarPort 前台 launcher、只注册入口与治理契约测试；保留 `/claude-code-vis` URL 前缀与 Python 静态服务行为。
- 仅调用 `claude-code-vis/stop` 与 `claude-code-vis/start` 完成切换。最终 PolarProcess 为 `running/pid=89364/port=19120/pid_verified=true/auto_start=true`，PID 的 PPID 为 PolarProcess；PolarPort 唯一 active owner 为 `claude-code-vis-server/claude-code-vis:19120`。
- `/` 与 `/claude-code-vis/` 均 HTTP 200；项目审计 `compliant`，全局 registry drift 从 8 降为 7。

### PolarPrivate4Taoci

- 仓库边界：`~/Desktop/Server` 共享 Git 根；目标目录已有未提交 TaoCi 邮件/readiness/LLM 与 launcher 迁移改动，本次在原改动上只补 authority precheck、strict port、注册入口、治理测试和 R10 证据，未提交或改写业务成果。
- 旧 live PID 29654 虽登记在 PolarProcess，但 PPID=1 且 12800 无 PolarPort owner。只注册 canonical 配置后，仅调用 `polarprivate4taoci/restart` 切换。
- 最终 PolarProcess 为 `running/pid=11592/port=12800/pid_verified=true/auto_start=true`，PID 的 PPID 为 PolarProcess；PolarPort 唯一 active owner 为 `PolarPrivate4Taoci/polarprivate4taoci:12800`。
- `/health` 与 `/ready` 均 HTTP 200；项目审计 `compliant`。非目标服务哈希 `82a34631…` 与端口哈希 `e1c50df6…` 前后完全一致；全局 registry drift 从 7 降为 6。

### TaoCi

- 仓库边界：`~/Desktop/Server` 共享 Git 根；只修改 TaoCi 运行时启动器、supervisor、治理测试与 `polaris.json`，保留同仓邮件、LLM、问卷、产品与其他未提交改动。
- `taoci-next` 作为唯一真实生命周期 owner，由 PolarProcess 前台管理 attached Docker Compose；3110、3115、18025 通过 `service_management.port_bindings` 归属同一个 supervisor，未注册三个伪生命周期服务。
- 最终 PolarProcess 为 `running/pid=73082/port=0`，PID 的 PPID 为 PolarProcess；PolarPort 唯一 active owner 分别为 `TaoCi/taoci-web:3110`、`TaoCi/taoci-admin-api:3115`、`TaoCi/taoci-mail-capture:18025`。
- 3110 `/health/ready`、3115 `/v1/admin/health`、18025 `/api/messages` 均 HTTP 200；治理合同 29/29、项目 audit `compliant`，TaoCi 四条 registry drift 全部消失。
- 本次同时扩展治理 Skill 和只读 auditor 的多端口 supervisor 表达，并补齐无端口 worker 不应要求 PolarPort owner 的回归测试；全局 registry drift 从 6 降为 3。

### market-truth-cs

- 仓库边界：`~/Desktop/Web_related/market-truth-cs` 当前不是 Git 仓库；新增 `polaris.json`、前台 launcher、只注册入口、精确生命周期 client 与治理测试，并将 package start 命令统一路由到 PolarProcess。
- 该 Docker stack 实际发布 3925 API 与 3085 LibreChat UI；两者均由 launcher 向 PolarPort 精确申领，并通过 `service_management.port_bindings` 归属唯一 `market-truth-cs-stack` lifecycle owner。
- 既有 `web-market-truth-cs-api` 记录无法通过注册 API清空历史 port；保留为 `stopped/pid=null/auto_start=false/restart_on_failure=false` tombstone，避免直接改共享数据库。排队 watchdog 曾短暂拉起旧 wrapper，已仅通过旧 service ID stop 清理。
- 最终 `market-truth-cs-stack` 为 PolarProcess `running/pid=78622/port=null`，PID 的 PPID 为 PolarProcess；PolarPort owner 为 `market-truth-cs/web-market-truth-cs-api:3925` 与 `market-truth-cs/web-market-truth-cs-lc:3085`，双入口 HTTP 正常。
- 验证：治理合同 4/4、Shell/JSON、Compose config、项目 audit 与全局 registry audit 通过；全局 drift 从 3 降为 2。

### PolarUI 活跃 feature 收尾

- 扩展 `service_management.services[]`：一个项目可以声明多个真实 PolarProcess lifecycle service，每个 service 再用自己的 `port_bindings` 表达次监听；auditor 回归覆盖单 supervisor 多端口、多 service 项目和无端口 worker。
- `polarui-native-web-qa-mailpit` 保持原 PID 2506，不做生命周期切换；14940 HTTP 是主 port，14945 SMTP 作为同一 service 的 secondary binding，未伪造第二个 PolarProcess 记录。
- `polarui-brainstorm-ui-logic` 从 literal-port direct command 切换到权威 preflight + exact PolarPort claim + 前台 launcher。最终 PolarProcess `running/pid=16246/port=14950/auto_start=false`，PPID 为 PolarProcess；14950 canonical owner active，HTTP 200。
- 只调用 brainstorm 精确 service ID stop/start；稳定 GUI 与 Native QA 其他服务未启停。受保护服务哈希 `a5291e14…`、端口哈希 `ad622e84…` 前后完全一致。
- 验证：PolarUI composite 3/3、稳定 GUI contract、Skill auditor regression、Shell/JSON、项目 audit 与 fresh ecosystem audit 全部通过；全局 drift 从 2 降为 0。

## Registry 根外残余漂移

当前 fresh ecosystem audit 为 `compliant`，registry drift = 0。后续新增持久服务必须在首次启动前完成项目 SSoT、PolarPort claim 与 PolarProcess 注册。
