#!/usr/bin/env python3
"""Hub alive check — returns 0 if Hub responds, 1 otherwise."""
import sys, subprocess, json, re

def main():
    port = sys.argv[1] if len(sys.argv) > 1 else "8040"
    try:
        r = subprocess.run(
            ["curl", "-s", "--max-time", "3",
             f"http://127.0.0.1:{port}/mcp",
             "-X", "POST",
             "-H", "Content-Type: application/json",
             "-H", "Accept: application/json, text/event-stream",
             "-d", '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"hub-check","version":"1.0"}},"id":0}'],
            capture_output=True, text=True, timeout=5
        )
        text = r.stdout
        m = re.search(r"data:\s*(\{.*\})", text, re.DOTALL)
        if m:
            text = m.group(1)
        d = json.loads(text)
        sys.exit(0 if d.get("jsonrpc") == "2.0" else 1)
    except Exception:
        sys.exit(1)

if __name__ == "__main__":
    main()
