# env-build

Ubuntu 24.04 开发环境 Docker 镜像。单一镜像，包含 Node/Python/Go/Rust/Android 工具链。

## 架构

### 模块化脚本

`scripts/setup.sh` 是主入口，通过 `id -u` 自动区分 root/user 阶段：

**Root 阶段**（按顺序）：
1. `01-system-deps.sh` — apt 系统依赖
2. `02-user-setup.sh` — 创建 ubuntu 用户 + sudo
3. `05-docker-cli.sh` — Docker CLI
4. `06-extra-tools.sh` — chsrc
5. `07-services.sh` — opencode/cloudcli init 服务 + SSH

**User 阶段**（按顺序）：
1. `03-shell-env.sh` — Oh My Zsh + Starship + Vim
2. `04-toolchain.sh` — mise（Node/Python/Go）+ rustup + Android SDK

### AI 工具

- 配置：`ai-tools/ai-tools.yaml`
- 脚本：`ai-tools/ai-tools`（install/update/list）
- 运行时安装到 `~/.local/bin/`，不在镜像构建时安装
- 支持 npm 和 binary（GitHub Release）两种类型

### 服务

- `opencode.init` / `cloudcli.init` — SysV init 脚本
- 均以 ubuntu 用户启动，通过 mise activate 加载和终端一致的环境
- 端口：opencode 4096、cloudcli 3001

### Dockerfile

- 单一镜像，无 WSL 变体
- 多阶段：base → root 阶段 → user 阶段 → ai-tools 文件 → 收尾
- 层缓存优化：系统依赖在前，AI 工具配置在最后

### CI

- `.github/workflows/build.yaml`
- 触发：tag `v*` + workflow_dispatch
- 推送到 GHCR，多架构（amd64 + arm64）
- 使用 GHA 缓存加速

## 代码规范

### Shell 脚本

- 头部 `set -eo pipefail`
- 使用 `log()` / `error()` / `warn()` 输出
- APT 安装用 `install_apt_packages()`
- git 克隆用 `safe_git_clone()`
- `.zshrc` 追加用 `add_to_zshrc()`（幂等）
- 文件命名：数字前缀 + kebab-case（`01-system-deps.sh`）
- 函数命名：lower_snake_case

### 环境变量

- 常量：UPPER_SNAKE_CASE
- 镜像标识：`IMAGE_VARIANT=ubuntu-dev`

### Git 提交

格式：`feat:` / `fix:` / `docs:` / `refactor:` / `test:` / `chore:`，中文描述。
