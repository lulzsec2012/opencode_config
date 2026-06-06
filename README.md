# opencode_config

opencode 及 opencode-multi 统一配置管理。

## 目录结构

```
opencode_config/
├── single/                  # opencode 单实例配置
│   ├── opencode.json
│   └── oh-my-openagent.json
├── multi/                   # opencode-multi 多 profile 配置
│   ├── local/               # 本地开发环境
│   ├── work/                # 工作环境
│   ├── mix-local/           # 本地混合
│   └── mix-work/            # 工作混合
├── scripts/
│   ├── setup.sh             # 一键部署（软连接 + 合并 + 备份）
│   └── oc-install.sh        # opencode 环境安装脚本
└── README.md
```

## 在新机器上部署

```bash
# 1. 确保 repo 已拉取
git clone ...
git submodule update --init

# 2. 运行 setup 建立软连接
cd scripts/opencode
bash scripts/setup.sh
```

`setup.sh` 会自动：
- 检测系统目录下是否已有配置文件
- 有则备份 → 合并（保留本机独有插件/mcp/agent）→ 建立软连接
- 无则直接建立软连接

之后编辑 `single/` 或 `multi/` 下的文件即时生效，git commit 即备份。
