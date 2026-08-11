# pc-principles — 嵌入式协议 (A-G)

按需加载：Agent 在执行 Hub 交互时读取此文件。协议 bash 实现已外置到 `~/.polarcop/core/scripts/`。

---

## 协议 A：Hub 环境初始化

所有需要 Hub 的 Agent 共享此初始化流程。

```bash
_proj_dir="${PC_PROJECT_DIR:-$(pwd)}"
PC_PROJECT_HASH=$(printf '%s' "$_proj_dir" | md5 -q 2>/dev/null | cut -c1-4 || printf '%s' "$_proj_dir" | md5sum 2>/dev/null | cut -c1-4 || echo "0000")
cd ~/.polarcop/core
HUB_CALL="$HOME/.polarcop/core/scripts/hub-call.sh"
AGENT_ID="{role}-$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)"
PC_HUB_PORT=""

# port-sdk 查 polarcop 端口 → MCP 验证
CANDIDATE_PORTS=$(curl -s --max-time 3 "http://127.0.0.1:4800/api/ports" 2>/dev/null \
  | python3 -c "
import sys,json
for p in json.loads(sys.stdin.read()):
    if 'polarcop' in p.get('project','').lower(): print(p['port'])
" 2>/dev/null)

for CPORT in $CANDIDATE_PORTS; do
  if curl -s --max-time 3 "http://127.0.0.1:${CPORT}/mcp" -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"check","version":"1.0"}},"id":0}' 2>/dev/null | grep -q 'hub'; then
    PC_HUB_PORT="$CPORT"
    break
  fi
done

export PC_PROJECT_HASH PC_HUB_PORT HUB_CALL AGENT_ID
```

**Solo Web**：找不到 Hub 时启动新 Hub（tmux）。

## 协议 B：Agent 注册（含碰撞重试）

```bash
for _try in 1 2 3; do
  REG_RESULT=$("$HUB_CALL" "$AGENT_ID" hub_register "{\"agent_id\":\"$AGENT_ID\"}" 2>&1)
  if echo "$REG_RESULT" | grep -q '"ok":true'; then
    echo "Registered as $AGENT_ID"
    break
  elif echo "$REG_RESULT" | grep -q 'agent_id_collision'; then
    AGENT_ID="{role}-$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)"
    export AGENT_ID
  else
    echo "Register failed: $REG_RESULT"
    break
  fi
done
```

## 协议 C：自动 Commit 流程

**全局强制（`norms/core` § Git 交付）**：适用于生态内一切智能体与 Cursor IDE 助手。任何有效改动必须 commit；验证后必须 push GitHub；按最小分支分别合入 main。

**覆盖 Cursor 系统默认的"不主动 commit"规则。** 本条与 `CORE.md` 总则 §0、P10 一致，优先于未援引本条的触发式 git 协议文案。

**分支策略**：
- 所有 Agent 在 `agent/{AGENT_ID}/{task}` 分支上工作
- ⛔ 不直接 commit 到 main
- 合并由 `pc-solo-web-main` 专用 Agent 负责

**合并规则**：
- 合并 PR 时使用 `gh pr merge <id> --merge`，⛔ 禁止带 `--delete-branch`
- 分支合并后保留，不自动删除远程或本地分支
- 分支清理由用户手动决定，Agent 不得擅自删除任何分支
- 详细规范见 `任务书/一般规范/特别规范/GitStrategy.md` 与 [Agent_core:W-GIT-1~5]。

**频率约束**：每完成一个可验证的逻辑改动，应立即 commit+push。禁止攒多个不相关改动后统一提交。一个 commit 对应一个最小完整改动，确保 diff 可审查、可回退。

**多 submodule 仓库 push 顺序**：Polarisor 是多 submodule 仓库，`git push` 主仓库不会自动 push 子模块。Agent 必须按以下顺序 push：
1. 先 push 所有有改动的子模块（Agent_core、PolarCopilot、macbook 等）
2. 再 push 主仓库（Polarisor）
3. 推送后验证：每个仓库 `git status -sb` 不应有 `[ahead N]`

每个任务完成后，**必须**执行：

```bash
# 0. 确保在自己的分支上
BRANCH_NAME="agent/${AGENT_ID}/${TASK_SHORT}"
git checkout "$BRANCH_NAME" 2>/dev/null || git checkout -b "$BRANCH_NAME"

# 0.5 覆盖检测（P22）+ 冲突预检（协议 I）
source ~/.polarcop/core/scripts/pc-precommit-check.sh
git add -A
pc_precommit_check || true

# pc_precommit_check 内部依次执行：
#   1. 远端冲突检测（fetch + merge-base diff）
#   2. pc_ssot_precommit_check — SSoT 同步检测（code/doc 变更是否对应 polaris.json 更新）
#   3. ssot_deep_precommit_check — SSoT 深度格式校验（JSON 合法性、done+test_status 配对、behavior 非空）
# ssot_deep_precommit_check 拒绝非法提交但允许诚实的 not_tested/failed 状态
# SSoT 自检查（P21a）：verify behavior[] on features, contacts existence

# 1. commit + push
git commit -m "{type}: {description} [$AGENT_ID]" && git push origin HEAD

# 2-5. SoTADiff 记录 + 三层验证 + 进化信号 + SSoT 同步
# 详见各步骤的 hub-call.sh 调用（hub_sotadiff_record, /api/verify, /api/evolution/signals）

# 5a. SSoT 格式自检（P21a）— 打开 polaris.json 时顺手修复格式问题
# 检查 feature 是否都有 behavior[]、contacts 是否存在
# 发现问题就地修复，不等用户发现
```

## 协议 D：check_hub（Web 模式专用）

Agent 完成任务 → send_prompt 汇报 → MCP 阻塞等待回答 → 收到 answer → 下一 turn 执行新任务 → ...

**⛔ 禁止启动时默认发问**：`setup` 只注册 Agent，不创建「等待指令」类 prompt。
**⛔ 阻塞式等待**：`check_hub` 必须是 send_prompt 之后的 turn 最后一步，禁止边等边做其它工作。

### 通信方式：hub-agent-N MCP

Web 模式使用 `hub-agent-N` MCP Server（`~/.cursor/hub-mcp-server/index.mjs`）
与 Hub 通信。MCP Server 内部处理 SSE / HTTP 轮询，Agent 侧只需调用 MCP tool。

**⛔⛔⛔ 禁止使用 curl + bash 循环与 Hub 通信。禁止生成 `while true; do curl ... done` 代码。
旧脚本 `pc-solo-web-start.sh` 已归档删除。**

唯一正确方式——MCP 工具：

| MCP Tool | 说明 |
|----------|------|
| `setup` | 发现 Hub + 注册 Agent（默认不创建 prompt） |
| `check_hub` | 阻塞等待回答（仅 send_prompt 之后调用） |
| `send_prompt` | 任务完成后发送带选项的 prompt |
| `patch_agent` | 更新 Agent 显示名 |
| `hub_status` | 查看连接状态 |

**Cursor Agent 实现**：`CallMcpTool("hub-agent-N", "check_hub")`——MCP 进程内阻塞，
直到用户在 Hub Web 回答。调用后停止本 turn，不消耗 Shell tool call。

### Hub Prompt API 速查（MCP 内部使用，Agent 无需直接调用）

| 接口 | 方法 | 用途 | 返回 |
|------|------|------|------|
| `/api/ui/prompts` | POST | 创建新 prompt | `{id, ...}` |
| `/api/ui/prompts` | GET | 列出 pending prompts | 仅 `answered_at IS NULL` |
| `/api/ui/prompts/:id` | GET | 查单个 prompt | 无论是否已回答 |
| `/api/ui/prompts/:id/stream` | GET | SSE 等待回答 | 推送 answered/superseded |
| `/api/ui/prompts/:id/answer` | POST | 提交回答 | `{ok, ...}` |

**单一 pending 约束**：同一 Agent 任意时刻只能有一个未答 prompt。要发新 prompt 必须先等当前 prompt 被回答，否则 Hub 直接返回 `409 pending_choice_exists`。`send_prompt` 工具会自动提示此约束。

## 协议 F：Agent 动态命名

Agent 的 display_name 必须是**当前工作目标的短摘要**，且**实时变动**。用户在 Hub Web 上看到的名字应能立即理解每个 Agent 正在做什么。

**更新方式**：

```
CallMcpTool("hub-agent-N", "patch_agent", { "display_name": "正在：{任务短摘要}" })
```

**命名格式**：`正在：{动词+对象}`，不超过 20 字。

| 场景 | 好的命名 | 差的命名 |
|------|---------|---------|
| 修复登录 bug | 正在：修复用户登录验证 | Solo Web Agent |
| 重构 API 层 | 正在：重构 Hub REST API | Polarisor Solo Web |
| 等待指令 | 空闲：等待指令 | solo-web-8bcc830c |
| 执行 YOLO | YOLO：实现用户注册功能 | YOLO Agent |

**必须更新的时机**（⛔ 漏任何一个 = 违反协议 F）：

1. **收到新任务后、执行前**：设为 `正在：{任务摘要}`
2. **任务完成后、等待前**：设为 `空闲：等待指令`
3. **进入 YOLO 后**：设为 `YOLO：{极限目标摘要}`
4. **领取 Pilot 任务后**：设为 `Pilot：{任务描述}`

**命名规则**：
1. 名字反映当前任务目标，不是角色身份
2. 任务目标变化时立即更新
3. ⛔ agent_id 绝不作为用户可见名字
4. ⛔ 禁止使用静态名称（如 "Solo Web Agent"）超过收到第一个任务之后

## 协议 G：YOLO 对齐与自动执行

YOLO 不是独立模式，而是 Solo 模式内的开关。核心价值在于**对齐**。

**触发条件**：用户说出 YOLO 触发词（"YOLO"、"全自动"、"不要问我直接做"、"自动把所有事情做完"）。

**三维对齐（缺一不可）**：极限目标（可度量）+ 工作逻辑（Debug > Test > Dev，固定）+ 用户预期体验

**SSoT 自动引用（必须）**：`[SSoT:ProjectName/R1/FeatureName]` 3 段格式。⛔ 禁止 `[P1]` 等非 SSoT 格式。

**Alignment API 格式**：

```
POST /api/ui/alignment
{
  agent_id, goal, work_logic, workflows[],
  plan_markdown, sections[{name, confirmed}]
}
```

**⛔ Hub 服务端验证（自动执行，Agent 无法绕过）**：
- `goal` 必须 ≥ 10 字符
- `plan_markdown` 必须 ≥ 50 字符
- `sections` 必须包含全部 7 个必要项
- 验证失败返回 400 + `alignment_validation_failed`

**⛔ 覆盖率检查（`GET /api/ui/alignment/:id/coverage`）**：
- 检查 plan_markdown 中 7 个 section header 是否存在且有实质内容
- 检查三维对齐是否全覆盖
- 检查 SSoT 引用是否存在且格式正确
- 返回 `score`（0-100%）、`errors`、`warnings`

**⛔ 审批拦截（`POST /api/ui/alignment/:id/approve`）**：
- 三维对齐未全覆盖 → 400 拒绝（除非 `force: true`）
- 覆盖率 < 60% → 400 拒绝（除非 `force: true`）

**对齐循环**：用户确认 → 自动执行；用户修改 → 更新方案；用户取消 → 回到正常模式

**自动执行阶段**：按计划执行 → 每步测试 → Bug 立修 → 每步协议 C → 按 `pc-solo-web` 发 Hub Prompt 汇报（含需求对齐，P19）

---

## 引用指南

| 场景 | 参考 |
|------|------|
| 选择实现方案时 | P1 |
| 输出结论或分析时 | P2 |
| 涉及凭证或个人信息时 | P3 |
| 开始复杂任务前 | P4 |
| 新增能力/流程/规则时 | P4a |
| 用户追问"为什么"时 | P5 |
| 用户说"例如/比如"时 | P5a |
| 发现"顺手可做"的额外工作时 | P6 |
| 面对现有代码时 | P8 |
| 删除文件/目录时 | P13 |
| 修改文件前读 diff 时 | P18 |
| 更新项目信息时 | P20 |
| 每次有效工作后同步 SSoT | P21 |
| 更新 SSoT 时自检格式合规 | P21a |
| commit 前检测功能覆盖 | P22 |
| 初始化 Hub 环境时 | 协议 A |
| 注册到 Hub 时 | 协议 B |
| 任务完成后 commit 时 | 协议 C |
| 轮询用户指令时 | 协议 D |
| 更新 Agent 名字时 | 协议 F |
| YOLO 对齐与自动执行时 | 协议 G |

## 协议 J：SOTAgent 守护进程自动恢复

Agent 启动或执行任务时，若 SOTAgent (port 4800) 不可达，必须尝试自动恢复：

```bash
if ! curl -s --max-time 3 "http://127.0.0.1:4800/api/status" >/dev/null 2>&1; then
  echo "[recovery] SOTAgent 不可达，尝试 sotctl start..."
  sotctl start 2>/dev/null || ~/Polarisor/SOTAgent/bin/sotctl start
fi
```

**`sotctl` 命令**（全局可用，`/opt/homebrew/bin/sotctl` → `~/Polarisor/SOTAgent/bin/sotctl`）：

| 命令 | 用途 |
|------|------|
| `sotctl start` | 启动 SOTAgent 守护进程 |
| `sotctl stop` | 停止（卸载 launchd 服务） |
| `sotctl restart` | 重启 |
| `sotctl status` | 查看守护进程 + 托管服务状态 |
| `sotctl logs [-f]` | 查看/跟踪日志 |

**规则**：
- SOTAgent 配置了 `KeepAlive=true`，理论上 launchd 会自动重拉
- 但 Agent 遇到 SOTAgent 不可达时仍应主动 `sotctl start`，加速恢复
- 恢复后等待 3s 再重试 API 调用

### 托管服务的生命周期管理（权威 = PolarProcess）

所有托管服务（auto_start 或手动注册）必须通过 **PolarProcess** HTTP API 操作（SOTAgent `:4800/api/services/*` 仅为历史 facade 透传，新代码勿用）：

```bash
# 停止（优雅，状态落库）
POST http://127.0.0.1:11055/api/services/:id/stop

# 启动
POST http://127.0.0.1:11055/api/services/:id/start

# 重启（先停后启）
POST http://127.0.0.1:11055/api/services/:id/restart

# 查询所有服务状态
GET http://127.0.0.1:11055/api/services

# 查看单个服务详情
GET http://127.0.0.1:11055/api/services/:id
```

端口一律经 PolarPort（:11050）`claim_port` 分配，禁止在 `command` 或代码中硬编码。

**禁止直接 kill/pkill 托管服务进程**，否则会导致状态不一致和双重拉起（详见 `ADVANCED.md` P27；最小挂载片段 `reference/SERVICE-PORT-MINIMAL.md`）。



## 协议 M：任务书体系规范

任务书是 Polarisor 生态的"执行记录层"——SSoT 记录项目状态细节，PolarSoul 记录系统设计哲学，任务书记录"每一步更改的来龙去脉"。三者互补，缺一不可。

### M1 — 任务书三层流程

所有任务通过"规划 → 编译 → 执行"三层流程处理：

| 阶段 | 规范文件 | 产出物 | 核心职责 |
|------|---------|--------|---------|
| 规划 | `任务书/一般规范/规划规范.md` | `任务书/<日期_编号>/<项目>.md` | 人+Agent 讨论，探索问题，编写设计期任务书 |
| 编译 | `任务书/一般规范/编译规范.md` | `任务书/<日期_编号>_compiled/<项目>.md` | Agent 重构文档为可执行任务包（14 项结构 + 7 条质量门槛） |
| 执行 | `任务书/一般规范/执行规范.md` | 代码改动 + 测试 + SSoT 同步 | Agent 按任务包干活，完成毕业测试后交付 |

完整规范见 `任务书/一般规范/` 目录。本协议仅摘录核心约束和新增规范。

### M2 — Agent ID 生成规则

- Agent ID 为 Agent 启动时的**时间戳**，精确到 0.1 秒，格式 `YYMMDD-HHmmss-S`（如 `260517-101523-4`）
- 若发现 ID 冲突或无编号，可重新申请新的时间戳 ID
- 当前为单 Agent 运行，ID 机制为后续多 Agent 并发预留

### M3 — 任务书命名格式

- 设计期任务书目录：`任务书/<日期_编号>/`
- 编译后任务包目录：`任务书/<日期_编号>_compiled/`
- 任务文件命名含 Agent ID：`<标题>_<AgentID>.md`
- 归档目录：`任务书/Done/<日期_编号>/` 和 `任务书/Done/<日期_编号>_compiled/`

### M4 — 任务书锁机制

- 不同 Agent 写入同一任务书目录时**必须上锁**，锁文件为 `任务_token.md`，包含 Agent 编号
- ⛔ **禁止删除其他 Agent 的锁或任务书**
- ⛔ **禁止修改其他 Agent 的任务_token.md**
- 例外：仅当用户明确要求，或当前 Agent 为该任务的负责人时可操作

### M5 — 任务书作为执行记录

任务书完成后归档到 `Done/` 目录，作为永久的执行记录：
- 归档使用 `mv` 而非 `cp`，原位置不得保留副本
- 归档必须包含任务文件和对应的 `任务_token.md`
- ⛔ 禁止删除已归档的任务书（即使过时）——它们是历史记录的一部分

---

## 协议 L：PolarSoul 维护规范

PolarSoul.md 是系统反身性的根基——它描述系统"是什么"、"为什么这样设计"、"出了问题往哪个方向改"。维护得当则是导航灯塔，维护不当则是噪音来源。

### L1 — 什么必须写入 PolarSoul

| 触发条件 | 写入内容 | 示例 |
|----------|---------|------|
| 新增生态组件 | 在根 PolarSoul 目录地图中添加一行 + 新项目创建自己的 PolarSoul.md | 新建 PolarGuard 项目 |
| 删除/归档生态组件 | 从目录地图中移除或标记为归档 | PolarProcess 迁入 SOTAgent |
| 设计哲学变更 | 更新第二节设计哲学或相关原则 | 从"本地优先"调整为"本地+云混合" |
| 系统架构层级变动 | 更新架构图和层间关系 | PolarCopilot 从服务层升级到入口层 |
| 项目定位/设计目标重大调整 | 更新第四节对应项目的设计目标 | PolarPilot 从"内置 Skill"变为独立系统 |
| 新增不可妥协的底线 | 在对应位置添加 | 新增"所有 Agent 行为必须经 Hub 审计" |
| 目录地图变更 | 新增/移除/重命名目录时更新第五节 | 新增 PolarGuard/ 目录 |

### L2 — 什么不该写入 PolarSoul

| 禁止写入 | 原因 | 应该写在哪里 |
|----------|------|-------------|
| Bug 修复记录 | PolarSoul 不是 changelog | git commit message |
| Feature 实现细节 | PolarSoul 描述"是什么"不描述"怎么做" | polaris.json（SSoT） |
| API 接口文档 | PolarSoul 不是 API docs | 项目 README 或 capabilities.json |
| 配置参数说明 | PolarSoul 不是配置手册 | 项目 README 或代码注释 |
| 临时决策或调试记录 | PolarSoul 只记录稳定的设计决策 | knowledge/ 或任务书 |
| 工时估算或进度百分比 | PolarSoul 不是项目管理工具 | 任务书或 Hub prompt |
| 某次 commit 的改动摘要 | PolarSoul 不是 commit log | git log |

### L3 — 写入判断规则

Agent 在考虑是否更新 PolarSoul 时，必须通过以下三问：

1. **这个改动影响系统的"身份"或"方向"吗？** — 如果只是实现细节的调整（重构、优化、Bug 修复），不写
2. **一个新来的 Agent 读了 PolarSoul 后，会不会因为缺了这条信息而做出错误判断？** — 如果会，必须写
3. **这条信息一年后还有意义吗？** — 如果只是当前阶段的临时状态，不写

三问中**任一为"是"**则写入，**全部为"否"**则不写。

### L4 — 目录地图日期维护

- Agent 每次 commit 涉及某个目录时，**顺手**刷新根 PolarSoul.md 第五节目录地图中对应行的"最后更新"日期和活跃度标记
- 活跃度标记规则：🟢 7 天内 / 🟡 7-30 天 / 🔴 超过 30 天 / ⚪ 从未 commit
- 不需要精确到秒，写日期（YYYY-MM-DD）即可
- ⛔ 禁止批量刷新所有日期——只更新本次实际改动的项目

### L5 — 子项目 PolarSoul.md 维护

每个生态项目自己的 PolarSoul.md 遵循同样的判断规则（L3 三问），但**粒度更细**：

- 子项目 PolarSoul 可以包含"关键设计决策"（Why 级别的解释）
- 子项目 PolarSoul 可以包含"与其他项目的边界"
- 子项目 PolarSoul **不应**包含 feature 列表（那是 polaris.json 的职责）
- 子项目 PolarSoul **不应**包含 API 文档（那是 README 或 capabilities.json 的职责）

---

## 协议 N：生态常识（Common Knowledge）

Agent 在 Polarisor 生态中反复遇到的高频问题和正确做法。本节不是原则（P 系列），而是**工具链使用的事实性知识**——犯错成本高、频率高、但规则很简单。

### N1 — LLM 调用工具链

**核心原则**：调用方只描述需求档次，不选模型。模型选择权完全归 LLM Proxy（PolarPrivate）。

**调用链**：

```
调用方代码 → LLM Proxy SDK (capability code) → PolarPrivate (模型选择+路由) → 上游 LLM Provider
```

**调用方三不原则**：
1. **不传模型名** — 只传 capability code
2. **不配 Base URL** — SDK 内部硬编码 LLM Proxy 地址
3. **不持 API Key** — PolarPrivate 在内存中注入密钥

**Capability Code SDK 用法**：

3 位二进制编码 QCS（质量-上下文-速度），调用方只需声明需求档次：

```typescript
import { createLLMClient } from 'polarclaw/sdk/llm-proxy';
const llm = createLLMClient();
const result = await llm.chat(messages, { capability: '100' });  // 质量优先
const result = await llm.chat(messages, { capability: '001' });  // 速度优先
const result = await llm.chat(messages, { capability: '010' });  // 长上下文
```

**Legacy intent 兼容**（仅限过渡期）：
```typescript
import { intentToCode } from 'polarclaw/sdk/llm-proxy';
const code = intentToCode('coding');  // → '100'
```

**健康检查**：
```typescript
const llm = createLLMClient();
const health = await llm.healthCheck();
// { status: 'ok', vault_unlocked: true }
```

**严禁**：
- 在调用方代码中出现具体模型名（如 GLM-5.1、qwen3.6-plus）
- 在调用方代码中配置 Base URL 或 API Key
- 绕过 SDK 直接构造 HTTP 请求到 LLM Proxy
- 不检查 PolarPrivate 健康状态就调用

### N2 — 端口分配（必须走 PolarPort）

**规则**：所有服务端口**必须**通过 PolarPort 统一分配，**严禁**硬编码端口号或随意申请。

```
正确：向 PolarPort 申请端口 → 拿到分配结果 → 使用分配的端口
错误：在代码里写 const PORT = 3000 → 直接 listen
```

**查询已分配端口**：`GET http://127.0.0.1:11050/api/list`（PolarPort，唯一权威；SOTAgent `:4800/api/ports` 仅 facade 展示）

| 服务 | 当前端口（动态分配，非硬编码） | 用途 |
|------|------|------|
| PolarPort | 11050 | 端口分配唯一权威 |
| PolarProcess | 11055 | 进程生命周期唯一权威 |
| PolarPrivate | 12790 | LLM 代理 + 密钥管理 |
| PolarBudget | 11060 | CPU 预算 / lease / QoS 唯一权威 |
| PolarCopilot Hub | 8040 | IDE Agent Web UI（MCP 通道入口） |

> 上表仅为当前快照，端口可能因 PolarPort 重新分配而变化。**必须**通过 PolarPort API 查询，不能在代码中假设固定端口。preferred 端口必须以 0/5 结尾。

### N3 — 程序生命周期管理（必须走 PolarProcess）

**规则**：所有服务的启动、守护和重启**必须**通过 PolarProcess（:11055）管理，**禁止**手动 kill、手动 nohup 或手动 node。SOTAgent 仅提供 console 前端展示。

**正确流程**：
1. **启动**：先向 PolarProcess `POST /api/services` 注册（`command` 不含硬编码端口）→ PolarProcess 负责启动 + Watchdog 守护
2. **重启**：`POST /api/services/:id/restart`，不直接 kill 进程
3. **停止**：`POST /api/services/:id/stop`，或项目内 `Start/start.sh stop`

**禁止**：
- `kill <pid>` 后手动 `nohup node ... &`
- 在 shell 脚本中直接启动服务绕过 PolarProcess（项目 `Start/start.sh` 属于合法编排，其内部走 `claim_port`）
- 不注册就启动——PolarProcess 不知道的服务等于不存在

**例外**：开发调试时可以临时直接启动（`npm run dev`），但部署/生产**必须**走 PolarProcess。

### N4 — PolarPrivate 健康检查

```
GET http://127.0.0.1:12790/health → { "status": "ok", "vault_unlocked": true }
```

- `vault_unlocked: false` 时所有 LLM 调用会失败——需要先解锁 vault
- PolarPrivate 不可达时，检查 SOTAgent 是否正在运行

---

## 协议 O：本地命令注册表

生态中所有 Agent 和用户可用的本地命令。命令通过符号链接安装到 `/opt/homebrew/bin/`（macOS）或 `/usr/local/bin/`（Linux），确保全局可用。

### O1 — 已注册命令

| 命令 | 源路径 | 全局路径 | 用途 |
|------|--------|---------|------|
| `sotctl` | `~/Polarisor/SOTAgent/bin/sotctl` | `/opt/homebrew/bin/sotctl` | SOTAgent 守护进程管理（start/stop/restart/status/logs） |

### O2 — 命令注册规范

新命令注册流程：
1. 在源项目的 `bin/` 目录创建可执行脚本
2. 创建符号链接到全局路径：`ln -sf ~/Polarisor/<Project>/bin/<cmd> /opt/homebrew/bin/<cmd>`
3. 在本表 O1 中添加对应行
4. 在源项目的 PolarSoul.md 中记录该命令的存在

### O3 — 命令命名规范

- 使用小写字母 + 可选连字符（如 `sotctl`、`polar-sync`）
- 前缀规则：生态级命令用 `polar-` 前缀，项目级命令用项目缩写（如 `sotctl` = SOTAgent Control）
- 禁止与系统命令重名
- 禁止不带前缀的通用名（如 `start`、`run`、`check`）

---

## 协议 P：TaskContract（任务契约系统）

TaskContract 是 Agent 运行时的核心机制，用于在长对话中防止灾难性遗忘和逻辑链断裂。它独立于对话历史，每轮注入 system prompt，不受上下文压缩影响。（该机制原实现于 PolarClaw，PolarClaw 已于 2026-08-11 退役——见根仓 ARCHIVED.md——协议本身仍对各 Agent 形态有效。）

### P1 — Contract 生命周期

```
用户消息 → 约束提取（LLM）→ 生态约束加载 → Contract 创建
→ 注入 system prompt → 执行步骤 → 每步验收 checkpoint → 完成
```

### P2 — 约束分类

| 来源 | 分类 | 说明 |
|------|------|------|
| `user` | format / process / content / tool / output | 用户在消息中明确提出的硬约束 |
| `ecosystem` | 同上 | 从 Agent_core 协议中按关键词匹配自动加载的规范约束 |

### P3 — 注入规则

- Contract 文本在**每轮** LLM 调用时注入到 system prompt 的固定位置
- 注入位置在 base prompt 之后、memory 之前
- 简单任务（0 约束 + 1 步骤）跳过注入，避免额外 token 开销
- Contract 文本被 `[TASK CONTRACT]...[/TASK CONTRACT]` 标记包围

### P4 — 步骤验收

- 每当 LLM 返回无工具调用的回复时，自动推进当前步骤为 `done`
- 如果存在后续步骤，注入 checkpoint 验证消息要求 LLM 对照约束列表自查
- 所有步骤完成后标记 contract 为 `completed`

### P5 — 持久化

- Contract 持久化到 SessionMemory 的 SQLite 数据库（`task_contracts` 表）
- 与 episodic memory 并列，通过 `conversation_id` 关联
- 会话恢复时自动加载 contract 继续执行

### P6 — 禁止

- 禁止在对话历史压缩时丢弃 contract 约束
- 禁止 LLM 自行修改或忽略 contract 中的硬约束
- 禁止跳过 checkpoint 验收直接完成任务

---

## 协议 Q：Agent 交互与汇报规范

所有 Agent 向用户汇报时必须遵循统一的交互标准。本协议从 PolarCopilot Solo Web 实践中提炼，适用于所有通信通道（Hub Web / IDE 插件 / CLI）。

### Q1 — Agent 身份标识

| 规则 | 说明 |
|------|------|
| 唯一 Agent ID | 启动时自动获取：MCP 模式由 hub-agent-N 分配 `hw-<uuid8>`；脚本模式用时间戳 `YYMMDD-HHmmss-S` |
| 动态显示名 | 格式 `{角色}：{动作+对象}`，不超 20 字。每收到新任务/完成任务/进入等待时**必须更新** |
| 禁止静态名称 | 收到第一个任务后，禁止保持 "Agent" / "Solo Web Agent" 等泛称 |

**显示名命名表（完整复制自协议 F，所有 Agent 统一执行）**：

| 场景 | 格式 | 示例 |
|------|------|------|
| 收到任务后 | `{角色}：{任务摘要}` | `码农：修复登录逻辑` / `侦探：排查泄漏` |
| 任务完成等待 | `空闲：等待指令` | |
| YOLO 模式 | `YOLO：{极限目标}` | `YOLO：实现用户注册` |
| Pilot 模式 | `Pilot：{任务描述}` | |
| 调研中 | `调研：{主题}` | `调研：LLM 计费方案` |

### Q2 — 汇报格式（必须表格化）

Agent 完成任务后的汇报**必须**使用以下结构化格式。所有关键信息以**表格**呈现，禁止纯文本叙述。

#### 格式 A：任务完成汇报

```markdown
## 任务完成：{任务名}

### 目标对齐
| 维度 | 内容 |
|------|------|
| 原需求 | {用户原文} |
| 实际完成 | {逐条对照} |
| 一致性 | ✅ 完全一致 / ⚠️ 有合理改进 / ❌ 有偏离 |

### 改动摘要
| 文件 | 改动 |
|------|------|
| {路径} | {描述} |

### 验证结果
| 检查项 | 结果 |
|--------|------|
| 编译/类型检查 | ✅/❌ |
| 测试 | {通过数/总数} |
| 回归影响 | ✅ 无 / ⚠️ {说明} |

### 交付
| 项目 | 值 |
|------|------|
| Commit | {hash} |
| Branch | {branch} |
| SSoT 同步 | ✅/❌ |
```

#### 格式 B：调研报告

```markdown
## 调研：{主题}

### 范围
| 维度 | 内容 |
|------|------|
| 调研问题 | {核心问题} |
| 信息来源 | {文档/代码/URL} |

### 结论
| 发现 | 说明 |
|------|------|
| {核心发现 1} | {证据} |
| {核心发现 2} | {证据} |

### 建议
| 建议 | 优先级 |
|------|--------|
| {行动建议} | {高/中/低} |
```

#### 格式 C：项目清查

```markdown
## 项目清查：{ProjectName}

### SSoT 状态
| 维度 | 值 |
|------|------|
| 状态 | {active/planning/archived} |
| 需求完成度 | {R1 (N/M) | R2 ...} |
| 阻塞项 | {列表或"无"} |

### 代码状态
| 指标 | 值 |
|------|------|
| 最近 commit | {hash} {message} ({time}) |
| 未提交变更 | {N 个文件} |
| 活跃分支 | {列表} |
```

### Q3 — 汇报约束

| 规则 | 说明 |
|------|------|
| 必须带 options | Hub 拒绝无选项的 prompt；选项不得包含"结束/退出" |
| 超 800 字用 Canvas | 同时发 Hub 摘要 prompt |
| 关键数据用表格 | 禁止在汇报中用纯文本列举已知结构化信息 |
| 交付必含 commit hash | 有代码改动的汇报必须记录 commit |
| 对齐必须逐条 | "实际完成"必须与"原需求"逐条对应，不可模糊带过 |

### Q4 — 交互循环规则

| 阶段 | 必须动作 |
|------|---------|
| 启动 | 1. setup 注册 Agent（不发 prompt）→ 2. 若 Cursor 有任务则执行，否则结束 turn |
| 收到任务 | 1. patch_agent 更新名称 → 2. 理解任务 → 3. 执行 |
| 执行完毕 | 1. send_prompt 格式化汇报（带 options）→ 2. patch_agent 改名 → 3. check_hub 阻塞等待 → **停止 turn** |
| 等待中 | check_hub 必须是 turn 最后一步；禁止边等边做其它工作 |
| 失败/阻塞 | 仍发汇报（标注失败原因和建议），然后 check_hub 阻塞等待 |

---

## 协议脚本位置

| 脚本 | 路径 | 用途 |
|------|------|------|
| pc-safe-write.sh | `~/.polarcop/core/scripts/pc-safe-write.sh` | 文件锁申请+跨项目保护 |
| pc-precommit-check.sh | `~/.polarcop/core/scripts/pc-precommit-check.sh` | commit 前冲突检测 |
| hub-call.sh | `~/.polarcop/core/scripts/hub-call.sh` | Hub MCP 工具调用 |
| sotctl | `~/Polarisor/SOTAgent/bin/sotctl` (→ `/opt/homebrew/bin/sotctl`) | SOTAgent 守护进程管理 |
