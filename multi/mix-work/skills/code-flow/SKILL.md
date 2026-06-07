# /code-flow — 代码流程可视化

<mcp name="mermaid" />

分析指定文件/目录的代码结构，生成 Mermaid 流程图。

## Triggers

- 用户要求"画流程图"、"看代码结构"、"可视化"、"调用关系"
- 用户输入 `/code-flow` 命令
- 用户想理解一段复杂代码的整体流程

## Workflow

1. **分析代码结构**（如果指定了文件路径）
   - 通过 Grep/AST-grep/LSP 扫描文件
   - 提取: import 关系、函数定义、函数调用、类结构、数据流
   - 如果是目录，扫描所有 .py/.js/.ts 文件

2. **生成 Mermaid 流程图**
   - 根据代码结构生成合适的图表类型
   - 主图: `graph TD` 或 `flowchart TD` 展示调用链路
   - 辅助图: `classDiagram` 展示类结构（如果有类）
   - 控制流: `sequenceDiagram` 展示典型交互（如果有跨模块调用）

3. **渲染输出**
   - 通过 `skill_mcp(mcp_name="mermaid", tool_name="mermaid_preview")` 渲染到浏览器
   - 同时将 Mermaid 源码写入 `docs/flow-<filename>.md`

## Mermaid 规则

- 节点标签用双引号包裹（避免特殊字符问题）
- 分段较长的图分成多个子图 (subgraph)
- 颜色区分: 入口函数用 `fill:#green`, 关键路径用 `fill:#blue`
- 最大 50 个节点，超出则仅显示核心路径

## 输出格式

```
分析结果写入: docs/flow-generate-config.md
Mermaid 图已通过浏览器预览 (mermaid_preview)

核心路径:
  main() → load_site_groups() → generate()
  generate() → _fetch_clash() → merge()
  generate() → build_routes() → write_config()
```
