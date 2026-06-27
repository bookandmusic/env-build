# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目简介

Ubuntu 开发环境自动化构建工具，使用单一 Shell 脚本编排，支持两种镜像变体：ubuntu-dev（轻量容器）和 ubuntu-wsl（WSL2 本地开发）。基础镜像为 ubuntu:24.04。

## 镜像变体

| 镜像 | 使用场景 | Docker | 核心特性 |
|------|---------|--------|---------|
| **ubuntu-dev** | 轻量开发容器 | CLI only | SSH + Docker CLI + mise + 完整工具链 + opencode Web UI + CloudCLI Web UI |
| **ubuntu-wsl** | WSL2 本地开发 | 完整 Engine | systemd + 完整 Docker + mise + 完整工具链 |

两种镜像均不包含 Code-Server 或 Homebrew。

### 端口说明（仅 ubuntu-dev）

| 端口 | 服务 | 说明 |
|------|------|------|
| 22 | sshd | SSH 远程访问 |
| 3001 | CloudCLI | AI 编程工具 Web 界面（Claude/Codex/Cursor/Gemini） |
| 4096 | opencode | opencode HTTP 服务 |

## 常用命令

### 直接执行

```bash
# root 级配置（系统依赖、用户创建、Docker）
sudo ./scripts/setup.sh

# 用户级配置（zsh、工具链、vim）
su - ubuntu
./scripts/setup.sh
```

`scripts/setup.sh` 通过 `id -u` 自动判断执行阶段。

### Docker 构建

```bash
# 单独构建 ubuntu-dev
docker build --target ubuntu-dev -t ubuntu-dev:latest .

# 单独构建 ubuntu-wsl
docker build --target ubuntu-wsl -t ubuntu-wsl:latest .

# 构建 WSL 导出镜像
docker build --target ubuntu-wsl -t ubuntu-dev-wsl:latest .
docker create --name ubuntu-dev-wsl-export ubuntu-dev-wsl:latest
docker export ubuntu-dev-wsl-export -o ubuntu-dev-wsl.tar
docker rm ubuntu-dev-wsl-export
```

### Docker Compose（推荐）

参见 README.md 中的 docker-compose.yml 配置示例，支持数据持久化。

**持久化目录**：

| 目录 | 用途 |
|------|------|
| `data/claude` | Claude Code + CloudCLI 配置 |
| `data/codex` | Codex 配置 |
| `data/opencode` | OpenCode 配置 |
| `data/cloudcli` | CloudCLI 数据库 |
| `data/cc-switch` | cc-switch-cli 配置 |
| `data/mise` | mise 工具链配置 |
| `workspace` | 项目工作目录 |

### 单脚本测试

```bash
bash -n scripts/setup.sh
```

## 架构

### 单一脚本模型

`scripts/setup.sh` 是项目的唯一入口脚本，按当前用户自动执行不同阶段：

**Root 阶段**：

1. 安装系统基础包
2. 创建 ubuntu 用户
3. 安装 chsrc 和 starship
4. 安装 Docker CLI 或 Docker Engine
5. 配置 WSL systemd（仅 ubuntu-wsl）
6. 安装 opencode 服务管理脚本

**User 阶段**：

1. 安装 Zsh + Oh My Zsh + 插件
2. 安装 mise 工具链
3. 安装 Vim 配置
4. 安装 AI 编程工具（opencode-ai、codex、claude-code、cloudcli、cc-switch-cli）

### 核心配置

- `scripts/setup.sh` — 唯一安装入口，合并公共函数、系统依赖、用户配置、Docker、Zsh、mise、Vim
- `scripts/services/opencode.init` — SysV init 服务脚本，管理 opencode 服务的启动、停止、重启和状态检查
- `Dockerfile` — 两阶段构建：`ubuntu-dev` 和 `ubuntu-wsl`
- `.github/workflows/docker-images.yaml` — 构建并推送两个镜像，导出 WSL tarball

### opencode 服务

- **服务管理**：`service opencode {start|stop|restart|status}`
- **运行用户**：ubuntu
- **工作目录**：`~/.opencode-server/`
  - 日志：`~/.opencode-server/logs/opencode.log`
  - PID：`~/.opencode-server/run/opencode.pid`
- **端口**：4096（可通过 `OPENCODE_PORT` 环境变量修改）
- **仅 ubuntu-dev**：WSL 变体不安装 opencode 服务管理脚本

### CloudCLI Web UI

- **服务管理**：`service cloudcli {start|stop|restart|status}`
- **访问地址**：`http://localhost:3001`
- **支持工具**：Claude Code、Codex、Cursor CLI、Gemini CLI
- **功能**：聊天、Shell 终端、文件浏览器、Git 浏览器、会话管理
- **端口**：3001（可通过 `CLOUDCLI_PORT` 环境变量修改）
- **仅 ubuntu-dev**：WSL 变体不安装 CloudCLI

### cc-switch-cli

- **用途**：管理和切换多个 AI 编程助手的服务提供商配置
- **启动命令**：`cc-switch-cli`
- **支持工具**：Claude Code、Codex、Gemini CLI 等

### 环境变量控制

| 变量 | 默认值 | 可选值 | 作用 |
|------|--------|--------|------|
| `IMAGE_VARIANT` | `ubuntu-dev` | `ubuntu-dev`, `ubuntu-wsl` | 镜像变体标识 |

Docker 模式由 `IMAGE_VARIANT` 自动推导：

- `ubuntu-dev` → Docker CLI only
- `ubuntu-wsl` → Docker Engine full

### Dockerfile

多阶段构建，两个构建目标：

- `ubuntu-dev` — `IMAGE_VARIANT=ubuntu-dev`，Docker CLI only
- `ubuntu-wsl` — `IMAGE_VARIANT=ubuntu-wsl`，Docker Engine full + systemd

## 代码规范

### Shell 脚本

- 头部必须 `set -eo pipefail`
- 使用 `log()` / `error()` / `warn()` 输出
- APT 安装统一用 `install_apt_packages()`
- git 克隆用 `safe_git_clone()`
- `.zshrc` 追加使用 `add_to_zshrc()` 确保幂等
- 配置文件创建用 `create_config_file()`

### 命名

- 脚本文件：kebab-case（`setup.sh` → `scripts/setup.sh`）
- 环境变量/常量：UPPER_SNAKE_CASE（`IMAGE_VARIANT`、`TSINGHUA_MIRROR`）
- 函数：lower_snake_case（`check_command`、`safe_git_clone`）
- Docker 镜像：小写连字符（`ubuntu-dev`、`ubuntu-wsl`）

### Dockerfile

- 多阶段构建：base → ubuntu-dev / ubuntu-wsl
- 使用 `--no-install-recommends` 并清理 `/var/lib/apt/lists/*`
- 每个变体独立设置 `IMAGE_VARIANT`

### Git 提交

格式：`feat:` / `fix:` / `docs:` / `refactor:` / `test:` / `chore:`，中文描述。

## 镜像源

构建时使用官方源，运行时通过 chsrc 按需切换：

- NPM：npmmirror（`chsrc npm npmmirror`）
- Go：goproxy.cn（`chsrc go goproxy.cn`）
- Docker：docker.1ms.run（daemon.json 中配置）

## 关键设计决策

1. **单一脚本入口**：`scripts/setup.sh` 通过 `id -u` 自动区分 root/user 阶段
2. **Docker 模式自动推导**：`IMAGE_VARIANT` 自动决定 Docker CLI only 或 Docker Engine full
3. **去掉 Code-Server**：专注于轻量开发环境
4. **去掉 Homebrew**：减少 WSL2 镜像体积
5. **WSL systemd**：`ubuntu-wsl` 使用 `/sbin/init` 作为 ENTRYPOINT
6. **镜像命名**：`ubuntu-dev` 和 `ubuntu-wsl` 作为独立镜像名，方便版本管理
