# Polarisor 术语表（GLOSSARY）

> Agent 在理解用户指令和生成报告时，必须参考本术语表。
> 语音输入、LLM 理解偏差、翻译器误译是三大歧义来源。
>
> **使用规则**：
> 1. 遇到用户消息中的模糊/易错词汇时，先查本表确认语义
> 2. Agent 自身输出中也必须使用本表定义的规范名称
> 3. 新增条目时在 `§3 易错词库` 中追加，无需修改其他文件

---

## §1 核心概念定义（防歧义）

| 术语 | 英文 | 准确定义 | 常见误区 |
|------|------|---------|---------|
| **生态 (Ecosystem)** | Polarisor Ecosystem | 指 `~/Polarisor` 根目录及其包含的所有子项目集合 | Agent 常将其误解为外部宏观环境或抽象概念；必须关联至具体代码库路径 |
| **SSoT** | Single Source of Truth | 每个项目根目录的 `polaris.json` 文件，记录项目状态/需求/特性 | 不是泛指"唯一数据源"概念，特指 polaris.json |
| **编译** | Compilation | 将规划期任务书重构为可执行任务包的过程（编译规范.md 定义） | 不是代码编译（tsc/gcc），是文档结构重构 |
| **Hub** | PolarCopilot Hub | PolarCopilot 的 Web UI + API 层，运行在 `~/.polarcop/core`，端口通常 8040 | 不是 GitHub Hub 也不是 Docker Hub |
| **Skill** | Agent Skill | Agent 的可执行能力包（`.cursor/skills/` 下的 SKILL.md 文件） | 不是抽象的"技能"，是具体的文件+流程定义 |
| **MCP** | Model Context Protocol | Cursor IDE 与外部工具的通信协议，Hub 通过 MCP Server 暴露工具 | 不是"消息控制协议"或其他缩写 |
| **YOLO** | You Only Live Once (执行模式) | 全自动执行模式：三维对齐 → 计划 → 自动执行 → 验收 | 不是"随意执行"，有严格的对齐和验收流程 |
| **ClawBin** | PolarClaw Recycle Bin | Agent 删除文件时的回收站（`mv` 到指定目录而非 `rm`） | 不是系统垃圾箱，是 Agent 专用归档区 |
| **检修 Agent** | `@checkup-agent` | 全生态唯一检修事件消费者 ID（`Agent_core/contracts/checkup-agent.id`）；Widget 提交固定路由，不绑定 solo-web session uuid | 不是项目 owner Agent，不是 Cursor 聊天窗口 ID |

---

## §1b 操作词典

| 术语 | 准确定义 | 在 PolarUI 中的对应 |
|------|---------|-------------------|
| **生态** | Polarisor 根目录及所有子项目的集合 | 生态地图 / 健康面板 |
| **原子化** | 复杂功能分解为最小可独立执行的正则化元件 | `node-defs` 各节点 |
| **Agentic 组件** | 工作层 + 核验层 + 重试循环的自主单元 | AgenticUnit / 复合 Pipeline |
| **编译** | 任务书重构为可执行任务包（非 tsc/gcc） | KnowLever / DIGiST 编译管线 |
| **万件归一** | 用 PolarUI 工作流管理各类任务 | 工作流模式 |
| **正则化** | 一输入一输出的机械化元件 | LLM/Control/Input/Output/Transform |
| **画中画** | 工作流内嵌可编辑子工作流容器 | WorkflowMeta 节点 |
| **接地点** | 多个 Output 并联汇聚语义等价输出 | 多 Output + `merge_strategy` |

---

## §1c 技术栈映射表

| 术语 | 生态内含义 | 运行位置 | 成本属性 | 调用方式 |
|------|-----------|---------|---------|---------|
| **LLM** | PolarPrivate `/v1` 大模型 API | 云端 Provider | 按次计费 | capability + LLM Proxy |
| **VLM** | 本地 Ollama 视觉语言模型 | 本机 Ollama | 零边际成本 | REST / CLI |
| **ASR** | 本地语音识别 | 本机 | 零边际成本 | 本地 API |
| **Embedding** | 向量嵌入 | 云端或本机 | 低 | KnowLever 内部 |
| **TTS** | 文字转语音 | 待定 | — | 待定 |

---

## §2 项目名称对照表

> 每个项目的规范名称、简称和语音输入常见误识别。

| 规范名称 | 简称 | 角色 | 语音常见误识别 |
|---------|------|------|--------------|
| **PolarClaw** | Claw | Agent 操作系统：会话管理/ReAct/多通道 | polar cloud, polar claw, 波拉克劳 |
| **PolarCopilot** | Copilot | IDE Agent 框架：Hub Web + MCP + Skill | polar copilot, 副驾驶 |
| **polarcop-vscode** | VSCode 插件 | PolarCopilot 的 VSCode/Cursor 扩展 | polarclaw-vscode（旧名） |
| **SOTAgent** | SOT | 服务守护进程：启停/健康/监控 | sot agent, 搜特 |
| **KnowLever** | KL | 知识编译与检索 | know lever, 知识杠杆, knowledge lever |
| **PolarPilot** | Pilot | 自主规划-执行引擎 | polar pilot, 飞行员 |
| **PolarPrivate** | Private | 密钥代理与 LLM Proxy | polar private, 私有的 |
| **PolarMemory** | Memory | 语义记忆系统 | polar memory, 记忆 |
| **PolarDesign** | Design | 设计系统（Linear 风格 UI Kit） | polar design |
| **AutoOffice** | AO | 多格式报告生成 | auto office, 自动办公 |
| **digist** | — | 信息摄取引擎（爬取+消化） | digest, 数字的, digitst |
| **Clock** | — | 番茄钟 + 信息流 | clock, 时钟 |
| **tqsdk** | — | 量化交易 SDK | TQ SDK, 天勤 |
| **PolarPort** | Port | 端口分配管理 | polar port |
| **PolarSync** | Sync | 设备同步 | polar sync |
| **PolarProcess** | Process | 进程管理 | polar process |
| **Agent_core** | Core | 共享准则/协议/工作流/脚本 | agent core |
| **Polarisor** | — | 生态根仓库（包含所有子项目作为 submodule） | polarizer, 偏振器 |

---

## §3 语音输入 / LLM 易错词库

> 用户使用语音输入时，翻译器经常将专有名词识别为同音/近音的其他词。
> Agent 遇到这些词时应自动修正为正确术语。

| 用户可能说的 / 语音识别结果 | 正确含义 | 说明 |
|--------------------------|---------|------|
| polar cloud | **PolarClaw** | 语音最常见误识别 |
| polarclaw-vscode | **polarcop-vscode** | 旧名残留，项目已重命名 |
| 波拉 | **Polar-** 系列项目 | 中文语音识别 |
| 搜特 | **SOTAgent** | 中文语音识别 |
| 副驾驶 | **PolarCopilot** | 中文直译 |
| 飞行员 | **PolarPilot** | 中文直译 |
| 知识杠杆 | **KnowLever** | 中文直译 |
| 数字的 / digest | **digist** | 拼写近似，注意 digist 不是 digest |
| 天勤 | **tqsdk** | 天勤量化 SDK |
| 生态 | **Polarisor 根目录** | 参见 §1 核心概念 |
| 编译 | **任务书编译**（非代码编译） | 上下文含"任务/规划"时按此理解 |
| hub | **PolarCopilot Hub**（非 GitHub） | 上下文含"Agent/prompt"时按此理解 |
| 灵魂文件 | **PolarSoul.md** | 生态自我描述文件 |
| No Liver / know liver / 诺利弗 | **KnowLever** | 最高频误识别之一 |
| Digist / digital | **digist** | digist ≠ digest |
| Agentic / agentick | **Agentic**（工作层+核验层） | 专有形容词 |
| Polarizer / polariser | **Polarisor** | 生态仓库名 |
| polar sync / 泼了 sink | **PolarSync** | 跨设备同步 |
| polar process | **PolarProcess** | 进程管理 |
| polar pilot | **PolarPilot** | 自主规划 |
| polar ops | **PolarOps** | 运维监控 |
| polar design | **PolarDesign** | 设计系统 |
| polar memory | **PolarMemory** | 语义记忆 |
| polar port | **PolarPort** | 端口分配 |
| 编译管线 | **KnowLever 编译管道** | 7 阶段知识编译 |
| 画中画 | **WorkflowMeta** | 工作流自修改容器 |
| 资金化 | **CostTracker** | 成本追踪组件 |
| 接地 / ground | **多 Output 接地点** | 非电气接地 |
| 触发 / trigger | **规则正则触发** | `Agent_core/rules` |
| solo web | **pc-solo-web** | Hub Web 模式 |
| 灵魂 / soul | **PolarSoul.md** | 系统自我描述 |
| 万件归一 | **PolarUI 工作流管理一切** | 设计理念 |
| lobster / 龙虾 | **PolarPilot lobster 事件总线** | `lobster-events.jsonl` |
| open claw / openclaw | **PolarClaw** | Agent 操作系统 |
| auto office / 自动办公 | **AutoOffice** | 多格式报告生成 |
| polar ui / 波了 UI | **PolarUI** | 元件化工作流编辑器 |
| 正则化 | **一输入一输出基础元件** | LLM/Control/Input/Output/Transform |
| 原子化 | **不可再分的 API 卡片** | Agentic 除外 |
| agent take | **预组装 Agent 入口** | IDEAgent / WebAgent |
| content render | **ContentRender** | 取代 ReportGenerator |
| master / slave | **Master/Slave 角色协议** | R7 role-protocol |
| 接地点 | **多 Output 语义汇聚** | merge_strategy 合并 |
| picture in picture | **WorkflowMeta 画中画** | 沙箱自修改工作流 |
| SOT / sot agent | **SOTAgent** | 守护进程（非 Source of Truth） |
| polar copilot hub | **PolarCopilot Hub** | Web Agent 面板 |

---

## §4 缩写速查

| 缩写 | 全称 | 上下文 |
|------|------|--------|
| SSoT | Single Source of Truth | polaris.json |
| SSE | Server-Sent Events | PolarClaw → 前端的流式通信 |
| GFM | GitHub Flavored Markdown | 表格/删除线/任务列表支持 |
| ReAct | Reason + Act | PolarClaw 的 Agent 执行框架 |
| DAG | Directed Acyclic Graph | 任务依赖图 |
| MCP | Model Context Protocol | Cursor IDE ↔ 外部工具通信 |
| LLM | Large Language Model | 各 AI 模型的统称 |
| VLM | Vision Language Model | 视觉语言模型 |
| RAG | Retrieval-Augmented Generation | 检索增强生成 |

---

## 维护说明

- 新增术语：直接在对应 section 追加行
- 所有 Agent 在发现新的"语音误识别→正确含义"映射时，应在 §3 追加
- 本文件由 Agent_core 管理，修改后需 commit + push
