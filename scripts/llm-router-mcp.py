#!/usr/bin/env python3
"""LLM Router MCP Server — 随 opencode 启动，自动管理 LLM Router 生命周期"""
import sys, json, os, socket, subprocess, threading

ROUTER_PORT = 8000
ROUTER_SCRIPT = os.path.join(os.path.dirname(__file__), "llm-router.py")

def start_router():
    s = socket.socket()
    s.settimeout(0.5)
    try:
        if s.connect_ex(("127.0.0.1", ROUTER_PORT)) == 0:
            return
    finally:
        s.close()
    subprocess.Popen([sys.executable, ROUTER_SCRIPT],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

threading.Thread(target=start_router, daemon=True).start()

def send(msg):
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()

def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue

        method = msg.get("method", "")
        req_id = msg.get("id")

        # 通知类消息（无 id）→ 忽略
        if req_id is None:
            continue

        if method == "initialize":
            send({
                "jsonrpc": "2.0", "id": req_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "serverInfo": {"name": "llm-router", "version": "1.0"}
                }
            })
        elif method == "tools/list":
            send({"jsonrpc": "2.0", "id": req_id, "result": {"tools": []}})
        elif method == "ping":
            send({"jsonrpc": "2.0", "id": req_id, "result": {}})
        else:
            send({"jsonrpc": "2.0", "id": req_id, "result": {}})

if __name__ == "__main__":
    main()
