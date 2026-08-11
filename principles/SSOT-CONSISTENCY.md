# SSOT 一致性机制设计

> 解决问题：SSOT 文档系统的长链路中，任何一环遗漏更新都可能导致
> Agent 认知与代码实际不一致。本文件定义自动检测 + 自愈策略。

## 问题模型

```
链路：PolarSkills/SOUL.md → Agent system prompt → Agent 行为 → 代码改动 → polaris.json
       ↑                                                                    ↓
       └────────────────────── 这两者可能不一致 ──────────────────────────────┘
```

**典型失败场景**：
1. 代码加了新功能，`polaris.json` 更新了 feature，但 `PolarSkills/SOUL.md` 没改
2. 删除了某个能力，`PolarSkills/` 里的 SKILL.md 没删
3. 接口参数变了，`PolarSoul.md` 里写的协议约定过期

## 设计原则

1. **代码为地面真相**：代码永远是 ground truth。当文档与代码矛盾时，代码对。
2. **时间戳比对**：`polaris.json` 最后修改时间 vs 代码最后修改时间 → 差距过大 = 告警
3. **检测在前、自愈在后**：先发现问题，再自动修复或提示 Agent 修复
4. **宽容更新窗口**：不要求每个 commit 都同步更新所有文档，但验收时必须一致

## 三层一致性保障

### Layer 1: 提交时检测（pc_precommit_check 增强）

已有 `pc_ssot_precommit_check`（协议 C 步骤 2）：

```bash
# 增强逻辑：
# 如果本次 commit 包含 src/ 下的功能文件变更
# 且没有同时包含 polaris.json 变更
# → 警告（非阻塞），提示 Agent "别忘了更新 polaris.json"
```

**关键**：非阻塞。允许 Agent 分多次 commit，但最后一个 commit 前必须同步。

### Layer 2: 分支合并时校验（PR Gate）

在 PR 合并到 main 前，SOTAgent 扫描：

```
检查项：
1. polaris.json.features 中 status=done 的 feature
   → 是否有对应的代码文件存在？
2. PolarSkills/ 中声明的能力
   → 是否有对应的 tools.ts / 路由注册？
3. PolarSoul.md 中声明的接口
   → 是否与实际暴露的 API 路由匹配？
4. 各文件 last_modified 时间差
   → 代码变更 > 7 天但文档未变 → 标记 stale
```

### Layer 3: 定期巡检 + 自愈（SOTAgent Cron）

SOTAgent 每日执行：

```
1. 扫描所有项目 polaris.json 的 last_modified
2. 对比 src/ 最新 commit 时间
3. 差距 > 7 天 → 生成 "SSOT Drift Alert"
4. 差距 > 14 天 → 自动创建修复任务到 roadmap

自愈策略（渐进式）：
- Level 1 (1-7天): 静默记录
- Level 2 (7-14天): 告警（Hub Web Dashboard 黄色标记）
- Level 3 (14天+): 自动生成 polaris.json 更新 PR（基于最近 commit 历史推断）
```

## 时间戳 SSOT 机制

**核心思想**：不强求所有文件实时同步，而是通过时间戳判断"谁更新"来决定真相。

### `polaris.json` 增加 `_meta` 字段

```json
{
  "_meta": {
    "last_synced_at": "2026-06-10T22:30:00+08:00",
    "sync_source": "agent/feat-ssot-doc-system",
    "schema_version": "1.0"
  }
}
```

### 冲突解决规则

| 情况 | 判断 | 行动 |
|------|------|------|
| 代码改了，polaris.json 没改 | `src/ git log` 比 `_meta.last_synced_at` 新 | Agent 下次看到时自动更新 |
| polaris.json 改了，代码没跟上 | polaris 有 `next_up` 但无对应 commit | 正常（还没开始做） |
| PolarSkills/ 过期 | SKILL.md mtime 比对应 tools.ts 旧 | 标记 stale，提示更新 |
| PolarSoul.md 过期 | 生态变更但 SOUL 未更新 | SOTAgent 触发跨项目更新 |

### 自愈触发点

```
Agent 工作流中的自动触发点：
1. Agent 接入项目时（读 worker.md 之前）→ 检查 _meta.last_synced_at
2. Agent 完成任务时（commit 之前）→ pc_ssot_precommit_check
3. PR 合并时 → SOTAgent PR Gate
4. 每日 cron → 全局巡检
```

## PolarSkills 耦合管理

### 问题
`PolarSkills/SOUL.md` 描述生态全景 → 注入 system prompt → Agent 据此工作。
如果生态变了（新项目上线、旧项目废弃），SOUL.md 不更新就会导致 Agent 幻觉。

### 解决方案：SOUL.md 声明式生成

```bash
# SOTAgent 定期从各项目的 PolarSoul.md 聚合生成根仓 PolarSoul.md
# 而不是手动维护
# （原聚合目标 PolarClaw 的 PolarSkills/SOUL.md 已随 PolarClaw 于 2026-08-11 退役）

聚合逻辑：
1. 扫描 Polarisor/ 下所有 PolarSoul.md
2. 提取 "生态位" + "承担功能" + "接口约定"
3. 按模板拼装为 PolarSkills/SOUL.md
4. 对比现有内容，有 diff 则自动 PR
```

**好处**：
- `SOUL.md` 不需要人/Agent 手动维护
- 各项目只管好自己的 `PolarSoul.md`
- 聚合生成的 SOUL.md 永远是最新的

### 向后兼容保障

```
如果代码引用了 PolarSkills 中的路径：
1. skill-discovery.ts 已有 fallback（PolarSkills/ → skills/）
2. 新增：如果 PolarSkills/SOUL.md 不存在，fallback 到 PolarSoul.md
3. 废弃的 Skill 不立刻删除，先标记 deprecated: true（frontmatter）
```

## 实施路径

1. **已完成**：六件套结构 + 代码路径迁移
2. **下一步**：
   - [ ] polaris.json 增加 `_meta` 字段（schema_version, last_synced_at）
   - [ ] pc_ssot_precommit_check 增强（功能文件变更 → 提示 polaris 同步）
   - [ ] SOTAgent 增加定期巡检脚本（比对时间戳、生成 drift alert）
   - [ ] SOUL.md 聚合生成器（从各 PolarSoul.md 自动组装）
