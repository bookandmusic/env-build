# Ubuntu 开发环境构建工具

自动化构建标准化 Ubuntu 24.04 开发环境，提供两种镜像变体：轻量开发容器和 WSL2 本地开发环境。基础镜像为 ubuntu:24.04。

## 镜像变体

| 镜像 | 使用场景 | Docker | 核心特性 |
|------|---------|--------|---------|
| **ubuntu-dev** | 轻量开发容器 | CLI only | SSH + Docker CLI + mise + 完整工具链 |
| **ubuntu-wsl** | WSL2 本地开发 | 完整 Engine | systemd + 完整 Docker + mise + 完整工具链 |

两种镜像均不包含 Code-Server 或 Homebrew。

### 工具链说明

所有镜像包含：

- **运行时**：Node.js 24, Python 3.13, Go 1.25, uv（通过 mise 管理）
- **AI 工具**：opencode-ai, codex, claude-code
- **基础工具**：curl, wget, git, vim, zsh + Oh My Zsh, Starship

## 快速开始

### ubuntu-dev 镜像

适用于轻量级开发容器，通过 Docker Socket 操作宿主机 Docker。

```bash
# 拉取镜像
docker pull ghcr.io/bookandmusic/ubuntu-dev:latest

# 启动容器（挂载 Docker Socket）
docker run -d \
  -p 2222:22 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $(stat -c '%g' /var/run/docker.sock) \
  --name ubuntu-dev \
  ghcr.io/bookandmusic/ubuntu-dev:latest

# SSH 登录
ssh ubuntu@localhost -p 2222  # 密码: 1

# 容器内操作
docker ps                          # 通过 socket 操作宿主机 Docker
service opencode start             # 启动 opencode 服务
service opencode status            # 查看 opencode 状态
tail -f ~/.opencode-server/logs/opencode.log  # 查看 opencode 日志
```

**特性**：

- SSH Server（端口 22，容器启动即就绪）
- Docker CLI（通过 socket 操作宿主机 Docker）
- mise + 完整运行时工具
- opencode 由用户登录后通过 `service opencode start` 启动
- 无 Code-Server
- 无 Docker Engine
- 无 Homebrew

---

### ubuntu-wsl 镜像

适用于 WSL2 本地开发环境，完整 Docker + systemd 支持。

#### 步骤 1: 下载镜像

从 [Releases](https://github.com/bookandmusic/env-build/releases) 下载对应架构的文件：

```powershell
# Windows PowerShell
$env:PROCESSOR_ARCHITECTURE
# AMD64 → 下载 amd64 版本
# ARM64 → 下载 arm64 版本
```

下载文件：

- `ubuntu-dev-wsl-amd64.tar.gz`（Intel/AMD 处理器）
- `ubuntu-dev-wsl-arm64.tar.gz`（ARM 处理器）

如果文件被切分为 `.part*`，需要先合并：

```powershell
Get-Content ubuntu-dev-wsl-amd64.tar.gz.part* -Raw | Set-Content ubuntu-dev-wsl-amd64.tar.gz -Encoding Byte
```

#### 步骤 2: 导入到 WSL

```powershell
# 解压
tar -xzf ubuntu-dev-wsl-amd64.tar.gz

# 导入到 WSL2
wsl --import UbuntuDev C:\WSL\UbuntuDev ubuntu-dev-wsl-amd64.tar

# 启动 WSL
wsl -d UbuntuDev
```

#### 步骤 3: 验证环境

```bash
# 检查默认用户（应该是 ubuntu）
whoami  # ubuntu

# 检查 systemd
systemctl status  # 应该正常运行

# 检查 Docker 服务
systemctl status docker  # active (running)
docker ps  # 无需 socket 挂载，直接使用

# 检查工具链
node --version  # v24.x
python --version  # 3.13.x
go version  # 1.25.x
mise list
```

#### WSL 高级配置

WSL 版本要求：≥ 0.67.6。

```powershell
wsl --version
wsl --update
```

Docker 完整测试：

```bash
docker pull hello-world
docker run hello-world
docker build -t test .
docker compose up -d
```

**特性**：

- systemd（完整 Linux 体验）
- Docker Engine（完整安装，无需宿主机）
- Docker CLI + Compose
- mise + 完整运行时工具
- SSH Server（systemd 管理）
- 默认用户 ubuntu
- 无 Code-Server
- 无 Homebrew

---

## 本地构建（开发者）

```bash
# 克隆仓库
git clone https://github.com/bookandmusic/env-build.git
cd env-build

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

## 独立脚本执行

适用于物理机、虚拟机或已有 Ubuntu 系统：

```bash
# root 级配置（系统依赖、用户创建、Docker）
sudo ./setup.sh

# 用户级配置（zsh、工具链、vim）
su - ubuntu
./setup.sh
```

`setup.sh` 会通过 `id -u` 自动判断当前阶段：

- root 用户：安装系统依赖、创建 ubuntu 用户、安装 Docker、配置 WSL
- ubuntu 用户：安装 Oh My Zsh、mise 工具链、Vim 配置

## 环境变量

| 变量 | 默认值 | 可选值 | 说明 |
|------|--------|--------|------|
| `IMAGE_VARIANT` | `ubuntu-dev` | `ubuntu-dev`, `ubuntu-wsl` | 镜像变体标识 |

Docker 模式由 `IMAGE_VARIANT` 自动推导：

- `ubuntu-dev` → Docker CLI only
- `ubuntu-wsl` → Docker Engine full

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
- `Dockerfile` — 多阶段构建：`ubuntu-dev` 和 `ubuntu-wsl`
- `opencode.init` — ubuntu-wsl 的 SysV init 服务脚本
- `.github/workflows/docker-images.yaml` — 构建并推送两个镜像，导出 WSL tarball

### Dockerfile

多阶段构建，两个构建目标：

- `ubuntu-dev` — `IMAGE_VARIANT=ubuntu-dev`，Docker CLI only
- `ubuntu-wsl` — `IMAGE_VARIANT=ubuntu-wsl`，Docker Engine full + systemd

## 常见问题

### Q: Docker Socket 挂载权限问题？

需要将容器内用户添加到宿主机 docker 组：

```bash
docker run -d \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $(stat -c '%g' /var/run/docker.sock) \
  ghcr.io/bookandmusic/ubuntu-dev:latest
```

或者使用 sudo：

```bash
docker exec -u ubuntu <container> sudo docker ps
```

### Q: WSL 中 systemd 未启动？

检查 WSL 版本：

```powershell
wsl --version
wsl --update
```

### Q: mise 工具未生效？

确保使用 zsh 并重新加载配置：

```bash
exec zsh -l
mise list
```

### Q: opencode 服务无法启动？

查看日志排查问题：

```bash
service opencode status
tail -f ~/.opencode-server/logs/opencode.log
```

日志和 PID 文件位置：
- 日志：`~/.opencode-server/logs/opencode.log`
- PID：`~/.opencode-server/run/opencode.pid`

## 镜像体积对比

| 镜像 | 预估体积 | 说明 |
|------|---------|------|
| ubuntu-dev | ~2.0GB | 最轻量，仅 Docker CLI |
| ubuntu-wsl | ~3.0GB | 完整 Docker + systemd |

## 技术栈

- **基础镜像**: Ubuntu 24.04
- **Shell**: Zsh + Oh My Zsh
- **包管理**: mise（运行时）, apt（系统包）
- **容器化**: Docker + Docker Compose
- **镜像源**: npmmirror（npm）、goproxy.io（Go）、docker.1ms.run（Docker）

## 贡献

欢迎提交 Issue 和 Pull Request。

## 许可证

MIT License
