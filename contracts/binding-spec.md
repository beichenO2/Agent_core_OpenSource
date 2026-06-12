# binding.md 文件规范

每个参与 Prompt 工程的项目应在根目录放置 `binding.md` 文件，记录该项目的 Prompt 策略和已验证决策。

## 必含项

### 1. 核心主张 (Core Claims)
项目在 Prompt 工程上的核心立场。例如：
- "PolarClaw 的 Prompt 应区分飞书入口和 IDE 入口"
- "KnowLever 的检索增强应在 Proxy 层之前完成"

### 2. 策略摘要 (Strategy Summary)
当前采用的 Prompt 策略及其理由。包含但不限于：
- system prompt 的分层结构
- 上下文窗口管理方式
- 角色策略 vs 安全策略的边界划分
- 计费层优化的具体做法

### 3. 已验证决策 (Verified Decisions)
经过实际验证的 Prompt 决策，标注验证日期和结果。例如：
- "2026-05-01: 将安全约束从 PolarClaw 移到 PolarPrivate Proxy 层 → 减少 30% 重复 token"
- "2026-04-28: 飞书入口使用简化 system prompt → 用户满意度提升"

## 不包含

- 具体 prompt 文本（那是项目内部实现细节）
- 模型参数配置（属于运行时配置）
- API Key 或密钥相关信息

## 文件位置

放在项目根目录：`{project}/binding.md`

## 使用方式

开发者在进行 Prompt 工程相关开发时：
1. 读取本项目的 `binding.md` 了解当前策略
2. 查阅关联项目的 `binding.md` 获取灵感
3. 手动决定是否采纳其他项目的做法
4. 将新决策记录到本项目的 `binding.md`

binding.md 是人类协作工具，不是自动化配置文件。
