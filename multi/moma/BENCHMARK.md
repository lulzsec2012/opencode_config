# 九天模型平台 (jiutian-moma) 基准测试报告

> 生成时间: 2026-07-22
> 测试方法: 非流式单轮请求，短提示 `用一句话解释什么是量子计算。返回20个字以内。`
> 参数: temperature=0.1, max_tokens=200
> 测试端点: `https://jiutian.10086.cn/largemodel/moma/api/v3`

## 稳定性对比 (两轮测试)

| 模型 | Run1 t/s | Run2 t/s | 偏差% | Run1 TTFT | Run2 TTFT | 稳定性 |
|------|---------|---------|-------|----------|----------|--------|
| deepseek-r1 | 5.5 | 6.0 | 9% | 1.82s | 1.67s | ✅ 稳定 |
| deepseek-v3 | 7.2 | 6.7 | 7% | 1.39s | 1.50s | ✅ 稳定 |
| deepseek-v32 | 6.5 | 5.6 | 14% | 1.53s | 1.77s | ✅ 稳定 |
| deepseek-v4-flash | 6.6 | 7.5 | 14% | 1.51s | 1.86s | ✅ 稳定 |
| jiutian-code-8b | 19.3 | 26.8 | 39% | 1.09s | 0.93s | 🔥 剧烈波动 |
| jiutian-da-35b | 35.4 | 35.2 | 1% | 5.65s | 5.69s | ✅ 稳定 |
| jiutian-lan-13b | 19.6 | 19.8 | 1% | 0.82s | 0.86s | ✅ 稳定 |
| jiutian-lan-236b | 5.3 | 5.0 | 6% | 2.06s | 2.19s | ✅ 稳定 |
| jiutian-lan-35b | 5.2 | 10.2 | 96% | 2.33s | 1.18s | 🔥 剧烈波动 |
| jiutian-lan-8b | 15.1 | 16.5 | 9% | 0.79s | 0.85s | ✅ 稳定 |
| jiutian-lan-thinking | 30.4 | 30.2 | 1% | 6.58s | 6.61s | ✅ 稳定 |
| jiutian-math-8b | 32.3 | 30.6 | 5% | 1.05s | 1.05s | ✅ 稳定 |
| minimax-latest | 13.7 | 10.9 | 20% | 14.64s | 18.34s | ⚠️ 波动 |
| minimax-m2.5 | 34.4 | 11.4 | 67% | 5.82s | 17.49s | 🔥 剧烈波动 |
| minimax-m2.7 | - | 17.5 | - | - | 11.40s | N/A (一轮失败) |
| auto | 5.9 | 8.2 | 39% | 2.02s | 1.47s | 🔥 剧烈波动 |
| kimi-k2.5-thinking | 16.5 | 16.6 | 1% | 12.13s | 12.01s | ✅ 稳定 |
| kimi-k2.6 | 13.5 | 14.0 | 4% | 14.86s | 14.24s | ✅ 稳定 |
| nemotron-3-super-120b-a12b | 95.1 | 84.2 | 11% | 1.88s | 1.48s | ✅ 稳定 |
| gpt-oss-120b | 119.1 | 112.7 | 5% | 1.68s | 1.77s | ✅ 稳定 |
| qwen3-235b-a22b-2507 | 14.2 | 13.4 | 6% | 0.77s | 0.82s | ✅ 稳定 |
| qwen3-coder-next | 50.4 | 52.4 | 4% | 3.97s | 3.81s | ✅ 稳定 |
| qwen3.5-397b-a17b | 30.6 | 23.7 | 23% | 6.53s | 8.45s | ⚠️ 波动 |
| qwen3.6-27b | 44.0 | 47.8 | 9% | 4.54s | 4.18s | ✅ 稳定 |
| qwen3.6-35b | 49.1 | 46.2 | 6% | 4.07s | 4.33s | ✅ 稳定 |
| glm-5 | 30.4 | 28.8 | 5% | 6.58s | 6.95s | ✅ 稳定 |
| glm-5.1 | 32.8 | 27.5 | 16% | 6.10s | 7.27s | ⚠️ 波动 |
| glm-5.2 | 25.8 | 27.1 | 5% | 7.75s | 7.38s | ✅ 稳定 |

> 稳定: 20/28  |  波动: 7/28

## 模型推荐分级

基于两轮平均性能，按 Tokens/s 和 TTFT 综合评级：

### 🚀 快速 (>= 20 t/s)

| 模型 | 系列 | 平均 t/s | TTFT | 适合场景 |
|------|------|---------|------|---------|
| gpt-oss-120b | GPT-OSS 系列 | 116 | 1.73s | 高速通用 |
| nemotron-3-super-120b-a12b | NVIDIA 系列 | 90 | 1.68s | 高速通用 |
| qwen3-coder-next | Qwen 系列 (通义千问) | 51 | 3.89s | 代码生成 |
| qwen3.6-35b | Qwen 系列 (通义千问) | 48 | 4.20s | 高通量通用 |
| qwen3.6-27b | Qwen 系列 (通义千问) | 46 | 4.36s | 高通量通用 |
| jiutian-da-35b | 九天达系列 | 35 | 5.67s | 综合通用 |
| jiutian-math-8b | 九天 Math | 31 | 1.05s | 数学计算 |
| jiutian-lan-thinking | 九天蓝系列 | 30 | 6.60s | 深度思考任务 |
| glm-5.1 | GLM 系列 (智谱) | 30 | 6.68s | 多模态/创意写作 |
| glm-5 | GLM 系列 (智谱) | 30 | 6.77s | 多模态/创意写作 |
| qwen3.5-397b-a17b | Qwen 系列 (通义千问) | 27 | 7.49s | 高通量通用 |
| glm-5.2 | GLM 系列 (智谱) | 26 | 7.56s | 多模态/创意写作 |
| jiutian-code-8b | 九天 Code | 23 | 1.01s | 代码快速搜索 |
| minimax-m2.5 | MiniMax 系列 | 23 | 11.65s | 通用 |

### ⚡ 中等 (8-20 t/s)

| 模型 | 系列 | 平均 t/s | TTFT | 适合场景 |
|------|------|---------|------|---------|
| jiutian-lan-13b | 九天蓝系列 | 20 | 0.84s | 轻量快速任务 |
| kimi-k2.5-thinking | Kimi 系列 (月之暗面) | 17 | 12.07s | 推理分析 |
| jiutian-lan-8b | 九天蓝系列 | 16 | 0.82s | 轻量快速任务 |
| qwen3-235b-a22b-2507 | Qwen 系列 (通义千问) | 14 | 0.79s | 快速推理 |
| kimi-k2.6 | Kimi 系列 (月之暗面) | 14 | 14.55s | 推理分析 |
| minimax-latest | MiniMax 系列 | 12 | 16.49s | 通用(高延迟) |
| minimax-m2.7 | MiniMax 系列 | 9 | 11.40s | 通用(高延迟) |

### 🐢 慢速 (< 8 t/s)

| 模型 | 系列 | 平均 t/s | TTFT | 适合场景 |
|------|------|---------|------|---------|
| jiutian-lan-35b | 九天蓝系列 | 8 | 1.75s | 通用 |
| deepseek-v4-flash | DeepSeek 系列 | 7 | 1.69s | 推理/代码(输出简洁) |
| auto | MOMA 路由 | 7 | 1.75s | 通用 |
| deepseek-v3 | DeepSeek 系列 | 7 | 1.44s | 推理/代码(输出简洁) |
| deepseek-v32 | DeepSeek 系列 | 6 | 1.65s | 推理/代码(输出简洁) |
| deepseek-r1 | DeepSeek 系列 | 6 | 1.75s | 推理/代码(输出简洁) |
| jiutian-lan-236b | 九天蓝系列 | 5 | 2.12s | 超大模型保底 |

## 详细数据

| 模型 | 系列 | 平均 t/s | 平均 TTFT | 平均输出 tok | Categorization |
|------|------|---------|----------|------------|---------------|
| gpt-oss-120b | GPT-OSS 系列 | 116 | 1.73s | 200 | fast |
| nemotron-3-super-120b-a12b | NVIDIA 系列 | 90 | 1.68s | 152 | fast |
| qwen3-coder-next | Qwen 系列 (通义千问) | 51 | 3.89s | 200 | fast |
| qwen3.6-35b | Qwen 系列 (通义千问) | 48 | 4.20s | 200 | fast |
| qwen3.6-27b | Qwen 系列 (通义千问) | 46 | 4.36s | 200 | fast |
| jiutian-da-35b | 九天达系列 | 35 | 5.67s | 200 | fast |
| jiutian-math-8b | 九天 Math | 31 | 1.05s | 33 | fast |
| jiutian-lan-thinking | 九天蓝系列 | 30 | 6.60s | 200 | fast |
| glm-5.1 | GLM 系列 (智谱) | 30 | 6.68s | 200 | fast |
| glm-5 | GLM 系列 (智谱) | 30 | 6.77s | 200 | fast |
| qwen3.5-397b-a17b | Qwen 系列 (通义千问) | 27 | 7.49s | 200 | fast |
| glm-5.2 | GLM 系列 (智谱) | 26 | 7.56s | 200 | fast |
| jiutian-code-8b | 九天 Code | 23 | 1.01s | 23 | fast |
| minimax-m2.5 | MiniMax 系列 | 23 | 11.65s | 200 | fast |
| jiutian-lan-13b | 九天蓝系列 | 20 | 0.84s | 16 | mid |
| kimi-k2.5-thinking | Kimi 系列 (月之暗面) | 17 | 12.07s | 200 | mid |
| jiutian-lan-8b | 九天蓝系列 | 16 | 0.82s | 13 | mid |
| qwen3-235b-a22b-2507 | Qwen 系列 (通义千问) | 14 | 0.79s | 11 | mid |
| kimi-k2.6 | Kimi 系列 (月之暗面) | 14 | 14.55s | 200 | mid |
| minimax-latest | MiniMax 系列 | 12 | 16.49s | 200 | mid |
| minimax-m2.7 | MiniMax 系列 | 9 | 11.40s | 100 | mid |
| jiutian-lan-35b | 九天蓝系列 | 8 | 1.75s | 12 | slow |
| deepseek-v4-flash | DeepSeek 系列 | 7 | 1.69s | 12 | slow |
| auto | MOMA 路由 | 7 | 1.75s | 12 | slow |
| deepseek-v3 | DeepSeek 系列 | 7 | 1.44s | 10 | slow |
| deepseek-v32 | DeepSeek 系列 | 6 | 1.65s | 10 | slow |
| deepseek-r1 | DeepSeek 系列 | 6 | 1.75s | 10 | slow |
| jiutian-lan-236b | 九天蓝系列 | 5 | 2.12s | 11 | slow |

## 当前 Agent 绑定方案

基于上述测试数据，当前配置的模型绑定策略如下：

| 角色 | 主模型 | 平均 t/s | TTFT | 理由 |
|------|--------|---------|------|------|
| sisyphus (协调) | deepseek-v4-flash | 7 | 1.69s | 最低 TTFT，输出简洁，适合频繁决策 |
| prometheus (规划) | deepseek-v3 | 7 | 1.45s | 推理与速度均衡 |
| hephaestus (编码) | qwen3-coder-next | 51 | 3.89s | 代码专业模型，高通量 |
| oracle (推理) | deepseek-r1 | 6 | 1.75s | 强推理能力，适合深度分析 |
| momus (审查) | deepseek-v4-flash | 7 | 1.69s | 低延迟快速审查 |
| metis (风险) | deepseek-r1 | 6 | 1.75s | 风险分析需要推理能力 |
| atlas (拆解) | deepseek-v4-flash | 7 | 1.69s | 低延迟快速拆解 |
| explore (搜索) | code-8b | 23 | 1.01s | 代码理解 + 低 TTFT |
| librarian (文档) | qwen3.6-35b | 48 | 4.20s | 高通量适合长文档 |
| sisyphus-junior (执行) | qwen3.6-27b | 46 | 4.36s | 高通量轻量执行 |
| multimodal-looker (视觉) | glm-5.2 | 26 | 7.57s | 多模态能力最强 |

## 注意事项

1. **TTFT vs 吞吐量**: 低 TTFT 模型（如 deepseek 系列 1.5s）适合交互式频繁调用的角色（协调器），高吞吐模型（如 qwen 系列 47 t/s）适合批处理角色（文档、代码）。
2. **内容格式差异**: GLM 系列将输出放在 `reasoning` 字段而非 `content` 字段，与 OpenAI 标准格式不同，需要注意 opencode 兼容性。
3. **MiniMax 系列不稳定**: m2.7 在首轮 503 不可用，m2.5 和 latest 的 TTFT 波动大（5.8s→17.5s），不建议作为主力。
4. **Qwen 输出含推理过程**: qwen3.5-397b、qwen3.6-35b/27b 等模型会在输出中附带 Thinking Process，可能影响 agent 的简洁性要求。
5. **Prompt 长度影响**: 测试用的短 prompt（25 tokens）并不能完全代表真实场景性能。带大量上下文的工作负载下速度会有变化。
6. **API Key 过期**: 九天平台的 API Key 绑定 OIDC，最长 7 天有效期。过期后需运行 `refresh_key.py` 刷新。
