#!/usr/bin/env python3
"""Compare two benchmark runs and generate stability report + model doc."""

import json

# Run 1 data (2026-07-22 23:23)
RUN1 = {
    "z.ai/glm-5": {"ttft": 6.58, "tps": 30.4, "ctok": 200},
    "z.ai/glm-5.1": {"ttft": 6.10, "tps": 32.8, "ctok": 200},
    "z.ai/glm-5.2": {"ttft": 7.75, "tps": 25.8, "ctok": 200},
    "deepseek/deepseek-r1": {"ttft": 1.82, "tps": 5.5, "ctok": 10},
    "deepseek/deepseek-v32": {"ttft": 1.53, "tps": 6.5, "ctok": 10},
    "deepseek/deepseek-v3": {"ttft": 1.39, "tps": 7.2, "ctok": 10},
    "deepseek/deepseek-v4-flash": {"ttft": 1.51, "tps": 6.6, "ctok": 10},
    "qwen/qwen3.5-397b-a17b": {"ttft": 6.53, "tps": 30.6, "ctok": 200},
    "qwen/qwen3.6-35b": {"ttft": 4.07, "tps": 49.1, "ctok": 200},
    "qwen/qwen3.6-27b": {"ttft": 4.54, "tps": 44.0, "ctok": 200},
    "qwen/qwen3-235b-a22b-2507": {"ttft": 0.77, "tps": 14.2, "ctok": 11},
    "qwen/qwen3-coder-next": {"ttft": 3.97, "tps": 50.4, "ctok": 200},
    "moonshotai/kimi-k2.6": {"ttft": 14.86, "tps": 13.5, "ctok": 200},
    "moonshotai/kimi-k2.5-thinking": {"ttft": 12.13, "tps": 16.5, "ctok": 200},
    "minimax/minimax-m2.7": {"ttft": None, "tps": None, "ctok": 0, "error": "503"},
    "minimax/minimax-m2.5": {"ttft": 5.82, "tps": 34.4, "ctok": 200},
    "minimax/minimax-latest": {"ttft": 14.64, "tps": 13.7, "ctok": 200},
    "jiutian/jiutian-lan-35b": {"ttft": 2.33, "tps": 5.2, "ctok": 12},
    "jiutian/jiutian-da-35b": {"ttft": 5.65, "tps": 35.4, "ctok": 200},
    "jiutian/jiutian-lan-236b": {"ttft": 2.06, "tps": 5.3, "ctok": 11},
    "jiutian/jiutian-lan-13b": {"ttft": 0.82, "tps": 19.6, "ctok": 16},
    "jiutian/jiutian-lan-8b": {"ttft": 0.79, "tps": 15.1, "ctok": 12},
    "jiutian/jiutian-lan-thinking": {"ttft": 6.58, "tps": 30.4, "ctok": 200},
    "jiutian/jiutian-code-8b": {"ttft": 1.09, "tps": 19.3, "ctok": 21},
    "jiutian/jiutian-math-8b": {"ttft": 1.05, "tps": 32.3, "ctok": 34},
    "nvidia/nemotron-3-super-120b-a12b": {"ttft": 1.88, "tps": 95.1, "ctok": 179},
    "openai/gpt-oss-120b": {"ttft": 1.68, "tps": 119.1, "ctok": 200},
    "moma/auto": {"ttft": 2.02, "tps": 5.9, "ctok": 12},
}

# Run 2 data (2026-07-22 23:39)
RUN2 = {
    "z.ai/glm-5": {"ttft": 6.95, "tps": 28.8, "ctok": 200},
    "z.ai/glm-5.1": {"ttft": 7.27, "tps": 27.5, "ctok": 200},
    "z.ai/glm-5.2": {"ttft": 7.38, "tps": 27.1, "ctok": 200},
    "deepseek/deepseek-r1": {"ttft": 1.67, "tps": 6.0, "ctok": 10},
    "deepseek/deepseek-v32": {"ttft": 1.77, "tps": 5.6, "ctok": 10},
    "deepseek/deepseek-v3": {"ttft": 1.50, "tps": 6.7, "ctok": 10},
    "deepseek/deepseek-v4-flash": {"ttft": 1.86, "tps": 7.5, "ctok": 14},
    "qwen/qwen3.5-397b-a17b": {"ttft": 8.45, "tps": 23.7, "ctok": 200},
    "qwen/qwen3.6-35b": {"ttft": 4.33, "tps": 46.2, "ctok": 200},
    "qwen/qwen3.6-27b": {"ttft": 4.18, "tps": 47.8, "ctok": 200},
    "qwen/qwen3-235b-a22b-2507": {"ttft": 0.82, "tps": 13.4, "ctok": 11},
    "qwen/qwen3-coder-next": {"ttft": 3.81, "tps": 52.4, "ctok": 200},
    "moonshotai/kimi-k2.6": {"ttft": 14.24, "tps": 14.0, "ctok": 200},
    "moonshotai/kimi-k2.5-thinking": {"ttft": 12.01, "tps": 16.6, "ctok": 200},
    "minimax/minimax-m2.7": {"ttft": 11.40, "tps": 17.5, "ctok": 200},
    "minimax/minimax-m2.5": {"ttft": 17.49, "tps": 11.4, "ctok": 200},
    "minimax/minimax-latest": {"ttft": 18.34, "tps": 10.9, "ctok": 200},
    "jiutian/jiutian-lan-35b": {"ttft": 1.18, "tps": 10.2, "ctok": 12},
    "jiutian/jiutian-da-35b": {"ttft": 5.69, "tps": 35.2, "ctok": 200},
    "jiutian/jiutian-lan-236b": {"ttft": 2.19, "tps": 5.0, "ctok": 11},
    "jiutian/jiutian-lan-13b": {"ttft": 0.86, "tps": 19.8, "ctok": 17},
    "jiutian/jiutian-lan-8b": {"ttft": 0.85, "tps": 16.5, "ctok": 14},
    "jiutian/jiutian-lan-thinking": {"ttft": 6.61, "tps": 30.2, "ctok": 200},
    "jiutian/jiutian-code-8b": {"ttft": 0.93, "tps": 26.8, "ctok": 25},
    "jiutian/jiutian-math-8b": {"ttft": 1.05, "tps": 30.6, "ctok": 32},
    "nvidia/nemotron-3-super-120b-a12b": {"ttft": 1.48, "tps": 84.2, "ctok": 125},
    "openai/gpt-oss-120b": {"ttft": 1.77, "tps": 112.7, "ctok": 200},
    "moma/auto": {"ttft": 1.47, "tps": 8.2, "ctok": 12},
}

CATEGORIES = {
    "z.ai": "GLM 系列 (智谱)",
    "deepseek": "DeepSeek 系列",
    "qwen": "Qwen 系列 (通义千问)",
    "moonshotai": "Kimi 系列 (月之暗面)",
    "minimax": "MiniMax 系列",
    "jiutian/jiutian-lan": "九天蓝系列",
    "jiutian/jiutian-da": "九天达系列",
    "jiutian/jiutian-lan-thinking": "九天蓝 Thinking",
    "jiutian/jiutian-code": "九天 Code",
    "jiutian/jiutian-math": "九天 Math",
    "nvidia": "NVIDIA 系列",
    "openai": "GPT-OSS 系列",
    "moma": "MOMA 路由",
}


def short_name(m):
    return m.split("/")[-1]


def categorize(m):
    for prefix, cat in CATEGORIES.items():
        if m.startswith(prefix):
            return cat
    return m.split("/")[0]


# Compare
all_models = sorted(set(list(RUN1.keys()) + list(RUN2.keys())))

lines = []
lines.append("# 九天模型平台 (jiutian-moma) 基准测试报告")
lines.append(f"")
lines.append(f"> 生成时间: 2026-07-22")
lines.append(
    f"> 测试方法: 非流式单轮请求，短提示 `用一句话解释什么是量子计算。返回20个字以内。`"
)
lines.append(f"> 参数: temperature=0.1, max_tokens=200")
lines.append(f"> 测试端点: `https://jiutian.10086.cn/largemodel/moma/api/v3`")
lines.append(f"")
lines.append("## 稳定性对比 (两轮测试)")
lines.append("")
lines.append("| 模型 | Run1 t/s | Run2 t/s | 偏差% | Run1 TTFT | Run2 TTFT | 稳定性 |")
lines.append("|------|---------|---------|-------|----------|----------|--------|")

stable_count = 0
volatile_count = 0

for m in all_models:
    r1 = RUN1.get(m, {})
    r2 = RUN2.get(m, {})
    tps1 = r1.get("tps")
    tps2 = r2.get("tps")
    ttft1 = r1.get("ttft")
    ttft2 = r2.get("ttft")

    if tps1 is None or tps2 is None:
        status = "N/A (一轮失败)"
    else:
        if tps1 > 0 and tps2 > 0:
            pct = abs(tps2 - tps1) / tps1 * 100
        else:
            pct = 999
        if pct < 15:
            status = "✅ 稳定"
            stable_count += 1
        elif pct < 30:
            status = "⚠️ 波动"
            volatile_count += 1
        else:
            status = "🔥 剧烈波动"
            volatile_count += 1

    sn = short_name(m)
    tps1_s = f"{tps1:.1f}" if tps1 else "-"
    tps2_s = f"{tps2:.1f}" if tps2 else "-"
    ttft1_s = f"{ttft1:.2f}s" if ttft1 else "-"
    ttft2_s = f"{ttft2:.2f}s" if ttft2 else "-"
    pct_s = f"{pct:.0f}%" if tps1 and tps2 else "-"
    lines.append(
        f"| {sn} | {tps1_s} | {tps2_s} | {pct_s} | {ttft1_s} | {ttft2_s} | {status} |"
    )

lines.append(f"")
lines.append(
    f"> 稳定: {stable_count}/{len(all_models)}  |  波动: {volatile_count}/{len(all_models)}"
)
lines.append(f"")

# Recommendation tiers
lines.append("## 模型推荐分级")
lines.append("")
lines.append("基于两轮平均性能，按 Tokens/s 和 TTFT 综合评级：")
lines.append("")

# Average the two runs
avg_data = {}
for m in all_models:
    r1 = RUN1.get(m, {})
    r2 = RUN2.get(m, {})
    tps1 = r1.get("tps") or 0
    tps2 = r2.get("tps") or 0
    ttft1 = r1.get("ttft") or 999
    ttft2 = r2.get("ttft") or 999
    ctok1 = r1.get("ctok") or 0
    ctok2 = r2.get("ctok") or 0

    if tps1 == 0 and tps2 == 0:
        continue

    avg_data[m] = {
        "avg_tps": (tps1 + tps2) / 2,
        "avg_ttft": (ttft1 + ttft2) / 2
        if ttft1 != 999 and ttft2 != 999
        else min(ttft1, ttft2),
        "avg_ctok": (ctok1 + ctok2) / 2,
    }

# Sort by tps descending
sorted_models = sorted(
    avg_data.keys(), key=lambda m: avg_data[m]["avg_tps"], reverse=True
)

# Speed tiers
fast = [(m, avg_data[m]) for m in sorted_models if avg_data[m]["avg_tps"] >= 20]
mid = [(m, avg_data[m]) for m in sorted_models if 8 <= avg_data[m]["avg_tps"] < 20]
slow = [(m, avg_data[m]) for m in sorted_models if avg_data[m]["avg_tps"] < 8]

lines.append("### 🚀 快速 (>= 20 t/s)")
lines.append("")
lines.append("| 模型 | 系列 | 平均 t/s | TTFT | 适合场景 |")
lines.append("|------|------|---------|------|---------|")
for m, d in fast:
    cat = categorize(m)
    sn = short_name(m)
    ttft_s = f"{d['avg_ttft']:.2f}s" if d["avg_ttft"] != 999 else "?"
    if "coder" in m:
        scene = "代码生成"
    elif "math" in m:
        scene = "数学计算"
    elif "thinking" in m:
        scene = "深度思考任务"
    elif "da" in m:
        scene = "综合通用"
    elif "lan-thinking" in m:
        scene = "通用推理"
    elif "glm" in m:
        scene = "多模态/创意写作"
    elif "gpt-oss" in m:
        scene = "高速通用"
    elif "nemotron" in m:
        scene = "高速通用"
    elif "qwen" in m:
        scene = "高通量通用"
    elif "code-8b" in m:
        scene = "代码快速搜索"
    else:
        scene = "通用"
    lines.append(f"| {sn} | {cat} | {d['avg_tps']:.0f} | {ttft_s} | {scene} |")

lines.append("")
lines.append("### ⚡ 中等 (8-20 t/s)")
lines.append("")
lines.append("| 模型 | 系列 | 平均 t/s | TTFT | 适合场景 |")
lines.append("|------|------|---------|------|---------|")
for m, d in mid:
    cat = categorize(m)
    sn = short_name(m)
    ttft_s = f"{d['avg_ttft']:.2f}s" if d["avg_ttft"] != 999 else "?"
    if "kimi" in m:
        scene = "推理分析"
    elif "lan-13b" in m or "lan-8b" in m:
        scene = "轻量快速任务"
    elif "minimax" in m:
        scene = "通用(高延迟)"
    elif "qwen3-235b" in m:
        scene = "快速推理"
    elif "lan-35b" in m:
        scene = "基础通用"
    elif "auto" in m:
        scene = "自动路由"
    elif "code-8b" in m:
        scene = "代码快速"
    else:
        scene = "通用"
    lines.append(f"| {sn} | {cat} | {d['avg_tps']:.0f} | {ttft_s} | {scene} |")

lines.append("")
lines.append("### 🐢 慢速 (< 8 t/s)")
lines.append("")
lines.append("| 模型 | 系列 | 平均 t/s | TTFT | 适合场景 |")
lines.append("|------|------|---------|------|---------|")
for m, d in slow:
    cat = categorize(m)
    sn = short_name(m)
    ttft_s = f"{d['avg_ttft']:.2f}s" if d["avg_ttft"] != 999 else "?"
    if "deepseek" in m:
        scene = "推理/代码(输出简洁)"
    elif "lan-236b" in m:
        scene = "超大模型保底"
    else:
        scene = "通用"
    lines.append(f"| {sn} | {cat} | {d['avg_tps']:.0f} | {ttft_s} | {scene} |")

# Detailed info
lines.append("")
lines.append("## 详细数据")
lines.append("")
lines.append("| 模型 | 系列 | 平均 t/s | 平均 TTFT | 平均输出 tok | Categorization |")
lines.append("|------|------|---------|----------|------------|---------------|")
for m in sorted_models:
    d = avg_data[m]
    cat = categorize(m)
    sn = short_name(m)
    lines.append(
        f"| {sn} | {cat} | {d['avg_tps']:.0f} | {d['avg_ttft']:.2f}s | {d['avg_ctok']:.0f} | {'fast' if d['avg_tps'] >= 20 else 'mid' if d['avg_tps'] >= 8 else 'slow'} |"
    )

# Current binding map
lines.append("")
lines.append("## 当前 Agent 绑定方案")
lines.append("")
lines.append("基于上述测试数据，当前配置的模型绑定策略如下：")
lines.append("")
lines.append("| 角色 | 主模型 | 平均 t/s | TTFT | 理由 |")
lines.append("|------|--------|---------|------|------|")
bindings = [
    (
        "sisyphus (协调)",
        "deepseek-v4-flash",
        7.1,
        1.69,
        "最低 TTFT，输出简洁，适合频繁决策",
    ),
    ("prometheus (规划)", "deepseek-v3", 7.0, 1.45, "推理与速度均衡"),
    ("hephaestus (编码)", "qwen3-coder-next", 51.4, 3.89, "代码专业模型，高通量"),
    ("oracle (推理)", "deepseek-r1", 5.8, 1.75, "强推理能力，适合深度分析"),
    ("momus (审查)", "deepseek-v4-flash", 7.1, 1.69, "低延迟快速审查"),
    ("metis (风险)", "deepseek-r1", 5.8, 1.75, "风险分析需要推理能力"),
    ("atlas (拆解)", "deepseek-v4-flash", 7.1, 1.69, "低延迟快速拆解"),
    ("explore (搜索)", "code-8b", 23.1, 1.01, "代码理解 + 低 TTFT"),
    ("librarian (文档)", "qwen3.6-35b", 47.7, 4.20, "高通量适合长文档"),
    ("sisyphus-junior (执行)", "qwen3.6-27b", 45.9, 4.36, "高通量轻量执行"),
    ("multimodal-looker (视觉)", "glm-5.2", 26.5, 7.57, "多模态能力最强"),
]
for name, model, tps, ttft, reason in bindings:
    lines.append(f"| {name} | {model} | {tps:.0f} | {ttft:.2f}s | {reason} |")

# Notes
lines.append("")
lines.append("## 注意事项")
lines.append("")
lines.append(
    "1. **TTFT vs 吞吐量**: 低 TTFT 模型（如 deepseek 系列 1.5s）适合交互式频繁调用的角色（协调器），高吞吐模型（如 qwen 系列 47 t/s）适合批处理角色（文档、代码）。"
)
lines.append(
    "2. **内容格式差异**: GLM 系列将输出放在 `reasoning` 字段而非 `content` 字段，与 OpenAI 标准格式不同，需要注意 opencode 兼容性。"
)
lines.append(
    "3. **MiniMax 系列不稳定**: m2.7 在首轮 503 不可用，m2.5 和 latest 的 TTFT 波动大（5.8s→17.5s），不建议作为主力。"
)
lines.append(
    "4. **Qwen 输出含推理过程**: qwen3.5-397b、qwen3.6-35b/27b 等模型会在输出中附带 Thinking Process，可能影响 agent 的简洁性要求。"
)
lines.append(
    "5. **Prompt 长度影响**: 测试用的短 prompt（25 tokens）并不能完全代表真实场景性能。带大量上下文的工作负载下速度会有变化。"
)
lines.append(
    "6. **API Key 过期**: 九天平台的 API Key 绑定 OIDC，最长 7 天有效期。过期后需运行 `refresh_key.py` 刷新。"
)

print("\n".join(lines))
