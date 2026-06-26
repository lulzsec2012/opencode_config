---
name: proxy-reminder
description: Use when docker pull is slow/failing/timing out; when apt/pip/npm/npx install hangs; when git clone to external repos fails; when curl/wget to public sites times out; when downloading from HuggingFace, Docker Hub, or any external registry is slow or unreachable
---

# Proxy Reminder

## Overview

This dev container operates inside a **Tailscale tailnet**. Multiple nodes in the tailnet (e.g. Alibaba Cloud ECS) run HTTP/SOCKS5 proxies (Clash, Stash, etc.). When any network operation fails or is slow, **proxies are available** — use them before assuming the network is down.

## Quick Start

```bash
# Auto-detect and configure proxy for current shell + git:
source scripts/proxy/free.sh
```

This scans all tailnet nodes for open proxy ports (7890/7897/7891/3128/8080 etc.), validates them (GitHub + Google + Git), and sets:
- `http_proxy` / `https_proxy` (current shell)
- `HTTP_PROXY` / `HTTPS_PROXY` (current shell)
- `git config --global http.proxy`
- `git config --global https.proxy`

## Scenarios

### docker pull / docker operations

Docker daemon runs on the **host** (not in dev container). Configure host-side:

```bash
# Option A: Registry mirrors (fastest, no proxy needed)
ssh lulizhi@100.117.18.87
sudo /workspace/playground/scripts/docker/setup-docker-mirror.sh

# Option B: Docker daemon HTTP proxy
ssh lulizhi@100.117.18.87
sudo /workspace/playground/scripts/docker/setup-docker-proxy.sh
```

### git clone / git operations

```bash
source scripts/proxy/free.sh    # sets git proxy automatically
# Or manually:
git config --global http.proxy http://<proxy-ip>:<port>
```

### apt / pip / npm / npx

```bash
source scripts/proxy/free.sh    # sets env vars
sudo apt update                 # respects http_proxy
pip install <package>
npm install
npx <command>
```

### HuggingFace / curl / wget / any download

```bash
source scripts/proxy/free.sh    # sets env vars
huggingface-cli download ...
curl -O https://...
```

## Useful Commands

| Command | What it does |
|---------|-------------|
| `source scripts/proxy/free.sh` | Auto-detect and configure proxy |
| `source scripts/proxy/free.sh --show` | Show current proxy status |
| `source scripts/proxy/free.sh --test` | Scan only, don't set |
| `sudo scripts/docker/setup-docker-proxy.sh` | Set Docker daemon proxy (host) |
| `sudo scripts/docker/setup-docker-mirror.sh` | Set Docker registry mirrors (host) |

## Verification

```bash
# Check current proxy
source scripts/proxy/free.sh --show

# Test proxy works
curl -I https://github.com
git ls-remote --heads https://github.com/aiprodcoder/MIXAPI.git
```

## When NOT to use proxy

- Accessing internal tailnet services (100.x.x.x addresses) — these are direct
- Accessing the host machine directly — use `NO_PROXY=localhost,127.0.0.1,::1,100.x.x.x`
