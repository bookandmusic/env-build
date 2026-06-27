# Ubuntu 开发环境构建工具

自动化构建标准化 Ubuntu 24.04 开发环境，支持两种镜像变体：Docker 容器和 WSL2。

## 镜像变体

| 镜像 | 使用场景 | Docker 模式 | 核心特性 |
|------|---------|------------|---------|
| **ubuntu-dev** | Docker 容器 | CLI only | SSH + Docker CLI + mise + AI 工具 + opencode Web UI + CloudCLI Web UI |
| **ubuntu-wsl** | WSL2 | 完整 Engine | systemd + SSH + 完整 Docker + mise + AI 工具 |

### 工具链

- **运行时**：Node.js 24、Python 3.13、Go 1.25、uv（mise 管理）
- **AI 工具**：opencode-ai、codex、claude-code、cc-switch-cli
- **Web UI**：cloudcli（仅 ubuntu-dev）
- **基础工具**：git、vim、zsh + Oh My Zsh、Starship

### 端口（ubuntu-dev）

| 端口 | 服务 |
|------|------|
| 22 | SSH |
| 3001 | CloudCLI Web UI |
| 4096 | opencode HTTP |

---

## 快速开始

创建 `docker-compose.yml`：

```yaml
services:
  ubuntu-dev:
    image: ghcr.nju.edu.cn/bookandmusic/ubuntu-dev:latest
    container_name: ubuntu-dev
    restart: unless-stopped
    ports:
      - "2222:22"
      - "3001:3001"
      - "4096:4096"
    volumes:
      - ./data/claude:/home/ubuntu/.claude
      - ./data/codex:/home/ubuntu/.codex
      - ./data/opencode:/home/ubuntu/.config/opencode
      - ./data/cloudcli:/home/ubuntu/.cloudcli
      - ./data/cc-switch:/home/ubuntu/.cc-switch
      - ./data/mise:/home/ubuntu/.config/mise
      - ./workspace:/home/ubuntu/workspace
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - TZ=Asia/Shanghai
    group_add:
      - "999"  # stat -c '%g' /var/run/docker.sock
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

启动：

```bash
docker compose up -d
```

访问：

```bash
ssh ubuntu@localhost -p 2222     # 密码: 1
# 容器内执行
webui                            # http://localhost:3001
```

### 持久化目录

| 目录 | 用途 |
|------|------|
| `data/claude` | Claude Code + CloudCLI 配置 |
| `data/codex` | Codex 配置 |
| `data/opencode` | OpenCode 配置 |
| `data/cloudcli` | CloudCLI 数据库 |
| `data/cc-switch` | cc-switch-cli 配置 |
| `data/mise` | mise 工具链配置 |
| `workspace` | 项目工作目录 |

### 常用命令

```bash
docker compose up -d           # 启动
docker compose down            # 停止
docker compose logs -f         # 日志
docker compose up -d --build   # 重建
```

---

## ubuntu-wsl

从 [Releases](https://github.com/bookandmusic/env-build/releases) 下载导入：

```powershell
tar -xzf ubuntu-dev-wsl-amd64.tar.gz
wsl --import UbuntuDev C:\WSL\UbuntuDev ubuntu-dev-wsl-amd64.tar
wsl -d UbuntuDev
```

---

## 本地构建

```bash
docker build --target ubuntu-dev -t ubuntu-dev:latest .
docker build --target ubuntu-wsl -t ubuntu-wsl:latest .
```

WSL 导出：

```bash
docker build --target ubuntu-wsl -t ubuntu-dev-wsl:latest .
docker create --name tmp ubuntu-dev-wsl:latest && docker export tmp -o ubuntu-dev-wsl.tar && docker rm tmp
```

---

## 独立安装

```bash
sudo ./scripts/setup.sh        # root：系统依赖、Docker
su - ubuntu && ./scripts/setup.sh  # user：zsh、工具链
```

---

## AI 工具使用

| 命令 | 说明 |
|------|------|
| `service cloudcli start` | 启动 CloudCLI Web UI（仅 ubuntu-dev） |
| `service opencode start` | 启动 opencode 服务 |
| `cc-switch-cli` | 切换 AI 提供商 |
| `up-ai` | 更新所有 AI 工具 |

---

## 技术栈

Ubuntu 24.04 / Zsh / mise / Docker Compose

## 镜像源

构建时使用官方源。进入容器后使用 chsrc 按需切换镜像源：

```bash
# 切换 npm 镜像源
chsrc npm npmmirror

# 切换 Go 模块代理
chsrc go goproxy.cn
```

## 许可证

MIT License
