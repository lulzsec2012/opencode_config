# opencode_config

opencode 及 opencode-multi 统一配置管理。

## 目录结构

```
opencode_config/
├── single/                  # opencode 单实例配置
│   ├── opencode.json
│   ├── oh-my-openagent.json
│   └── skills/              # 单实例技能（含 mattpocock symlink）
├── multi/                   # opencode-multi 多 profile 配置
│   ├── local/               # 本地开发环境
│   ├── work/                # 工作环境
│   ├── mix-local/           # 本地混合
│   └── mix-work/            # 工作混合
├── vendor/
│   └── mattpocock-skills/   # mattpocock/skills 供应商副本（engineering + productivity）
├── scripts/
│   ├── setup.sh             # 一键部署（软连接 + 合并 + 备份）
│   └── oc-install.sh        # opencode 环境安装脚本
└── README.md
```

## mattpocock skills

[mattpocock/skills](https://github.com/mattpocock/skills)（"Skills for Real
Engineers"）的 25 个 promoted 技能已通过 symlink 接入所有配置：

- `single/skills/` + `multi/<profile>/skills/` 中每个技能是指向
  `vendor/mattpocock-skills/` 的软连接，一处更新全局生效
- engineering（18）: tdd / code-review / diagnosing-bugs / grill-with-docs /
  implement / triage / wayfinder / to-spec / to-tickets / research / ...
- productivity（7）: grill-me / grilling / handoff / teach / writing-for-agents / ...
- `local` / `mix-local` / `mix-work` 保留原 amit 版 `grill-me`（真实目录），不覆盖

更新供应商副本：

```bash
bash scripts/oc-install.sh --update-mp   # 重下载 + 重建 symlink
```

使用前在项目里运行一次 `/setup-matt-pocock-skills` 配置 issue tracker。

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
- `~/.config/opencode/skills` 若已存在本机独有技能则**不动**（仅告警），
  否则软连接到 `single/skills/`

之后编辑 `single/` 或 `multi/` 下的文件即时生效，git commit 即备份。
