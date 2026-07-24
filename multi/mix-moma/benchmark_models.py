#!/usr/bin/env python3
"""Benchmark jiutian models — non-streaming, reports TTFT + throughput."""

import json, os, sys, time, urllib.request, urllib.error

API_KEY = os.environ.get("JIUTIAN_API_KEY")
BASE = "https://jiutian.10086.cn/largemodel/moma/api/v3"
PROMPT = "用一句话解释什么是量子计算。返回20个字以内。"

ALL_MODELS = [
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
]


def test(model_id):
    body = json.dumps(
        {
            "model": model_id,
            "messages": [{"role": "user", "content": PROMPT}],
            "temperature": 0.1,
            "max_tokens": 200,
            "stream": False,
        }
    ).encode()
    req = urllib.request.Request(
        f"{BASE}/chat/completions",
        data=body,
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
        },
    )
    start = time.time()
    try:
        resp = urllib.request.urlopen(req, timeout=90)
        ttft = time.time() - start
        data = json.loads(resp.read())
        elapsed = time.time() - start
        choice = next((c for c in data.get("choices", []) if c is not None), None)
        if choice is None:
            return {"error": "no valid choices"}
        msg = choice.get("message", {}) or {}
        content = msg.get("content") or msg.get("reasoning") or ""
        usage = data.get("usage", {}) or {}
        prompt_tok = usage.get("prompt_tokens", 0) or 0
        completion_tok = usage.get("completion_tokens", 0) or 0
        details = usage.get("completion_tokens_details") or {}
        reasoning_tok = details.get("reasoning_tokens", 0) or 0
        tps = round(completion_tok / elapsed, 1) if elapsed and completion_tok else 0
        return {
            "elapsed": round(elapsed, 2),
            "ttft": round(ttft, 3),
            "prompt_tok": prompt_tok,
            "completion_tok": completion_tok,
            "reasoning_tok": reasoning_tok,
            "tps": tps,
            "content": content[:80].replace("\n", " "),
        }
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:120]
        return {"error": f"HTTP {e.code}: {body}"}
    except Exception as e:
        return {"error": f"{type(e).__name__}: {str(e)[:100]}"}


def main():
    if not API_KEY:
        print("ERROR: set JIUTIAN_API_KEY")
        sys.exit(1)
    results = []
    for i, m in enumerate(ALL_MODELS, 1):
        print(f"  [{i:2d}/{len(ALL_MODELS)}] {m:<40s} ", end="", flush=True)
        r = test(m)
        results.append(r)
        if r.get("error"):
            print(f"\033[31mFAIL\033[0m  {r['error'][:60]}")
        else:
            print(
                f"\033[32mOK\033[0m  {r['elapsed']:>4.1f}s  TTFT={r['ttft']:.2f}s  {r['tps']:>4.1f} t/s"
            )

    print("\n" + "=" * 120)
    print(
        f"{'Model':<40s} {'Time':>6s} {'TTFT':>6s} {'Ptok':>4s} {'Ctok':>4s} {'Rtok':>4s} {'t/s':>6s}  Content"
    )
    print("-" * 120)
    for m, r in zip(ALL_MODELS, results):
        if r.get("error"):
            print(f"  {m:<38s}  FAIL  {r['error'][:55]}")
        else:
            c = r["content"][:40]
            print(
                f"  {m:<38s} {r['elapsed']:>5.1f}s {r['ttft']:>5.1f}s {r['prompt_tok']:>4d} {r['completion_tok']:>4d} {r['reasoning_tok']:>4d} {r['tps']:>5.1f}  {c}"
            )

    print("\n" + "=" * 120)
    ranked = sorted(
        [(m, r) for m, r in zip(ALL_MODELS, results) if not r.get("error")],
        key=lambda x: x[1]["tps"],
        reverse=True,
    )
    print("  速度排名:")
    for m, r in ranked:
        bar = "█" * max(1, min(60, int(r["tps"] * 1.5)))
        print(
            f"  {m:<38s} {r['tps']:>5.1f} t/s  TTFT={r['ttft']:.2f}s  C={r['completion_tok']:>3d}  {bar}"
        )

    fast = [(m, r) for m, r in ranked if r["tps"] >= 20]
    mid = [(m, r) for m, r in ranked if 8 <= r["tps"] < 20]
    slow = [(m, r) for m, r in ranked if r["tps"] < 8]
    print(f"\n  \033[32mFast (>=20): {' '.join(m for m, _ in fast)}\033[0m")
    print(f"  \033[33mMid  (8-20): {' '.join(m for m, _ in mid)}\033[0m")
    print(f"  \033[31mSlow (<8): {' '.join(m for m, _ in slow)}\033[0m")


if __name__ == "__main__":
    main()
