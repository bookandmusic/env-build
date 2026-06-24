#!/bin/bash
set -eo pipefail

# ============================================================
# env-build 统一安装脚本
# 通过 id -u 自动判断 root/user 阶段
# ============================================================

IMAGE_VARIANT="${IMAGE_VARIANT:-ubuntu-dev}"

# 镜像源
TSINGHUA_MIRROR="https://mirrors.tuna.tsinghua.edu.cn"
DOCKER_MIRROR="https://docker.1ms.run"

# ============================================================
# 公共函数
# ============================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
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

    echo "ubuntu:1" | chpasswd
    usermod -aG sudo ubuntu
    chsh -s "$(which zsh)" ubuntu

    create_config_file /etc/sudoers.d/ubuntu \
        'ubuntu ALL=(ALL) NOPASSWD:ALL' 440

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

    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    create_config_file "/etc/apt/sources.list.d/docker.list" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${TSINGHUA_MIRROR}/docker-ce/linux/ubuntu $(lsb_release -cs) stable"

    if [ "$IMAGE_VARIANT" = "ubuntu-wsl" ]; then
        log "Installing Docker Engine (full)..."
        install_apt_packages \
            docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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

    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"

    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' "$HOME/.zshrc"
    sed -i 's/plugins=(git)/plugins=(git sudo z zsh-autosuggestions zsh-syntax-highlighting zsh-completions python golang starship)/g' "$HOME/.zshrc"

    mkdir -p ~/.config
    starship preset plain-text-symbols -o ~/.config/starship.toml
}

setup_toolchain() {
    log "Setting up development toolchain..."

    check_command "curl"
    curl https://mise.run | MISE_INSTALL_PATH="$HOME/.local/bin/mise" sh
    add_to_zshrc 'eval "$($HOME/.local/bin/mise activate zsh)"'

    eval "$($HOME/.local/bin/mise activate bash)"

    mise settings experimental=true

    mise use -g python@3.13 go@1.25 node@24 uv

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

    if [[ ! "$IMAGE_VARIANT" =~ ^(ubuntu-dev|ubuntu-wsl)$ ]]; then
        error "IMAGE_VARIANT must be 'ubuntu-dev' or 'ubuntu-wsl', got '${IMAGE_VARIANT}'"
    fi

    if [ "$(id -u)" -eq 0 ]; then
        setup_root
    else
        setup_user
    fi

    log "env-build setup completed successfully"
}

main "$@"
