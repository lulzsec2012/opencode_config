#!/usr/bin/env bash
# qoder-setup.sh — 安装 qodercli 并配置 opencode 集成
#
# 使用场景：
#   1. 首次在新机器上部署 qoder + opencode
#   2. 无头环境（SSH 无 GUI），通过 Personal Access Token (PAT) 登录
#
# PAT 获取地址（在自己桌面浏览器打开）：
#   https://qoder.com/account/integrations
#
# 用法：
#   bash scripts/opencode/scripts/qoder-setup.sh
#   # 或先设好 PAT 再一键:
#   QODER_PERSONAL_ACCESS_TOKEN="pt-..." bash scripts/opencode/scripts/qoder-setup.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SINGLE_CFG="$REPO_DIR/single/opencode.json"
MULTI_DIR="$REPO_DIR/multi"
PLUGIN_NAME="opencode-qoder-auth"

# ---------- colors ----------
info()  { echo -e "  \033[36m->\033[0m $*"; }
ok()    { echo -e "  \033[32mOK\033[0m $*"; }
warn()  { echo -e "  \033[33m!>\033[0m $*"; }
action(){ echo -e "\033[1m\n== $* ==\033[0m"; }

echo ""
echo "Qoder CLI — 安装 & OpenCode 集成"
echo "=================================="
echo ""

# ---------- 1. 安装 qodercli ----------
action "检查 / 安装 qodercli"

if command -v qodercli &>/dev/null; then
  ok "qodercli 已安装: $(qodercli --version 2>/dev/null || echo '版本未知')"
else
  info "正在通过 npm 全局安装 @qoder-ai/qodercli ..."
  npm install -g @qoder-ai/qodercli
  ok "qodercli 安装完成: $(qodercli --version 2>/dev/null || echo '版本未知')"
fi

# ---------- 2. 登录 ----------
action "Qoder 登录"

if [ -f "$HOME/.qoder/.auth/user" ]; then
  ok "检测到已有登录会话 (~/.qoder/.auth/user)"
else
  # 优先用环境变量中的 PAT
  if [ -n "${QODER_PERSONAL_ACCESS_TOKEN:-}" ]; then
    info "使用 QODER_PERSONAL_ACCESS_TOKEN 登录..."
    QODER_PERSONAL_ACCESS_TOKEN="$QODER_PERSONAL_ACCESS_TOKEN" qodercli login --pat 2>/dev/null || \
      QODER_PERSONAL_ACCESS_TOKEN="$QODER_PERSONAL_ACCESS_TOKEN" qodercli /login <<< $'2\n' 2>/dev/null || true
    # fallback: 直接写 auth file
    if [ ! -f "$HOME/.qoder/.auth/user" ]; then
      mkdir -p "$HOME/.qoder/.auth"
      cat > "$HOME/.qoder/.auth/user" <<-EOF
{
  "personal_access_token": "${QODER_PERSONAL_ACCESS_TOKEN}"
}
EOF
      ok "PAT 已写入 ~/.qoder/.auth/user"
    fi
  else
    echo ""
    warn "未检测到 QODER_PERSONAL_ACCESS_TOKEN 环境变量。"
    echo ""
    echo "  请在桌面浏览器打开以下地址获取 Personal Access Token:"
    echo "    https://qoder.com/account/integrations"
    echo ""
    echo "  然后执行:"
    echo "    export QODER_PERSONAL_ACCESS_TOKEN=\"pt-...\""
    echo "    bash $0"
    echo ""
    echo "  或手动运行 qodercli 后输入 /login 选择 PAT 方式登录。"
    echo ""
    exit 1
  fi
fi

# ---------- 3. 写入 opencode 配置 ----------
action "添加 opencode-qoder-auth 插件到所有 profile"

# 需要添加 jq 来修改 JSON
if ! command -v jq &>/dev/null; then
  info "正在安装 jq ..."
  apt-get update -qq && apt-get install -y -qq jq
fi

add_plugin() {
  local file="$1"
  local label="$2"
  [ -f "$file" ] || { warn "$label: 文件不存在，跳过"; return; }

  # 检查是否已有该插件
  if jq -e ".plugin | index(\"$PLUGIN_NAME\")" "$file" >/dev/null 2>&1; then
    ok "$label: 已包含 $PLUGIN_NAME，跳过"
    return
  fi

  # 追加插件（保持数组排序）
  jq --arg p "$PLUGIN_NAME" '.plugin += [$p] | .plugin |= unique' "$file" > "${file}.tmp"
  mv "${file}.tmp" "$file"
  ok "$label: 已添加 $PLUGIN_NAME"
}

# single
add_plugin "$SINGLE_CFG" "single/opencode.json"

# multi profiles
for profile_dir in "$MULTI_DIR"/*/; do
  [ -d "$profile_dir" ] || continue
  name=$(basename "$profile_dir")
  cfg="$profile_dir/opencode.json"
  add_plugin "$cfg" "multi/$name/opencode.json"
done

# ---------- 4. 验证 ----------
action "验证"

echo ""
echo "  Qoder CLI 就绪:      $(qodercli --version 2>/dev/null || echo '?')"
echo "  登录状态:            $( [ -f "$HOME/.qoder/.auth/user" ] && echo '已登录' || echo '未登录')"
echo "  已配置 profile:"
for f in "$SINGLE_CFG" "$MULTI_DIR"/*/opencode.json; do
  [ -f "$f" ] || continue
  has=$(jq -e ".plugin | index(\"$PLUGIN_NAME\")" "$f" >/dev/null 2>&1 && echo '✓' || echo '✗')
  echo "    $has  $(realpath --relative-to="$REPO_DIR" "$f")"
done

echo ""
echo ""
info "下一步（在 opencode 中验证）:"
echo "    opencode models | grep qoder"
echo "    opencode run -m qoder/lite \"hello\""
echo ""
info "如需在 ~/.bashrc 中持久化 PAT 避免每次手动 export:"
echo '    echo "export QODER_PERSONAL_ACCESS_TOKEN=\"pt-...\"" >> ~/.bashrc'
echo ""
