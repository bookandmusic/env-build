#!/bin/bash
# 遇到错误立即退出，管道中任一命令失败也退出
set -eo pipefail

# ============================================================
# env-build 统一安装脚本
# 单一入口，通过 id -u 自动判断以 root 还是 ubuntu 用户执行
# ============================================================

# 镜像变体：ubuntu-dev（轻量容器）或 ubuntu-wsl（WSL2 完整环境）
IMAGE_VARIANT="${IMAGE_VARIANT:-ubuntu-dev}"

# Docker Hub 镜像加速（仅对 docker pull 生效）
DOCKER_MIRROR="https://docker.1ms.run"

# Go 模块代理（运行时镜像源，安装完成后再配置）
GOPROXY_MIRROR="https://goproxy.cn,direct"

# ============================================================
# 公共函数
# ============================================================

# 带时间戳的日志输出，统一写往 stderr
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# 错误日志并立即退出
error() {
    echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') $*" >&2
    exit 1
}

# 警告日志
warn() {
    echo "[WARN] $(date +'%Y-%m-%d %H:%M:%S') $*" >&2
}

# 检查命令是否存在，缺失则报错退出
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "Required command '$1' not found"
    fi
}

# 批量安装 APT 包，自动清理列表缓存以减少镜像层体积
install_apt_packages() {
    local packages=("$@")
    log "Installing APT packages: ${packages[*]}"
    apt-get update || error "Failed to update package lists"
    apt-get install -y --no-install-recommends "${packages[@]}" || \
        error "Failed to install packages: ${packages[*]}"
    rm -rf /var/lib/apt/lists/*
}

# 安全克隆：如果目标目录已存在则跳过，保证幂等性
safe_git_clone() {
    local repo_url="$1"
    local target_dir="$2"
    local depth="${3:-1}"

    if [ -d "$target_dir/.git" ]; then
        log "Repository $target_dir already exists, skipping clone"
        return 0
    fi

    log "Cloning $repo_url to $target_dir"
    if ! git clone --depth="$depth" "$repo_url" "$target_dir"; then
        rm -rf "$target_dir"  # 清理失败的残留
        error "Failed to clone $repo_url"
    fi
}

# 向 .zshrc 追加配置，已存在则跳过，保证幂等
add_to_zshrc() {
    local line="$1"
    local target="${HOME}/.zshrc"
    [ -f "$target" ] || touch "$target"
    if ! grep -qxF "$line" "$target" 2>/dev/null; then
        echo "$line" >> "$target"
    fi
}

# 创建配置文件，支持设置权限
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
        curl wget sudo git vim unzip zip tar gnupg lsb-release \
        ca-certificates zsh jq netcat-openbsd procps \
        openssh-client openssh-server \
        iproute2 iputils-ping dnsutils \
        htop tree tmux lsof strace

    update-alternatives --install /usr/bin/editor editor /usr/bin/vim 100
    update-alternatives --set editor /usr/bin/vim
}

install_chsrc() {
    log "Installing chsrc..."
    check_command "curl"
    local script
    script=$(curl -fsSL https://chsrc.run/posix) || error "Failed to download chsrc installer"
    [ -n "$script" ] || error "Empty response from chsrc.run"
    echo "$script" | bash -s -- -d /usr/local/bin || error "Failed to install chsrc"
    [ -x /usr/local/bin/chsrc ] || error "chsrc binary not found after installation"
}

install_starship() {
    log "Installing starship..."
    check_command "curl"
    check_command "jq"
    local starship_arch asset_url
    case "$(uname -m)" in
        x86_64|amd64)
            starship_arch="x86_64-unknown-linux-musl"
            ;;
        aarch64|arm64)
            starship_arch="aarch64-unknown-linux-musl"
            ;;
        *)
            error "Unsupported architecture for starship: $(uname -m)"
            ;;
    esac
    asset_url=$(curl -fsSL https://api.github.com/repos/starship/starship/releases/latest \
        | jq -r ".assets[].browser_download_url | select(endswith(\"${starship_arch}.tar.gz\"))") || \
        error "Failed to fetch starship release info"
    [ -n "$asset_url" ] || error "No matching starship asset found for ${starship_arch}"
    curl -fsSL "$asset_url" -o /tmp/starship.tar.gz || error "Failed to download starship"
    tar -xzf /tmp/starship.tar.gz -C /tmp || error "Failed to extract starship"
    [ -f /tmp/starship ] || error "starship binary not found in archive"
    install -m 0755 /tmp/starship /usr/local/bin/starship
    rm -rf /tmp/starship /tmp/starship.tar.gz
}

create_user() {
    log "Configuring user environment..."

    if ! id ubuntu &>/dev/null; then
        log "Creating ubuntu user..."
        useradd -m -s /bin/bash -G sudo ubuntu
        echo "ubuntu:1" | chpasswd
    else
        log "User ubuntu already exists, ensuring proper configuration..."
    fi

    usermod -aG sudo ubuntu 2>/dev/null || true
    chsh -s "$(which zsh)" ubuntu 2>/dev/null || warn "Failed to set zsh as default shell for ubuntu"

    create_config_file /etc/sudoers.d/ubuntu \
        'ubuntu ALL=(ALL) NOPASSWD:ALL' 440
}

setup_docker_repository() {
    log "Setting up Docker APT repository..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || \
        error "Failed to add Docker GPG key"

    create_config_file "/etc/apt/sources.list.d/docker.list" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
}

install_docker() {
    log "Installing Docker..."
    setup_docker_repository

    if [ "$IMAGE_VARIANT" = "ubuntu-wsl" ]; then
        log "Installing Docker Engine (full) for WSL..."
        install_apt_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        if id ubuntu &>/dev/null && getent group docker >/dev/null; then
            usermod -aG docker ubuntu
            log "Added ubuntu user to docker group"
        fi

        mkdir -p /etc/docker
        create_config_file "/etc/docker/daemon.json" \
            '{"registry-mirrors": ["'"${DOCKER_MIRROR}"'"]}'
    else
        log "Installing Docker CLI only for container..."
        install_apt_packages docker-ce-cli docker-buildx-plugin docker-compose-plugin
    fi
}

setup_wsl_config() {
    # WSL 专用配置：启用 systemd、默认用户、Windows 路径互通
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

install_opencode_service() {
    log "Installing opencode service..."

    if [ "$IMAGE_VARIANT" = "ubuntu-wsl" ]; then
        # systemd service (ubuntu-wsl)
        [ -f /tmp/opencode.service ] || error "opencode.service not found at /tmp/opencode.service"
        cp /tmp/opencode.service /etc/systemd/system/opencode.service
        chmod 644 /etc/systemd/system/opencode.service
        log "Installed systemd service for ubuntu-wsl"
    else
        # SysV init script (ubuntu-dev)
        [ -f /tmp/opencode.init ] || error "opencode.init not found at /tmp/opencode.init"
        cp /tmp/opencode.init /etc/init.d/opencode
        chmod 755 /etc/init.d/opencode
        log "Installed SysV init script for ubuntu-dev"
    fi
}

setup_root() {
    log "Starting root-level setup..."
    install_system_deps
    # git 安装后配置代理（configure_proxy 首次调用时 git 尚未安装）
    if [ -n "${HTTP_PROXY:-}" ] && command -v git &>/dev/null; then
        git config --global http.proxy "${HTTP_PROXY}"
        git config --global https.proxy "${HTTPS_PROXY:-${HTTP_PROXY}}"
    fi
    create_user
    install_chsrc
    install_starship
    install_docker
    setup_wsl_config
    install_opencode_service
    log "Root-level setup completed"
}

# ============================================================
# User 阶段函数
# ============================================================

setup_oh_my_zsh() {
    log "Setting up Oh My Zsh and plugins..."

    safe_git_clone "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh"

    mkdir -p "$HOME/.oh-my-zsh/custom/plugins"

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

    create_config_file "$HOME/.zshrc" \
'export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git sudo z zsh-autosuggestions zsh-syntax-highlighting zsh-completions python golang starship)
source $ZSH/oh-my-zsh.sh'

    mkdir -p ~/.config
    starship preset plain-text-symbols -o ~/.config/starship.toml
}

install_mise() {
    log "Installing mise..."
    mkdir -p "$HOME/.local/bin"

    local mise_script
    mise_script=$(curl -fsSL https://mise.run) || error "Failed to download mise installer"
    [ -n "$mise_script" ] || error "Empty response from mise.run"
    echo "$mise_script" | MISE_INSTALL_PATH="$HOME/.local/bin/mise" sh || error "Failed to install mise"
    [ -x "$HOME/.local/bin/mise" ] || error "mise binary not found or not executable"

    add_to_zshrc 'eval "$($HOME/.local/bin/mise activate zsh)"'
    export PATH="$HOME/.local/bin:$PATH"
}

setup_toolchain() {
    log "Setting up development toolchain..."
    install_mise

    "$HOME/.local/bin/mise" settings set experimental true

    local tools=("python@3.13" "go@1.25" "node@24" "uv")
    for tool in "${tools[@]}"; do
        log "Installing $tool via mise..."
        "$HOME/.local/bin/mise" use -g "$tool" || warn "Failed to install $tool, continuing..."
    done

    eval "$($HOME/.local/bin/mise activate bash)"

    # 安装 Go 工具（构建时走代理或直连，不设置镜像源）
    log "Installing Go tools..."
    go install -v golang.org/x/tools/gopls@latest || warn "Failed to install gopls"
    go install -v github.com/go-delve/delve/cmd/dlv@latest || warn "Failed to install dlv"

    # 安装完成后再配置国内镜像源，避免干扰 CI 构建和代理
    export GOPROXY="${GOPROXY_MIRROR}"
    add_to_zshrc "export GOPROXY=\"${GOPROXY_MIRROR}\""
    log "Configured GOPROXY=${GOPROXY_MIRROR}"
}

setup_vim() {
    log "Installing vimrc..."
    # amix/vimrc：经过大量用户验证的 Vim 配置集
    safe_git_clone "https://github.com/amix/vimrc.git" "$HOME/.vim_runtime"
    sh ~/.vim_runtime/install_awesome_vimrc.sh
}

setup_ai_tools() {
    log "Installing AI coding tools..."

    npm install -g opencode-ai
    npm install -g @openai/codex
    npm install -g @anthropic-ai/claude-code

    # 安装完成后再配置镜像源，避免干扰 CI 构建和代理
    if [ -z "${CI:-}" ]; then
        log "Configuring npmmirror for npm..."
        npm config set registry https://registry.npmmirror.com
    fi

    add_to_zshrc 'alias up-oc="npm install -g opencode-ai@latest && sudo service opencode restart"'
    add_to_zshrc 'alias up-cx="npm install -g @openai/codex@latest"'
    add_to_zshrc 'alias up-cl="npm install -g @anthropic-ai/claude-code@latest"'
    add_to_zshrc 'alias up-ai="up-oc && up-cx && up-cl"'
}

setup_user() {
    log "Starting user-level setup..."
    setup_oh_my_zsh
    setup_toolchain
    setup_vim
    setup_ai_tools

    log "Cleaning up..."
    rm -rf /home/ubuntu/.cache/*
    log "User-level setup completed"
}

# ============================================================
# 主逻辑
# ============================================================

# 配置构建时代理（apt / git / npm / curl 均通过环境变量生效）
configure_proxy() {
    if [ -n "${HTTP_PROXY:-}" ]; then
        log "Configuring proxy: ${HTTP_PROXY}"
        # apt 代理（apt 在 base 镜像中已可用）
        cat > /etc/apt/apt.conf.d/99proxy << EOF
Acquire::http::Proxy "${HTTP_PROXY}";
Acquire::https::Proxy "${HTTPS_PROXY:-${HTTP_PROXY}}";
EOF
        # git 代理（git 可能还未安装，延迟到 install_system_deps 之后）
        if command -v git &>/dev/null; then
            git config --global http.proxy "${HTTP_PROXY}"
            git config --global https.proxy "${HTTPS_PROXY:-${HTTP_PROXY}}"
        fi
    else
        log "No proxy configured, using direct connection"
        rm -f /etc/apt/apt.conf.d/99proxy
        git config --global --unset http.proxy 2>/dev/null || true
        git config --global --unset https.proxy 2>/dev/null || true
    fi
}

main() {
    log "env-build setup starting..."
    log "IMAGE_VARIANT=${IMAGE_VARIANT}"

    if [[ ! "$IMAGE_VARIANT" =~ ^(ubuntu-dev|ubuntu-wsl)$ ]]; then
        error "IMAGE_VARIANT must be 'ubuntu-dev' or 'ubuntu-wsl', got '${IMAGE_VARIANT}'"
    fi

    # 自动判断：root → 系统配置，非 root → 用户配置
    if [ "$(id -u)" -eq 0 ]; then
        configure_proxy
        setup_root
    else
        setup_user
    fi

    log "env-build setup completed successfully"
}

main "$@"
