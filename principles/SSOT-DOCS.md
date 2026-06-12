# SSOT 文档系统规范

> 本规范定义 Polarisor 生态中每个项目必须维护的文档结构。
> 所有文件都是给 Agent 看的，人不直接参与修订。Agent 通过 git 分支提交改动。

## 文件结构

```
<ProjectRoot>/
├── PolarSoul.md              # 灵魂：我是谁、生态位置、能接入什么
├── polaris.json              # 当前状态 SSoT
├── worker.md                 # 负责 Agent：谁干活、怎么干
├── roadmap.md                # 需求 + 规划：下一步干什么
├── decisions/                # 为什么：ADR 架构决策记录
│   ├── 001-xxx.md
│   └── ...
└── PolarSkills/              # 技能文档（给所有 Agent 看）
    └── <skill-name>/
        ├── SKILL.md              # 如何使用
        ├── DEPLOY.md             # 如何部署
        └── TROUBLESHOOT.md       # 如何 debug
```

## 各文件职责

### `PolarSoul.md` — 项目灵魂

**读者**：其它项目的 Agent 想了解我时读这个。

内容：
- 项目定位和核心价值（一句话说清楚）
- 生态位置（跟谁协作、被谁依赖）
- 接口约定（端口、协议、能力摘要）
- 数据边界（管什么数据、不管什么）

**约束**：Agent 可在生态变更时更新接口约定部分。

### `polaris.json` — 当前状态 SSoT

**定义**：正在发生什么。

包含三层：
1. **现在状态**：各特性当前状态（done / in-progress / blocked）、服务健康
2. **正在进行的工作**：当前活跃任务、进行中的分支
3. **马上要做的任务**：即将执行、已确认要做的（从 roadmap 提升上来的）

**不包含**：
- 暂时不做的 → 放 `roadmap.md`
- 长远规划 → 放 `roadmap.md`
- 历史决策 → 放 `decisions/`

**建议字段**：
```json
{
  "name": "ProjectName",
  "status": "active",
  "health": { "last_deploy_at": "...", "uptime": "..." },
  "active_work": [...],
  "next_up": [...],
  "features": [...],
  "requirements": [...]
}
```

**约束**：Agent 每次完成任务必须同步更新。

### `worker.md` — 负责 Agent

**读者**：被分配到这个项目的 Agent 首先读这个。

内容：
- Agent 身份定义（我是这个项目的谁）
- 工作模式（怎么干：流程、偏好、风格）
- 行为规则（什么不能做）
- 工作范围（可以改什么、协作关系）

### `roadmap.md` — 需求 + 规划

**定义**：下一步干什么（Agent 挑任务从这里拿）。

内容：
- 里程碑（有明确完成条件的阶段目标）
- 待做事项（按优先级排序）
- 依赖关系（什么阻塞什么）

**与 polaris.json 的关系**：
- roadmap 中的事项被确认要做 → 提升到 `polaris.json.next_up`
- `polaris.json.next_up` 开始执行 → 移到 `polaris.json.active_work`
- `active_work` 完成 → 更新 features 状态

### `decisions/` — ADR 架构决策

**格式**：每个决策一个文件，编号递增。

```markdown
# ADR-NNN: 标题

## 状态
accepted / deprecated / superseded by ADR-XXX

## 背景
为什么要做这个决策

## 方案
考虑过哪些选择

## 决定
最终选了什么

## 后果
这个决定带来什么影响
```

### `PolarSkills/` — 技能文档

**定位**：独立目录（不是 `.cursor/skills/`），给所有 Agent 用。

Agent 接入一个项目时的指令：
> "用这个项目前先读 `PolarSkills/` 目录"

三维文档：
| 文件 | 场景 | 读者 |
|------|------|------|
| `SKILL.md` | 如何使用 | 其它 Agent 来了直接用 |
| `DEPLOY.md` | 如何部署 | 一开始 README 引用 |
| `TROUBLESHOOT.md` | 如何 debug | 有 bug 了看这里 |

## Agent 工作流

1. Agent 被分配到项目 → 读 `worker.md`（我怎么工作）
2. 需要了解项目 → 读 `PolarSoul.md`（这是什么）
3. 找活干 → 读 `polaris.json`（马上要做的） → `roadmap.md`（更远的）
4. 做决策 → 查 `decisions/`（前人怎么决定的）
5. 用项目能力 → 读 `PolarSkills/<name>/SKILL.md`
6. 完成任务 → 更新 `polaris.json`，git commit + push

## Git 策略

- 所有文档改动走 Agent 分支 → PR → 合并
- `polaris.json` 更新频率最高（每次任务完成）
- `PolarSoul.md` 变更需要生态影响评估
- `decisions/` 只追加不修改（deprecated 标记旧的）

## 合规检查

SOTAgent 定期扫描各项目：
- ✅ 是否存在全部必需文件
- ✅ `polaris.json` 是否过期（最后更新 > 7 天告警）
- ✅ `PolarSkills/` 三维文档是否完整
- ✅ 活跃项目是否有 `worker.md`
