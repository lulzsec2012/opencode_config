#!/usr/bin/env bash
# setup.sh — 将 repo 配置部署到系统路径
#
# 支持 Linux / macOS。
#
# 对每个配置文件：
#   1. 系统路径不存在         → 直接建立软连接到 repo
#   2. 系统路径已是 repo 链接 → 跳过
#   3. 系统路径已存在非链接   → 备份 → 合并（保留本机独有内容）→ 建立软连接
#
# 合并策略：
#   - provider / model / agents / categories: repo 版本优先（更新）
#   - plugin[]: 合并去重，保留本机独有插件
#   - mcp{}: 合并，repo 冲突时覆盖，本机独有 mcp server 保留
#   - 本机独有顶层 key: 全部保留

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SINGLE_SRC="$REPO_DIR/single"
MULTI_SRC="$REPO_DIR/multi"
BACKUP_DIR="$HOME/.config/opencode-backup-$(date +%Y%m%d%H%M%S)"

# ---------- OS detection ----------
_os="linux"
case "$(uname -s)" in
  Darwin) _os="macos" ;;
esac

# ---------- Platform-specific config paths ----------
# opencode: always ~/.config/opencode/ (per opencode docs)
OPENCODE_CFG="$HOME/.config/opencode"

# opencode-multi: uses dirs crate → XDG on Linux, ~/Library on macOS
if [ "$_os" = "macos" ]; then
  _xdg="${XDG_CONFIG_HOME:-}"
  if [ -n "$_xdg" ]; then
    OPENCODE_MULTI_PROFILES="$_xdg/opencode-multi/profiles"
  else
    OPENCODE_MULTI_PROFILES="$HOME/Library/Application Support/opencode-multi/profiles"
  fi
else
  OPENCODE_MULTI_PROFILES="${XDG_CONFIG_HOME:-$HOME/.config}/opencode-multi/profiles"
fi

# ---------- ReVa wrapper 部署 ----------
REVA_SCRIPT_SRC="$REPO_DIR/scripts/mcp-reva-wrapper.sh"
REVA_SCRIPT_NAME="mcp-reva-wrapper"

deploy_reva_wrapper() {
  # 1. 复制到 opencode 配置目录
  mkdir -p "$OPENCODE_CFG/scripts"
  do_link "$REVA_SCRIPT_SRC" "$OPENCODE_CFG/scripts/$REVA_SCRIPT_NAME"
  ok "ReVa wrapper → $OPENCODE_CFG/scripts/$REVA_SCRIPT_NAME"

  # 2. 复制到 opencode-multi 配置目录
  mkdir -p "$OPENCODE_MULTI_PROFILES/../scripts"
  do_link "$REVA_SCRIPT_SRC" "$OPENCODE_MULTI_PROFILES/../scripts/$REVA_SCRIPT_NAME"
  ok "ReVa wrapper → $OPENCODE_MULTI_PROFILES/../scripts/$REVA_SCRIPT_NAME"

  # 3. 链接到 ~/.local/bin/（已在 PATH 中，确保直接执行）
  mkdir -p "$HOME/.local/bin"
  if [ ! -L "$HOME/.local/bin/$REVA_SCRIPT_NAME" ] || [ "$(readlink "$HOME/.local/bin/$REVA_SCRIPT_NAME")" != "$REVA_SCRIPT_SRC" ]; then
    do_link "$REVA_SCRIPT_SRC" "$HOME/.local/bin/$REVA_SCRIPT_NAME"
    ok "ReVa wrapper → $HOME/.local/bin/$REVA_SCRIPT_NAME"
  else
    ok "$HOME/.local/bin/$REVA_SCRIPT_NAME 已指向 repo，跳过"
  fi
}

undeploy_reva_wrapper() {
  # 撤销链接（不删源文件）
  [ -L "$OPENCODE_CFG/scripts/$REVA_SCRIPT_NAME" ] && rm -f "$OPENCODE_CFG/scripts/$REVA_SCRIPT_NAME"
  [ -L "$OPENCODE_MULTI_PROFILES/../scripts/$REVA_SCRIPT_NAME" ] && rm -f "$OPENCODE_MULTI_PROFILES/../scripts/$REVA_SCRIPT_NAME"
  [ -L "$HOME/.local/bin/$REVA_SCRIPT_NAME" ] && rm -f "$HOME/.local/bin/$REVA_SCRIPT_NAME"
}

# ---------- helpers ----------
info()  { echo -e "  \033[36m->\033[0m $*"; }
ok()    { echo -e "  \033[32mOK\033[0m $*"; }
warn()  { echo -e "  \033[33m!>\033[0m $*"; }
action(){ echo -e "\033[1m\n== $* ==\033[0m"; }

_mktemp() {
  if [ "$_os" = "macos" ]; then
    mktemp -t "opencode-merge" 2>/dev/null || mktemp "${TMPDIR:-/tmp}/opencode-merge.XXXXXXXXXX"
  else
    mktemp
  fi
}

is_repo_link() {
  [ -L "$1" ] && case "$(readlink "$1")" in "$REPO_DIR"/*|"$REPO_DIR") return 0;; esac
  return 1
}

do_link() {
  # rm destination if it's a real dir (ln -f won't replace dir with symlink)
  if [ -d "$2" ] && [ ! -L "$2" ]; then rm -rf "$2"; fi
  ln -snf "$1" "$2"
}

check_jq() {
  if ! command -v jq &>/dev/null; then
    echo "  Error: jq is required but not found." >&2
    if [ "$_os" = "macos" ]; then
      echo "  Install: brew install jq" >&2
    else
      echo "  Install: apt install jq  (or: yum install jq)" >&2
    fi
    exit 1
  fi
}

# ---------- jq merge filters ----------
JQ_MERGE_OPENCODE='
def merge_opencode($r; $l):
  ($r | keys) as $rk | ($l | keys) as $lk | ($rk + $lk | unique) as $all |
  reduce $all[] as $k (
    {};
    if $k == "plugin" then
      .[$k] = ((($l[$k] // []) + ($r[$k] // [])) | unique)
    elif $k == "mcp" then
      .[$k] = (($l[$k] // {}) * ($r[$k] // {}))
    elif ($r | has($k)) then
      .[$k] = $r[$k]
    else
      .[$k] = $l[$k]
    end
  );
merge_opencode($repo; $local)
'

JQ_MERGE_OHMYAGENT='
def merge_ohmyagent($r; $l):
  ($r | keys) as $rk | ($l | keys) as $lk | ($rk + $lk | unique) as $all |
  reduce $all[] as $k (
    {};
    if $k == "agents" then
      .[$k] = (($l[$k] // {}) * ($r[$k] // {}))
    elif $k == "categories" then
      .[$k] = (($l[$k] // {}) * ($r[$k] // {}))
    elif ($r | has($k)) then
      .[$k] = $r[$k]
    else
      .[$k] = $l[$k]
    end
  );
merge_ohmyagent($repo; $local)
'

merge_json() {
  local type="$1"  # opencode | ohmyagent
  local repo_file="$2"
  local local_file="$3"
  local out_file="$4"

  if [ ! -f "$local_file" ]; then
    cp "$repo_file" "$out_file"
    return 0
  fi

  local filter
  [ "$type" = "ohmyagent" ] && filter="$JQ_MERGE_OHMYAGENT" || filter="$JQ_MERGE_OPENCODE"

  jq -n \
    --argjson repo "$(cat "$repo_file")" \
    --argjson local "$(cat "$local_file")" \
    "$filter" > "$out_file"
}

# ---------- deploy single instance ----------
deploy_single() {
  action "opencode 单实例 → $OPENCODE_CFG/"
  mkdir -p "$OPENCODE_CFG"

  for f in opencode.json oh-my-openagent.json; do
    local src="$SINGLE_SRC/$f"
    local dst="$OPENCODE_CFG/$f"

    [ -f "$src" ] || { warn "repo 中缺少 $src，跳过"; continue; }

    if is_repo_link "$dst"; then
      ok "$f 已指向 repo，跳过"
      continue
    fi

    # Determine merge type
    local mtype="opencode"
    [[ "$f" == *oh-my-openagent* ]] && mtype="ohmyagent"

    if [ -f "$dst" ] || [ -L "$dst" ]; then
      warn "$f 已存在但非 repo 链接 → 备份 + 合并"
      mkdir -p "$BACKUP_DIR/single"
      cp "$dst" "$BACKUP_DIR/single/$f"

      local tmpfile; tmpfile=$(_mktemp)
      merge_json "$mtype" "$src" "$dst" "$tmpfile"
      cp "$tmpfile" "$src"
      rm -f "$tmpfile"
      info "本机独有配置已合并到 repo"
    fi

    do_link "$src" "$dst"
    ok "$f  → $dst"
  done
}

# ---------- deploy multi profiles ----------
deploy_multi() {
  action "opencode-multi profiles → $OPENCODE_MULTI_PROFILES/"
  mkdir -p "$OPENCODE_MULTI_PROFILES"

  for profile_dir in "$MULTI_SRC"/*/; do
    [ -d "$profile_dir" ] || continue
    local name; name=$(basename "$profile_dir")
    local dst="$OPENCODE_MULTI_PROFILES/$name"

    if is_repo_link "$dst"; then
      ok "$name 已指向 repo，跳过"
      continue
    fi

    # Merge per-file if local profile dir exists
    if [ -d "$dst" ]; then
      warn "$name 已存在但非 repo 链接 → 备份 + 合并"
      mkdir -p "$BACKUP_DIR/multi"
      cp -r "$dst" "$BACKUP_DIR/multi/$name"

      for f in opencode.json oh-my-openagent.json; do
        local src_file="$profile_dir/$f"
        local dst_file="$dst/$f"
        [ -f "$src_file" ] || continue
        [ -f "$dst_file" ] || continue

        local mtype="opencode"
        [[ "$f" == *oh-my-openagent* ]] && mtype="ohmyagent"

        local tmpfile; tmpfile=$(_mktemp)
        merge_json "$mtype" "$src_file" "$dst_file" "$tmpfile"
        cp "$tmpfile" "$src_file"
        rm -f "$tmpfile"
      done
      info "本机独有配置已合并到 repo"
    fi

    # Remove existing dir before linking (ln -sf won't replace a directory)
    [ -d "$dst" ] && rm -rf "$dst"
    do_link "$profile_dir" "$dst"
    ok "$name → $dst"
  done
}

# ---------- main ----------
echo ""
echo "opencode_config — 配置部署工具"
echo "仓库: $REPO_DIR"
echo "系统: $_os"
echo ""

check_jq

deploy_single
deploy_multi
deploy_reva_wrapper

echo ""
action "完成"
[ -d "$BACKUP_DIR" ] && info "备份目录: $BACKUP_DIR"
info "后续编辑 $REPO_DIR 下文件即时生效，git add/commit 即备份。"
echo ""
