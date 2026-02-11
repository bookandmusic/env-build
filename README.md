# Ubuntu 开发环境构建工具

自动化构建标准化 Ubuntu 开发环境，支持独立脚本执行、Docker 容器和 WSL2 导入三种部署方式。基础镜像为 ubuntu:24.04。

## 快速开始

### 独立脚本执行

适用于物理机、虚拟机或已有 Ubuntu 系统：

```bash
# 按需设置环境变量
export INSTALL_DOCKER=true
export CONFIG_USER=true

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
docker run -d -p 22:22 --name ubuntu-dev ubuntu-dev:latest

# SSH + Code-Server 容器
docker build --build-arg INSTALL_CODE_SERVER=true -t code-server:latest .
docker run -d -p 22:22 -p 8080:8080 --name code-server code-server:latest
```

### WSL 导入

```bash
# 构建 WSL 专用镜像并导出
docker build --build-arg WSL_CONFIG=true -t ubuntu-dev-wsl:latest .
./scripts/export-wsl.sh

# Windows 侧导入
wsl --import UbuntuDev <安装路径> ubuntu-dev-wsl.tar
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `INSTALL_DOCKER` | `true` | 安装 Docker（容器内自动禁用） |
| `CONFIG_USER` | `true` | 创建 ubuntu 用户并配置 sudo |
| `WSL_CONFIG` | `true` | WSL2 systemd 配置 |
| `INSTALL_CODE_SERVER` | `false` | 安装 Code-Server IDE |

值只接受 `true` / `false` 字符串。Docker 构建时 `INSTALL_DOCKER` 硬编码为 `false`。

## 架构

两阶段编排模型：

**Stage 1 — root-setup.sh**（root 权限）：
1. `01-system-deps.sh` — 系统基础包
2. `02-docker-setup.sh` — Docker（条件执行）
3. `03-user-config.sh` — 用户创建、WSL 配置、starship

**Stage 2 — user-setup.sh**（ubuntu 用户）：

4. `04-oh-my-zsh-setup.sh` — Zsh + 插件
5. `05-toolchain-setup.sh` — mise/Homebrew 管理的开发工具链
6. `06-vimrc.sh` — Vim 配置
7. `07-code-server.sh` — Code-Server IDE（条件执行）

核心配置：

- `scripts/configs/common.sh` — 公共函数库 + 镜像源常量
- `scripts/configs/variables.sh` — 环境变量默认值与验证
- `scripts/configs/start-services.sh` — 容器入口点脚本
