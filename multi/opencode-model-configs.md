# opencode-multi 五套模型配置方案比对

> 本地模型: Gemma4-26B-FP8 (GPU2-3, ~260 tok/s) + Qwen3.6-27B (GPU0-1, ~100 tok/s, 262K ctx)
> 云端模型: DeepSeek V4 Flash / DeepSeek V4 Pro

## 各模块逐行对比

| 模块 | work | dev | mix-work | mix-local | local |
|------|:----:|:---:|:--------:|:---------:|:-----:|
| **Agents** | | | | | |
| sisyphus（协调） | DS Flash | DS Flash | DS Flash | Qwen3.6 | Qwen3.6 |
| prometheus（规划） | DS Pro | DS Pro | DS Pro | DS Flash | Qwen3.6 |
| hephaestus（编码） | DS Flash | DS Flash | DS Flash | Qwen3.6 | Qwen3.6 |
| oracle（推理） | DS Pro | DS Pro | DS Pro | DS Pro | Qwen3.6 |
| momus（审查） | DS Pro | DS Pro | DS Pro | DS Flash | Qwen3.6 |
| metis（风险） | DS Pro | DS Pro | DS Pro | DS Flash | Qwen3.6 |
| atlas（拆解） | DS Flash | DS Flash | DS Flash | Qwen3.6 | Qwen3.6 |
| explore（搜索） | DS Flash | Gemma4 | Gemma4 | Gemma4 | Gemma4 |
| sisyphus-junior（执行） | DS Flash | Gemma4 | Gemma4 | Gemma4 | Gemma4 |
| librarian（文档） | DS Flash | Qwen3.6 | Qwen3.6 | Qwen3.6 | Qwen3.6 |
| multimodal-looker（视觉） | DS Flash | DS Flash | DS Flash | Qwen3.6 | Qwen3.6 |
| **Categories** | | | | | |
| visual-engineering（前端） | DS Flash | Gemma4 | Gemma4 | Gemma4 | Gemma4 |
| artistry（创意） | DS Flash | Qwen3.6 | Qwen3.6 | Qwen3.6 | Qwen3.6 |
| ultrabrain（超难推理） | DS Pro | DS Pro | DS Pro | DS Pro | Qwen3.6 |
| coder（编码） | DS Flash | DS Flash | DS Flash | Qwen3.6 | Qwen3.6 |
| deep（深度研究） | DS Pro | DS Pro | DS Pro | DS Flash | Qwen3.6 |
| quick（轻量） | DS Flash | Gemma4 | Gemma4 | Gemma4 | Gemma4 |
| writing（写作） | DS Flash | Qwen3.6 | DS Flash | Qwen3.6 | Qwen3.6 |
| analysis-lite（轻分析） | DS Flash | Qwen3.6 | Qwen3.6 | Qwen3.6 | Qwen3.6 |
| unspecified-low（低优） | DS Flash | Gemma4 | Gemma4 | Gemma4 | Gemma4 |
| unspecified-high（高优） | DS Flash | DS Flash | DS Flash | Qwen3.6 | Qwen3.6 |

> **图例**: DS Pro = DeepSeek V4 Pro（云端高阶推理）| DS Flash = DeepSeek V4 Flash（云端快速推理）| Gemma4 = 本地 Gemma4-26B-FP8（~260 tok/s, 262K）| Qwen3.6 = 本地 Qwen3.6-27B（~100 tok/s, 262K）

## 汇总对比

| | work | dev | mix-work | mix-local | local |
|:----|:----:|:---:|:--------:|:---------:|:-----:|
| DS Pro | 6 | 6 | 6 | 2 | 0 |
| DS Flash | 15 | 6 | 7 | 4 | 0 |
| Qwen3.6 | 0 | 4 | 3 | 10 | 16 |
| Gemma4 | 0 | 5 | 5 | 5 | 5 |
| **云端占比** | **100%** | **57%** | **62%** | **29%** | **0%** |
| **本地占比** | 0% | 43% | 38% | 71% | 100% |

## 配置建议

| 配置 | 一句话推荐 |
|------|-----------|
| **work** | 纯云端，最高质量但有网络依赖，适合重要产出 |
| **dev** | 原默认配置，work 基础上搬 9 个模块到本地，适合日常工作 |
| **mix-work** | 保留 DS 全分工（Pro 不动），仅 6 类纯速度型放本地，**当前最推荐的工作配置** |
| **mix-local** | 最大化本地（71%），仅 6 个强推理模块走云端（oracle/ultrabrain 用 Pro），**日常迭代最佳** |
| **local** | 纯本地 0 成本，适合批量简单任务、断网环境 |

## 性能基准（本地模型）

| 模型 | 单用户 tok/s | 并发 tok/s | Score | 上下文 | SWE-bench |
|------|:-----------:|:---------:|:----:|:-----:|:---------:|
| Gemma4-26B-FP8 (TP2, MTP=4) | ~260 | 228 | 85.1 | 262K | — |
| Qwen3.6-27B (TP2, MTP=3) | ~100 | 86 | 69.3 | 262K | 77.2% |

## 配置原则

- **work**: 编码质量最高优先级。所有模块使用 DS，其中 6 个高推理模块用 Pro。
- **dev**: 在 work 基础上，将搜索/执行/轻量/前端/视觉等 9 个低逻辑影响模块迁移到本地加速。
- **mix-work**: 保留 DS 全分工（保持原 Pro 级别不变），仅 6 个纯速度型模块放本地（Gemma4/Qwen3.6），所有本地模块设 DS Flash 兜底。
- **mix-local**: 最大化本地使用（71%），仅 6 个强推理模块走云端。oracle 和 ultrabrain 升级到 DS Pro。
- **local**: 纯本地，无云端依赖。Gemma4 处理 5 个速度敏感模块，Qwen3.6 处理其余 16 个。
