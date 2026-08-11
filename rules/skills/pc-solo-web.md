---
id: skill-pc-solo-web
level: skill
always: false
triggers: []
priority: 10
invocation: explicit
covers:
  - "pc-solo-web"
  - "Hub MCP"
---
# Skill：PolarCopilot Solo Web 模式

> 技能层规则：**仅在被显式调用时注入**（如 Planner 节点选择 skill_id，或 Agent 主动 read skill 文件）。
> 不通过用户消息正则自动触发。

## 何时调用

- 用户触发 `$pc-solo-web`、Hub Web 单 Agent 模式
- 需要通过 `hub-agent-N` MCP 与 Hub 长轮询通信

## 核心约束

1. ✅ 鼓励 SubAgent / Cursor Task（P12）：分析调研用 `cursor-grok-4.5-high-fast`，编码用 `composer-2.5-fast`；Hub 交互与验收不下放
2. `setup({})` 只注册 Agent，不创建首条 prompt；**setup 后 `hub_status`**
3. **Turn 结束**才 `send_prompt` + `check_hub`（§0.4 对齐/调研/执行/阻塞；禁止干活中途发 Hub）
4. `send_prompt` 409 → 只 `check_hub`，禁止只回 Cursor（§0.5）
5. 完成有效任务后 commit+push（协议 C）

## 信源

完整流程见 `PolarCopilot/.cursor/skills/pc-solo-web/SKILL.md`。
