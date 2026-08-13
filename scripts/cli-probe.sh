#!/usr/bin/env bash
# /pc-yolo CLI 就绪探针 — 区分「已登录」与「headless 可执行」
# 用法：bash scripts/pc-yolo/cli-probe.sh [workspace]
# 退出码：0=就绪  1=未登录  2=执行超时/无 assistant 响应  3=配置错误
set -euo pipefail

WS="${1:-${PC_PROJECT_DIR:-$(pwd)}}"
AGENT="${AGENT_BIN:-$(command -v agent || true)}"
TIMEOUT_SEC="${PC_YOLO_PROBE_TIMEOUT:-45}"

if [[ -z "$AGENT" ]]; then
  echo "FAIL: agent 不在 PATH"
  exit 3
fi

echo "=== L1 认证 ==="
if ! "$AGENT" whoami 2>&1; then
  echo "FAIL: 未登录 — 运行 agent login"
  exit 1
fi

echo "=== 清理僵尸 agent -p ==="
pkill -f "cursor-agent.*index.js -p" 2>/dev/null || true
sleep 1

echo "=== L2 执行探针 (${TIMEOUT_SEC}s) ==="
# 从 IDE 嵌套 spawn 时去掉会干扰 headless 的环境变量
export PC_PROJECT_DIR="$WS"
unset CURSOR_AGENT VSCODE_IPC_HOOK VSCODE_CODE_CACHE_PATH CURSOR_EXTENSION_HOST_ROLE 2>/dev/null || true

python3 - "$AGENT" "$WS" "$TIMEOUT_SEC" <<'PY'
import json, os, subprocess, sys, threading, time

agent, workspace, timeout_sec = sys.argv[1], sys.argv[2], int(sys.argv[3])
cmd = [
    agent, "-p", "--trust", "--force", "--yolo", "--approve-mcps", "--sandbox", "disabled",
    "--output-format", "stream-json", "--stream-partial-output",
    "--model", "composer-2.5-fast", "--workspace", workspace,
    "Reply with exactly: OK",
]
env = os.environ.copy()
for k in ("CURSOR_AGENT", "VSCODE_IPC_HOOK", "VSCODE_CODE_CACHE_PATH", "CURSOR_EXTENSION_HOST_ROLE"):
    env.pop(k, None)

proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
got_init = False
got_assistant = False
lines = []

def read_stdout():
    global got_init, got_assistant
    assert proc.stdout is not None
    for line in proc.stdout:
        lines.append(line.rstrip())
        if '"type":"system"' in line and '"subtype":"init"' in line:
            got_init = True
        if '"type":"assistant"' in line:
            got_assistant = True
            break
        if '"type":"result"' in line:
            break

t = threading.Thread(target=read_stdout, daemon=True)
t.start()
deadline = time.time() + timeout_sec
while time.time() < deadline:
    if got_assistant:
        break
    if proc.poll() is not None:
        break
    time.sleep(0.2)

if proc.poll() is None:
    proc.kill()

if got_assistant:
    print("PASS: assistant 响应已收到")
    sys.exit(0)

if got_init:
    print(f"FAIL: 会话已建立但 {timeout_sec}s 内无 assistant 响应（Cursor 后端/API 问题）")
    for ln in lines[-5:]:
        print(" ", ln[:240])
    sys.exit(2)

print("FAIL: 未收到 init 事件（CLI 配置或网络）")
for ln in lines[-5:]:
    print(" ", ln[:240])
sys.exit(2)
PY
