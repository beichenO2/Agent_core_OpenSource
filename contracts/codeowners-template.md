# CODEOWNERS 模板 — 沙箱内 / 沙箱外 写权限分发

> 每个被托管项目必须在项目根目录创建 `CODEOWNERS` 文件，按以下模板修改后使用。
> 模板中的 `@<project-owner-agent>` 替换为项目实际负责 Agent 标识。

```text
# CODEOWNERS — 沙箱内 / 沙箱外 写权限分发

# 默认（沙箱内）：仅项目负责 Agent
*                       @<project-owner-agent>

# 沙箱外：所有 Agent 可读写
/sandbox-external/      @<project-owner-agent> @other-agents
/contracts/             @<project-owner-agent> @other-agents
/adapters/              @<project-owner-agent> @other-agents
/tests/contracts/       @<project-owner-agent> @other-agents

# 项目龙虾目录：PolarPilot 写
/lobster/               @polarpilot-agent
```

## 使用说明

1. 将模板内容复制到项目根目录的 `CODEOWNERS` 文件中。
2. 把 `@<project-owner-agent>` 替换为本项目负责 Agent 的标识（如 `@knowlever-agent`）。
3. 如果项目使用 `src/` 而非 `sandbox-internal/` 作为沙箱内根目录，默认规则（`*`）已覆盖，无需额外配置。
4. 如果项目有额外的沙箱外目录（如 `项目字典/`），按相同格式追加。
