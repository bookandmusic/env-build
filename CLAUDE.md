# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目简介

Ubuntu 开发环境自动化构建工具，使用模块化 Shell 脚本编排，支持 Docker 容器、WSL2 和物理机/虚拟机部署。基础镜像为 ubuntu:24.04。

## 常用命令

### 直接执行

```bash
# root 级配置（系统依赖、Docker、用户创建）
sudo ./scripts/orchestration/root-setup.sh

# 用户级配置（zsh、工具链、vim、code-server）
su - ubuntu
./scripts/orchestration/user-setup.sh
```

### Docker 构建

```bash
# SSH 最小容器
docker build -t ubuntu-dev:latest .

# SSH + Code-Server 容器
docker build --build-arg INSTALL_CODE_SERVER=true -t code-server:latest .

# WSL 导出用镜像
docker build --build-arg WSL_CONFIG=true -t ubuntu-dev-wsl:latest .

# 运行
docker run -d -p 22:22 --name ubuntu-dev ubuntu-dev:latest
docker run -d -p 22:22 -p 8080:8080 --name code-server code-server:latest

# WSL 导出
./scripts/export-wsl.sh
```

### 单脚本测试

```bash
# 可单独执行任意安装脚本进行测试
./scripts/installation/01-system-deps.sh
```

## 架构

### 两阶段编排模型

**Stage 1 — root-setup.sh**（root 权限）按序执行：
1. `01-system-deps.sh` — 系统基础包
2. `02-docker-setup.sh` — Docker（条件执行，内部守卫）
3. `03-user-config.sh` — 用户创建、WSL 配置、starship

**Stage 2 — user-setup.sh**（ubuntu 用户）按序执行：
4. `04-oh-my-zsh-setup.sh` — Zsh + 插件
5. `05-toolchain-setup.sh` — mise/Homebrew 管理的开发工具链
6. `06-vimrc.sh` — Vim 配置
7. `07-code-server.sh` — Code-Server IDE（条件执行，内部守卫）

### 核心配置层

- `scripts/configs/common.sh` — 公共函数库（log/error/warn、install_apt_packages、safe_git_clone、create_config_file、add_to_zshrc）+ 镜像源常量
- `scripts/configs/variables.sh` — 环境变量默认值、验证逻辑、预检查（网络连通性、磁盘空间）
- `scripts/configs/start-services.sh` — 容器入口点脚本（自包含，不依赖 common.sh）
- `scripts/export-wsl.sh` — WSL 镜像导出工具

### 环境变量控制

| 变量 | 默认值 | 作用 |
|------|--------|------|
| `INSTALL_DOCKER` | `true` | 安装 Docker（容器内硬编码 `false`） |
| `INSTALL_CODE_SERVER` | `false` | 安装 Code-Server |
| `CONFIG_USER` | `true` | 创建 ubuntu 用户 |
| `WSL_CONFIG` | `true` | WSL2 systemd 配置 |

值只接受 `true` / `false` 字符串。

### Dockerfile

单一 Dockerfile 通过 build ARG 控制变体：
- `INSTALL_CODE_SERVER`（默认 `false`）— 是否安装 Code-Server
- `WSL_CONFIG`（默认 `false`）— 是否启用 WSL 配置
- `INSTALL_DOCKER` 硬编码为 `false`，不暴露为 ARG

## 代码规范

### Shell 脚本

- 头部必须 `set -eo pipefail`，通过 `SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)` 动态定位并 `source common.sh`
- 使用 `log()` / `error()` / `warn()` 输出，不直接 echo
- APT 安装统一用 `install_apt_packages()`，git 克隆用 `safe_git_clone()`
- `.zshrc` 追加使用 `add_to_zshrc()` 确保幂等
- 条件功能通过 `if [ "${VAR}" = "true" ]` 判断环境变量
- 条件脚本（02-docker-setup.sh、07-code-server.sh）内部包含守卫，支持独立执行

### 命名

- 脚本文件：kebab-case（`root-setup.sh`）
- 环境变量/常量：UPPER_SNAKE_CASE（`INSTALL_DOCKER`、`TSINGHUA_MIRROR`）
- 函数：lower_snake_case（`check_command`、`safe_git_clone`）
- Docker 镜像：小写连字符（`ubuntu-dev`、`code-server`）

### Dockerfile

- 两层构建：Layer 1 root 操作 → Layer 2 user 操作
- 使用 `--no-install-recommends` 并清理 `/var/lib/apt/lists/*`

### Git 提交

格式：`feat:` / `fix:` / `docs:` / `refactor:` / `test:` / `chore:`，中文描述。

## 镜像源

项目全局使用国内镜像加速，定义在 `common.sh`：清华（APT/PyPI/Homebrew）、npmmirror（NPM）、goproxy.io（Go）、docker.1ms.run（Docker）。修改脚本时注意保持镜像源一致性。
