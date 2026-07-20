#!/usr/bin/env bash
# qoder-run.sh - 加大 ARG_MAX 后启动 opencode-multi qoder 避免 E2BIG
#
# ARG_MAX = RLIMIT_STACK / 4 (系统有封顶 ~6MB)
# 默认 8MB 栈 → ARG_MAX = 2MB
# 改为 64MB 栈 → ARG_MAX = 6MB (×3)
#
# 用法:
#   bash qoder-run.sh              # 交互式会话
#   bash qoder-run.sh run "提问"   # 一次性指令
set -euo pipefail

OLD=$(ulimit -s)
ARGMAX_OLD=$(python3 -c "import os; print(os.sysconf('SC_ARG_MAX'))")

ulimit -s 65536 2>/dev/null || true

NEW=$(ulimit -s)
ARGMAX_NEW=$(python3 -c "import os; print(os.sysconf('SC_ARG_MAX'))")

echo "栈限制: ${OLD}KB -> ${NEW}KB"
echo "ARG_MAX: ${ARGMAX_OLD}bytes -> ${ARGMAX_NEW}bytes (x$(( ARGMAX_NEW / ARGMAX_OLD )))" >&2

exec opencode-multi run qoder "$@"
