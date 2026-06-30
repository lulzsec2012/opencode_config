#!/usr/bin/env bash
# mcp-reva-wrapper.sh — 为 OpenCode MCP 启动 ReVa，自动加载环境变量
#
# OpenCode 启动 MCP server 时不 source .bashrc，
# 此包装脚本确保 GHIDRA_INSTALL_DIR 正确设置。
#
# 用法: 在 opencode.json 中引用此脚本:
#   "ReVa": {
#     "type": "local",
#     "command": ["bash", "<repo>/scripts/opencode/scripts/mcp-reva-wrapper.sh"],
#     "enabled": true
#   }

set -euo pipefail

# 自动检测 Ghidra 安装目录
GHIDRA_DIR=""
for _d in "$HOME/.local/opt/ghidra_"*_PUBLIC; do
  if [ -f "$_d/ghidraRun" ]; then
    GHIDRA_DIR="$_d"
    break
  fi
done

if [ -z "$GHIDRA_DIR" ]; then
  echo "Error: Ghidra not found in ~/.local/opt/ghidra_*_PUBLIC" >&2
  echo "Run scripts/opencode/scripts/install-reva.sh first" >&2
  exit 1
fi

export GHIDRA_INSTALL_DIR="$GHIDRA_DIR"
export PATH="$GHIDRA_DIR/support:$PATH"

exec mcp-reva "$@"
