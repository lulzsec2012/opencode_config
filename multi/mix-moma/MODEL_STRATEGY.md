# MOMA 模型绑定策略 v2 — 基于全面调研

## 模型能力一览

### 🌟 开源 SOTA Agentic 模型

| 模型 | 架构 | 核心优势 | 关键指标 | 最适合 |
|------|------|---------|---------|--------|
| **GLM-5** (z.ai/glm-5) | 744B MoE, 40B active | 开源最强 Agentic Engineering | SWE-bench 77.8%, MCP-Atlas 67.8, τ²-Bench 89.7, Vending Bench #1 OS | 复杂规划、Architecture设计、Agent多步执行 |
| **GLM-5.1** | 同上升级 | 改进版，多模态文档输出 | 可生成docx/pdf/xlsx/PPT | 创意写作、文档生成 |
| **GLM-5.2** | 最新版 | 最强多模态+Agentic | 26 t/s, 稳定 | 综合Agentic任务首选 |
| **Kimi K2.6** | MoE, 32B active | 长周期编码稳定性 | Terminal-Bench 66.7, SWE-Bench Pro 58.6, 4000+ tool calls/12h | 持续编码、长周期Agent |
| **Kimi K2.5 Thinking** | MoE, 32B active, MoonViT | 原生多模态+推理 | HLE 50.2 w/tools, 200+步推理链, MMMU-Pro 78.5 | 多模态推理、视觉分析 |
| **MiniMax M2.7** | 230B MoE, 9.8B active | 自进化+SRE/DevOps | SWE-Pro 56.22%, SWE Multilingual 76.5, GDPval-AA ELO 1495 | 代码审查、缺陷分析、SRE |
| **MiniMax M2.5** | MoE | 极致编码速度 | SWE-bench 80.2%, 100 tps, 37% faster than M2.1 | 快速迭代编码 |

### ⚡ 高速通用模型

| 模型 | 架构 | 速度(实测) | TTFT | 特点 |
|------|------|-----------|------|------|
| **GPT-OSS-120B** | 120B | 119 t/s | 1.7s | 极速吞吐，高可用 |
| **NVIDIA Nemotron 120B** | 120B/12B active, Mamba+MoE | 95 t/s | 2.0s | **1M上下文**，PinchBench 85.6% |
| **Qwen3-Coder-Next** | 80B/3B active | 50 t/s | 4.1s | 3B active极致效率，SWE-bench 71.3% |
| **Qwen3.6-35B** | 35B | 49 t/s | 4.2s | 高通量通用 |
| **九天 Da-35B** | 35B | 35 t/s | 5.7s | 九天自研高吞吐 |

### 🔬 专业模型

| 模型 | 特点 | 实测速度 | TTFT | 适用 |
|------|------|---------|------|------|
| **九天 Code-8B** | 代码理解专用 | 24 t/s | 0.9s | 代码搜索、快速分析 |
| **九天 Math-8B** | 数学计算专用 | 31 t/s | 1.0s | 数值分析 |
| **九天蓝 Thinking** | 国产推理模型 | 30 t/s | 6.6s | 中文深度推理 |
| **九天蓝 13B** | 极小TTFT | 20 t/s | 0.8s | 超快响应 |
| **九天蓝 8B** | 最小模型 | 15 t/s | 0.8s | 低优任务 |

---

## Agent 绑定策略 — 全面优化

### 核心理念
1. **GLM-5 系列是开源最强 Agentic** — 取代 DeepSeek 作为主协调/规划/编码模型
2. **Kimi K2.6/K2.5 是编码和多模态王者** — 编码主力 + 视觉分析
3. **MiniMax M2.7 是 SRE/审查专家** — 用于代码审查和缺陷分析
4. **Nemotron 是超长上下文王者** — 1M 上下文用于文档/深度研究
5. **GPT-OSS 是高可用兜底** — 最快速度做 unspecified-high
6. **九天专业小模型做极速任务** — Code-8B/Math-8B/蓝系列做 quick/轻量

### Agents 绑定

```
sisyphus     → GLM-5.2      (最强Agentic，擅长复杂决策与协调)
prometheus   → GLM-5        (Vending Bench #1，长周期规划王者)
hephaestus   → Kimi K2.6    (Terminal-Bench 66.7，12小时稳定编码)
oracle       → K2.5 Thinking (HLE 50.2，200+步推理链)
momus        → MiniMax M2.7  (SRE/DevOps审查，97%技能遵循)
metis        → DeepSeek R1   (纯推理模型，反事实/边界条件分析)
atlas        → 九天Code-8B   (TTFT=0.9s极速拆解)
explore      → 九天Code-8B   (代码搜索最快)
librarian    → Nemotron 120B (1M上下文，PinchBench 85.6%)
sisyphus-jr  → 九天蓝13B     (TTFT=0.8s极速响应)
multimodal   → K2.5 Thinking (MoonViT原生多模态)
```

### Categories 绑定

```
visual-engineer → K2.5 Thinking (多模态SOTA)
artistry       → GLM-5.1       (可生成docx/pdf，33t/s)
ultrabrain     → K2.5 Thinking (HLE 50.2)
deep           → K2.5 Thinking (深度研究+Agent Swarm)
coder          → Kimi K2.6     (Terminal-Bench 66.7)
quick          → 九天Code-8B   (TTFT=0.9s)
writing        → GLM-5.1       (一键docx/pdf/xlsx)
analysis-lite  → 九天Math-8B   (数学专业)
unspecified-low → 九天蓝8B      (最小最快)
unspecified-high → GPT-OSS 120B (119t/s极速兜底)
```

### 用到的模型（15/26，之前只用9个）

✅ 已使用：GLM-5/5.1/5.2, Kimi K2.6/K2.5, DeepSeek R1/V4-flash, MiniMax M2.7, Nemotron, GPT-OSS, Qwen3-Coder, 九天Code/Math/蓝8B/蓝13B/蓝Thinking

⏸️ 备用（未直接绑定但作为 fallback）：DeepSeek V3/V32, Qwen3.5/3.6 系列, MiniMax M2.5/latest, 九天蓝35B/236B/Da-35B, Auto

> 更新时间: 2026-07-22
