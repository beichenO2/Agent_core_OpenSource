# Polar Runtime Governance Design

## 目标

让 `~/Polarisor` 现有项目及以后由 Codex 开发的项目遵循同一运行时规则：PolarPort 是长期监听端口的唯一权威，PolarProcess 是长期运行服务生命周期的唯一权威。治理层必须先提供可见性和明确操作路径，不能通过批量重启、自动迁移端口或杀进程来强行达成一致。

## 现状依据

- PolarPort `:11050` 与 PolarProcess `:11055` 当前健康。
- PolarProcess 当前记录 19 个带端口的运行服务，PolarPort 只有 9 个 active 端口记录，说明两个事实源之间存在历史漂移。
- `~/Polarisor` 当前 19 个项目级 `polaris.json` 中有 6 个未声明 `service_management`。
- Agent_core 已有 P27 和 `reference/SERVICE-PORT-MINIMAL.md`，但 Codex 没有一个会在普通开发、调试、预览和部署任务中主动触发的独立 Skill。

## 方案比较

### 方案 A：只修改现有 pc 系 Skills

改动最少，但只覆盖显式进入 PolarCopilot 工作流的任务，普通 Codex 开发任务仍可能直接运行 `npm run dev`、硬编码端口或使用 `kill`。不能满足“以后都用 Codex 开发”的覆盖范围。

### 方案 B：新增全局 Codex Skill，并以 Agent_core 为规范源（采用）

在 Agent_core 内创建 `polar-runtime-governance`，通过 `~/.codex/skills` 软链接安装。Skill 负责触发和操作流程，详细契约放在 Skill reference 中，只读审计脚本提供确定性检查。它不会修改现有服务，适合逐项目接入。

### 方案 C：增加 shell hook 或命令拦截器

约束最强，但可能误拦一次性测试、安装脚本或第三方工具，也可能影响正在运行的服务。当前阶段风险高，等只读审计稳定、项目逐步接入后再评估。

## 适用边界

纳入治理：开发服务器、API、前端预览、worker、daemon、scheduler、MCP HTTP 服务、容器入口，以及任何退出当前 Codex 命令后仍应持续运行的进程。

不纳入治理：编译、单元测试、格式化、lint、数据库一次性迁移、代码生成和其他随当前命令结束的一次性任务。测试框架内部短生命周期的随机回环端口允许存在，但不得作为人工访问或后续任务依赖的常驻服务。

PolarPort 与 PolarProcess 自身属于引导基础设施，由 launchd 作为最外层守护；Codex 不通过目标服务自身管理它们，也不在普通项目任务中重启它们。

## Codex 工作流

1. 先识别任务是否会产生长期进程或监听端口。
2. 只读检查 PolarPort、PolarProcess 健康和目标项目现状。
3. 已注册服务通过 PolarProcess API 查询、启动、停止或重启。
4. 新服务先补 `polaris.json`、健康端点和 `Start/start.sh`，再用 PolarPort claim 端口，最后向 PolarProcess 注册。
5. 端口不得写进 PolarProcess 的注册 command；command 从环境或项目启动脚本消费 PolarPort 结果。
6. 失败时只处理目标服务，不批量清理、不抢占端口、不杀不明 PID。
7. 发现历史漂移时输出报告并记录 SSoT；在独立迁移任务中逐项目修复。

## 组件

- `.cursor/skills/polar-runtime-governance/SKILL.md`：触发条件、决策流程和禁止行为。
- `.cursor/skills/polar-runtime-governance/references/runtime-contract.md`：接入契约、操作矩阵、异常处理和 Codex 检查表。
- `.cursor/skills/polar-runtime-governance/scripts/runtime-governance-audit.sh`：只读项目/生态审计。
- `.cursor/skills/polar-runtime-governance/tests/runtime-governance-audit.test.sh`：以假 API 响应和临时项目验证退出码与报告。
- `.cursor/skills/polar-runtime-governance/agents/openai.yaml`：Codex UI 元数据和隐式触发配置。
- `~/.codex/skills/polar-runtime-governance`：指向 Agent_core 技能目录的安装软链接。

## 安全策略

- 审计脚本只允许 `GET`、文件读取和文本扫描，不调用任何启动、停止、重启、allocate、release 或 reserve API。
- 默认不修改目标项目。
- 不把现有漂移直接视为自动修复授权。
- 所有写入仅限 Agent_core 的规范、Skill、测试和 SSoT。
- 合并前运行 Skill 校验、脚本测试、JSON 校验和现有契约测试。

## 验收标准

- Codex 能在开发/调试/预览/部署长期服务时触发 Skill。
- Skill 明确区分常驻服务与一次性命令。
- 审计脚本在合规、漂移、基础设施不可达三类场景返回稳定退出码。
- 审计真实生态时不产生 POST/PUT/PATCH/DELETE 请求，也不改变服务状态。
- Agent_core SSoT 记录设计、实现和验证证据。
