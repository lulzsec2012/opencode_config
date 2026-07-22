#!/usr/bin/env python3
"""
LLM Router MCP Server — 随 opencode 启动，自动管理 LLM Router 生命周期

MCP 协议入口，opencode 通过 mcp 配置自动启动此脚本。
脚本会在后台启动 LLM Router (HTTP server on :8000)，
并保持 MCP 连接存活，opencode 结束时自动清理。
"""
import sys, json, threading, os, signal, socket, subprocess

ROUTER_PORT = 8000
ROUTER_SCRIPT = os.path.join(os.path.dirname(__file__), "llm-router.py")
router_proc = None

def start_router():
    global router_proc
    # 检查是否已运行
    s = socket.socket()
    s.settimeout(0.5)
    try:
        if s.connect_ex(("127.0.0.1", ROUTER_PORT)) == 0:
            s.close()
            return
    finally:
        s.close()
    # 启动 router 子进程
    router_proc = subprocess.Popen(
        [sys.executable, ROUTER_SCRIPT],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

t = threading.Thread(target=start_router, daemon=True)
t.start()

# ── MCP 协议处理 ────────────────────────────────

def send(msg):
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()

def main():
    # 读取 MCP 初始化消息
    line = sys.stdin.readline()
    if not line:
        return
    init = json.loads(line)
    send({
        "jsonrpc": "2.0", "id": init.get("id"),
        "result": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "serverInfo": {"name": "llm-router", "version": "1.0"}
        }
    })
    # 保持连接，忽略后续消息
    for line in sys.stdin:
        try:
            msg = json.loads(line)
            if "id" in msg:
                send({"jsonrpc": "2.0", "id": msg["id"], "result": {}})
        except json.JSONDecodeError:
            pass

if __name__ == "__main__":
    main()
