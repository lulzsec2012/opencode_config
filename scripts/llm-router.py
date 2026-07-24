#!/usr/bin/env python3
"""LLM Router — 自动选择最优 LLM 后端

启动方式（随 opencode 启动）:
  python3 llm-router.py --daemon

路由优先级:
  1. localhost (本机 vLLM)       0ms 额外延迟
  2. tailscale (tailnet 内网)    ~12ms
  3. mixapi (公网转发)          兜底

自动探测:
  - 扫描 localhost:8000-8010 发现 vLLM 实例
  - 执行 tailscale ip -4 获取 tailscale IP
  - 从环境变量 MIXAPI_BASE_URL 获取 MixAPI 地址
"""

import json, os, sys, socket, threading, time, subprocess, datetime, urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import Request, urlopen
from urllib.error import URLError

ROUTER_PORT = 8000
PROBE_TIMEOUT = 0.3  # 端口探测超时（秒）
CACHE_TTL = 30       # 后端选择缓存（秒）

# ── 后端探测 ──────────────────────────────────────────────────────────

def detect_tailscale_ip():
    """自动获取本机 Tailscale IP"""
    try:
        out = subprocess.run(["tailscale", "ip", "-4"],
            capture_output=True, text=True, timeout=3)
        if out.returncode == 0:
            ip = out.stdout.strip()
            if ip:
                return ip
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return None

def port_open(host, port, timeout=PROBE_TIMEOUT):
    """探测端口是否开放"""
    try:
        s = socket.create_connection((host, port), timeout=timeout)
        s.close()
        return True
    except (OSError, socket.timeout):
        return False

def probe_ports(host, ports):
    """并发探测多个端口"""
    results = {}
    threads = []
    lock = threading.Lock()
    def probe(p):
        if port_open(host, p):
            with lock: results[p] = True
    for p in ports:
        t = threading.Thread(target=probe, args=(p,), daemon=True)
        t.start()
        threads.append(t)
    for t in threads:
        t.join(timeout=1)
    return sorted(results.keys())

class BackendCache:
    """后端选择缓存，定时刷新"""
    def __init__(self):
        self._lock = threading.Lock()
        self._best = None
        self._expires = 0
        self._mixapi_url = None
        self._mixapi_key = None

    def _read_env(self):
        raw = os.environ.get("MIXAPI_BASE_URL", "").rstrip("/")
        self._mixapi_url = raw.replace("/v1", "") if raw else ""
        self._mixapi_key = os.environ.get("MIXAPI_API_KEY", "")

    def _discover_models(self, host, port):
        """查询一个端口上运行的是什么模型"""
        try:
            url = f"http://{host}:{port}/v1/models"
            req = urllib.request.Request(url)
            resp = urllib.request.urlopen(req, timeout=2)
            data = json.loads(resp.read())
            models = [m["id"] for m in data.get("data", []) if m.get("id")]
            return models
        except Exception:
            return []

    def _probe_all(self):
        self._read_env()
        ts_ip = detect_tailscale_ip()
        port_range = list(range(8000, 8011))
        exclude = set()
        try:
            s = socket.socket()
            s.bind(("127.0.0.1", ROUTER_PORT))
            s.close()
        except OSError:
            exclude.add(ROUTER_PORT)
        if exclude:
            port_range = [p for p in port_range if p not in exclude]
        results = []

        # localhost: 找开放端口 → 查模型名称 → 建立映射
        local_map = {}
        for port in probe_ports("127.0.0.1", port_range):
            models = self._discover_models("127.0.0.1", port)
            for m in models:
                local_map[m] = port
        if local_map:
            results.append(("localhost", "127.0.0.1", local_map))

        # tailscale
        if ts_ip and ts_ip != "127.0.0.1":
            ts_map = {}
            for port in probe_ports(ts_ip, port_range):
                models = self._discover_models(ts_ip, port)
                for m in models:
                    ts_map[m] = port
            if ts_map:
                results.append(("tailscale", ts_ip, ts_map))

        # mixapi
        if self._mixapi_url:
            results.append(("mixapi", self._mixapi_url, self._mixapi_key))

        return results

    def get_backends(self):
        now = time.time()
        with self._lock:
            if now < self._expires and self._best is not None:
                return self._best
        bk = self._probe_all()
        with self._lock:
            self._best = bk
            self._expires = now + CACHE_TTL
        return bk

    def get_backend_for_model(self, model):
        """根据模型名称查找最优后端和端口"""
        backends = self.get_backends()
        for name, addr, meta in backends:
            if name == "mixapi":
                return name, addr, meta
            if isinstance(meta, dict):
                port = meta.get(model)
                if port:
                    return name, addr, port
        # 兜底：走 mixapi
        return ("mixapi", self._mixapi_url or "", self._mixapi_key or "")

cache = BackendCache()

# ── Token 日志（本地文件 + Langfuse 自动检测）─────────────────────────

LOG_FILE = "/tmp/llm-token-log.jsonl"

class TokenLogger:
    """记录每次 LLM 调用的 token 消耗。

    自动探测 Langfuse 服务，存在则实时推送，不存在或中断则静默回退。
    任何情况下不影响主线请求。
    """
    def __init__(self):
        self._enabled = False
        self._lock = threading.Lock()
        self._last_probe = 0
        self._consecutive_fails = 0

    def _check(self):
        now = time.time()
        with self._lock:
            if now - self._last_probe < 60:
                return self._enabled
        ok = port_open("127.0.0.1", 3010, timeout=0.1)
        with self._lock:
            self._enabled = ok
            self._last_probe = now
            if ok:
                self._consecutive_fails = 0
        return ok

    def log(self, model, prompt_tokens, completion_tokens, elapsed_ms, backend):
        if not self._check():
            return
        record = {
            "t": time.time(),
            "model": model,
            "provider": backend,
            "in": prompt_tokens,
            "out": completion_tokens,
            "total": prompt_tokens + completion_tokens,
            "ms": int(elapsed_ms),
        }
        threading.Thread(target=self._push, args=(record,), daemon=True).start()

    def _push(self, record):
        try:
            body = json.dumps({
                "batch": [{
                    "type": "observation-create",
                    "body": {
                        "type": "GENERATION",
                        "model": record["model"],
                        "metadata": {"provider": record["provider"]},
                        "usage": {
                            "input": record["in"],
                            "output": record["out"],
                            "unit": "TOKENS",
                            "total": record["total"]
                        },
                        "startTime": datetime.datetime.fromtimestamp(record["t"]).isoformat(),
                    }
                }]
            }).encode()
            req = urllib.request.Request(
                "http://127.0.0.1:3010/api/public/ingestion",
                data=body,
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            urllib.request.urlopen(req, timeout=2)
            with self._lock:
                self._consecutive_fails = 0
        except Exception:
            with self._lock:
                self._consecutive_fails += 1
                # 连续 3 次失败则立即禁用，下次 probe 再重新检测
                if self._consecutive_fails >= 3:
                    self._enabled = False

token_log = TokenLogger()

# ── HTTP Handler ──────────────────────────────────────────────────────

class RouterHandler(BaseHTTPRequestHandler):
    server_version = "LLMRouter/1.0"

    def _forward(self, body=None):
        t0 = time.time()
        model = "qwen3.6-27b"
        if body:
            try: model = json.loads(body).get("model", model)
            except: pass

        name, addr, meta = cache.get_backend_for_model(model)
        stream = body and '"stream":true' in body

        if name == "mixapi":
            target = f"{addr}{self.path}"
            headers = {"Authorization": f"Bearer {meta}"}
        else:
            target = f"http://{addr}:{meta}{self.path}"
            headers = {}

        # 转发
        req = Request(target, data=body.encode() if body else None, method=self.command)
        req.add_header("Content-Type", "application/json")
        for k, v in headers.items():
            req.add_header(k, v)

        try:
            resp = urlopen(req, timeout=180)
            data = resp.read()
            elapsed = (time.time() - t0) * 1000
            print(f"  [{name:10s}] {model.split('/')[-1][:20]:20s} {resp.status} {len(data)}B {elapsed:.0f}ms")

            # 解析 token 用量并推送 Langfuse
            if not stream and data:
                try:
                    u = json.loads(data).get("usage", {})
                    pt = u.get("prompt_tokens", 0) or u.get("input_tokens", 0)
                    ct = u.get("completion_tokens", 0) or u.get("output_tokens", 0)
                    if pt or ct:
                        token_log.log(model, pt, ct, elapsed, name)
                except (json.JSONDecodeError, AttributeError):
                    pass

            self.send_response(resp.status)
            for k, v in resp.headers.items():
                if k.lower() in ("content-length", "content-encoding",
                                 "transfer-encoding", "connection"):
                    continue
                self.send_header(k, v)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        except URLError as e:
            self.send_error(502, f"Backend error: {e.reason}")

    def do_GET(self):
        if self.path == "/v1/models":
            backends = cache.get_backends()
            all_models = []
            seen = set()
            import urllib.request
            for name, addr, meta in backends:
                if isinstance(meta, dict):
                    # localhost / tailscale: meta = {model_name: port}
                    for model_name, port in meta.items():
                        base = f"http://{addr}:{port}/v1"
                        try:
                            req = urllib.request.Request(f"{base}/models")
                            resp = urllib.request.urlopen(req, timeout=3)
                            data = json.loads(resp.read())
                            for m in data.get("data", []):
                                mid = m.get("id")
                                if mid and mid not in seen:
                                    seen.add(mid)
                                    all_models.append(m)
                        except Exception:
                            pass
                elif isinstance(meta, str) and name == "mixapi":
                    # mixapi: meta = api_key
                    base = f"{addr}/v1"
                    try:
                        req = urllib.request.Request(f"{base}/models")
                        req.add_header("Authorization", f"Bearer {meta}")
                        resp = urllib.request.urlopen(req, timeout=5)
                        data = json.loads(resp.read())
                        for m in data.get("data", []):
                            mid = m.get("id")
                            if mid and mid not in seen:
                                seen.add(mid)
                                all_models.append(m)
                    except Exception:
                        pass
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"object":"list","data":all_models}).encode())
        elif self.path.startswith("/v1"):
            self._forward()
        else:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            backends = [(n, a) for n, a, _ in cache.get_backends()]
            self.wfile.write(json.dumps({
                "service": "LLM Router", "backends": backends
            }).encode())

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("content-length", 0))).decode()
        self._forward(body)

    def log_message(self, format, *args):
        pass

# ── 启动 ──────────────────────────────────────────────────────────────

def run_server(port=ROUTER_PORT, daemon=False):
    # 检查端口是否已被占用（多 opencode 进程时静默退出）
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(1)
        # 如果能 connect 成功，说明端口已被占用
        if s.connect_ex(("127.0.0.1", port)) == 0:
            s.close()
            return  # 已有实例在运行，静默退出
        s.close()
    except:
        pass
    if daemon:
        pid = os.fork()
        if pid > 0:
            print(pid)  # 输出 PID 给调用方
            return
        os.setsid()
        # 再次 fork 脱离终端
        pid = os.fork()
        if pid > 0:
            os._exit(0)

    server = HTTPServer(("127.0.0.1", port), RouterHandler)
    print(f"LLM Router :{port}  ", file=sys.stderr)
    backends = cache.get_backends()
    for name, addr, meta in backends:
        if name == "mixapi":
            print(f"  mixapi: {addr}", file=sys.stderr)
        elif meta:
            print(f"  {name}: {addr} ports={meta}", file=sys.stderr)
    server.serve_forever()

if __name__ == "__main__":
    port = ROUTER_PORT
    daemon = False
    for a in sys.argv[1:]:
        if a == "--daemon": daemon = True
        elif a.isdigit(): port = int(a)
        elif a in ("-h", "--help"):
            print(__doc__); sys.exit(0)

    run_server(port, daemon)
