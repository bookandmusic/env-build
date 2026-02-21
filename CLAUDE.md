# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目简介

Ubuntu 开发环境自动化构建工具，使用模块化 Shell 脚本编排，支持三种镜像变体：code-server（远程开发）、ubuntu-dev（轻量容器）、ubuntu-wsl（WSL2 本地开发）。基础镜像为 ubuntu:24.04。

## 镜像变体

| 镜像 | 使用场景 | 核心特性 |
|------|---------|---------|
| **code-server** | 远程开发环境 | SSH + Code-Server + Docker CLI + 完整工具链 |
| **ubuntu-dev** | 轻量开发容器 | SSH + Docker CLI + 完整工具链（无 IDE） |
| **ubuntu-wsl** | WSL2 本地开发 | systemd + 完整 Docker + Homebrew + 工具链 |

## 常用命令

### 直接执行

```bash
# 设置环境变量
export IMAGE_VARIANT=ubuntu-dev  # 或 code-server, ubuntu-wsl
export DOCKER_MODE=cli-only      # 或 full, none

# root 级配置（系统依赖、用户创建、Docker）
sudo ./scripts/orchestration/root-setup.sh

# 用户级配置（zsh、工具链、vim、code-server）
su - ubuntu
./scripts/orchestration/user-setup.sh
```

### Docker 构建

```bash
# 一键构建所有镜像
./scripts/build-images.sh

# 或单独构建
docker build --target code-server -t code-server:latest .
docker build --target ubuntu-dev -t ubuntu-dev:latest .
docker build --target ubuntu-wsl -t ubuntu-dev-wsl:latest .

# 运行
docker run -d -p 22:22 -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  code-server:latest

docker run -d -p 2222:22 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ubuntu-dev:latest

# WSL 导出
./scripts/export-wsl.sh ubuntu-dev-wsl:latest ubuntu-dev-wsl.tar
```

### 单脚本测试

```bash
# 可单独执行任意安装脚本进行测试
./scripts/installation/01-system-deps.sh
```

## 架构

### 两阶段编排模型

**Stage 1 — root-setup.sh**（root 权限）按序执行：
1. `01-system-deps.sh` — 系统基础包（含 netcat）
2. `03-user-config.sh` — 创建 ubuntu 用户、WSL 配置
3. `02-docker-cli-setup.sh` 或 `02-docker-engine-setup.sh` — Docker 安装（根据 DOCKER_MODE）

**Stage 2 — user-setup.sh**（ubuntu 用户）按序执行：
4. `04-oh-my-zsh-setup.sh` — Zsh + 插件
5. `05-toolchain-setup.sh` — mise 工具链（WSL 变体含 Homebrew）
6. `06-vimrc.sh` — Vim 配置
7. `07-code-server.sh` — Code-Server（条件执行，内部守卫）

### 核心配置层

- `scripts/configs/common.sh` — 公共函数库（log/error/warn、install_apt_packages、safe_git_clone、create_config_file、add_to_zshrc）+ 镜像源常量
- `scripts/configs/variables.sh` — 环境变量默认值、验证逻辑、预检查
- `scripts/configs/start-services.sh` — 容器入口点脚本（根据 IMAGE_VARIANT 启动不同服务）
- `scripts/configs/wsl.conf` — WSL 配置模板
- `scripts/export-wsl.sh` — WSL 镜像导出工具
- `scripts/build-images.sh` — 一键构建所有镜像

### 环境变量控制

| 变量 | 默认值 | 可选值 | 作用 |
|------|--------|--------|------|
| `IMAGE_VARIANT` | `ubuntu-dev` | `code-server`, `ubuntu-dev`, `ubuntu-wsl` | 镜像变体标识 |
| `DOCKER_MODE` | `cli-only` | `none`, `cli-only`, `full` | Docker 安装模式 |
| `INSTALL_CODE_SERVER` | `false` | `true`, `false` | 是否安装 Code-Server |
| `CONFIG_USER` | `true` | `true`, `false` | 是否创建 ubuntu 用户 |
| `WSL_CONFIG` | `false` | `true`, `false` | 是否启用 WSL 配置 |

**向后兼容**：`INSTALL_DOCKER=true` 自动映射为 `DOCKER_MODE=full`

值只接受 `true` / `false` 字符串。

### Dockerfile

多阶段构建，三个构建目标：
- `code-server` — IMAGE_VARIANT=code-server, DOCKER_MODE=cli-only, INSTALL_CODE_SERVER=true
- `ubuntu-dev` — IMAGE_VARIANT=ubuntu-dev, DOCKER_MODE=cli-only, INSTALL_CODE_SERVER=false
- `ubuntu-wsl` — IMAGE_VARIANT=ubuntu-wsl, DOCKER_MODE=full, WSL_CONFIG=true

## 代码规范

### Shell 脚本

- 头部必须 `set -eo pipefail`，通过 `SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)` 动态定位并 `source common.sh`
- 使用 `log()` / `error()` / `warn()` 输出，不直接 echo
- APT 安装统一用 `install_apt_packages()`，git 克隆用 `safe_git_clone()`
- `.zshrc` 追加使用 `add_to_zshrc()` 确保幂等
- 条件功能通过环境变量判断（`IMAGE_VARIANT`, `DOCKER_MODE`, `INSTALL_CODE_SERVER`）
- 条件脚本内部包含守卫，支持独立执行

### 命名

- 脚本文件：kebab-case（`root-setup.sh`）
- 环境变量/常量：UPPER_SNAKE_CASE（`IMAGE_VARIANT`、`DOCKER_MODE`、`TSINGHUA_MIRROR`）
- 函数：lower_snake_case（`check_command`、`safe_git_clone`）
- Docker 镜像：小写连字符（`ubuntu-dev`、`code-server`、`ubuntu-dev-wsl`）

### Dockerfile

- 多阶段构建：base → code-server / ubuntu-dev / ubuntu-wsl
- 使用 `--no-install-recommends` 并清理 `/var/lib/apt/lists/*`
- 每个变体独立设置环境变量

### Git 提交

格式：`feat:` / `fix:` / `docs:` / `refactor:` / `test:` / `chore:`，中文描述。

## 镜像源

项目全局使用国内镜像加速，定义在 `common.sh`：清华（APT/PyPI/Homebrew）、npmmirror（NPM）、goproxy.io（Go）、docker.1ms.run（Docker）。修改脚本时注意保持镜像源一致性。

## 关键设计决策

1. **用户创建顺序**：03-user-config.sh 在 Docker 安装之前执行，确保 ubuntu 用户存在后再添加到 docker 组
2. **Homebrew 条件安装**：仅在 IMAGE_VARIANT=ubuntu-wsl 时安装，减少其他镜像体积
3. **Docker 模式分离**：cli-only（仅 CLI，用于 socket 挂载）vs full（完整 Engine，用于 WSL）
4. **WSL systemd**：ubuntu-wsl 使用 /sbin/init 作为 ENTRYPOINT，通过 wsl.conf 设置默认用户
5. **镜像命名**：code-server 作为独立镜像名（非标签），方便版本管理
