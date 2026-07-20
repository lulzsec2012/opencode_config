#!/usr/bin/env bash
set -e

echo "========================================"
echo "  OpenCode Environment Setup"
echo "========================================"

# ---------- user-local npm setup ----------
# 所有 npm global 包安装到 ~/.local，避免 sudo
export NPM_CONFIG_PREFIX="$HOME/.local"
mkdir -p "$HOME/.local/bin"
npm config set prefix "$HOME/.local" 2>/dev/null || true
# 确保 PATH 包含用户本地 bin 目录
case ":$PATH:" in
  *:"$HOME/.local/bin":*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# JSON plugin 添加工具：向 opencode.json 的 plugin 数组中添加条目（自动去重）
plugin_add() {
  local json_file="$1"
  local plugin_name="$2"
  if [ ! -f "$json_file" ]; then
    echo "  ⚠️  $json_file 不存在，跳过"
    return 1
  fi
  # 使用 Python3 安全地修改 JSON
  python3 -c "
import json, sys
path = '$json_file'
name = '$plugin_name'
with open(path) as f:
    cfg = json.load(f)
plugins = cfg.get('plugin', [])
if name not in plugins:
    plugins.append(name)
    cfg['plugin'] = plugins
    with open(path, 'w') as f:
        json.dump(cfg, f, indent=4)
    print(f'  ✅ 已添加 {name}' if name not in plugins else f'  🔁 {name} 已存在')
else:
    print(f'  🔁 {name} 已存在')
" 2>&1 | tail -1
}

# ---------- helpers ----------

# npm 包版本检测：未安装则安装，已安装则对比 registry 版本决定升级/跳过
npm_check_upgrade() {
  local pkg="$1"
  local label="${2:-$pkg}"
  local installed

  installed=$(npm ls -g --depth=0 "$pkg" 2>&1 | grep -Eo "@[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9._-]+)?" | head -1 | tr -d '@')
  if [ -z "$installed" ]; then
    echo "  $label 未安装，正在安装..."
    npm_install_user "$pkg" || { echo "  $label 安装失败" >&2; return 1; }
    return
  fi

  local latest
  latest=$(npm view "$pkg" version 2>/dev/null || echo "")
  if [ -z "$latest" ]; then
    echo "  $label $installed（无法获取最新版本）"
    return
  fi

  if [ "$installed" = "$latest" ]; then
    echo "  $label $installed（已是最新），跳过"
  else
    echo "  $label: $installed -> $latest，升级中..."
    npm_install_user "$pkg" || { echo "  $label 升级失败" >&2; return 1; }
  fi
}

npm_install_user() {
  local pkg="$1"
  npm install -g "$pkg"
}

ver_gt() {
  [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ] && [ "$1" != "$2" ]
}

# ---------- 1. opencode CLI ----------
echo ""
echo "[1/14] Installing opencode CLI..."
npm_install_opencode() {
  npm_install_user "opencode-ai"
}

if command -v opencode &>/dev/null; then
  inst_ver=$(opencode --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9._-]+)?' | head -1)
  if [ -z "$inst_ver" ]; then
    echo "  opencode 已安装（版本号未识别）"
  else
    latest_ver=$(npm view opencode-ai version 2>/dev/null || echo "")
    if [ -z "$latest_ver" ]; then
      echo "  opencode $inst_ver（无法获取最新版本）"
    elif [ "$inst_ver" = "$latest_ver" ]; then
      echo "  opencode $inst_ver（已是最新），跳过"
    elif ver_gt "$latest_ver" "$inst_ver"; then
      echo "  opencode: $inst_ver -> $latest_ver，升级中..."
      npm_install_opencode
      echo "  opencode 已升级: $(opencode --version)"
    else
      echo "  opencode $inst_ver（已是最新），跳过"
    fi
  fi
else
  echo "  通过 npm 安装 opencode-ai..."
  if command -v npm &>/dev/null; then
    npm_install_opencode
    echo "  opencode installed: $(opencode --version)"
  else
    echo "  尝试官方脚本安装..."
    if curl -fsSL --connect-timeout 5 --max-time 15 https://opencode.ai/install | bash; then
      export PATH="$HOME/.opencode/bin:$PATH"
      echo "  opencode installed: $(opencode --version)"
    else
      echo "  npm 和官方脚本均不可用，请手动安装 opencode" >&2
      exit 1
    fi
  fi
fi

# ---------- 2. bun ----------
echo ""
echo "[2/14] Installing bun..."
_has_bun=false
if command -v bun &>/dev/null; then
  _has_bun=true
elif [ -f "$HOME/.bun/bin/bun" ]; then
  export PATH="$HOME/.bun/bin:$PATH"
  _has_bun=true
fi

if $_has_bun; then
  inst_ver=$(bun --version)
  echo "  bun $inst_ver，检测升级..."
  _old_ver="$inst_ver"
  bun upgrade 2>/dev/null || echo "  (bun upgrade 不可用，跳过)"
  _new_ver=$(bun --version)
  if [ "$_old_ver" != "$_new_ver" ]; then
    echo "  bun 已升级: $_old_ver -> $_new_ver"
  else
    echo "  bun $inst_ver（已是最新），跳过"
  fi
else
  echo "  Installing bun..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
  echo "  bun installed: $(bun --version)"
fi

# ---------- 3. oh-my-openagent ----------
echo ""
echo "[3/14] Installing oh-my-openagent plugin..."
if npm ls -g --depth=0 oh-my-openagent 2>&1 | grep -q 'oh-my-openagent@'; then
  echo "  oh-my-openagent 已安装"
elif npm ls -g --depth=0 oh-my-opencode 2>&1 | grep -q 'oh-my-opencode@'; then
  echo "  oh-my-opencode 已安装（oh-my-openagent 别名）"
else
  echo "  尝试安装 oh-my-openagent..."
  npm install -g oh-my-openagent 2>&1 | tail -3 || {
    echo "  oh-my-openagent 安装失败，回退到 oh-my-opencode..."
    npm install -g oh-my-opencode 2>&1 | tail -3
  }
fi
echo "  配置指南: https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/refs/heads/master/docs/guide/installation.md"

# ---------- 4. openspec ----------
echo ""
echo "[4/14] Installing openspec..."
npm_check_upgrade "@fission-ai/openspec" "openspec"
echo "  在项目目录执行 'openspec init' 初始化"

# 清理 npx 输出中的 ANSI 控制字符和进度条
clean_npx() {
  sed -u 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/\x1b\][0-9;]*[^\x1b]*\x1b\\//g; s/\r//g' 2>/dev/null || cat
}

skill_dir() {
  local d="$HOME/.agents/skills/$1"
  [ -d "$d" ] && echo "$d" && return 0
  d="$HOME/.opencode/skills/$1"
  [ -d "$d" ] && echo "$d" && return 0
  return 1
}

# ---------- 5. superpowers ----------
echo ""
echo "[5/14] Installing superpowers skills..."
if skill_dir "superpowers" >/dev/null; then
  echo "  superpowers 已安装，检查更新..."
  npx --yes skills add obra/superpowers 2>&1 | clean_npx
else
  npx --yes skills add obra/superpowers
  echo "  superpowers installed"
fi

# ---------- 6. planning-with-files ----------
echo ""
echo "[6/14] Installing planning-with-files..."
if skill_dir "planning-with-files" >/dev/null; then
  echo "  planning-with-files 已安装，检查更新..."
  npx --yes skills add OthmanAdi/planning-with-files 2>&1 | clean_npx
else
  npx --yes skills add OthmanAdi/planning-with-files
  echo "  planning-with-files installed"
fi

# ---------- 7. conversation-analysis ----------
echo ""
echo "[7/14] Installing opencode-conversation-analysis..."
if skill_dir "opencode-conversation-analysis" >/dev/null; then
  echo "  opencode-conversation-analysis 已安装，检查更新..."
  npx --yes skills add connorads/dotfiles@opencode-conversation-analysis -y -g 2>&1 | clean_npx || echo "  跳过"
else
  npx --yes skills add connorads/dotfiles@opencode-conversation-analysis -y -g || echo "  ⚠️ 跳过"
fi

# ---------- 8. dcp-dynamic-limits ----------
echo ""
echo "[8/14] Installing opencode-dcp-dynamic-limits..."
npm_check_upgrade "opencode-dcp-dynamic-limits"

# ---------- 9. opencode-headroom ----------
echo ""
echo "[9/14] Installing opencode-headroom..."
npm_check_upgrade "opencode-headroom"
echo "  headroom 已安装，在 opencode.json 的 plugin 中添加 opencode-headroom 启用"

# ---------- 10. opencode plugins ----------
echo ""
echo "[10/14] Installing opencode plugins..."
for _pkg in opencode-debug-helper opencode-agent-context opencode-codegraph opencode-localmemory opencode-skill-creator opencode-yaml-hooks opencode-skills-collection; do
  npm_check_upgrade "$_pkg"
done

# ---------- 11. ponytail ----------
echo ""
echo "[11/14] Installing ponytail plugin..."
echo "  ponytail: Lazy senior dev mode for AI agents."
echo "  GitHub: https://github.com/DietrichGebert/ponytail"
npm_check_upgrade "@dietrichgebert/ponytail" "ponytail"
# 自动添加到 opencode-multi 配置文件的 plugin 数组中
_OC_MULTI="${XDG_CONFIG_HOME:-$HOME/.config}/opencode-multi/profiles"
for _profile in mix-work mix-local local; do
  _cfg="$_OC_MULTI/$_profile/opencode.json"
  if [ -f "$_cfg" ]; then
    plugin_add "$_cfg" "@dietrichgebert/ponytail"
  fi
done

# ---------- 11b. karpathy-skills ----------
echo ""
echo "[11b/14] Installing @swarmclawai/andrej-karpathy-skills..."
echo "  Karpathy-inspired coding-agent guidelines for all profiles."
echo "  GitHub: https://github.com/swarmclawai/andrej-karpathy-skills"
npm_check_upgrade "@swarmclawai/andrej-karpathy-skills" "karpathy-skills"
# 安装 skill 到各个 profile
_skill_src="$(npm root -g)/@swarmclawai/andrej-karpathy-skills/adapters/opencode/.opencode/skills/karpathy-guidelines"
for _profile in mix-work mix-local local; do
  _skill_dst="$_OC_MULTI/$_profile/skills/karpathy-guidelines"
  if [ -d "$_skill_src" ] && [ -d "$_OC_MULTI/$_profile" ]; then
    mkdir -p "$_skill_dst"
    cp "$_skill_src/SKILL.md" "$_skill_dst/SKILL.md"
    echo "  ✅ $_profile: karpathy-guidelines installed"
  fi
done

# ---------- 11c. grill-me ----------
echo ""
echo "[11c/14] Installing grill-me skill..."
echo "  Relentless design interview skill for stress-testing plans."
echo "  npm: @amit-t/skill-grill-me"
npm_check_upgrade "@amit-t/skill-grill-me" "grill-me"
# 安装 skill 到各个 profile
_skill_src="$(npm root -g)/@amit-t/skill-grill-me/skill"
for _profile in mix-work mix-local local; do
  _skill_dst="$_OC_MULTI/$_profile/skills/grill-me"
  if [ -d "$_skill_src" ] && [ -d "$_OC_MULTI/$_profile" ]; then
    mkdir -p "$_skill_dst"
    cp "$_skill_src/SKILL.md" "$_skill_dst/SKILL.md"
    echo "  ✅ $_profile: grill-me installed"
  fi
done

# ---------- 11d. caveman ----------
echo ""
echo "[11d/14] Installing caveman-opencode-plugin..."
echo "  Caveman communication mode for opencode."
echo "  npm: caveman-opencode-plugin"
npm_check_upgrade "caveman-opencode-plugin" "caveman"
# 添加到所有 opencode-multi 配置
for _profile in mix-work mix-local work local debug; do
  _cfg="$_OC_MULTI/$_profile/opencode.json"
  if [ -f "$_cfg" ]; then
    plugin_add "$_cfg" "caveman-opencode-plugin"
  fi
  # 创建 caveman.json 配置（如果不存在）
  _ccfg="$_OC_MULTI/$_profile/caveman.json"
  if [ ! -f "$_ccfg" ]; then
    cat > "$_ccfg" <<'CEOF'
{
  "enabled": true,
  "defaultMode": "full",
  "features": {
    "caveman": true,
    "commit": true,
    "review": true
  }
}
CEOF
    echo "  ✅ $_profile: caveman.json created"
  else
    echo "  🔁 $_profile: caveman.json already exists"
  fi
done

# ---------- 11e. speckit-agent-skills ----------
echo ""
echo "[11e/14] Installing speckit-agent-skills..."
echo "  Spec Kit (Spec-Driven Development) workflow skills."
echo "  GitHub: https://github.com/github/speckit-agent-skills"
_SPECKIT_TMP="/tmp/speckit-agent-skills"
if [ ! -d "$_SPECKIT_TMP" ]; then
  echo "  Downloading speckit-agent-skills from GitHub..."
  curl -sL "https://api.github.com/repos/github/speckit-agent-skills/tarball/main" -o /tmp/speckit-skills.tar.gz
  mkdir -p "$_SPECKIT_TMP"
  tar xzf /tmp/speckit-skills.tar.gz -C "$_SPECKIT_TMP" --strip-components=1 2>/dev/null
  rm -f /tmp/speckit-skills.tar.gz
fi
_SKILLS_SRC="$_SPECKIT_TMP/skills"
if [ -d "$_SKILLS_SRC" ]; then
  for _profile in mix-work mix-local work local debug; do
    echo "  Installing to $_profile..."
    for _skill in speckit-analyze speckit-baseline speckit-checklist speckit-clarify speckit-constitution speckit-implement speckit-plan speckit-specify speckit-tasks speckit-taskstoissues; do
      _src="$_SKILLS_SRC/$_skill"
      _dst="$_OC_MULTI/$_profile/skills/$_skill"
      if [ -d "$_src" ]; then
        mkdir -p "$_dst"
        cp -a "$_src/"* "$_dst/" 2>/dev/null
      fi
    done
    echo "    ✅ $_profile: speckit skills installed"
  done
else
  echo "  ⚠️  Failed to download speckit-agent-skills"
fi

# ---------- 11f. opencode-debug-helper ----------
echo ""
echo "[11f/14] Installing opencode-debug-helper plugin..."
echo "  Debug Helper for OpenCode: inspect context, prompts, and provider state."
echo "  npm: opencode-debug-helper"
# plugin已在上方通过npm_check_upgrade安装，此处确保添加到各配置
_OC_MULTI="${XDG_CONFIG_HOME:-$HOME/.config}/opencode-multi/profiles"
for _profile in mix-work mix-local work local debug; do
  _cfg="$_OC_MULTI/$_profile/opencode.json"
  if [ -f "$_cfg" ]; then
    plugin_add "$_cfg" "opencode-debug-helper"
  fi
done

# ---------- 12. Ghidra + ReVa ----------
echo ""
echo "[12/14] Installing Ghidra + ReVa (Reverse Engineering Assistant)..."
_REVA_SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/install-reva.sh"
if [ -f "$_REVA_SCRIPT" ]; then
  # 检测是否已安装
  _reva_installed=false
  if command -v mcp-reva &>/dev/null && [ -n "${GHIDRA_INSTALL_DIR:-}" ] && [ -f "$GHIDRA_INSTALL_DIR/ghidraRun" ]; then
    _reva_installed=true
    echo "  Ghidra + ReVa 已安装，跳过"
  elif command -v mcp-reva &>/dev/null; then
    # mcp-reva 在但 Ghidra 路径不对 — 尝试检测
    for _d in "$HOME/.local/opt/ghidra_"*_PUBLIC; do
      if [ -f "$_d/ghidraRun" ]; then
        export GHIDRA_INSTALL_DIR="$_d"
        _reva_installed=true
        echo "  Ghidra 已安装（$_d），ReVa CLI $(mcp-reva --version 2>/dev/null) 已安装，跳过"
        break
      fi
    done
  fi

  if ! $_reva_installed; then
    echo "  运行 install-reva.sh..."
    bash "$_REVA_SCRIPT" 2>&1 | while IFS= read -r _line; do echo "    $_line"; done
    echo "  Ghidra + ReVa 安装完成"
    export GHIDRA_INSTALL_DIR="$(ls -d "$HOME/.local/opt/ghidra_"*_PUBLIC 2>/dev/null | head -1)"
  fi
else
  echo "  install-reva.sh 未找到（预期路径: $_REVA_SCRIPT），跳过"
fi

# ---------- 13. codebase-memory-mcp ----------
echo ""
echo "[13/14] Installing codebase-memory-mcp (Code Intelligence Knowledge Graph)..."
if command -v codebase-memory-mcp &>/dev/null; then
  echo "  codebase-memory-mcp $(codebase-memory-mcp --version 2>/dev/null || echo '')已安装，检查更新..."
  codebase-memory-mcp update 2>&1 | while IFS= read -r _line; do echo "    $_line"; done
else
  echo "  通过官方安装脚本安装..."
  curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash 2>&1 | while IFS= read -r _line; do echo "    $_line"; done
  if command -v codebase-memory-mcp &>/dev/null; then
    echo "  codebase-memory-mcp 安装成功"
    # 官方安装器会自动检测 OpenCode 并配置 MCP，
    # 但由于我们使用 repo 管理配置，后续 setup.sh 会覆盖为 repo 版本
    echo "  注意: 使用仓库配置管理，运行 setup.sh 后生效"
  else
    echo "  codebase-memory-mcp 安装失败，请手动安装:"
    echo "    curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash"
  fi
fi

# ---------- extra tools ----------
echo ""
echo "--- Optional tools ---"

echo ""
echo "opencode-agent-optimizer:"
npm_check_upgrade "opencode-agent-optimizer"
echo "  用法: opencode-agent-optimizer summary"
echo "        opencode-agent-optimizer suggest --all"
echo "        opencode-agent-optimizer install"

echo ""
echo "opencode-analytics:"
npm_check_upgrade "opencode-analytics"
echo "  注意: opencode-analytics v0.1.0 为库文件，无 CLI 命令"
echo "  用法: 在项目中 import 使用"

echo ""
echo "opencode-multi:"
ensure_rust() {
  if command -v cargo &>/dev/null && [ "$(cargo --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+' | head -1)" = "1.8" ]; then
    echo "  Rust $(cargo --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+') OK"
    return 0
  fi
  if command -v rustup &>/dev/null; then
    echo "  升级 Rust..."
    rustup default stable 2>&1 | tail -1
    . "$HOME/.cargo/env"
    return 0
  fi
  echo "  安装 rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>&1 | tail -1
  . "$HOME/.cargo/env"
}
ensure_rust
if command -v cargo &>/dev/null; then
  local_ver=$(cargo install --list 2>/dev/null | grep -E '^opencode-multi v' | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  latest_ver=$(cargo search opencode-multi 2>/dev/null | grep -Eo '^opencode-multi[^#]*#([0-9]+\.[0-9]+\.[0-9]+)' | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ -n "$local_ver" ] && [ "$local_ver" = "$latest_ver" ]; then
    echo "  opencode-multi $local_ver（已是最新），跳过"
  elif [ -n "$local_ver" ]; then
    echo "  opencode-multi: $local_ver -> $latest_ver，升级中..."
    cargo install opencode-multi --force 2>&1 | tail -1
  else
    echo "  安装 opencode-multi..."
    cargo install opencode-multi 2>&1 | tail -1
  fi
else
  echo "  cargo 不可用，跳过 opencode-multi"
fi

# ---------- RTK (Rust Token Killer) ----------
echo ""
echo "--- RTK (Rust Token Killer) ---"
echo "  RTK 是一款 CLI 代理，可将常见开发命令的 LLM token 消耗降低 60-90%"
echo "  项目: https://github.com/rtk-ai/rtk"

# 检查 rtk 版本是否正确（需要 >= 0.23.0 且来自 rtk-ai/rtk）
rtk_ok=false
if command -v rtk &>/dev/null; then
  rtk_ver="$(rtk --version 2>/dev/null)"
  if echo "$rtk_ver" | grep -qE '^rtk [0-9]+\.[0-9]+'; then
    major="$(echo "$rtk_ver" | sed 's/rtk //' | cut -d. -f1)"
    minor="$(echo "$rtk_ver" | sed 's/rtk //' | cut -d. -f2)"
    if [ "$major" -ge 1 ] || { [ "$major" -eq 0 ] && [ "$minor" -ge 23 ]; }; then
      echo "  rtk $rtk_ver 已安装（版本正确）"
      rtk_ok=true
    fi
  fi
  if [ "$rtk_ok" = false ]; then
    echo "  ⚠️ 发现错误版本的 rtk ($rtk_ver)，删除后重新安装..."
    rm -f "$(which rtk)" "$HOME/.local/bin/rtk" "$HOME/.cargo/bin/rtk" 2>/dev/null || true
  fi
fi

if [ "$rtk_ok" = false ]; then
  echo "  通过官方脚本安装 rtk（v0.43.0）..."
  if curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh; then
    echo "  rtk 安装成功"
  else
    echo "  ⚠️ rtk 安装失败，请稍后手动执行安装命令" >&2
  fi
fi

# 确保 rtk 在 PATH 中
export PATH="$HOME/.local/bin:$PATH"

if command -v rtk &>/dev/null; then
  echo "  配置 RTK OpenCode 插件..."
  PLUGIN_SRC="${SCRIPT_DIR}/../multi/mix-work/plugins/rtk.ts"
  for cfg_dir in "${SCRIPT_DIR}/../single" "${SCRIPT_DIR}/../multi/debug" "${SCRIPT_DIR}/../multi/local" "${SCRIPT_DIR}/../multi/mix-local" "${SCRIPT_DIR}/../multi/mix-work" "${SCRIPT_DIR}/../multi/work"; do
    mkdir -p "${cfg_dir}/plugins"
    cp "$PLUGIN_SRC" "${cfg_dir}/plugins/rtk.ts"
    echo "    → 已同步 rtk.ts 到 $(basename $cfg_dir)/plugins/"
  done
  if rtk init -g --opencode; then
    echo "  RTK OpenCode 插件配置完成"
  else
    echo "  ⚠️ rtk init 配置失败，请稍后手动执行: rtk init -g --opencode" >&2
  fi
fi

# ---------- opencode-codegraph ----------
echo ""
echo "--- opencode-codegraph ---"
echo "  opencode-codegraph 通过分析 GitHub PR 为代码审查提供图上下文"
echo "  仓库: https://github.com/colbymchenry/codegraph"

if command -v codegraph &>/dev/null; then
  echo "  codegraph $(codegraph --version 2>/dev/null) 已安装"
else
  echo "  通过官方脚本安装 codegraph..."
  if curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh; then
    echo "  codegraph 安装成功"
  else
    echo "  ⚠️ codegraph 安装失败，请稍后手动执行: curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh" >&2
  fi
fi

# ---------- PATH 注入 .bashrc ----------
echo ""
echo "[14/14] Ensuring PATH is set in ~/.bashrc..."
_patch_bashrc_path() {
  local path_entry="$1"
  local marker="$2"
  if grep -qF "$marker" "$HOME/.bashrc" 2>/dev/null; then
    echo "  $path_entry 已存在，跳过"
    return
  fi
  cat >> "$HOME/.bashrc" <<EOF

# $marker
export PATH="\$PATH:$path_entry"
EOF
  echo "  $path_entry 已添加到 ~/.bashrc"
}
_patch_bashrc_path "$HOME/.local/bin" "opencode-user-local-bin"
_patch_bashrc_path "$HOME/.bun/bin" "opencode-bun-bin"
_patch_bashrc_path "$HOME/.cargo/bin" "opencode-cargo-bin"

echo ""
echo "========================================"
echo "  OpenCode Environment Setup Complete!"
echo "========================================"
echo ""
echo "下一步:"
echo "  1. 配置 opencode.json (复制 ~/.config/opencode/opencode.json)"
echo "  2. source ~/.bashrc 或新开终端"
echo "  3. 运行 opencode 开始使用"
