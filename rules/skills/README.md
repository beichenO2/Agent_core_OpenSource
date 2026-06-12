# Skills 层（显式调用）

与 **norms/**（全量注入）和 **protocols/**（正则触发）不同，本目录规则**不会**因用户消息自动注入。

## 调用方式

| 消费端 | 机制 |
|--------|------|
| Cursor Agent | 用户或路由 Skill 指向 `read SKILL.md` |
| PolarUI Planner | 节点参数 `skill_id` → `selectSkill(id)` |
| PolarClaw | adapter 按需拉取 |
| trigger-engine | `selectSkill('skill-pc-solo-web')` |

## 文件格式

与 protocols 相同 YAML frontmatter + Markdown，但 `level: skill` 且 `invocation: explicit`。

## 当前条目

- `pc-solo-web.md` — Hub Web Solo Agent 模式摘要
