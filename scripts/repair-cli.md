# Cursor CLI 修复清单（/pc-yolo 硬阻塞时）

> 探针：`bash scripts/pc-yolo/cli-probe.sh`  
> L1 通过 = 已登录；L2 通过 = headless 工人可用。

## 1. 本机配置（一次性）

**`~/.cursor/cli-config.json`** 须含：

```json
{
  "approvalMode": "unrestricted",
  "network": { "useHttp1ForAgent": true },
  "sandbox": { "mode": "disabled", "networkAccess": "allow_all" },
  "permissions": {
    "allow": ["Shell(**)", "Write(**)", "Read(**)", "Mcp(**)"],
    "deny": []
  }
}
```

**仓库 `.cursor/cli.json`**（仅 `permissions`，勿写 `approvalMode`/`network`/`sandbox`）：

```json
{
  "permissions": {
    "allow": ["Shell(**)", "Write(**)", "Read(**)", "Mcp(**)"],
    "deny": []
  }
}
```

## 2. 探针失败分级

| 现象 | 含义 | 动作 |
|------|------|------|
| L1 失败 | 未登录 | `agent logout && agent login`（**Cursor 外 Terminal.app**） |
| L2：有 init、无 assistant | 后端/API 卡住 | 见 §3 |
| L2：Invalid project config | `.cursor/cli.json` schema 错误 | 只保留 `permissions` |
| 多个 `agent -p` 僵尸进程 | 嵌套 spawn 泄漏 | `pkill -f "cursor-agent.*index.js -p"` |

## 3. L2 init 有、assistant 无（常见）

1. **Cursor 外** Terminal 重登：`agent logout && agent login`
2. 配置 API Key（Dashboard → Integrations）：
   ```bash
   export CURSOR_API_KEY="..."
   bash scripts/pc-yolo/cli-probe.sh
   ```
3. `agent update`
4. 检查 VPN/代理/firewall 对 `cursor.com` / `api2.cursor.sh` 的 WebSocket
5. 仍失败 → Cursor 支持 / 论坛（headless `-p` 无 assistant 响应）

## 4. 禁止

- 仅用 `agent whoami` 判断 CLI 就绪
- 在 IDE 嵌套 shell 裸跑 `agent -p`（须 `agent-worker.sh` + 探针通过）
- 探针未过就宣称 /pc-yolo 已启动
