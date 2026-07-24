#!/usr/bin/env python3
"""统一跨 Provider 基准测试 — deepseek / mixapi / vllm / jiutian

用法:
    export DEEPSEEK_API_KEY=sk-xxx
    export JIUTIAN_API_KEY=sk-xxx
    python3 benchmark_all.py
    python3 benchmark_all.py --quick      # 每个模型只测一轮
    python3 benchmark_all.py --model deepseek/deepseek-v4-flash  # 只测指定模型
"""

import json, os, sys, time, argparse, urllib.request, urllib.error

# ── Provider 定义 ──
PROVIDERS = {
    "deepseek": {
        "name": "DeepSeek 云端",
        "base_url": "https://api.deepseek.com/v1",
        "api_key_var": "DEEPSEEK_API_KEY",
        "models": ["deepseek-v4-flash", "deepseek-v4-pro"],
        "default_key": None,  # will be read from env
    },
    "mixapi": {
        "name": "MixAPI 本地代理",
        "base_url": "os_env:MIXAPI_BASE_URL",  # special: use env var
        "api_key_var": "MIXAPI_API_KEY",
        "models": ["qwen3.6-27b"],
        "default_key": "not-needed",
    },
    "vllm-8001": {
        "name": "vLLM 8001 (gemma4)",
        "base_url": "http://localhost:8001/v1",
        "api_key_var": None,
        "models": ["gemma4-26b-fp8"],
        "default_key": "not-needed",
    },
    "vllm-8002": {
        "name": "vLLM 8002 (qwen3.6)",
        "base_url": "http://localhost:8002/v1",
        "api_key_var": None,
        "models": ["qwen3.6-27b"],
        "default_key": "not-needed",
    },
    "jiutian": {
        "name": "九天平台",
        "base_url": "https://jiutian.10086.cn/largemodel/moma/api/v3",
        "api_key_var": "JIUTIAN_API_KEY",
        "models": [
            "z.ai/glm-5",
            "z.ai/glm-5.1",
            "z.ai/glm-5.2",
            "deepseek/deepseek-r1",
            "deepseek/deepseek-v32",
            "deepseek/deepseek-v3",
            "deepseek/deepseek-v4-flash",
            "qwen/qwen3.5-397b-a17b",
            "qwen/qwen3.6-35b",
            "qwen/qwen3.6-27b",
            "qwen/qwen3-235b-a22b-2507",
            "qwen/qwen3-coder-next",
            "moonshotai/kimi-k2.6",
            "moonshotai/kimi-k2.5-thinking",
            "minimax/minimax-m2.7",
            "minimax/minimax-m2.5",
            "minimax/minimax-latest",
            "jiutian/jiutian-lan-35b",
            "jiutian/jiutian-da-35b",
            "jiutian/jiutian-lan-236b",
            "jiutian/jiutian-lan-13b",
            "jiutian/jiutian-lan-8b",
            "jiutian/jiutian-lan-thinking",
            "jiutian/jiutian-code-8b",
            "jiutian/jiutian-math-8b",
            "nvidia/nemotron-3-super-120b-a12b",
            "openai/gpt-oss-120b",
            "moma/auto",
        ],
        "default_key": None,
    },
}

PROMPT_SHORT = "用一句话解释什么是量子计算。返回20个字以内。"
PROMPT_LONG = """请详细分析这段 Python 代码的时间复杂度和空间复杂度，给出优化建议，并重写优化版本：

def find_duplicates(arr):
    result = []
    for i in range(len(arr)):
        for j in range(i + 1, len(arr)):
            if arr[i] == arr[j] and arr[i] not in result:
                result.append(arr[i])
    return result
"""


def resolve_base_url(provider_config):
    """Resolve base_url, handling os_env: prefix for env-based URLs."""
    url = provider_config["base_url"]
    if url.startswith("os_env:"):
        var_name = url[7:]
        url = os.environ.get(var_name)
        if not url:
            return None
    return url


def get_api_key(provider_config):
    """Get API key for a provider."""
    var_name = provider_config.get("api_key_var")
    if var_name is None:
        return provider_config.get("default_key", "")
    key = os.environ.get(var_name)
    if key:
        return key
    return provider_config.get("default_key", "")


def test_model(provider_name, model_id, prompt, max_tokens=200):
    """Call a model via its provider API (non-streaming). Returns metrics dict."""
    pconf = PROVIDERS[provider_name]
    base_url = resolve_base_url(pconf)
    if not base_url:
        return {
            "provider": provider_name,
            "model": model_id,
            "error": "base_url not resolved (env var missing?)",
        }

    api_key = get_api_key(pconf)
    if api_key is None:
        return {
            "provider": provider_name,
            "model": model_id,
            "error": "API key not found",
        }

    body = json.dumps(
        {
            "model": model_id,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.1,
            "max_tokens": max_tokens,
            "stream": False,
        }
    ).encode()

    headers = {"Content-Type": "application/json"}
    if api_key and api_key != "not-needed":
        headers["Authorization"] = f"Bearer {api_key}"

    req = urllib.request.Request(
        f"{base_url}/chat/completions", data=body, headers=headers
    )

    start = time.time()
    try:
        resp = urllib.request.urlopen(req, timeout=120)
        ttft = time.time() - start
        data = json.loads(resp.read())
        elapsed = time.time() - start
        choice = next((c for c in data.get("choices", []) if c is not None), None)
        if choice is None:
            return {
                "provider": provider_name,
                "model": model_id,
                "error": "no valid choices",
            }
        msg = choice.get("message", {}) or {}
        content = msg.get("content") or msg.get("reasoning") or ""
        usage = data.get("usage", {}) or {}
        prompt_tok = usage.get("prompt_tokens", 0) or 0
        completion_tok = usage.get("completion_tokens", 0) or 0
        details = usage.get("completion_tokens_details") or {}
        reasoning_tok = details.get("reasoning_tokens", 0) or 0
        tps = round(completion_tok / elapsed, 1) if elapsed and completion_tok else 0
        return {
            "provider": provider_name,
            "model": model_id,
            "elapsed": round(elapsed, 2),
            "ttft": round(ttft, 3),
            "prompt_tok": prompt_tok,
            "completion_tok": completion_tok,
            "reasoning_tok": reasoning_tok,
            "tps": tps,
            "content_preview": content[:50].replace("\n", " "),
        }
    except urllib.error.HTTPError as e:
        body_err = e.read().decode("utf-8", errors="replace")[:150]
        return {
            "provider": provider_name,
            "model": model_id,
            "error": f"HTTP {e.code}: {body_err}",
        }
    except Exception as e:
        return {
            "provider": provider_name,
            "model": model_id,
            "error": f"{type(e).__name__}: {str(e)[:100]}",
        }


def main():
    parser = argparse.ArgumentParser(description="跨 Provider 基准测试")
    parser.add_argument("--quick", action="store_true", help="只测短提示")
    parser.add_argument("--model", type=str, help="指定模型 (格式: provider/model_id)")
    args = parser.parse_args()

    # Build test plan
    test_plan = []
    if args.model:
        # Format: provider/model_id or just model_id
        if "/" in args.model and args.model.count("/") >= 1:
            parts = args.model.split("/", 1)
            provider_name = parts[0]
            model_id = parts[1]
            if provider_name in PROVIDERS:
                test_plan.append((provider_name, model_id))
            else:
                # maybe jiutian model with / in it
                for pn, pc in PROVIDERS.items():
                    if args.model in pc["models"] or args.model.startswith(pn):
                        test_plan.append((pn, args.model))
                        break
        else:
            # search all providers
            for pn, pc in PROVIDERS.items():
                if args.model in pc["models"]:
                    test_plan.append((pn, args.model))
                    break
    else:
        for pn, pc in PROVIDERS.items():
            for m in pc["models"]:
                test_plan.append((pn, m))

    if not test_plan:
        print("ERROR: no models to test")
        sys.exit(1)

    # Test short prompt
    print(f"\n{'=' * 120}")
    print(f"  跨 Provider 基准测试  |  短提示: {PROMPT_SHORT[:40]}...")
    print(f"  共计 {len(test_plan)} 个模型组合")
    print(f"{'=' * 120}")

    short_results = []
    for i, (pn, model) in enumerate(test_plan, 1):
        pname = PROVIDERS[pn]["name"]
        label = f"[{pn}] {model}"
        print(f"  [{i:2d}/{len(test_plan)}] {label:<50s} ", end="", flush=True)
        r = test_model(pn, model, PROMPT_SHORT)
        short_results.append(r)
        if r.get("error"):
            print(f"\033[31mFAIL\033[0m  {r['error'][:55]}")
        else:
            print(
                f"\033[32mOK\033[0m  {r['elapsed']:>5.1f}s  TTFT={r['ttft']:.2f}s  {r['tps']:>5.1f} t/s  {r['content_preview'][:35]}"
            )

    # Long prompt test (unless --quick)
    long_results = None
    if not args.quick:
        print(f"\n{'=' * 120}")
        print(f"  长提示测试  |  ~150 tokens")
        print(f"{'=' * 120}")
        long_results = []
        for i, (pn, model) in enumerate(test_plan, 1):
            pname = PROVIDERS[pn]["name"]
            label = f"[{pn}] {model}"
            print(f"  [{i:2d}/{len(test_plan)}] {label:<50s} ", end="", flush=True)
            r = test_model(pn, model, PROMPT_LONG, max_tokens=512)
            long_results.append(r)
            if r.get("error"):
                print(f"\033[31mFAIL\033[0m  {r['error'][:55]}")
            else:
                print(
                    f"\033[32mOK\033[0m  {r['elapsed']:>5.1f}s  TTFT={r['ttft']:.2f}s  {r['tps']:>5.1f} t/s  tok={r['completion_tok']}"
                )

    # ── Summary table ──
    print(f"\n{'=' * 120}")
    print(f"  短提示结果汇总")
    print(f"{'=' * 120}")
    print(
        f"{'Provider':<12s} {'Model':<35s} {'Time':>6s} {'TTFT':>7s} {'t/s':>6s} {'Ptok':>5s} {'Ctok':>5s} {'Status':>6s}"
    )
    print("-" * 120)

    # Sort by tps descending for working models
    def sort_key(r):
        if r.get("error"):
            return (1, 0)
        return (0, -r.get("tps", 0))

    for r in sorted(short_results, key=sort_key):
        prov = r["provider"][:10]
        model = r["model"][:33]
        if r.get("error"):
            print(f"  {prov:<10s} {model:<33s}  FAIL  {r['error'][:60]}")
        else:
            print(
                f"  {prov:<10s} {model:<33s} {r['elapsed']:>5.1f}s {r['ttft']:>6.2f}s {r['tps']:>5.1f} {r['prompt_tok']:>5d} {r['completion_tok']:>5d}  OK"
            )

    # Provider comparison
    print(f"\n{'=' * 120}")
    print(f"  Provider 对比 (相同模型)")
    print(f"{'=' * 120}")

    # Find models tested across multiple providers
    model_providers = {}
    for r in short_results:
        if r.get("error"):
            continue
        m = r["model"]
        model_providers.setdefault(m, []).append(r)

    for m, results in sorted(model_providers.items()):
        if len(results) < 2:
            continue
        print(f"\n  [{m}]")
        for r in sorted(results, key=lambda x: x["tps"], reverse=True):
            print(
                f"    {r['provider']:<12s}  {r['tps']:>5.1f} t/s  TTFT={r['ttft']:.2f}s  total={r['elapsed']:.1f}s"
            )

    # Speed tiers across all providers
    print(f"\n{'=' * 120}")
    print(f"  全局速度排名")
    print(f"{'=' * 120}")
    working = [r for r in short_results if not r.get("error") and r.get("tps", 0) > 0]
    for r in sorted(working, key=lambda x: x["tps"], reverse=True):
        bar = "█" * max(1, min(60, int(r["tps"] * 1.5)))
        print(
            f"  [{r['provider']:<10s}] {r['model']:<35s} {r['tps']:>5.1f} t/s  TTFT={r['ttft']:.2f}s  {bar}"
        )


if __name__ == "__main__":
    main()
