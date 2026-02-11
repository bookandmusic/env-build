#!/bin/bash
set -eo pipefail

# 通用函数和配置
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

# 增强的包安装函数
install_apt_packages() {
    local packages=("$@")
    log "Installing APT packages: ${packages[*]}"
    
    apt-get update || error "Failed to update package lists"
    apt-get install -y --no-install-recommends "${packages[@]}" || \
        error "Failed to install packages: ${packages[*]}"
    rm -rf /var/lib/apt/lists/*
}

# 安全的git克隆函数
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

# 幂等追加到 .zshrc
add_to_zshrc() {
    local line="$1"
    local target="${HOME}/.zshrc"
    if ! grep -qF "$line" "$target" 2>/dev/null; then
        echo "$line" >> "$target"
    fi
}

# 配置文件创建函数
create_config_file() {
    local filepath="$1"
    local content="$2"
    local permissions="${3:-644}"
    
    log "Creating config file: $filepath"
    echo "$content" > "$filepath" || error "Failed to create $filepath"
    chmod "$permissions" "$filepath" || error "Failed to set permissions on $filepath"
}

# 加载环境变量配置
# Get the directory of the current script using bash-compatible syntax
COMMON_SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
source "$COMMON_SCRIPT_DIR/variables.sh"

# 配置清华镜像源
export TSINGHUA_MIRROR="https://mirrors.tuna.tsinghua.edu.cn"
export PYPI_MIRROR="${TSINGHUA_MIRROR}/pypi/web/simple"
export NPM_MIRROR="https://registry.npmmirror.com"
export DOCKER_MIRROR="https://docker.1ms.run"
export BREW_BOTTLE_DOMAIN="${TSINGHUA_MIRROR}/homebrew-bottles"
export GOPROXY="https://goproxy.io,direct"