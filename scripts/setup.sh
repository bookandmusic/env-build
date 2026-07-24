#!/bin/bash
set -eo pipefail

# ============================================================
# env-build 主入口
# 通过 id -u 自动判断 root / user 阶段，按顺序调用子脚本
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 镜像变体标识
export IMAGE_VARIANT="${IMAGE_VARIANT:-ubuntu-dev}"

# ============================================================
# 公共函数（子脚本通过 source 继承）
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
    apt-get update -qq || error "Failed to update package lists"
    apt-get install -y -qq --no-install-recommends "${packages[@]}" || \
        error "Failed to install packages: ${packages[*]}"
    rm -rf /var/lib/apt/lists/*
}

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
        rm -rf "$target_dir"
        error "Failed to clone $repo_url"
    fi
}

add_to_zshrc() {
    local line="$1"
    local target="${HOME}/.zshrc"
    [ -f "$target" ] || touch "$target"

    local var_name=""
    if [[ "$line" =~ ^export\ ([A-Za-z_][A-Za-z0-9_]*)= ]]; then
        var_name="${BASH_REMATCH[1]}"
    fi

    if [ -n "$var_name" ]; then
        local tmp_file
        tmp_file=$(mktemp)
        grep -vxE "export ${var_name}=.*" "$target" 2>/dev/null > "$tmp_file" || true
        mv "$tmp_file" "$target"
    fi

    if ! grep -qxF "$line" "$target" 2>/dev/null; then
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

# 配置构建时代理
configure_proxy() {
    if [ -n "${HTTP_PROXY:-}" ]; then
        log "Configuring proxy: ${HTTP_PROXY}"
        cat > /etc/apt/apt.conf.d/99proxy << PROXY_EOF
Acquire::http::Proxy "${HTTP_PROXY}";
Acquire::https::Proxy "${HTTPS_PROXY:-${HTTP_PROXY}}";
PROXY_EOF
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

# ============================================================
# 主逻辑
# ============================================================

main() {
    log "env-build setup starting (IMAGE_VARIANT=${IMAGE_VARIANT})"

    if [ "$(id -u)" -eq 0 ]; then
        # Root 阶段：系统级配置
        configure_proxy
        source "${SCRIPT_DIR}/01-system-deps.sh"
        source "${SCRIPT_DIR}/02-user-setup.sh"
        source "${SCRIPT_DIR}/05-docker-cli.sh"
        source "${SCRIPT_DIR}/06-extra-tools.sh"
        source "${SCRIPT_DIR}/07-services.sh"
    else
        # User 阶段：用户级环境
        source "${SCRIPT_DIR}/03-shell-env.sh"
        source "${SCRIPT_DIR}/04-toolchain.sh"
    fi

    log "env-build setup completed successfully"
}

main "$@"
