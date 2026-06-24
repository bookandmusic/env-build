#!/bin/bash
# 遇到错误立即退出，管道中任一命令失败也退出
set -eo pipefail

# ============================================================
# env-build 统一安装脚本
# 单一入口，通过 id -u 自动判断以 root 还是 ubuntu 用户执行
# ============================================================

# 镜像变体：ubuntu-dev（轻量容器）或 ubuntu-wsl（WSL2 完整环境）
IMAGE_VARIANT="${IMAGE_VARIANT:-ubuntu-dev}"

# 国内镜像源，加速依赖下载
TSINGHUA_MIRROR="https://mirrors.tuna.tsinghua.edu.cn"
DOCKER_MIRROR="https://docker.1ms.run"

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

    if [ -d "$target_dir" ]; then
        log "Directory $target_dir already exists, skipping clone"
        return 0
    fi

    log "Cloning $repo_url to $target_dir"
    git clone --depth="$depth" "$repo_url" "$target_dir" || \
        error "Failed to clone $repo_url"
}

# 向 .zshrc 追加配置，已存在则跳过，保证幂等
add_to_zshrc() {
    local line="$1"
    local target="${HOME}/.zshrc"
    if ! grep -qF "$line" "$target" 2>/dev/null; then
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
        curl wget sudo git vim unzip zip tar gnupg lsb-release software-properties-common \
        ca-certificates zsh build-essential jq \
        openssh-client openssh-server

    update-alternatives --install /usr/bin/editor editor /usr/bin/vim 100
    update-alternatives --set editor /usr/bin/vim
}

create_user() {
    log "Configuring user environment..."

    if ! id ubuntu &>/dev/null; then
        log "Creating ubuntu user..."
        useradd -m -s /bin/bash -G sudo ubuntu
    fi

    # 设置密码为 "1"，方便首次登录；sudo 免密码
    echo "ubuntu:1" | chpasswd
    usermod -aG sudo ubuntu
    chsh -s "$(which zsh)" ubuntu

    create_config_file /etc/sudoers.d/ubuntu \
        'ubuntu ALL=(ALL) NOPASSWD:ALL' 440

    # chsrc：一键切换系统镜像源的命令行工具
    log "Installing chsrc..."
    check_command "curl"
    curl https://chsrc.run/posix | bash -s -- -d /usr/local/bin

    # Starship：跨 Shell 的极简提示符
    log "Installing starship..."
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
    # 从 GitHub API 获取最新 release 的下载 URL，再下载并安装
    asset_url=$(curl -fsSL https://api.github.com/repos/starship/starship/releases/latest \
        | jq -r ".assets[].browser_download_url | select(endswith(\"${starship_arch}.tar.gz\"))")
    curl -fsSL "$asset_url" -o /tmp/starship.tar.gz
    tar -xzf /tmp/starship.tar.gz -C /tmp
    install -m 0755 /tmp/starship /usr/local/bin/starship
    rm -rf /tmp/starship /tmp/starship.tar.gz
}

install_docker() {
    log "Setting up Docker..."

    # 添加 Docker 官方 GPG 密钥和镜像源（走清华镜像）
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    create_config_file "/etc/apt/sources.list.d/docker.list" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${TSINGHUA_MIRROR}/docker-ce/linux/ubuntu $(lsb_release -cs) stable"

    # ubuntu-wsl 安装完整 Docker Engine；ubuntu-dev 仅安装 CLI
    if [ "$IMAGE_VARIANT" = "ubuntu-wsl" ]; then
        log "Installing Docker Engine (full)..."
        install_apt_packages \
            docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        if id ubuntu &>/dev/null && getent group docker >/dev/null; then
            usermod -aG docker ubuntu
            log "Added ubuntu user to docker group"
        fi

        # 配置 Docker 镜像加速
        mkdir -p /etc/docker
        create_config_file "/etc/docker/daemon.json" \
            '{
    "registry-mirrors": ["'"${DOCKER_MIRROR}"'"]
}'
    else
        log "Installing Docker CLI only..."
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

    safe_git_clone "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh"

    mkdir -p "$HOME/.oh-my-zsh/custom/plugins"

    # 常用 Zsh 插件：自动建议、语法高亮、补全增强
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

    # 从模板生成 .zshrc，再替换主题和插件列表
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"

    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' "$HOME/.zshrc"
    sed -i 's/plugins=(git)/plugins=(git sudo z zsh-autosuggestions zsh-syntax-highlighting zsh-completions python golang starship)/g' "$HOME/.zshrc"

    mkdir -p ~/.config
    # Starship 纯文本符号主题，避免终端字体不兼容
    starship preset plain-text-symbols -o ~/.config/starship.toml
}

setup_toolchain() {
    log "Setting up development toolchain..."

    # mise：多语言版本管理器，替代 asdf/nvm/pyenv
    curl https://mise.run | MISE_INSTALL_PATH="$HOME/.local/bin/mise" sh
    add_to_zshrc 'eval "$($HOME/.local/bin/mise activate zsh)"'

    eval "$($HOME/.local/bin/mise activate bash)"

    # 启用实验特性以支持更多后端（如 uv）
    mise settings experimental=true

    # 安装常用运行时和工具
    mise use -g python@3.13 go@1.25 node@24 uv

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

    # 更新别名：up-oc / up-cx / up-cl / up-ai
    add_to_zshrc 'alias up-oc="npm install -g opencode-ai@latest"'
    add_to_zshrc 'alias up-cx="npm install -g @openai/codex@latest"'
    add_to_zshrc 'alias up-cl="npm install -g @anthropic-ai/claude-code@latest"'
    add_to_zshrc 'alias up-ai="up-oc && up-cx && up-cl"'

    # 仅 ubuntu-dev 需要在线服务（WSL 使用 systemd）
    if [ "$IMAGE_VARIANT" = "ubuntu-dev" ]; then
        log "Creating startup script for opencode serve..."
        cat > "$HOME/start.sh" << 'SHEOF'
#!/bin/bash

eval "$(/home/ubuntu/.local/bin/mise activate bash)"

sudo service ssh start || true

exec opencode serve --hostname 0.0.0.0 --port 4096
SHEOF
        chmod +x "$HOME/start.sh"
    fi
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

main() {
    log "env-build setup starting..."
    log "IMAGE_VARIANT=${IMAGE_VARIANT}"

    if [[ ! "$IMAGE_VARIANT" =~ ^(ubuntu-dev|ubuntu-wsl)$ ]]; then
        error "IMAGE_VARIANT must be 'ubuntu-dev' or 'ubuntu-wsl', got '${IMAGE_VARIANT}'"
    fi

    # 自动判断：root → 系统配置，非 root → 用户配置
    if [ "$(id -u)" -eq 0 ]; then
        setup_root
    else
        setup_user
    fi

    log "env-build setup completed successfully"
}

main "$@"
