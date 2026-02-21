# Ubuntu 开发环境构建工具

自动化构建标准化 Ubuntu 24.04 开发环境，提供三种专用镜像变体，满足不同使用场景。

## 镜像变体

| 镜像 | 使用场景 | 核心特性 |
|------|---------|---------|
| **code-server** | 远程开发环境 | SSH + Code-Server + Docker CLI + 完整工具链 |
| **ubuntu-dev** | 轻量开发容器 | SSH + Docker CLI + 完整工具链（无 IDE） |
| **ubuntu-wsl** | WSL2 本地开发 | systemd + 完整 Docker + Homebrew + 工具链 |

### 工具链说明

所有镜像包含：
- **运行时**：Node.js 24, Python 3.13, Go 1.25（通过 mise 管理）
- **CLI 工具**：bat, eza, fd, fzf, ripgrep, lazydocker, lazygit 等
- **开发工具**：goimports-reviser, gofumpt, gosec, glances, httpie 等
- **基础工具**：netcat, curl, wget, git, vim, zsh + Oh My Zsh

**ubuntu-wsl 额外包含**：Homebrew（用于本地开发环境）

## 快速开始

### code-server 镜像

适用于需要 Web IDE 的远程开发场景。

```bash
# 拉取镜像
docker pull ghcr.io/bookandmusic/code-server:latest

# 启动容器（挂载 Docker Socket）
docker run -d \
  -p 22:22 -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $(stat -c '%g' /var/run/docker.sock) \
  --name code-server \
  ghcr.io/bookandmusic/code-server:latest

# 访问方式
# SSH: ssh ubuntu@localhost -p 22（密码: 1）
# Code-Server: http://localhost:8080

# 验证 Docker CLI
docker exec -u ubuntu code-server docker ps

# 验证运行时工具
docker exec -u ubuntu code-server node --version  # v24.x
docker exec -u ubuntu code-server python --version  # 3.13.x
docker exec -u ubuntu code-server go version  # 1.25.x
```

**特性**：
- ✅ SSH Server（端口 22）
- ✅ Code-Server（端口 8080，无需认证）
- ✅ Docker CLI（通过 socket 操作宿主机 Docker）
- ✅ mise + 完整运行时工具
- ❌ Docker Engine（使用宿主机）
- ❌ Homebrew

---

### ubuntu-dev 镜像

适用于轻量级开发容器，无 IDE 开销。

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
docker ps  # 通过 socket 操作宿主机 Docker
mise list  # 查看已安装工具
node --version
```

**特性**：
- ✅ SSH Server（端口 22）
- ✅ Docker CLI（通过 socket 操作宿主机 Docker）
- ✅ mise + 完整运行时工具
- ❌ Code-Server
- ❌ Docker Engine
- ❌ Homebrew

---

### ubuntu-wsl 镜像

适用于 WSL2 本地开发环境，完整 Docker + systemd 支持。

#### 步骤 1: 下载镜像

从 [Releases](https://github.com/bookandmusic/env-build/releases) 下载对应架构的文件：

**确定你的架构**：
```powershell
# Windows PowerShell
$env:PROCESSOR_ARCHITECTURE
# AMD64 → 下载 amd64 版本
# ARM64 → 下载 arm64 版本
```

下载文件：
- `ubuntu-dev-wsl-amd64.tar.gz`（Intel/AMD 处理器）
- `ubuntu-dev-wsl-arm64.tar.gz`（ARM 处理器）

**如果文件被切分为 `.part*`**，需要先合并：
```powershell
# Windows PowerShell
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
brew --version  # Homebrew 版本

# 检查 mise
mise list
```

#### WSL 高级配置

**启用 systemd（如果未生效）**：

WSL 版本要求：≥ 0.67.6

```bash
# 检查 WSL 版本
wsl --version

# 如果 systemd 未启动，检查配置
cat /etc/wsl.conf
```

应该包含：
```ini
[boot]
systemd=true

[user]
default=ubuntu
```

**Docker 完整测试**：

```bash
# 拉取镜像
docker pull hello-world

# 运行容器
docker run hello-world

# 构建镜像
docker build -t test .

# 使用 docker-compose
docker compose up -d
```

**特性**：
- ✅ systemd（完整 Linux 体验）
- ✅ Docker Engine（完整安装，无需宿主机）
- ✅ Docker CLI + Compose
- ✅ mise + 完整运行时工具
- ✅ Homebrew
- ✅ SSH Server（systemd 管理）
- ✅ 默认用户 ubuntu
- ❌ Code-Server

---

## 本地构建（开发者）

如果需要自定义或贡献代码：

```bash
# 克隆仓库
git clone https://github.com/bookandmusic/env-build.git
cd env-build

# 一键构建所有镜像
./scripts/build-images.sh

# 或单独构建
docker build --target code-server -t code-server:latest .
docker build --target ubuntu-dev -t ubuntu-dev:latest .
docker build --target ubuntu-wsl -t ubuntu-dev-wsl:latest .
```

## 独立脚本执行

适用于物理机、虚拟机或已有 Ubuntu 系统：

```bash
# 设置环境变量
export IMAGE_VARIANT=ubuntu-dev  # 或 code-server, ubuntu-wsl
export DOCKER_MODE=cli-only      # 或 full, none
export INSTALL_CODE_SERVER=false # 或 true

# root 级配置
sudo ./scripts/orchestration/root-setup.sh

# 用户级配置
su - ubuntu
./scripts/orchestration/user-setup.sh
```

## 环境变量

| 变量 | 默认值 | 可选值 | 说明 |
|------|--------|--------|------|
| `IMAGE_VARIANT` | `ubuntu-dev` | `code-server`, `ubuntu-dev`, `ubuntu-wsl` | 镜像变体标识 |
| `DOCKER_MODE` | `cli-only` | `none`, `cli-only`, `full` | Docker 安装模式 |
| `INSTALL_CODE_SERVER` | `false` | `true`, `false` | 是否安装 Code-Server |
| `CONFIG_USER` | `true` | `true`, `false` | 是否创建 ubuntu 用户 |
| `WSL_CONFIG` | `false` | `true`, `false` | 是否启用 WSL 配置 |

**向后兼容**：`INSTALL_DOCKER=true` 自动映射为 `DOCKER_MODE=full`

## 架构

### 两阶段编排模型

**Stage 1 — root-setup.sh**（root 权限）：
1. `01-system-deps.sh` — 系统基础包（含 netcat）
2. `03-user-config.sh` — 创建 ubuntu 用户、WSL 配置
3. `02-docker-cli-setup.sh` 或 `02-docker-engine-setup.sh` — Docker 安装

**Stage 2 — user-setup.sh**（ubuntu 用户）：
4. `04-oh-my-zsh-setup.sh` — Zsh + 插件
5. `05-toolchain-setup.sh` — mise 工具链（WSL 变体含 Homebrew）
6. `06-vimrc.sh` — Vim 配置
7. `07-code-server.sh` — Code-Server（条件执行）

### 核心配置

- `scripts/configs/common.sh` — 公共函数库 + 镜像源常量
- `scripts/configs/variables.sh` — 环境变量验证
- `scripts/configs/start-services.sh` — 容器启动脚本
- `scripts/configs/wsl.conf` — WSL 配置模板

## 常见问题

### Q: Docker Socket 挂载权限问题？

**A**: 需要将容器内用户添加到宿主机 docker 组：

```bash
# 启动时添加 docker 组权限
docker run -d \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $(stat -c '%g' /var/run/docker.sock) \
  ghcr.io/bookandmusic/ubuntu-dev:latest

# 或者使用 sudo（ubuntu 用户有 sudo 权限）
docker exec -u ubuntu <container> sudo docker ps
```

### Q: WSL 中 systemd 未启动？

**A**: 检查 WSL 版本（需要 ≥ 0.67.6）：

```powershell
wsl --version
wsl --update
```

### Q: Code-Server 无法访问？

**A**: 检查端口映射和防火墙：

```bash
# 检查服务状态
docker exec code-server ps aux | grep code-server

# 检查端口
docker port code-server
```

### Q: mise 工具未生效？

**A**: 确保使用 zsh 并重新加载配置：

```bash
exec zsh -l
mise list
```

## 镜像体积对比

| 镜像 | 预估体积 | 说明 |
|------|---------|------|
| code-server | ~2.5GB | 含 Code-Server + Docker CLI |
| ubuntu-dev | ~2.0GB | 最轻量，仅 Docker CLI |
| ubuntu-wsl | ~3.5GB | 含完整 Docker + Homebrew |

## 技术栈

- **基础镜像**: Ubuntu 24.04
- **Shell**: Zsh + Oh My Zsh
- **包管理**: mise（运行时）, apt（系统包）, Homebrew（WSL）
- **容器化**: Docker + Docker Compose
- **IDE**: Code-Server（可选）
- **镜像源**: 清华大学开源镜像站

## 贡献

欢迎提交 Issue 和 Pull Request。

## 许可证

MIT License
