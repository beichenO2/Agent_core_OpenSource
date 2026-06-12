# W-PROMPT-1: Prompt 工程跨项目协作规则

## 规则内容

PolarClaw、PolarCopilot、PolarPilot 三个"开发者"项目在进行 Prompt 工程相关开发时，**必须在开始前读取本项目及关联项目的 `binding.md`**。

## 适用范围

- 修改或新增 system prompt
- 调整上下文窗口策略
- 变更角色策略或安全策略边界
- 优化计费层 Prompt 结构

## 执行步骤

1. 读取本项目的 `binding.md`，了解当前策略
2. 读取 PolarPrivate 的 `binding.md`，了解 Proxy 层的安全底线和 `append_system_prompt` 机制
3. 根据关联关系，读取相关项目的 `binding.md`（如 PolarClaw ↔ PolarCopilot ↔ PolarPilot）
4. 在开发过程中，将新决策记录到本项目的 `binding.md`

## 关联项目矩阵

| 项目 | 必读 binding.md | 原因 |
|------|----------------|------|
| PolarClaw | PolarPrivate, PolarCopilot | 共享 LLM Proxy，入口策略互补 |
| PolarCopilot | PolarPrivate, PolarClaw | IDE Agent 依赖 Proxy 安全层 |
| PolarPilot | PolarPrivate | 思考模板影响 Prompt 结构 |

## binding.md 规范

参见 [Agent_core:contracts/binding-spec.md](../contracts/binding-spec.md)。
