#!/usr/bin/env bash
# install-reva.sh — 安装 Ghidra + ReVa (Reverse Engineering Assistant) MCP 服务器
#                  包括 Java 21、Ghidra、ReVa CLI、Ghidra 扩展 JAR
#
# 安装内容:
#   1. OpenJDK 21（Ghidra 12.0+ 需要 Java 21+）
#   2. Ghidra 最新稳定版（下载到 ~/.local/opt/ghidra）
#   3. ReVa Python CLI（uv tool install reverse-engineering-assistant）
#   4. ReVa Ghidra 扩展 JAR（下载并安装到 Ghidra/Extensions/）
#   5. 环境变量（GHIDRA_INSTALL_DIR、PATH）
#
# 使用方式:
#   bash scripts/opencode/scripts/install-reva.sh              # 全量安装
#   bash scripts/opencode/scripts/install-reva.sh --java       # 只装 Java
#   bash scripts/opencode/scripts/install-reva.sh --ghidra     # 只装 Ghidra
#   bash scripts/opencode/scripts/install-reva.sh --reva       # 只装 ReVa CLI
#   bash scripts/opencode/scripts/install-reva.sh --extension  # 只装 Ghidra 扩展
#   bash scripts/opencode/scripts/install-reva.sh --check      # 只检查状态
#
# 安装后:
#   - 编辑 opencode.json 启用 ReVa MCP（enabled: true）
#   - 运行 mcp-reva-wrapper 启动 headless Ghidra + ReVa 服务
#   - 在 OpenCode 中即可使用 ReVa 工具进行二进制分析

set -euo pipefail

# ---------- config ----------
GHIDRA_VERSION="12.1.2"
GHIDRA_DIR="$HOME/.local/opt/ghidra"
GHIDRA_INSTALL_DIR="$GHIDRA_DIR/ghidra_${GHIDRA_VERSION}_PUBLIC"
GHIDRA_DOWNLOAD_URL="https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VERSION}_build/ghidra_${GHIDRA_VERSION}_PUBLIC_20250325.zip"
# 如果上面版本的下载链接失效，从 https://github.com/NationalSecurityAgency/ghidra/releases 获取最新

REVA_GH_REPO="cyberkaida/reverse-engineering-assistant"
REVA_PYPI="reverse-engineering-assistant"
BIN_DIR="$HOME/.local/bin"
OPT_DIR="$HOME/.local/opt"
ENV_MARKER="reva-env"

# ---------- colors ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "  ${CYAN}->${NC} $*"; }
ok()    { echo -e "  ${GREEN}OK${NC} $*"; }
warn()  { echo -e "  ${YELLOW}!>${NC} $*"; }
err()   { echo -e "  ${RED}!!${NC} $*" >&2; }
step()  { echo -e "\n${CYAN}==${NC} ${YELLOW}$*${NC}"; }

# ---------- helpers ----------
ensure_opt_dir() { mkdir -p "$OPT_DIR" "$BIN_DIR"; }
check_cmd() { command -v "$1" &>/dev/null; }

clean_npx() {
  sed -u 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/\x1b\][0-9;]*[^\x1b]*\x1b\\//g; s/\r//g' 2>/dev/null || cat
}

# ---------- proxy detection ----------
setup_proxy() {
  for proxy_addr in "http://127.0.0.1:7890" "http://127.0.0.1:7897" "http://127.0.0.1:3128"; do
    if curl -sI --connect-timeout 3 -x "$proxy_addr" \
      "https://api.github.com" >/dev/null 2>&1; then
      export http_proxy="$proxy_addr"
      export https_proxy="$proxy_addr"
      HTTP_PROXY="$proxy_addr" HTTPS_PROXY="$proxy_addr"
      info "使用代理: $proxy_addr"
      return 0
    fi
  done
  warn "未检测到可用代理，尝试直连..."
  return 1
}

# ---------- 1. Java 21 ----------
install_java() {
  step "[1/5] 安装 OpenJDK 21"

  if check_cmd java; then
    local jver; jver=$(java -version 2>&1 | head -1 | grep -Eo 'version "[0-9]+' | grep -Eo '[0-9]+')
    if [ "$jver" -ge 21 ] 2>/dev/null; then
      ok "Java $jver 已安装 (>=21 满足要求)"
      return 0
    fi
    warn "Java 版本为 $jver，需要 21+，将升级/安装"
  fi

  if check_cmd apt-get; then
    info "Debian/Ubuntu: 安装 openjdk-21-jdk-headless..."
    sudo apt-get update -qq && sudo apt-get install -y -qq openjdk-21-jdk-headless
  elif check_cmd yum; then
    info "RHEL/CentOS: 安装 java-21-openjdk-headless..."
    sudo yum install -y java-21-openjdk-headless
  elif check_cmd dnf; then
    info "Fedora: 安装 java-21-openjdk-headless..."
    sudo dnf install -y java-21-openjdk-headless
  elif check_cmd brew; then
    info "macOS: 安装 openjdk@21..."
    brew install openjdk@21
    sudo ln -sfn "$(brew --prefix)/opt/openjdk@21/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk-21.jdk
  else
    err "不支持的包管理器，请手动安装 Java 21+:"
    err "  https://adoptium.net/temurin/releases/?version=21"
    exit 1
  fi

  if check_cmd java; then
    ok "Java $(java -version 2>&1 | head -1)"
  else
    err "Java 安装失败"
    exit 1
  fi
}

# ---------- 2. Ghidra ----------
install_ghidra() {
  step "[2/5] 安装 Ghidra $GHIDRA_VERSION"

  if [ -d "$GHIDRA_INSTALL_DIR" ]; then
    ok "Ghidra $GHIDRA_VERSION 已存在于 $GHIDRA_INSTALL_DIR"
    setup_ghidra_env
    return 0
  fi

  ensure_opt_dir

  local zip_file="/tmp/ghidra_${GHIDRA_VERSION}.zip"

  if [ ! -f "$zip_file" ]; then
    info "下载 Ghidra $GHIDRA_VERSION..."
    # 尝试官方 release 链接；如果 404 则去 releases 页面找最新版
    if ! wget -q --show-progress "$GHIDRA_DOWNLOAD_URL" -O "$zip_file" 2>/dev/null; then
      warn "官方链接失效，尝试从 GitHub Releases 获取..."
      rm -f "$zip_file"
      local latest_url
      latest_url=$(curl -sL "https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest" | grep -Eo '"browser_download_url": "[^"]+\.zip"' | head -1 | cut -d'"' -f4)
      if [ -z "$latest_url" ]; then
        err "无法获取 Ghidra 下载地址，请手动下载:"
        err "  https://github.com/NationalSecurityAgency/ghidra/releases"
        err "  然后解压到 $GHIDRA_INSTALL_DIR"
        exit 1
      fi
      info "最新版: $latest_url"
      wget -q --show-progress "$latest_url" -O "$zip_file"
    fi
  else
    info "使用已下载的 $zip_file"
  fi

  info "解压到 $OPT_DIR..."
  unzip -qo "$zip_file" -d "$OPT_DIR"
  rm -f "$zip_file"

  if [ ! -d "$GHIDRA_INSTALL_DIR" ]; then
    local actual_dir
    actual_dir=$(ls -d "$OPT_DIR"/ghidra_*_PUBLIC 2>/dev/null | head -1)
    if [ -n "$actual_dir" ]; then
      info "检测到实际目录: $actual_dir"
      GHIDRA_INSTALL_DIR="$actual_dir"
    else
      err "解压后未找到 Ghidra 目录"
      err "请手动解压到 $OPT_DIR/ghidra_<version>_PUBLIC"
      exit 1
    fi
  fi

  ok "Ghidra 已安装到 $GHIDRA_INSTALL_DIR"
  setup_ghidra_env
}

setup_ghidra_env() {
  local rc_file="$HOME/.bashrc"
  if grep -qF "$ENV_MARKER" "$rc_file" 2>/dev/null; then
    sed -i "/$ENV_MARKER/,/END $ENV_MARKER/d" "$rc_file"
  fi

  cat >> "$rc_file" <<EOF

# $ENV_MARKER
export GHIDRA_INSTALL_DIR="$GHIDRA_INSTALL_DIR"
export PATH="\$PATH:$GHIDRA_INSTALL_DIR/support"
# END $ENV_MARKER
EOF

  export GHIDRA_INSTALL_DIR="$GHIDRA_INSTALL_DIR"
  export PATH="$PATH:$GHIDRA_INSTALL_DIR/support"
  ok "环境变量已写入 ~/.bashrc（GHIDRA_INSTALL_DIR, PATH）"
}

# ---------- 3. ReVa CLI ----------
install_reva() {
  step "[3/5] 安装 ReVa Python CLI"

  # 检查 GHIDRA_INSTALL_DIR
  if [ -z "${GHIDRA_INSTALL_DIR:-}" ]; then
    if [ -d "$HOME/.local/opt/ghidra/ghidra_${GHIDRA_VERSION}_PUBLIC" ]; then
      export GHIDRA_INSTALL_DIR="$HOME/.local/opt/ghidra/ghidra_${GHIDRA_VERSION}_PUBLIC"
    else
      local detected
      detected=$(ls -d "$HOME/.local/opt/ghidra/ghidra_"*_PUBLIC 2>/dev/null | head -1)
      if [ -n "$detected" ]; then
        export GHIDRA_INSTALL_DIR="$detected"
        info "自动检测到 GHIDRA_INSTALL_DIR=$detected"
      else
        warn "GHIDRA_INSTALL_DIR 未设置且未检测到 Ghidra"
        warn "请先安装 Ghidra 或设置 GHIDRA_INSTALL_DIR 环境变量"
        warn "继续安装 ReVa CLI，但 mcp-reva 需要 GHIDRA_INSTALL_DIR 才能运行"
      fi
    fi
  fi

  if check_cmd mcp-reva; then
    local rver; rver=$(mcp-reva --version 2>/dev/null || echo "")
    if [ -n "$rver" ]; then
      ok "ReVa CLI 已安装 ($rver)"
      local latest
      latest=$(uv tool list 2>/dev/null | grep "$REVA_PYPI" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
      if [ -n "$latest" ] && [ "$rver" != "$latest" ]; then
        info "升级 ReVa CLI: $rver -> $latest..."
        uv tool install --upgrade "$REVA_PYPI"
        ok "ReVa CLI 已升级到 $(mcp-reva --version)"
      fi
      return 0
    fi
  fi

  info "通过 uv 安装 $REVA_PYPI..."
  uv tool install "$REVA_PYPI"

  if check_cmd mcp-reva; then
    ok "ReVa CLI 已安装: $(mcp-reva --version 2>/dev/null || echo 'ok')"
  else
    warn "mcp-reva 不在 PATH 中"
    warn "尝试: export PATH=\"\$HOME/.local/bin:\$PATH\""
    export PATH="$HOME/.local/bin:$PATH"
    if check_cmd mcp-reva; then
      ok "ReVa CLI 已安装（需添加 ~/.local/bin 到 PATH）"
    fi
  fi
}

# ---------- Ghidra detection (for extension step) ----------
detect_ghidra() {
  if [ -n "${GHIDRA_INSTALL_DIR:-}" ] && [ -f "$GHIDRA_INSTALL_DIR/ghidraRun" ]; then
    echo "$GHIDRA_INSTALL_DIR"
    return 0
  fi
  local detected
  detected=$(ls -d "$OPT_DIR"/ghidra_*_PUBLIC 2>/dev/null | sort -V | tail -1)
  if [ -n "$detected" ] && [ -f "$detected/ghidraRun" ]; then
    echo "$detected"
    return 0
  fi
  return 1
}

detect_ghidra_version() {
  local dir="$1"
  basename "$dir" | sed 's/^ghidra_//; s/_PUBLIC$//'
}

map_extension_version() {
  local ghidra_ver="$1"
  case "$ghidra_ver" in
    12.0|12.0.0)     echo "12.0" ;;
    12.0.1)          echo "12.0.1" ;;
    12.0.2)          echo "12.0.2" ;;
    12.0.3)          echo "12.0.3" ;;
    12.0.4)          echo "12.0.4" ;;
    12.1|12.1.*)     echo "12.1" ;;
    12.2|12.2.*)     echo "12.2" ;;
    *)
      local major="${ghidra_ver%%.*}"
      local minor="${ghidra_ver#*.}"; minor="${minor%%.*}"
      echo "${major}.${minor}"
      return 1
      ;;
  esac
}

# ---------- 4. ReVa Ghidra 扩展 ----------
install_extension() {
  step "[4/5] 安装 ReVa Ghidra 扩展"

  # 先检测 Ghidra
  local GHIDRA_DIR
  GHIDRA_DIR=$(detect_ghidra) || {
    err "Ghidra 未安装，请先运行: bash $(basename "$0") --ghidra"
    return 1
  }
  ok "Ghidra: $GHIDRA_DIR"

  local GHIDRA_VER
  GHIDRA_VER=$(detect_ghidra_version "$GHIDRA_DIR")
  ok "Ghidra 版本: $GHIDRA_VER"

  # 映射扩展版本
  local EXT_VER
  EXT_VER=$(map_extension_version "$GHIDRA_VER") || {
    warn "非精确匹配 -> 尝试 ${EXT_VER:-未知}"
  }
  ok "目标扩展版本: Ghidra $EXT_VER"

  # 检查是否已安装
  local existing_jar
  existing_jar=$(find "$GHIDRA_DIR/Ghidra/Extensions" -name "reverse-engineering-assistant.jar" 2>/dev/null | head -1)
  if [ -n "$existing_jar" ]; then
    ok "扩展 JAR 已安装: $existing_jar ($(ls -lh "$existing_jar" | awk '{print $5}'))"
    local jar_version
    if check_cmd jar; then
      jar_version=$(jar tf "$existing_jar" 2>/dev/null | grep -c "reva/headless/" || echo "0")
      if [ "$jar_version" -gt 0 ]; then
        ok "扩展类验证通过 (${jar_version} 个 reva/headless 类)"
        return 0
      fi
    fi
    warn "现有扩展可能不完整，继续安装..."
  fi

  # 配置代理（仅扩展下载需要）
  if [ -z "${http_proxy:-}" ] && [ -z "${https_proxy:-}" ]; then
    setup_proxy >/dev/null 2>&1 || true
  fi

  # 获取最新 release 信息
  local api_url="https://api.github.com/repos/${REVA_GH_REPO}/releases/latest"
  info "获取 ReVa 最新 release 信息..."
  local release_data
  release_data=$(curl -sL --connect-timeout 15 "$api_url" 2>/dev/null) || {
    err "无法访问 GitHub API: $api_url"
    return 1
  }

  local tag_name
  tag_name=$(echo "$release_data" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('tag_name',''))
except: print('')
" 2>/dev/null) || tag_name=""

  if [ -z "$tag_name" ]; then
    err "无法获取 release 信息"
    return 1
  fi
  info "最新 release: $tag_name"

  # 查找匹配的扩展包
  local asset_url
  asset_url=$(echo "$release_data" | python3 -c "
import sys,json,re
try:
    d=json.load(sys.stdin)
    pat = re.compile(r'ghidra_${EXT_VER}_PUBLIC_\d+_reverse-engineering-assistant\.zip')
    for a in d.get('assets',[]):
        if pat.match(a.get('name','')):
            print(a.get('browser_download_url',''))
            sys.exit(0)
except: pass
" 2>/dev/null) || asset_url=""

  if [ -z "$asset_url" ]; then
    err "未找到 Ghidra ${EXT_VER} 对应的 ReVa 扩展"
    err "可用版本: 12.0, 12.0.1, 12.0.2, 12.0.3, 12.0.4, 12.1"
    err "当前 Ghidra: ${GHIDRA_VER}"
    return 1
  fi

  local zip_file="/tmp/reva_ghidra_${EXT_VER}.zip"
  info "下载: $(basename "$asset_url")"

  if ! curl -sL --connect-timeout 30 --max-time 300 --retry 3 --retry-delay 10 \
       --tls-max 1.2 -o "$zip_file" "$asset_url"; then
    warn "重试（无 TLS 限制）..."
    rm -f "$zip_file"
    if ! curl -sL --connect-timeout 30 --max-time 300 --retry 3 --retry-delay 10 \
         -o "$zip_file" "$asset_url"; then
      err "下载失败，手动下载:"
      err "  $asset_url"
      err "  然后解压到: $GHIDRA_DIR/Ghidra/Extensions/"
      return 1
    fi
  fi
  info "下载完成"

  # 安装到 Ghidra 系统扩展目录
  local ext_target="$GHIDRA_DIR/Ghidra/Extensions"
  if [ ! -d "$ext_target" ]; then
    err "未找到扩展目录: $ext_target"
    rm -f "$zip_file"
    return 1
  fi

  if [ -d "$ext_target/reverse-engineering-assistant" ]; then
    info "移除旧版扩展..."
    rm -rf "$ext_target/reverse-engineering-assistant"
  fi

  info "解压中..."
  if ! unzip -qo "$zip_file" -d "$GHIDRA_DIR"; then
    err "解压失败"
    rm -f "$zip_file"
    return 1
  fi
  rm -f "$zip_file"

  # 验证安装
  local installed_jar="$ext_target/reverse-engineering-assistant/lib/reverse-engineering-assistant.jar"
  if [ -f "$installed_jar" ]; then
    ok "安装完成: $installed_jar ($(ls -lh "$installed_jar" | awk '{print $5}'))"
  else
    warn "未找到预期 JAR 路径，尝试自动检测..."
    local found
    found=$(find "$GHIDRA_DIR/Ghidra" -name "reverse-engineering-assistant.jar" 2>/dev/null | head -1)
    if [ -n "$found" ]; then
      ok "JAR 已安装: $found"
    else
      err "安装后未找到 JAR，请检查 zip 内容结构"
      return 1
    fi
  fi

  ok "ReVa Ghidra 扩展安装完成"
}

# ---------- verify ----------
verify() {
  echo ""
  step "验证安装"

  local all_ok=true
  local java_ok=false; local ghidra_ok=false; local reva_ok=false; local ext_ok=false

  # Java
  if check_cmd java; then
    local jver; jver=$(java -version 2>&1 | head -1)
    echo "  Java:     $jver"
    java_ok=true
  else
    warn "Java 未安装"
  fi

  # Ghidra
  local gdir
  gdir=$(detect_ghidra) || true
  if [ -n "$gdir" ]; then
    ghidra_ok=true
    echo "  Ghidra:   $gdir"
    if [ -f "$gdir/ghidraRun" ]; then
      ok "    ghidraRun 存在"
    else
      warn "    ghidraRun 未找到"
      all_ok=false
    fi
  else
    warn "Ghidra 未安装"
    all_ok=false
  fi

  # ReVa CLI
  if check_cmd mcp-reva; then
    reva_ok=true
    echo "  ReVa CLI: $(mcp-reva --version 2>/dev/null || echo '已安装')"
  else
    warn "mcp-reva 未安装"
    all_ok=false
  fi

  # Extension JAR
  if [ -n "$gdir" ]; then
    local ejar
    ejar=$(find "$gdir/Ghidra/Extensions" -name "reverse-engineering-assistant.jar" 2>/dev/null | head -1)
    if [ -n "$ejar" ]; then
      ext_ok=true
      echo "  扩展 JAR: $ejar ($(ls -lh "$ejar" | awk '{print $5}'))"
    else
      warn "ReVa Ghidra 扩展未安装"
      all_ok=false
    fi
  fi

  echo "  GHIDRA_INSTALL_DIR: ${GHIDRA_INSTALL_DIR:-${gdir:-未设置}}"

  echo ""
  if $all_ok; then
    echo -e "  ${GREEN}全部安装完成。${NC}"
  else
    warn "部分组件未安装完成，请检查上面的警告信息。"
  fi

  # 检查 opencode.json 配置
  local opencode_configs
  opencode_configs=$(find /workspace/playground/scripts/opencode -name "opencode.json" -exec grep -l "ReVa" {} \; 2>/dev/null || true)
  if [ -n "$opencode_configs" ]; then
    echo ""
    echo "  ReVa MCP 配置状态:"
    echo "$opencode_configs" | while read -r cfg; do
      local enabled
      enabled=$(python3 -c "import json; print(json.load(open('$cfg'))['mcp']['ReVa']['enabled'])" 2>/dev/null || echo "unknown")
      if [ "$enabled" = "True" ]; then
        ok "  $cfg (已启用)"
      else
        warn "  $cfg (未启用)"
      fi
    done
  fi

  cat <<EOF

━━━ 使用说明 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. 确保环境变量加载:
       source ~/.bashrc

  2. 启动 ReVa headless 服务:
       mcp-reva-wrapper

  3. 在 OpenCode 中，确保 opencode.json 中 ReVa MCP 已启用:
       "ReVa": { "type": "local", "command": ["mcp-reva-wrapper"], "enabled": true }

  4. 验证: mcp-reva 2>&1 | head -10
     应看到 'ReVa server ready on port ...'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# ---------- main ----------
main() {
  echo ""
  echo "========================================"
  echo "  Ghidra + ReVa 安装脚本"
  echo "========================================"
  echo "  系统: $(uname -s) $(uname -m)"
  echo "  Python: $(python3 --version 2>/dev/null || echo 'N/A')"
  echo "  uv: $(uv --version 2>/dev/null || echo 'N/A')"
  echo "========================================"

  local do_java=true
  local do_ghidra=true
  local do_reva=true
  local do_extension=true
  local do_verify=true

  case "${1:-}" in
    --java)      do_ghidra=false; do_reva=false; do_extension=false ;;
    --ghidra)    do_java=false;   do_reva=false; do_extension=false ;;
    --reva)      do_java=false;   do_ghidra=false; do_extension=false ;;
    --extension) do_java=false;   do_ghidra=false; do_reva=false ;;
    --check|-c)  do_java=false;   do_ghidra=false; do_reva=false; do_extension=false ;;
    --help|-h)
      echo "用法: $0 [--java|--ghidra|--reva|--extension|--check]"
      echo "  不带参数: 全量安装 (Java → Ghidra → ReVa CLI → 扩展)"
      echo "  --java:     只安装 Java"
      echo "  --ghidra:   只安装 Ghidra"
      echo "  --reva:     只安装 ReVa CLI"
      echo "  --extension:只安装 Ghidra 扩展"
      echo "  --check:    只检查状态"
      exit 0
      ;;
  esac

  $do_java      && install_java
  $do_ghidra    && install_ghidra
  $do_reva      && install_reva
  $do_extension && install_extension

  $do_verify && verify
}

main "$@"
