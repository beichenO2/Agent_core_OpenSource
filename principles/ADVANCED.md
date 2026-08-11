# pc-principles — 高级规则 (P13-P22)

按需加载：Agent 在需要以下规则时读取此文件。

---

## P13. 归档规则（含语义删除判断）

**⛔ 禁止 `rm` 删除文件/目录**，一律 `mv` 到 ClawBin。

### 语义判断前置（删除前 6 维检查）

**🔒 不可变规则**：在执行任何删除/归档/卸载/覆盖操作前，必须逐项过 6 维语义检查表。禁止因"重启工作流"、"清理缓存"、"简化结构"等机械触发词直接删除。

| 维度 | 检查问题 | 不通过时动作 |
|------|----------|-------------|
| 1. 引用性 | 是否被其他代码/配置/脚本/文档 import/引用？ | ⛔ 不删，先解除引用 |
| 2. 未来价值 | 之后还会不会用到？（含调试、参考、回退场景） | 归档到 ClawBin，不删 |
| 3. 兼容性 | 是否旧但仍兼容？删后会破坏向后兼容吗？ | 保留或标记 deprecated |
| 4. 可再生性 | 能否从源码/构建过程重新生成？ | 可再生 → 允许删除 |
| 5. 回滚点 | 删后有没有回退手段？（git history / backup） | 无回滚 → 禁止删除 |
| 6. 替代方案 | 有没有更安全的做法？（禁用/隔离/停用 vs 删除） | 有替代 → 用替代方案 |

**执行规则**：
- 6 维中任何 1 维不通过 → 不执行删除，采用对应动作
- 6 维全部通过 → 走 ClawBin 归档（仍不真删）
- **只有例外列表内的文件**才允许真删（见下方）
- ⛔ 禁止跳过检查直接删除（"我觉得没用了"不是有效理由）
- ⛔ 禁止把"清理"、"整理"、"简化"作为跳过检查的理由

### 两阶段删除流程

```
阶段 1: plan_delete — 输出要删什么、为什么删、6 维检查结果、影响范围、回滚方式
阶段 2: execute_delete — 确认后执行（mv 到 ClawBin / 真删例外项）
```

Agent 自行执行时两阶段在内部完成（不需要人工审批），但**必须在 commit message 或 Hub prompt 中包含 plan_delete 摘要**。

### 方向 B：主动发现过时文件（该删不删的检测）

**🔒 不可变规则**：Agent 在修改/创建/重构文件时，必须顺带审视"周围是否有该清理但没人清理的过时文件"。

**触发时机**（Agent 应主动思考"这个还有用吗"）：

| 场景 | 检查内容 |
|------|----------|
| 创建新文件替代旧文件时 | 旧文件是否应该归档？（如 v2 替代 v1） |
| 修改配置文件时 | 配置中引用的路径/模块是否仍然存在？ |
| 删除或重命名函数/类时 | 是否有其他文件仍在引用旧名？ |
| 升级依赖版本时 | 旧版本的 polyfill/补丁/兼容代码是否可以移除？ |
| 重构目录结构时 | 是否有孤立文件（不被任何入口引用）？ |

**过时判定 5 信号**（满足 2 个以上 → 提议归档）：

1. **被替代** — 存在更新的版本/实现，旧版不再被引用
2. **无入口** — 没有任何文件 import/require/引用它
3. **已废弃标记** — 文件名含 `.bk`、`_legacy`、`_old`、`deprecated`
4. **长期未动** — git log 显示 >6 个月无改动，且不在核心路径上
5. **功能已移除** — 对应的 SSoT feature 已标记 done 但文件仍停留在旧位置

**执行方式**：
- 发现过时文件 → **不自行删除** → 在任务完成报告或 Hub prompt 中列出建议归档清单
- 格式：`[建议归档] {文件路径} — 原因：{哪些过时信号命中}`
- 用户确认后才执行归档（方向 A 的 6 维检查仍然生效）
- ⛔ 禁止发现后不报告（"反正没人提就不管"）
- ⛔ 禁止发现后直接删除（必须报告，让用户确认）

### ClawBin 位置与摆放

- `~/Desktop/ClawBin/` — 统一归档目录（个人临时文件与项目相关归档）
- 技术路线 / Skill 归档：`ClawBin/{路线名}/`
- 项目归档：`ClawBin/{项目名}/`
- 日常临时：`ClawBin/YYYY-MM-DD/{描述}/`
- 文档归档：`ClawBin/{文件名}_legacy.{ext}`
- **归档前**：在 commit message 或 Prompt 中说明归档原因
- **归档后**：不主动清理 ClawBin（由人工定期整理）

## P14. 技术选型时效性

技术选型必须考虑方案的当前活跃度，避免推荐已被社区淘汰的方案。

- **优先最近 1 年内**的方案（发布或重大更新在 1 年以内）
- **"未被淘汰"的判定标准**：在大厂开源项目中仍然可以见到在用 → 未被淘汰；见不到 → 已被淘汰
- 调研时标注技术的发布年份和当前活跃度
- 长期广泛使用的经典路径（如 Git、SQLite、React）不受 1 年限制
- ⛔ 禁止推荐已被社区主流弃用的方案（即使文档还在）

## P15. No Translate（不准翻译用户输入）

**用户发来的信息不准翻译。用户发什么语言，就用什么语言去读。**

- 翻译会造成语义破坏，错别字被掩盖
- 对手写笔记等图片内容，必须走 VLM 直接读取，不走 OCR 再翻译
- Agent 回复语言跟随用户：用户用中文就回中文，用英文就回英文

## P16. No Time Estimate（不写工时估算）

**文档和方案中不写工时估算。** 用户 vibecoding，工时数字没有参考价值。

- Canvas、ROADMAP、方案文档中不出现"工时"、"小时"、"天"等估算列
- 路线图按依赖顺序排列，不按时间估算排列
- 如需表达优先级，用依赖关系和批次编号

## P17. Canvas 使用规范

**内容超过 800 字或包含结构化数据（表格、对比、架构图）时，必须使用 Canvas。**

- Canvas = 独立可查看的分析产出物（不是聊天附件）
- 只能从 `cursor/canvas` 导入组件，不用外部库
- **双通道可达（必须）**：Canvas 只在 IDE 中渲染。当用户通过 Hub Web 交互时，写入 Canvas 后**必须同时按 `pc-solo-web` 向 Hub 发一条 prompt**，包含结构化摘要
- 风格：扁平、极简、有层次感。颜色从 `useHostTheme()` 取，不硬编码 hex
- 交互式双视角模式：需求/方案类文档使用「问题→方案」+「实施路线」双视角切换

## P18. R-ReadDiff-Write（写前读 diff）

**🔒 不可变规则**：Agent 修改文件前必须先读该文件的近期 diff 历史。

```bash
git log --oneline -5 -- <target_file>
git diff HEAD~3 -- <target_file>
```

- 防止覆盖他人近期改动
- 发现近期有他人改动 → 读懂改动意图后再写，不盲写
- 与 SoTADiff 联动：commit 后的三层验证是 R-ReadDiff-Write 的自动化兜底

## P19. 需求一致性报告

任务完成后的报告**必须包含**：

1. **原需求**（用户原文）
2. **原技术路线**（用户原文 + AI 理解）
3. **实际使用的技术路线**（偏离必须说明原因）
4. **技术路线反推** → 实际实现了什么
5. **一致性判定**：✅ 完全一致 / ⚠️ 有合理改进 / ❌ 有偏离
6. **心智走查**：模拟用户流程从头走到尾，至少找出 1 个问题或风险点

## P20. SSoT 文档管理（polaris.json）

每个项目的 **唯一真实来源（Single Source of Truth）** 是项目根目录的 `polaris.json`。

- **格式**: JSON，包含项目元数据、需求列表、功能清单、状态、技术栈、阻塞项
- **Feature status 枚举**: `planned` → `in-progress` → `tested` → `done` | `blocked`（见 P21b）
- **SSoT 引用格式**: `[SSoT:ProjectName/ReqId/FeatureName]` 3 段精确引用到 Feature 级别
- **语言规则**: polaris.json 中面向人的文本**必须使用中文**
- **维护规则**: 项目信息变更时**必须**同步更新 polaris.json
- ⛔ 禁止使用 `_Polarisor/projects.md` 或硬编码 `eco-tree.json` 作为项目信息源（已废弃）

## P21. SSoT 同步强制（每次有效工作后必须更新）

**🔒 不可变规则**：每次有效工作后，Agent **必须**同步更新 polaris.json。

- **何时更新**: 完成 feature → 更新 status；新增功能 → 添加条目；接口/行为变更 → 更新字段
- **何时不更新**: 纯解释/讨论（无代码产出）；调试中间步骤
- **更新方式**: `PATCH /api/polaris/{project_name}`

### P21b. Feature Status 生命周期（写完代码 ≠ done）

**🔒 不可变规则**：Feature 的 status 必须准确反映验证阶段，禁止跳过测试直接标记 done。

**状态转换链**：
```
planned → in-progress → tested → done
                ↓            ↓
              blocked      blocked
```

| 状态 | 含义 | 转入条件 |
|------|------|----------|
| planned | 已规划未开始 | 初始状态 |
| in-progress | 代码编写中 | 开始开发 |
| tested | 代码完成+通过验证 | 通过以下全部验证 |
| done | 确认无问题，可交付 | tested 状态 + 无已知问题 |
| blocked | 发现问题/受阻 | 任何阶段发现问题 |

**验证链（in-progress → tested 必须通过）**：
1. **编译/类型检查**：TypeScript strict 无错误
2. **单文件测试**：修改的文件独立验证功能正确
3. **拉通测试**：与上下游模块联合验证（API 调用链、数据流）
4. **边界测试**：异常输入、空值、超长数据、并发访问
5. **回归确认**：确认未破坏已有功能

**⛔ 禁止**：
- 写完代码直接标 done（必须经过验证链）
- 仅凭"编译通过"就标 done（编译通过 ≠ 功能正确）

### P21c. 问题发现即回退（Bug → blocked）

**🔒 不可变规则**：在任何阶段发现 feature 有问题，**第一时间**将 SSoT 中该 feature 的 status 回退为 `blocked`。

**触发条件**（满足任一即回退）：
- 用户报告该功能有 bug
- 测试发现功能不符合 behavior 描述
- 依赖的其他功能发生变更导致本功能失效
- 生产环境发现问题

**回退操作**：
1. `PATCH /api/polaris/{project}` 将 feature.status 改为 `blocked`
2. 在 feature 中添加 `blockers` 说明问题
3. 通过 Hub Prompt 通知用户

**⛔ 禁止**：
- 发现 bug 后保持 done 状态（"先修再说"）
- 延迟回退（"等确认了再改"）
- 只改代码不改 SSoT 状态

### P21a. SSoT 格式合规自检（更新时自动执行）

**🔒 不可变规则**：Agent 每次打开 polaris.json 准备更新时，**顺手检查并修复**同文件中的格式问题。

**检查项**：
1. **结构化字段**：所有 feature 必须有 `behavior[]`。仅有 `description` 无结构化字段（tech/interfaces/behavior）的 → 自动将 description 拆分为 behavior 数组
2. **contacts 字段**：必须存在 `contacts.last_updated` 和 `contacts.updated_by`
3. **中文规则**：面向人的文本（need/approach/behavior/feature name）必须中文
4. **`_meta` 字段**：必须存在 `_meta.schema_version` 和 `_meta.last_synced_at`（ISO 8601）；缺失则补齐
5. **done → evidence**：`status: "done"` 的 feature 必须有 `evidence[]`（至少一条，含日期和描述）；缺失则根据 git log 补齐

**触发时机**：不需要用户要求。Agent 每次因 P21 触碰 polaris.json 时自动执行。
**范围**：仅修复当前正在编辑的 polaris.json，不跨项目扫描。
**⛔ 禁止**：等用户发现格式问题后再修 — 格式合规是 Agent 的基本卫生习惯。

**跨项目写入保护**：修改**非自己注册项目**的 polaris.json 时，**必须**先调用 `pc_safe_write`（协议 H）申请文件锁。即使只是格式迁移、contacts 更新等"安全"改动，也必须走跨项目写入保护 — 因为 PeerSync 可能在同一时间自动同步同一文件。

## P22. Commit 前覆盖检测（多 Agent 防覆盖）

**🔒 不可变规则**：Agent 在 commit 前必须检测自己的改动是否覆盖了同分支上其他 Agent 的已有代码。

**检测流程**已外置到脚本 `~/.polarcop/core/scripts/pc-precommit-check.sh`，Agent 只需 source 调用。

**规则**：
- **Layer 1 触发**（>20 行删除）→ 必须阅读被删除的代码，确认不是功能覆盖
- **Layer 2 触发**（git log -S 发现已有）→ 对比两个版本，保留更完整的
- 搜索工具报告"不存在"时，**强制执行** `git log -S "关键词"` 确认功能确实从未实现过
- ⛔ 禁止仅凭搜索结果断定功能缺失

## P23. 重要决策交叉验证（先验证再下结论）

**🔒 不可变规则**：Agent 对外部世界做出判断前，必须至少完成一次独立交叉验证。禁止仅凭训练时知识做出关键决策。

### 触发条件（满足任一即触发）

- 选择/推荐模型（LLM、嵌入模型、图像模型等）
- 选择/推荐技术栈、框架、库
- 判断某工具/服务/API 是否可用
- 比较多个方案并推荐
- 涉及价格、性能基准、发布日期、版本号等时效性信息

### 强制动作

1. **联网验证**：触发条件命中时，**必须**先调用 WebSearch 或查阅官方文档/注册表，获取当前信息后再回答
2. **禁止训练知识直决**：⛔ 不得仅凭模型训练数据判断"这个模型很好"或"这个框架推荐使用"
3. **验证结果引用**：回答中必须注明信息来源（URL 或文档路径）

### 名称解析 5 级降级

当用户给出的名称/简称/缩写找不到精确匹配时，**禁止直接宣告不存在**，必须走降级链：

```
Level 1: 精确匹配 — 完全一致的名称
Level 2: 别名表   — 检查已知别名/缩写（如 GPT-4o → gpt-4o-2024-08-06）
Level 3: 部分匹配 — 模糊搜索候选列表（如 "claude" → claude-3.5-sonnet, claude-3-opus...）
Level 4: 外部搜索 — WebSearch 或官方 API/文档查询
Level 5: 候选返回 — 仍不确定时，返回候选清单 + 置信度，让用户选择
```

- ⛔ 禁止在 Level 1 失败后直接退出工作
- ⛔ 禁止输出"模型不存在"、"无法找到"后停止 — 必须走完降级链
- ✅ Level 5 兜底：永远给用户选择权，不替用户做"不存在"的决定

### 技术选型时效性增强（补充 P14）

- 推荐方案时**必须标注**：方案名称、最新版本、最近更新日期、社区活跃度
- 存在多个候选时，以**表格对比**形式展示（名称/版本/更新日期/优劣）
- ⛔ 禁止推荐后不提供任何时效性佐证

## P24. 多 Prompt 独立性原则

编写多个 Prompt 分发给不同 Agent 时，**每个 Prompt 必须完全独立自包含**。

- 每个 Agent 收到的 Prompt 是它唯一的上下文，它不知道其他 Agent 的存在
- ⛔ 禁止出现"同 Prompt 1"、"步骤同上"、"参见 Prompt X"等引用其他 Prompt 的文字
- ⛔ 禁止假设 Agent 看过其他 Prompt 或知道其他 Agent 的工作内容
- ✅ 每个 Prompt 必须包含完整的：目标、输入路径、输出规范、执行步骤、格式要求
- ✅ 重复的内容就全文重复写，不要偷懒缩写

## P25. 规范文档文体（首次阅读可执行）

**🔒 不可变规则**：编写规范/原则/流程类文档时，规则正文必须使用定义式语气，禁止迁移口吻污染执行条款。

- 规则正文优先使用“必须 / 应 / 不得 / 禁止”等约束词，直接陈述当前规则
- ⛔ 禁止在规则正文使用依赖历史语境的措辞（如“不再”“改回”“恢复旧版”“继续沿用旧版”）
- 需要记录历史变化时，必须放入单独“变更说明/迁移说明”段，不得混入规则条款
- 目标是“首次阅读即执行”：读者无需了解旧版本也能准确执行当前规则

## P26. 服务状态诊断优先级（launchd 日志时效性）

launchd 服务的日志文件（`StandardErrorPath` / `StandardOutPath`）采用追加模式，不会自动清理。服务多次重启、代码已修复后，旧错误日志仍存在于文件中，Agent 读取时可能误判当前状态。

### 诊断优先级（从高到低）

Agent 在诊断服务问题时，**必须按以下优先级获取信息**：

1. **实时 API 检查**：通过 HTTP/端口检查服务是否实际运行
   ```bash
   curl -s --max-time 3 "http://127.0.0.1:{port}/health"
   ```
2. **端口 / 进程状态检查**（禁止裸 `lsof` / `kill` / `pkill`）：

   **只读探测（优先）：**

   ```bash
   # PolarPort：注册表 + TCP 占用（无 PID）
   curl -fsS "http://127.0.0.1:11050/api/ports/{port}/status"

   # PolarProcess：单端口监听者 + 归属（替代 lsof -iTCP:PORT）
   curl -fsS "http://127.0.0.1:11055/api/diagnostics/ports/{port}"

   # 多端口批量（替代 for p in …; lsof … 循环）
   curl -fsS "http://127.0.0.1:11055/api/diagnostics/ports-batch?ports={p1},{p2}"

   # 全机 TCP 监听 + 托管归属（替代 lsof -iTCP -sTCP:LISTEN）
   curl -fsS "http://127.0.0.1:11055/api/diagnostics/listening-ports"

   # 按端口反查注册服务
   curl -fsS "http://127.0.0.1:11055/api/services/by-port/{port}"

   # 注册服务视角
   curl -fsS "http://127.0.0.1:11055/api/services/{id}/port-status"

   # 全部注册服务端口冲突
   curl -fsS "http://127.0.0.1:11055/api/diagnostics/port-conflicts"

   # PID 探活（替代 kill -0 + ps -p）
   curl -fsS "http://127.0.0.1:11055/api/diagnostics/process/{pid}"

   # 轮询直到端口空闲（替代 sleep; lsof || echo "port free"）
   curl -fsS -X POST "http://127.0.0.1:11055/api/diagnostics/ports/{port}/wait-free" \
     -H 'Content-Type: application/json' -d '{"timeout_ms":10000}'
   ```

   **受控清理（仅 PolarProcess 托管范围，禁止裸 PID kill）：**

   ```bash
   # 清理本系统托管残留并确认端口空闲（替代 kill PID; sleep; lsof）
   curl -fsS -X POST "http://127.0.0.1:11055/api/diagnostics/ports/{port}/clear-and-verify"

   # 启动前端口卫生
   curl -fsS -X POST "http://127.0.0.1:11055/api/services/{id}/ensure-port-ready"

   # 停止并确认端口释放（替代 stop; sleep; lsof）
   curl -fsS -X POST "http://127.0.0.1:11055/api/services/{id}/stop-and-verify"

   # 端口就绪后重启（替代 kill; sleep; lsof; restart 链）
   curl -fsS -X POST "http://127.0.0.1:11055/api/services/{id}/restart-clean"
   ```

   完整契约见 `Agent_core/.cursor/skills/polar-runtime-governance/references/runtime-contract.md` §4.1。

3. **launchctl 状态**：检查 launchd 服务加载状态
   ```bash
   launchctl list | grep "{label}"
   ```
4. **日志尾部检查**（最低优先级）：仅查看最近 N 行日志，并检查时间戳
   ```bash
   tail -20 /path/to/error.log
   ```

### Hook 常见拦截场景与正确路径

Cursor `polar-runtime-guard` 会拦截含 `kill` / `lsof` / `pkill` / `&` 的复合 shell。策略为 **deny-once-then-ask**：同命令指纹在 TTL（默认 30 分钟）内**首次 `deny`**（硬拒绝 + `agent_message` 促改写，避免失忆后卡在确认弹窗），**再次才 `ask`** 交用户确认例外。以下三类**不在 PolarProcess 管辖范围**，但仍频繁触发 Hook；Agent 须走对应替代路径，禁止在脚本里裸写 `kill`/`lsof`。

#### A. Safari / safaridriver（浏览器驱动，非托管持久服务）

| 被拦模式 | 正确路径 |
|---------|---------|
| `kill $(pgrep -f safaridriver …)` | 若已注册 PolarProcess：按 **service id** 调 `stop`/`restart`；否则用 **bb-browser** skill / Safari MCP 结束会话（勿原样重试被 deny 的 kill；确属例外再说明理由等第二次 ask 放行） |
| `safaridriver --port 4445 &` | 禁止 Agent 后台直启；浏览器自动化走 **bb-browser** skill（Safari + AppleScript）或 Safari MCP |
| `lsof -iTCP:4445` | `curl -fsS http://127.0.0.1:11055/api/diagnostics/ports/4445`（只读） |

#### B. cursor-agent CLI 僵尸（Hub 拉起的一次性进程，非 PolarProcess 托管）

| 被拦模式 | 正确路径 |
|---------|---------|
| `pkill -f "cursor-agent"`（裸写） | 使用 **`Agent_core/scripts/cli-probe.sh`** 或 **`agent-worker.sh`**（Hook 白名单）；Hub `spawn-queue` 也会定期 sweep 孤儿 |
| `kill -0` / `ps -p` 探活 | `curl -fsS http://127.0.0.1:11055/api/diagnostics/process/{pid}` |
| 需要重启 RR 会话 | 走 Hub RR API / `rr-orchestrator` skill，不要 shell 杀 cursor-agent |

#### C. Git 锁文件（文件锁诊断，非端口/进程治理）

| 被拦模式 | 正确路径 |
|---------|---------|
| `lsof .git/index.lock` + `kill` 复合命令 | **禁止**；遵循 P13：先等 git 进程结束，不强制删锁 |
| 只读检查锁是否存在/时效 | `test -f .git/index.lock && stat -f '%Sm %z bytes' .git/index.lock` |
| 是否有 git 在跑 | `pgrep -fl '[g]it'`（单一只读命令，无 kill 复合） |
| 确认为陈旧空锁且无 git 进程 | 可 `rm -f .git/index.lock`（一次性，勿写入 reusable 脚本；参考 `PolarFlow/scripts/knowlever-maintain.sh` 运维模式） |

> **边界**：以上三类若将来注册为 PolarProcess 托管服务（含 `polaris.json` + `POST /api/services/register`），则生命周期回归 PolarProcess API，不再适用本小节例外。

### 日志时效性验证

Agent 读取日志时，**必须检查日志条目的时间戳**：

1. 日志无时间戳 → 在报告中明确说明「日志无时间戳，时效性未知」
2. 最新日志条目时间早于当前时间超过 1 小时 → 在报告中明确说明「日志可能过时」
3. 服务重启后 → 优先使用实时检查验证，而非依赖历史日志

### ⛔ 禁止行为

- ⛔ 禁止仅凭日志文件内容断定服务当前状态
- ⛔ 禁止把日志作为唯一诊断依据
- ⛔ 禁止在实时检查通过后仍报告日志中的旧错误

### 日志清理建议（运维任务）

定期清理 launchd 日志的运维任务应写入对应项目的 `polaris.json` 或 SOTAgent 配置：

```bash
# 清空日志（保留文件）
: > /path/to/service.log

# 或归档后清空
mv /path/to/service.log /path/to/service.log.$(date +%Y%m%d) && touch /path/to/service.log
```

新增 launchd 服务时，应在 plist 中配置日志轮转或使用系统日志（`syslog`）。

## P27. 服务生命周期管理规范（硬约束）

**PolarManager** = **PolarPort** + **PolarProcess** + **PolarBudget**。这是 Polarisor 管理生态项目的「三巨头」：端口、进程生命周期、CPU 预算/护核。PolarPrivate / SOTAgent 是相邻基础设施，不属于 PolarManager。

| 职责 | 唯一权威 | 端口 | SOTAgent 的角色 |
|------|----------|------|----------------|
| 端口分配 | **PolarPort**（PolarManager） | :11050 | 无（仅 console 展示） |
| 进程启/停/重启/守护 | **PolarProcess**（PolarManager） | :11055 | 无（`/api/services/*` 仅 facade 透传到 PolarProcess） |
| CPU 预算 / lease / QoS 降级 | **PolarBudget**（PolarManager） | :11060 | 无 |

SOTAgent **只提供前端面板**（console :4880）方便用户查看，不是操作权威。所有服务的启/停/重启**必须**经过 PolarProcess，所有端口**必须**经过 PolarPort 分配，本地 CPU 密集并行**必须**经 PolarBudget（不可用时 fail-open 并标注 `budget_unavailable`）；禁止直接对进程发送 `kill`/`pkill`/`SIGTERM` 信号，禁止硬编码端口，禁止自建第二套 CPU 调度器。

### 唯一合法操作路径

| 优先级 | 路径 | 适用范围 |
|--------|------|----------|
| 1（最高） | PolarProcess HTTP API | 所有托管服务（auto_start 或手动注册） |
| 2 | `Start/*.sh` 脚本（项目内，内部走 `claim_port`） | 局部编排存在时优先于默认 spawn |
| 兼容 | SOTAgent `/api/services/*`（facade） | 仅历史调用方；最终仍转发 PolarProcess，新代码勿用 |

**PolarProcess HTTP API**：

```bash
# 生命周期
POST http://127.0.0.1:11055/api/services/:id/stop
POST http://127.0.0.1:11055/api/services/:id/start
POST http://127.0.0.1:11055/api/services/:id/restart
POST http://127.0.0.1:11055/api/services/:id/stop-and-verify      # stop + 确认端口释放
POST http://127.0.0.1:11055/api/services/:id/restart-clean         # ensure-port-ready + restart
POST http://127.0.0.1:11055/api/services/:id/ensure-port-ready

# 查询
GET  http://127.0.0.1:11055/api/services
GET  http://127.0.0.1:11055/api/services/by-port/:port

# 诊断（安全替代 lsof/kill，详见 P26 §Hook 常见拦截场景）
GET  http://127.0.0.1:11055/api/diagnostics/ports/:port
GET  http://127.0.0.1:11055/api/diagnostics/ports-batch?ports=…
GET  http://127.0.0.1:11055/api/diagnostics/listening-ports
GET  http://127.0.0.1:11055/api/diagnostics/port-conflicts
GET  http://127.0.0.1:11055/api/diagnostics/process/:pid
POST http://127.0.0.1:11055/api/diagnostics/ports/:port/wait-free
POST http://127.0.0.1:11055/api/diagnostics/ports/:port/clear-own
POST http://127.0.0.1:11055/api/diagnostics/ports/:port/clear-and-verify
```

**端口分配**（真实存在的两个入口，二选一）：

```bash
# Shell：Agent_core 共享脚本（Start/start.sh 标准写法）
source Agent_core/scripts/port-claim.sh
PORT=$(claim_port "my-service" "MyProject" 4880)   # preferred 必须以 0/5 结尾
```

```typescript
// TypeScript：PolarPort SDK（内置 30s 心跳）
import { claimPort, releasePort } from 'PolarPort/src/sdk/index.js';
const port = await claimPort({ service: 'my-service', project: 'MyProject', preferred: 4880, heartbeat: true });
```

### ⛔ 禁止行为

- **禁止**用 `kill -9`、`pkill -f`、`killall` 停止托管服务
- **禁止**手动 `kill -SIGTERM <pid>` 停止非自身拥有的进程
- **禁止**绕过 PolarProcess 直接用 `node &` / `npm start &` 等方式重启服务
- **禁止**在服务注册的 `command` 字段或代码中硬编码端口——一律 `claim_port` 动态取得
- **禁止**分配不以 0/5 结尾的 preferred 端口（PolarPort 合规规则，范围 8000–19999）
- **禁止**在不了解后果的情况下重启 PolarProcess / PolarPort（守护与端口注册随之中断）

### auto_start 服务行为约定

- `auto_start: true` 的服务由 PolarProcess Watchdog 自动管理（30s 健康检查，读各项目 `polaris.json` 的 `service_management.health_endpoint`），正常情况下不需人工干预
- 服务崩溃后自动重试；crash loop（5 分钟内 ≥10 次重启）检测后停止机械重启，升级为 SOTAgent 告警等待人工/Agent 介入
- **`polaris.json` 的 `health_endpoint` 必须与服务实际监听端口一致**——Watchdog 以它为准，写错会导致健康误判与反复重启
- 确需人工介入时，**必须**通过 PolarProcess API 操作，禁止直接杀进程

### 服务失控时的紧急处置（例外，不是规范）

当服务行为异常且 PolarProcess API 也不响应时：

1. 通过项目自身 `Start/start.sh stop` 停止目标服务
2. 仍无效则手动清理残余进程：`pkill -f "<service_name>"`（这是紧急例外，不应写入脚本）
3. 重启 PolarProcess（`bash PolarProcess/Start/start.sh restart`）
4. 通过 PolarProcess API 重新启动各服务

### 为什么禁止直接 kill 进程？

直接 `kill`/`pkill` 会绕过 PolarProcess 的状态记录，导致：

- `shared_services.status` 与实际进程状态不一致
- Watchdog 误判服务已崩溃并尝试重启（双重拉起）
- `restart_count` 配额被错误消耗
- 端口未 release，PolarPort registry 残留 stale 记录

### 本地自主 Agent 的最小挂载片段

非 pc 系的本地自主 Agent（不加载 Agent_core 全量规则）**必须**在其系统提示或 skill 中挂载 `Agent_core/reference/SERVICE-PORT-MINIMAL.md`，该片段是本原则的最小可执行子集。

---

## P28. P-REFLEX（反身性原则：断言必引证、SSoT 优先）

Agent 的诊断和分析能力受限于其推理链质量。本原则强制要求 Agent 在做出事实断言时提供可验证证据，防止"看起来正确但实际错误"的幻觉性诊断。

### 核心规则

1. **断言必引证**：Agent 对代码/系统状态的任何事实性断言，必须附带可验证的证据来源：
   - 代码断言 → `[文件: path/to/file.ts:行号]`，且行号必须来自当前读取结果
   - 功能断言 → `[SSoT: project/polaris.json → feature.status]`
   - 接口断言 → `[API: 端点 + 请求/响应示例]`
   - ⛔ 禁止"据我所知""应该是""大概在第 X 行"等未经验证的断言

2. **polaris.json 优先**：在判断某个功能/特性的状态时，必须优先查阅目标项目的 `polaris.json`：
   - polaris.json 说 `done` + 代码确认存在 → 断言该功能已完成
   - polaris.json 说 `in_progress` → 不得断言"已完成"，除非同时更新 SSoT
   - polaris.json 不存在该功能 → 明确标注"SSoT 未记录"

3. **交叉验证**：当结论涉及多个证据源（代码、文档、SSoT、用户陈述）时，必须检查一致性：
   - 不一致 → 在报告中显式标注矛盾点
   - 一致 → 标注为"交叉验证通过"

4. **不确定性标注**：当证据不充分时，必须在结论前标注置信度：
   - `[确定]` — 直接从代码/SSoT 读取，可验证
   - `[高概率]` — 多个间接证据一致，但未直接验证
   - `[推测]` — 基于模式匹配或训练知识，需进一步确认

### 触发场景

- 编写调研报告时（格式 B）
- 编译任务书的 verify codebase 阶段
- 诊断 bug 或系统状态时
- 回答用户关于项目状态的提问时

### 背景

本原则源自反身性探查（2026-05-18），发现 Agent 自诊断准确率约 67%，主要失败模式为：行号漂移（记忆模糊的行号代替实际读取）、特征遗漏（读代码不够彻底就下结论）、过强断言（将推测表述为事实）。

