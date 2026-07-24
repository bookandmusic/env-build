#!/bin/bash
# Docker CLI 安装（root 执行，仅 CLI 不装 daemon）

install_docker_cli() {
    log "Installing Docker CLI..."
    check_command "curl"

    local arch
    case "$(uname -m)" in
        x86_64|amd64)   arch="x86_64" ;;
        aarch64|arm64)   arch="aarch64" ;;
        *)               error "Unsupported architecture for Docker CLI: $(uname -m)" ;;
    esac

    local version
    version=$(curl -fsSL https://api.github.com/repos/docker/cli/releases/latest \
        | jq -r '.tag_name' | sed 's/^v//') || error "Failed to get Docker CLI version"

    local url="https://download.docker.com/linux/static/stable/${arch}/docker-${version}.tgz"
    log "Downloading Docker CLI v${version}..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    curl -fsSL "$url" | tar xz -C "$tmp_dir"
    mv "$tmp_dir/docker/docker" /usr/local/bin/docker
    chmod +x /usr/local/bin/docker
    rm -rf "$tmp_dir"

    # 将 ubuntu 用户加入 docker 组（如果组存在）
    if getent group docker &>/dev/null; then
        usermod -aG docker ubuntu
    fi

    log "Docker CLI v${version} installed"
}

install_docker_cli
