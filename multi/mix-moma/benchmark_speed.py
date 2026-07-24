#!/usr/bin/env python3
"""speed-test — 跨平台 Provider 模型测速
用法: /benchmark           → 测所有 provider
      /benchmark jiutian   → 只测特定 provider
      python3 benchmark_speed.py --config opencode.json
"""

import json, os, sys, time, urllib.request, urllib.error, argparse

PROMPT = "hi"
MAX_TOKENS = 50

def find_config():
    """跨平台自动发现 opencode.json (Linux/macOS)"""
    home = os.path.expanduser("~")
    xdg = os.environ.get("XDG_CONFIG_HOME", os.path.join(home, ".config"))
    cand = []

    # 1. 当前目录
    cand.append("opencode.json")
    # 2. opencode 默认路径 (Linux)
    cand.append(os.path.join(xdg, "opencode", "opencode.json"))
    # 3. opencode 默认路径 (macOS)
    cand.append(os.path.join(home, "Library", "Application Support", "opencode", "opencode.json"))
    # 4. opencode-multi profiles (Linux + macOS)
    for mp in [os.path.join(xdg, "opencode-multi", "profiles"),
               os.path.join(home, "Library", "Application Support", "opencode-multi", "profiles")]:
        if os.path.isdir(mp):
            for d in sorted(os.listdir(mp)):
                p = os.path.join(mp, d, "opencode.json")
                if os.path.isfile(p):
                    cand.append(os.path.realpath(p) if os.path.islink(p) else p)
    # 5. 环境变量
    for ev in ["OPENCODE_CONFIG", "OPENCODE_PROFILE_DIR"]:
        v = os.environ.get(ev, "")
        if v:
            p = v if v.endswith("opencode.json") else os.path.join(v, "opencode.json")
            if os.path.isfile(p):
                cand.insert(0, p)

    for p in cand:
        if os.path.isfile(p):
            with open(p) as f:
                return json.load(f), p
    return None, None

def resolve_env(val):
    if isinstance(val, str) and val.startswith("{env:") and val.endswith("}"):
        return os.environ.get(val[5:-1], "")
    return val

def test_model(provider_name, provider_cfg, model_id):
    opts = provider_cfg.get("options", {})
    base_url = opts.get("baseURL", "")
    api_key = resolve_env(opts.get("apiKey", ""))
    if not base_url:
        return {"s": "fail", "r": "no baseURL"}

    body = json.dumps({"model": model_id, "messages": [{"role":"user","content":PROMPT}],
        "max_tokens": MAX_TOKENS, "temperature": 0, "stream": False}).encode()
    headers = {"Content-Type": "application/json"}
    if api_key and api_key != "not-needed":
        headers["Authorization"] = f"Bearer {api_key}"

    req = urllib.request.Request(f"{base_url.rstrip('/')}/chat/completions", data=body, headers=headers)
    start = time.time()
    try:
        resp = urllib.request.urlopen(req, timeout=30)
        ttft = time.time() - start
        data = json.loads(resp.read())
        elapsed = time.time() - start
        ctok = (data.get("usage", {}) or {}).get("completion_tokens", 0) or 0
        tps = round(ctok / elapsed, 1) if elapsed and ctok else 0
        return {"s": "ok", "ttft": round(ttft, 3), "tps": tps, "ctok": ctok}
    except urllib.error.HTTPError as e:
        return {"s": "fail", "r": f"HTTP {e.code}"}
    except Exception as e:
        return {"s": "fail", "r": type(e).__name__}

def grade(t):
    return "🚀" if t >= 40 else "✅" if t >= 20 else "⚡" if t >= 8 else "🐢"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("provider", nargs="?", help="只测指定 provider")
    p.add_argument("--config", help="指定 opencode.json 路径")
    a = p.parse_args()

    cfg, found = (None, None)
    if a.config:
        with open(a.config) as f:
            cfg = json.load(f)
    else:
        cfg, found = find_config()
    if not cfg:
        print("❌ 找不到 opencode.json")
        sys.exit(1)

    providers = cfg.get("provider", {})
    if a.provider:
        if a.provider in providers:
            providers = {a.provider: providers[a.provider]}
        else:
            print(f"❌ Provider '{a.provider}' 不存在，可用: {list(providers.keys())}")
            sys.exit(1)

    print(f"\n{'='*70}")
    print(f"  Speed Test — {len(providers)} provider(s)")
    print(f"{'='*70}\n")

    results = []
    for pname, pcfg in providers.items():
        models = pcfg.get("models", {})
        if not models: continue
        print(f"  [{pname}]")
        for mid in models:
            r = test_model(pname, pcfg, mid)
            r["p"] = pname; r["m"] = mid
            results.append(r)
            if r["s"] == "ok":
                print(f"    {mid:<42s} {r['ttft']:>5.1f}s {r['tps']:>5.1f} t/s  {grade(r['tps'])}")
            else:
                print(f"    {mid:<42s} {'—':>6s} {'—':>6s}    ❌ {r.get('r','?')}")
        time.sleep(0.3)
        print()

    ok = [r for r in results if r["s"] == "ok"]
    if ok:
        ok.sort(key=lambda r: r["tps"], reverse=True)
        print(f"  ══ 速度 Top 10 ══")
        for i, r in enumerate(ok[:10], 1):
            bar = "█" * max(1, min(40, int(r["tps"])))
            print(f"  {i:>2}. [{r['p']:<12s}] {r['m']:<35s} {r['tps']:>5.1f} t/s {bar}")

        ok.sort(key=lambda r: r["ttft"])
        print(f"\n  ══ TTFT Top 10 ══")
        for i, r in enumerate(ok[:10], 1):
            f = "⏳" if r["ttft"] > 3 else ""
            print(f"  {i:>2}. [{r['p']:<12s}] {r['m']:<35s} {r['ttft']:>5.1f}s {f}")

    fail = [r for r in results if r["s"] != "ok"]
    if fail:
        print(f"\n  ❌ 不可用 ({len(fail)}):")
        for r in fail:
            print(f"  [{r['p']:<12s}] {r['m']:<35s} {r.get('r','?')}")
    print()

if __name__ == "__main__":
    main()
