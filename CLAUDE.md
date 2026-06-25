# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目简介

Ubuntu 开发环境自动化构建工具，使用单一 Shell 脚本编排，支持两种镜像变体：ubuntu-dev（轻量容器）和 ubuntu-wsl（WSL2 本地开发）。基础镜像为 ubuntu:24.04。

## 镜像变体

| 镜像 | 使用场景 | Docker | 核心特性 |
|------|---------|--------|---------|
| **ubuntu-dev** | 轻量开发容器 | CLI only | SSH + Docker CLI + mise + 完整工具链 |
| **ubuntu-wsl** | WSL2 本地开发 | 完整 Engine | systemd + 完整 Docker + mise + 完整工具链 |

两种镜像均不包含 Code-Server 或 Homebrew。

## 常用命令

### 直接执行

```bash
# root 级配置（系统依赖、用户创建、Docker）
sudo ./setup.sh

# 用户级配置（zsh、工具链、vim）
su - ubuntu
./setup.sh
```

`setup.sh` 通过 `id -u` 自动判断执行阶段。

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

### 单脚本测试

```bash
bash -n setup.sh
bash -n start.sh
```

## 架构

### 单一脚本模型

`setup.sh` 是项目的唯一入口脚本，按当前用户自动执行不同阶段：

**Root 阶段**：

1. 安装系统基础包
2. 创建 ubuntu 用户
3. 安装 Docker CLI 或 Docker Engine
4. 配置 WSL systemd（仅 ubuntu-wsl）

**User 阶段**：

1. 安装 Zsh + Oh My Zsh + 插件
2. 安装 mise 工具链
3. 安装 Vim 配置

### 核心配置

- `setup.sh` — 唯一安装入口，合并公共函数、系统依赖、用户配置、Docker、Zsh、mise、Vim
- `opencode.init` — SysV init 服务脚本，管理 opencode 服务的启动、停止、重启和状态检查
- `Dockerfile` — 两阶段构建：`ubuntu-dev` 和 `ubuntu-wsl`
- `.github/workflows/docker-images.yaml` — 构建并推送两个镜像，导出 WSL tarball

### opencode 服务

- **服务管理**：`service opencode {start|stop|restart|status}`
- **运行用户**：ubuntu
- **工作目录**：`~/.opencode-server/`
  - 日志：`~/.opencode-server/logs/opencode.log`
  - PID：`~/.opencode-server/run/opencode.pid`
- **端口**：4096（可通过 `OPENCODE_PORT` 环境变量修改）

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

- 脚本文件：kebab-case（`setup.sh`）
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

项目全局使用国内镜像加速：

- APT/PyPI/Homebrew：清华大学开源镜像站
- NPM：npmmirror
- Go：goproxy.io
- Docker：docker.1ms.run

## 关键设计决策

1. **单一脚本入口**：`setup.sh` 通过 `id -u` 自动区分 root/user 阶段
2. **Docker 模式自动推导**：`IMAGE_VARIANT` 自动决定 Docker CLI only 或 Docker Engine full
3. **去掉 Code-Server**：专注于轻量开发环境
4. **去掉 Homebrew**：减少 WSL2 镜像体积
5. **WSL systemd**：`ubuntu-wsl` 使用 `/sbin/init` 作为 ENTRYPOINT
6. **镜像命名**：`ubuntu-dev` 和 `ubuntu-wsl` 作为独立镜像名，方便版本管理
