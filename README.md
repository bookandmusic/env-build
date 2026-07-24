# env-build

Ubuntu 24.04 开发环境镜像，包含 Node/Python/Go/Rust/Android 完整工具链，支持 Tauri Android 构建和远程无线调试。

## 内置工具链

| 类别 | 工具 |
|------|------|
| 语言 | Node.js 24、Python 3.13、Go 1.25、Rust stable（via mise + rustup） |
| Android | JDK 17、Android SDK（API 35、build-tools 35、NDK 27）、ADB |
| 终端 | Zsh + Oh My Zsh + Starship |
| 编辑器 | Vim（精简配置） |
| 容器 | Docker CLI |
| 换源 | chsrc |
| 服务 | opencode（:4096）、cloudcli Web UI（:3001）、sshd（:22） |

## 快速使用

```bash
# 拉取镜像
docker pull ghcr.io/bookandmusic/env-build:latest

# 运行
docker run -d \
  --name dev \
  -p 2222:22 \
  -p 3001:3001 \
  -p 4096:4096 \
  -v ~/workspace:/home/ubuntu/workspace \
  ghcr.io/bookandmusic/env-build:latest

# SSH 连接
ssh -p 2222 ubuntu@localhost
```

## AI 工具管理

AI 工具不预装在镜像中，通过配置文件管理，运行时手动安装/更新：

```bash
# 首次安装所有 AI 工具
ai-tools install

# 更新所有 AI 工具到最新版
ai-tools update

# 查看已安装工具及版本
ai-tools list
```

配置文件：`~/.config/ai-tools/ai-tools.yaml`

```yaml
tools:
  - name: opencode
    type: npm
    package: opencode-ai

  - name: cc-switch
    type: binary
    repo: SaladDay/cc-switch-cli
    filename:
      x86_64: cc-switch-linux-amd64
      aarch64: cc-switch-linux-arm64
```

支持两种类型：
- `npm` — 通过 npm install -g 安装
- `binary` — 从 GitHub Release 下载二进制到 ~/.local/bin/

## 服务管理

```bash
# opencode HTTP 服务（端口 4096）
sudo service opencode {start|stop|restart|status}

# cloudcli Web UI（端口 3001）
sudo service cloudcli {start|stop|restart|status}
```

## 无线调试（Android）

```bash
# 手机端开启无线调试后
adb tcpip 5555
adb connect <手机IP>:5555
adb devices
```

## 本地构建

```bash
# 构建镜像
docker build -t env-build:local .

# 带代理构建
docker build --build-arg HTTP_PROXY=http://host:port -t env-build:local .

# 运行测试
bash test/build-and-test.sh
```

## CI/CD

- 打 `v*` tag 自动构建并推送到 GHCR
- 支持 `workflow_dispatch` 手动触发
- 多架构：linux/amd64 + linux/arm64

```bash
# 发布新版本
git tag v1.0.0
git push origin v1.0.0
```

## 项目结构

```
├── Dockerfile                     # 单一镜像构建
├── .github/workflows/build.yaml   # CI 构建推送 GHCR
├── scripts/
│   ├── setup.sh                   # 主入口（自动判断 root/user）
│   ├── 01-system-deps.sh          # 系统依赖
│   ├── 02-user-setup.sh           # ubuntu 用户
│   ├── 03-shell-env.sh            # zsh/starship/vim
│   ├── 04-toolchain.sh            # mise/rust/android
│   ├── 05-docker-cli.sh           # Docker CLI
│   ├── 06-extra-tools.sh          # chsrc
│   ├── 07-services.sh             # init 服务
│   ├── services/
│   │   ├── opencode.init
│   │   └── cloudcli.init
│   └── configs/
│       └── vimrc
├── ai-tools/
│   ├── ai-tools                   # 管理脚本
│   └── ai-tools.yaml              # 工具配置
└── test/
    └── build-and-test.sh
```
