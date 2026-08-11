# 两层计费模型架构

Polarisor 的 LLM 调用链路涉及两个独立的计费层。每层有不同的"一次消费"单位，需在 Prompt 设计和调用策略上分别优化。

## 第一层：Cursor 层（一轮对话 = 一次消费）

### 计费单位
一问一答（用户发一条消息 → Agent 返回一条完整回复）即为一次消费。无论 Agent 内部调用了多少工具、读了多少文件、执行了多少 Shell 命令，均计为一次。

### 覆盖范围
- Cursor IDE（Claude Code 模式）
- PolarCopilot（IDE Agent）

注意：VSCode（Claude Code）与 Cursor IDE 在计费上是同一层——都消耗 Cursor 配额。

### PolarClaw 一体两面架构（已退役）
> PolarClaw 已于 2026-08-11 退役（见根仓 `ARCHIVED.md`），本节保留作为双入口计费的设计参考，不再描述现行链路。

PolarClaw 有两个入口，但共享同一个 LLM Proxy：
- **飞书入口**：面向产品经理，提供自然语言交互
- **IDE 插件入口**：面向开发者，提供代码辅助

两个入口的计费模型相同（均为 Cursor 层配额），但 Prompt 策略可不同。

### 优化策略
- **"一问一答即是所有"**：在一次 Agent turn 中尽可能完成更多工作
- 避免无意义的确认轮次（"我来帮你看看" → 直接执行）
- 批量执行：多个独立操作合并到一次 turn
- 使用 YOLO 模式减少人工确认循环

## 第二层：LLM Proxy 层（一次 API 调用 = 一次消费）

### 计费单位
一次 HTTP API 调用即为一次消费。通过 PolarPrivate Proxy 转发到上游 LLM 服务（阿里云 CodingPlan / 天翼云息壤 / MiniMax 等）。

### 覆盖范围
- PolarPrivate `/proxy/llm.*` 路由转发的所有请求
- KnowLever RAG 的 LLM 调用
- DiGist 摘要生成的 LLM 调用
- AutoOffice 报告生成的 LLM 调用

### 优化策略
- **"每次调用作用最大化"**：减少调用次数，提高单次调用信息密度
- Prompt 压缩：PolarPrivate R8 自动截断超长上下文
- 结果缓存：相同输入避免重复调用
- 模型选择：任务匹配模型能力，不为简单任务使用大模型
- batch 合并：多个小请求合并为一次批量调用

## 两层独立但串联

```
用户 → [Cursor层: 一轮对话] → Agent → [Proxy层: N次API调用] → LLM
         计费单位: 1次                    计费单位: N次
```

一次 Cursor 层消费可能触发 0~N 次 Proxy 层消费。优化目标是在两层各自最小化消费次数。

## 注意事项

- 这是两层而非三层：不存在独立于 Cursor 和 Proxy 的中间层
- 各项目的 `binding.md` 中应包含本项目的计费优化策略
- CodingPlan 类渠道（阿里云/天翼云）有额外使用约束（仅限 AI 编程工具内使用）
