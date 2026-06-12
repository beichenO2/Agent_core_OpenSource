---
id: protocols/ssot
level: protocol
triggers:
  - "\\bSSoT\\b"
  - "polaris\\.json"
  - "up to date"
  - "Up to date"
  - "生态地图"
  - "feature"
  - "需求"
  - "未完成"
  - "PolarSkills"
  - "worker\\.md"
  - "PolarSoul"
  - "六件"
priority: 10
---

# 协议：SSoT 文档系统

## 核心规则

1. 每个项目以 `polaris.json` 为**当前状态**唯一信源（正在发生什么 + 正在进行的工作 + 马上要做的任务）。
2. 修改功能后**必须**同步更新对应 feature 的 `status` + `evidence`。
3. 完成任务后必须更新 `polaris.json`，git commit + push。

## 六件套结构（每个项目必须有）

```
<ProjectRoot>/
├── PolarSoul.md        # 灵魂：我是谁、生态位
├── polaris.json        # 当前状态 SSoT（含 _meta.last_synced_at）
├── worker.md           # Agent 身份与工作模式
├── roadmap.md          # 需求规划（暂不做的放这里）
├── decisions/          # ADR 架构决策记录
└── PolarSkills/        # 技能文档（给所有 Agent 看）
    └── <name>-ops/
        ├── SKILL.md          # 如何使用
        ├── DEPLOY.md         # 如何部署
        └── TROUBLESHOOT.md   # 如何 debug
```

## Agent 工作流

1. 被分配到项目 → 读 `worker.md`
2. 了解项目 → 读 `PolarSoul.md`
3. 找活干 → 读 `polaris.json`（马上要做的） → `roadmap.md`（更远的）
4. 做决策 → 查 `decisions/`
5. 用项目能力 → 读 `PolarSkills/<name>/SKILL.md`
6. 完成任务 → 更新 `polaris.json`，git commit + push

## polaris.json 字段要求

- `_meta.last_synced_at`：最后同步时间（ISO 8601），每次 commit 自动更新
- `features[].status`：done / in-progress / blocked
- `features[].evidence`：status=done 时**必须**有（git hash、测试记录等）
- `features[].test_status`：passed / failed / not_tested / stub

## 一致性检查（自动执行）

| 层级 | 时机 | 行为 |
|------|------|------|
| L1 | git commit | 非阻塞警告 + auto update `_meta.last_synced_at` |
| L2 | PR merge | 阻塞：freshness > 7d / done 无 evidence / 六件套缺失 |
| L3 | 每日 9:00 | 全库 drift 巡检，报告到日志 |

## 详细规范

→ `Agent_core/principles/SSOT-DOCS.md`
→ `Agent_core/principles/SSOT-CONSISTENCY.md`
