# Agent_core Roadmap

> 进度视图：当前阶段、完成情况、下一步。事实源是 `polaris.json`，本文件只做进度摘要。

## 当前状态

| 维度 | 状态 |
| --- | --- |
| 版本 | 1.0.0 |
| 项目状态 | active |

## Requirement 完成情况

| ID | 名称 | 完成度 | 说明 |
| --- | --- | --- | --- |
| R1 | 骨架与注册表结构 | 100% | skeleton + registry + rule_reference_schema |
| R2 | 规范迁移（principles/protocols） | 100% | 从分散位置迁入 + 向后兼容 symlink |
| R3 | Cursor Rules 整合 | 100% | w_rules + 散落片段合并 |
| R4 | 高级规范（billing/binding/thinking/prompt） | 100% | 全部 done |

## 已知阻塞项

无。

## 下一步

1. 补充 polaris.json 中缺失的 `need`/`approach` 字段。
2. 文档新鲜度自动化脚本（批次 E）。
3. ADR 机制建立后，本项目承载协议 M 维护。

## 更新记录

| 日期 | 更新内容 |
| --- | --- |
| 2026-06-10 | 初始创建：从 polaris.json 提取进度信息 |
