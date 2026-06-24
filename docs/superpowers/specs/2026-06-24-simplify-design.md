# env-build 简化重构设计文档

**日期**: 2026-06-24
**状态**: 已批准
**范围**: 简化 env-build 项目，减少文件数量和复杂度

---

## 1. 背景与目标

### 1.1 当前问题

- **文件过多**: 11 个脚本文件 + 4 个 CI/CD 工作流，维护成本高
- **环境变量复杂**: 5 个环境变量（IMAGE_VARIANT、DOCKER_MODE、INSTALL_CODE_SERVER、CONFIG_USER、WSL_CONFIG）关系复杂
- **两阶段编排难以理解**: root-setup.sh + user-setup.sh 编排器 + 7 个安装脚本
- **配置层混乱**: common.sh、variables.sh、start-services.sh 职责不清
- **CI/CD 工作流重复**: 4 个工作流逻辑重复

### 1.2 简化目标

- **文件数量**: 从 11+ 个减少到 3 个核心文件
- **环境变量**: 从 5 个减少到 1 个（IMAGE_VARIANT）
- **代码行数**: 从 ~800 行减少到 ~300 行
- **镜像变体**: 从 3 个减少到 2 个（去掉 code-server）
- **CI/CD 工作流**: 从 4 个减少到 1 个

### 1.3 用户需求

- **主要场景**: 轻量级开发环境（类似 ubuntu-dev）
- **Docker**: 仅 CLI 模式（socket 挂载）
- **IDE**: 不需要 Code-Server
- **工具链**: 保持当前配置（Node.js/Python/Go + CLI 工具）
- **WSL2**: 需要精简版 WSL2 镜像（去掉 Homebrew）

---

## 2. 架构设计

### 2.1 目录结构

```
env-build/
├── setup.sh                    # 单一入口脚本（自动判断 root/user 阶段）
├── Dockerfile                  # 两个构建目标（ubuntu-dev + ubuntu-wsl）
├── .github/workflows/
│   └── docker-images.yaml      # 单一构建工作流
├── README.md
└── docs/
    └── superpowers/specs/
        └── 2026-06-24-simplify-design.md  # 本文档
```

### 2.2 镜像变体

| 变体 | 场景 | Docker | IDE | 工具链 |
|------|------|--------|-----|--------|
| **ubuntu-dev** | 轻量开发 | CLI only | 无 | Node.js/Python/Go + CLI 工具 |
| **ubuntu-wsl** | WSL2 本地 | 完整 Engine | 无 | 同上 |

**去掉的功能**：
- ❌ Code-Server 镜像变体
- ❌ Homebrew（WSL2 中）
- ❌ 复杂的环境变量控制

### 2.3 环境变量控制（极简）

**仅需 1 个环境变量**：

```bash
IMAGE_VARIANT=ubuntu-dev  # 或 ubuntu-wsl
```

**内部自动判断**：
- `ubuntu-dev` → `DOCKER_MODE=cli-only`
- `ubuntu-wsl` → `DOCKER_MODE=full`

**去掉的变量**：
- ❌ `INSTALL_CODE_SERVER`（不再支持）
- ❌ `CONFIG_USER`（始终创建用户）
- ❌ `WSL_CONFIG`（通过 IMAGE_VARIANT 判断）
- ❌ `DOCKER_MODE`（自动推导）

---

## 3. 核心组件设计

### 3.1 setup.sh 设计

单一入口脚本，通过 `id -u` 判断执行阶段。

#### 3.1.1 脚本结构

```bash
#!/bin/bash
set -eo pipefail

# ============================================================
# 配置常量（硬编码，无环境变量）
# ============================================================

IMAGE_VARIANT="${IMAGE_VARIANT:-ubuntu-dev}"

# 镜像源配置
TSINGHUA_MIRROR="https://mirrors.tuna.tsinghua.edu.cn"
PYPI_MIRROR="${TSINGHUA_MIRROR}/pypi/web/simple"
NPM_MIRROR="https://registry.npmmirror.com"
DOCKER_MIRROR="https://docker.1ms.run"
GOPROXY="https://goproxy.io,direct"

# ============================================================
# 公共函数
# ============================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') $*" >&2
    exit 1
}

warn() {
    echo "[WARN] $(date +'%Y-%m-%d %H:%M:%S') $*" >&2
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "Required command '$1' not found"
    fi
}

install_apt_packages() {
    local packages=("$@")
    log "Installing APT packages: ${packages[*]}"
    apt-get update || error "Failed to update package lists"
    apt-get install -y --no-install-recommends "${packages[@]}" || \
        error "Failed to install packages: ${packages[*]}"
    rm -rf /var/lib/apt/lists/*
}

safe_git_clone() {
    local repo_url="$1"
    local target_dir="$2"
    local depth="${3:-1}"
    
    if [ -d "$target_dir" ]; then
        log "Directory $target_dir already exists, skipping clone"
        return 0
    fi
    
    log "Cloning $repo_url to $target_dir"
    git clone --depth="$depth" "$repo_url" "$target_dir" || \
        error "Failed to clone $repo_url"
}

add_to_zshrc() {
    local line="$1"
    local target="${HOME}/.zshrc"
    if ! grep -qF "$line" "$target" 2>/dev/null; then
        echo "$line" >> "$target"
    fi
}

create_config_file() {
    local filepath="$1"
    local content="$2"
    local permissions="${3:-644}"
    
    log "Creating config file: $filepath"
    echo "$content" > "$filepath" || error "Failed to create $filepath"
    chmod "$permissions" "$filepath" || error "Failed to set permissions on $filepath"
}

# ============================================================
# Root 阶段函数
# ============================================================

install_system_deps() {
    log "Installing system dependencies..."
    install_apt_packages \
        net-tools iproute2 iputils-ping dnsutils traceroute \
        curl wget sudo git vim unzip tar gnupg lsb-release software-properties-common \
        ca-certificates zsh build-essential procps jq htop gnupg2 lsb-release \
        openssh-client openssh-server tree netcat-openbsd
    
    update-alternatives --install /usr/bin/editor editor /usr/bin/vim 100
    update-alternatives --set editor /usr/bin/vim
}

create_user() {
    log "Configuring user environment..."
    
    # 创建 ubuntu 用户（如果不存在）
    if ! id ubuntu &>/dev/null; then
        log "Creating ubuntu user..."
        useradd -m -s /bin/bash -G sudo ubuntu
    fi
    
    # 设置密码和权限
    echo "ubuntu:1" | chpasswd
    usermod -aG sudo ubuntu
    chsh -s "$(which zsh)" ubuntu
    
    create_config_file /etc/sudoers.d/ubuntu \
        'ubuntu ALL=(ALL) NOPASSWD:ALL' 440
    
    # 安装 chsrc 和 starship
    log "Installing chsrc..."
    check_command "curl"
    curl https://chsrc.run/posix | bash -s -- -d /usr/local/bin
    
    log "Installing starship..."
    local starship_arch asset_url
    case "$(uname -m)" in
        x86_64|amd64)
            starship_arch="x86_64-unknown-linux-gnu"
            ;;
        aarch64|arm64)
            starship_arch="aarch64-unknown-linux-gnu"
            ;;
        *)
            error "Unsupported architecture for starship: $(uname -m)"
            ;;
    esac
    asset_url=$(curl -fsSL https://api.github.com/repos/starship/starship/releases/latest \
        | jq -r ".assets[].browser_download_url | select(endswith(\"${starship_arch}.tar.gz\"))")
    curl -fsSL "$asset_url" -o /tmp/starship.tar.gz
    tar -xzf /tmp/starship.tar.gz -C /tmp
    install -m 0755 /tmp/starship /usr/local/bin/starship
    rm -rf /tmp/starship /tmp/starship.tar.gz
}

install_docker() {
    log "Setting up Docker..."
    
    # 准备 Docker 仓库
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    create_config_file "/etc/apt/sources.list.d/docker.list" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${TSINGHUA_MIRROR}/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
    
    if [ "$IMAGE_VARIANT" = "ubuntu-wsl" ]; then
        # WSL2: 安装完整 Docker Engine
        log "Installing Docker Engine (full)..."
        install_apt_packages \
            docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # 配置 Docker 用户组
        if id ubuntu &>/dev/null && getent group docker >/dev/null; then
            usermod -aG docker ubuntu
            log "Added ubuntu user to docker group"
        fi
        
        mkdir -p /etc/docker
        create_config_file "/etc/docker/daemon.json" \
            '{
    "registry-mirrors": ["'"${DOCKER_MIRROR}"'"]
}'
    else
        # ubuntu-dev: 仅安装 CLI
        log "Installing Docker CLI only..."
        install_apt_packages docker-ce-cli docker-buildx-plugin docker-compose-plugin
    fi
}

setup_wsl_config() {
    if [ "$IMAGE_VARIANT" = "ubuntu-wsl" ]; then
        log "Configuring WSL environment..."
        create_config_file /etc/wsl.conf \
'[boot]
systemd=true

[user]
default=ubuntu

[interop]
enabled=true
appendWindowsPath=true'
    fi
}

setup_root() {
    log "Starting root-level setup..."
    install_system_deps
    create_user
    install_docker
    setup_wsl_config
    log "Root-level setup completed"
}

# ============================================================
# User 阶段函数
# ============================================================

setup_oh_my_zsh() {
    log "Setting up Oh My Zsh and plugins..."
    
    # 克隆 Oh My Zsh
    safe_git_clone "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh"
    
    # 创建插件目录
    mkdir -p "$HOME/.oh-my-zsh/custom/plugins"
    
    # 安装插件
    local plugins=(
        "zsh-users/zsh-autosuggestions"
        "zsh-users/zsh-syntax-highlighting"
        "zsh-users/zsh-completions"
    )
    
    for plugin in "${plugins[@]}"; do
        local name
        name=$(basename "$plugin")
        safe_git_clone "https://github.com/${plugin}" "$HOME/.oh-my-zsh/custom/plugins/${name}"
    done
    
    # 配置 .zshrc
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
    
    # 更新主题和插件
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' "$HOME/.zshrc"
    sed -i 's/plugins=(git)/plugins=(git sudo z zsh-autosuggestions zsh-syntax-highlighting zsh-completions python golang starship)/g' "$HOME/.zshrc"
    
    mkdir -p ~/.config
    starship preset plain-text-symbols -o ~/.config/starship.toml
}

setup_toolchain() {
    log "Setting up development toolchain..."
    
    # 安装 mise
    check_command "curl"
    curl https://mise.run | MISE_INSTALL_PATH="$HOME/.local/bin/mise" sh
    add_to_zshrc 'eval "$($HOME/.local/bin/mise activate zsh)"'
    
    # 激活 mise 环境（当前脚本由 bash 执行）
    eval "$($HOME/.local/bin/mise activate bash)"
    
    # 配置 mise
    mise settings experimental=true
    
    # 安装工具
    mise use -g bat eza uv duf fd fzf gdu lazydocker lazygit ripgrep poetry \
        python@3.13 go@1.25 node@24 pipx btop
    
    # Go 工具
    mise use -g \
        go:github.com/incu6us/goimports-reviser/v3@v3.10.0 \
        go:mvdan.cc/gofumpt@latest \
        go:github.com/securego/gosec/v2/cmd/gosec@latest \
        go:github.com/fzipp/gocyclo/cmd/gocyclo@latest
    
    # pipx 工具
    mise use -g pipx:glances pipx:httpie pipx:ipython pipx:litecli pipx:mycli pipx:tldr
}

setup_vim() {
    log "Installing vimrc..."
    safe_git_clone "https://github.com/amix/vimrc.git" "$HOME/.vim_runtime"
    sh ~/.vim_runtime/install_awesome_vimrc.sh
}

setup_user() {
    log "Starting user-level setup..."
    setup_oh_my_zsh
    setup_toolchain
    setup_vim
    
    log "Cleaning up..."
    rm -rf /home/ubuntu/.cache/*
    log "User-level setup completed"
}

# ============================================================
# 主逻辑
# ============================================================

main() {
    log "env-build setup starting..."
    log "IMAGE_VARIANT=${IMAGE_VARIANT}"
    
    # 验证 IMAGE_VARIANT
    if [[ ! "$IMAGE_VARIANT" =~ ^(ubuntu-dev|ubuntu-wsl)$ ]]; then
        error "IMAGE_VARIANT must be 'ubuntu-dev' or 'ubuntu-wsl', got '${IMAGE_VARIANT}'"
    fi
    
    # 根据当前用户执行不同阶段
    if [ "$(id -u)" -eq 0 ]; then
        setup_root
    else
        setup_user
    fi
    
    log "env-build setup completed successfully"
}

main "$@"
```

#### 3.1.2 执行流程

```
main()
├── 验证 IMAGE_VARIANT
├── 判断当前用户
│   ├── root (id -u == 0)
│   │   └── setup_root()
│   │       ├── install_system_deps()
│   │       ├── create_user()
│   │       ├── install_docker()
│   │       └── setup_wsl_config()
│   └── user (id -u != 0)
│       └── setup_user()
│           ├── setup_oh_my_zsh()
│           ├── setup_toolchain()
│           └── setup_vim()
└── 完成
```

### 3.2 Dockerfile 设计

```dockerfile
# ============ 基础阶段 ============
FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

SHELL ["/bin/bash", "-c"]

COPY setup.sh /tmp/setup.sh
RUN chmod +x /tmp/setup.sh

# ============ ubuntu-dev 变体 ============
FROM base AS ubuntu-dev

ENV IMAGE_VARIANT=ubuntu-dev

RUN /tmp/setup.sh

USER ubuntu
WORKDIR /home/ubuntu
SHELL ["/bin/zsh", "-lc"]

RUN /tmp/setup.sh

EXPOSE 22
CMD ["sleep", "infinity"]

# ============ ubuntu-wsl 变体 ============
FROM base AS ubuntu-wsl

ENV IMAGE_VARIANT=ubuntu-wsl

RUN /tmp/setup.sh

USER ubuntu
WORKDIR /home/ubuntu
SHELL ["/bin/zsh", "-lc"]

RUN /tmp/setup.sh

USER root
WORKDIR /root
EXPOSE 22
ENTRYPOINT ["/sbin/init"]
CMD []
```

#### 3.2.1 构建流程

```
base (ubuntu:24.04)
├── COPY setup.sh
├── chmod +x
│
├── ubuntu-dev 阶段
│   ├── ENV IMAGE_VARIANT=ubuntu-dev
│   ├── RUN setup.sh (root 阶段: 系统依赖 + 用户 + Docker CLI)
│   ├── USER ubuntu
│   └── RUN setup.sh (user 阶段: Zsh + 工具链 + Vim)
│
└── ubuntu-wsl 阶段
    ├── ENV IMAGE_VARIANT=ubuntu-wsl
    ├── RUN setup.sh (root 阶段: 系统依赖 + 用户 + Docker Engine + WSL 配置)
    ├── USER ubuntu
    ├── RUN setup.sh (user 阶段: Zsh + 工具链 + Vim)
    └── ENTRYPOINT ["/sbin/init"]  # systemd
```

### 3.3 CI/CD 工作流设计

```yaml
name: Build and Push Multi-Arch Docker Images

on:
  workflow_dispatch:
    inputs:
      tag:
        description: 'Docker 镜像标签（留空使用默认日期格式）'
        required: false
        default: ''

env:
  REGISTRY: ghcr.io

jobs:
  build-images:
    runs-on: ubuntu-latest
    permissions:
      packages: write
      contents: read

    strategy:
      matrix:
        include:
          - image: ubuntu-dev
            target: ubuntu-dev
            push: true
          - image: ubuntu-wsl
            target: ubuntu-wsl
            push: true

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Log in to container registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Set tags
        id: vars
        run: |
          DATE=$(date +'%Y%m%d')
          INPUT_TAG="${{ github.event.inputs.tag }}"
          if [ -z "$INPUT_TAG" ]; then
            TAG="${DATE}"
          else
            TAG="$INPUT_TAG"
          fi
          echo "TAG=$TAG" >> $GITHUB_ENV

      - name: Build and push multi-arch image
        uses: docker/build-push-action@v6
        with:
          context: .
          file: ./Dockerfile
          target: ${{ matrix.target }}
          push: true
          platforms: linux/amd64,linux/arm64
          tags: |
            ${{ env.REGISTRY }}/${{ github.actor }}/${{ matrix.image }}:${{ env.TAG }}
            ${{ env.REGISTRY }}/${{ github.actor }}/${{ matrix.image }}:latest

  build-wsl:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    strategy:
      matrix:
        arch: [amd64, arm64]

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Set tags
        id: vars
        run: |
          DATE=$(date +'%Y%m%d')
          INPUT_TAG="${{ github.event.inputs.tag }}"
          if [ -z "$INPUT_TAG" ]; then
            TAG="${DATE}"
          else
            TAG="$INPUT_TAG"
          fi
          echo "TAG=$TAG" >> $GITHUB_ENV

      - name: Build WSL image
        run: |
          docker buildx build \
            --platform linux/${{ matrix.arch }} \
            --target ubuntu-wsl \
            --load \
            -t ubuntu-dev-wsl:${{ matrix.arch }} .

      - name: Export WSL tarball
        run: |
          CONTAINER_ID=$(docker create ubuntu-dev-wsl:${{ matrix.arch }} /bin/true)
          docker export "$CONTAINER_ID" -o ubuntu-dev-wsl-${{ matrix.arch }}.tar
          docker rm "$CONTAINER_ID"

      - name: Compress tarball
        run: |
          gzip ubuntu-dev-wsl-${{ matrix.arch }}.tar
          ls -lh ubuntu-dev-wsl-${{ matrix.arch }}.tar.gz

      - name: Check file size and split if needed
        id: split
        run: |
          FILE="ubuntu-dev-wsl-${{ matrix.arch }}.tar.gz"
          SIZE=$(stat -c%s "$FILE")
          MAX_SIZE=$((2 * 1024 * 1024 * 1024))  # 2GB
          
          echo "File size: $(numfmt --to=iec-i --suffix=B $SIZE)"
          
          if [ $SIZE -gt $MAX_SIZE ]; then
            echo "File exceeds 2GB, splitting into 1.9GB parts..."
            split -b 1900M "$FILE" "${FILE}.part"
            rm "$FILE"
            ls -lh "${FILE}.part"*
            echo "split=true" >> $GITHUB_OUTPUT
          else
            echo "File is within 2GB limit, no split needed"
            echo "split=false" >> $GITHUB_OUTPUT
          fi

      - name: Upload WSL tarball (single file)
        if: steps.split.outputs.split == 'false'
        uses: actions/upload-artifact@v4
        with:
          name: ubuntu-dev-wsl-${{ matrix.arch }}
          path: ubuntu-dev-wsl-${{ matrix.arch }}.tar.gz

      - name: Upload WSL tarball (split files)
        if: steps.split.outputs.split == 'true'
        uses: actions/upload-artifact@v4
        with:
          name: ubuntu-dev-wsl-${{ matrix.arch }}
          path: ubuntu-dev-wsl-${{ matrix.arch }}.tar.gz.part*

      - name: Create Release and Upload Assets
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: |
            ubuntu-dev-wsl-${{ matrix.arch }}.tar.gz
            ubuntu-dev-wsl-${{ matrix.arch }}.tar.gz.part*
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 4. 简化效果对比

| 项目 | 当前 | 简化后 | 减少 |
|------|------|--------|------|
| 脚本文件 | 11 个 | 1 个 | **-91%** |
| 环境变量 | 5 个 | 1 个 | **-80%** |
| CI/CD 工作流 | 4 个 | 1 个 | **-75%** |
| 代码行数 | ~800 行 | ~300 行 | **-62%** |
| 镜像变体 | 3 个 | 2 个 | **-33%** |

---

## 5. 关键设计决策

### 5.1 单一脚本 + 内部函数

**决策**: 使用单一 setup.sh 脚本，通过 `id -u` 判断执行阶段

**理由**:
- 最大程度简化文件数量
- 保持两阶段执行模型（root/user）
- 易于理解和维护

**权衡**:
- ✅ 文件数量最少（1 个）
- ✅ 所有逻辑集中，易于查找
- ⚠️ 单文件可能较长（~300 行）
- ⚠️ 需要理解 id -u 判断逻辑

### 5.2 硬编码配置

**决策**: 去掉环境变量控制，直接在脚本中硬编码配置

**理由**:
- 简化使用方式，无需设置环境变量
- 减少配置错误的可能性
- 专注于轻量开发场景

**权衡**:
- ✅ 使用最简单
- ✅ 无配置错误
- ⚠️ 失去灵活性
- ⚠️ 如需修改需编辑脚本

### 5.3 自动推导 Docker 模式

**决策**: 通过 IMAGE_VARIANT 自动推导 DOCKER_MODE

**理由**:
- 减少用户需要关心的变量
- 逻辑清晰：ubuntu-dev → CLI，ubuntu-wsl → Engine

**权衡**:
- ✅ 用户只需关心一个变量
- ✅ 逻辑清晰
- ⚠️ 如需自定义需修改脚本

### 5.4 去掉 Code-Server

**决策**: 不再支持 Code-Server 镜像变体

**理由**:
- 用户明确表示不需要
- 简化脚本逻辑
- 减少镜像体积

**权衡**:
- ✅ 脚本更简单
- ✅ 镜像更小
- ⚠️ 失去 Web IDE 功能
- ⚠️ 如需恢复需手动添加

### 5.5 去掉 Homebrew

**决策**: WSL2 镜像中不再安装 Homebrew

**理由**:
- 用户明确表示不需要
- 减少 WSL2 镜像体积
- 简化安装流程

**权衡**:
- ✅ 镜像更小
- ✅ 安装更快
- ⚠️ 失去 Homebrew 包管理
- ⚠️ 如需恢复需手动安装

---

## 6. 实施计划

### 6.1 阶段一：创建新文件

1. 创建 `setup.sh`（合并所有脚本逻辑）
2. 更新 `Dockerfile`（简化为两个构建目标）
3. 更新 `.github/workflows/docker-images.yaml`（合并 WSL 导出）

### 6.2 阶段二：删除旧文件

1. 删除 `scripts/orchestration/` 目录
2. 删除 `scripts/installation/` 目录
3. 删除 `scripts/configs/` 目录
4. 删除 `scripts/build-images.sh`
5. 删除 `scripts/export-wsl.sh`
6. 删除 `.github/workflows/wsl-export.yml`
7. 删除 `.github/workflows/sync-docker-image-with-skopeo.yml`
8. 删除 `.github/workflows/sync-docker-image-with-manifest.yml`

### 6.3 阶段三：更新文档

1. 更新 `README.md`（简化使用说明）
2. 更新 `CLAUDE.md`（更新架构说明）

### 6.4 阶段四：测试验证

1. 本地构建测试：`docker build --target ubuntu-dev -t ubuntu-dev:latest .`
2. 本地构建测试：`docker build --target ubuntu-wsl -t ubuntu-wsl:latest .`
3. 功能验证：SSH 登录、工具链检查
4. CI/CD 测试：触发 GitHub Actions 工作流

---

## 7. 风险与缓解

### 7.1 风险：失去灵活性

**缓解**:
- 保留 IMAGE_VARIANT 环境变量
- 如需扩展可修改 setup.sh

### 7.2 风险：单文件过长

**缓解**:
- 使用清晰的函数划分
- 添加注释说明各部分功能

### 7.3 风险：CI/CD 工作流合并

**缓解**:
- 保留 matrix 策略支持多架构
- 保留 WSL 导出功能

---

## 8. 总结

本设计通过以下方式简化 env-build 项目：

1. **单一脚本**：合并 11 个脚本为 1 个 setup.sh
2. **极简配置**：仅保留 IMAGE_VARIANT 环境变量
3. **自动推导**：通过 IMAGE_VARIANT 自动决定 Docker 模式
4. **去掉冗余**：移除 Code-Server 和 Homebrew 支持
5. **CI/CD 合并**：4 个工作流合并为 1 个

**最终效果**：
- 文件数量：11 → 1（-91%）
- 环境变量：5 → 1（-80%）
- 代码行数：~800 → ~300（-62%）
- 镜像变体：3 → 2（-33%）

**核心价值**：
- ✅ 最大程度简化
- ✅ 易于理解和维护
- ✅ 保留核心功能（轻量开发 + WSL2）
- ✅ 向后兼容（IMAGE_VARIANT 保留）
