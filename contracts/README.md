# Agent_core Contracts

本目录包含 Agent_core 生态级契约定义。所有被托管项目的沙箱外契约必须与此处的定义兼容。

## 契约列表

| Schema | 用途 | 变更历史 |
|--------|------|---------|
| `rule-reference.schema.json` | Agent 规则引用格式 | 初始版本 |
| `checkup-event.schema.json` | 跨项目统一检修事件 | 2026-05-08 新增（260505 批次） |
| `codeowners-template.md` | CODEOWNERS 文件模板 | 2026-05-08 新增（260505 批次） |

## Examples

- `examples/checkup-event.example.json` — CheckupEvent 完整示例

## Contract Tests

- `../tests/contracts/checkup-event.contract.test.ts` — CheckupEvent schema 校验测试
