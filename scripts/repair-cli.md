# Cursor CLI 修复清单（/pc-yolo 硬阻塞时）

> 探针：`bash ~/Polarisor/Agent_core/scripts/cli-probe.sh`  
> L1 通过 = 已登录；L2 通过 = headless 工人可用。  
> **日常调用**：`bash ~/Polarisor/Agent_core/scripts/polar-agent.sh`（经 PolarProcess `register-and-start`，自动继承代理）。  
> ⛔ 禁止裸终端 `export HTTP_PROXY=…` 后直接 `agent -p`；⛔ 禁止绕过 PolarProcess 的 `agent-worker.sh` 旧路径。

## 0. PolarProcess 入口（默认）

```bash
# 权威必须在线（代理由 PolarProcess 注入给托管进程）
curl -fsS http://127.0.0.1:11055/api/health
curl -fsS http://127.0.0.1:11055/api/runtime/proxy | python3 -m json.tool

# Codex / 总控派 Cursor CLI 工人
export PC_PROJECT_DIR=/path/to/project
bash ~/Polarisor/Agent_core/scripts/polar-agent.sh --prompt-file /tmp/prompt.md
# 或
bash ~/Polarisor/Agent_core/scripts/agent-worker.sh /tmp/prompt.md
```

每次运行会注册临时服务 `cursor-cli-<id>`，worker 脚本：`Agent_core/Start/cursor-cli-worker.sh`。  
产出：`~/.cursor-cli/jobs/<id>/output.log`。

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
- 在 IDE 嵌套 shell / 裸终端直接 `agent -p`（须 `polar-agent.sh` → PolarProcess）
- 手写 `HTTP_PROXY` 冒充 PolarProcess 代理注入
- PolarProcess 未启动时假装 CLI 工人可用
- 探针未过就宣称 /pc-yolo 已启动
