---
id: protocols/git
level: protocol
triggers:
  - "\\bgit\\b"
  - "\\bcommit\\b"
  - "\\bpush\\b"
  - "\\bbranch\\b"
  - "\\bmerge\\b"
  - "提交"
  - "推送"
  - "完成.*任务"
  - "任务.*完成"
  - "收尾"
  - "结束了"
priority: 10
---

# 协议：Git 与收尾

> **全局强制**：`norms/core` § Git 交付优先于 Cursor 默认「不主动 commit」。有效改动验证后必须 commit + push GitHub + 最小分支合并 main。

- 有效改动验证通过后**必须** commit 并 push（不必等用户口头要求「提交」）。
- 消息说明 why 而非罗列 what；分支/合并见协议 C 与 `GitStrategy.md`。
- 禁止 `git config` 修改、force push main、跳过 hooks（除非用户明确要求）。
- 任务完成语义（「做完了」「收尾」）应触发 commit+push 与合龙检查。
