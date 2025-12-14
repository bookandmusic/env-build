#!/bin/bash
set -e

# 动态获取脚本根目录
SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

# 使用环境变量控制WSL配置
if [ "${WSL_CONFIG}" = "true" ]; then
    log "Configuring WSL environment..."
    mkdir -p /etc
    cat > /etc/wsl.conf << EOF
[boot]
systemd=true
[user]
default=ubuntu
EOF
fi

# 仅对选择的用户配置代码块使用CONFIG_USER环境变量
if [ "${CONFIG_USER}" = "true" ]; then
    log "Configuring user environment..."

    # 创建用户和权限
    echo "ubuntu:1" | chpasswd
    usermod -aG sudo ubuntu
    chsh -s "$(which zsh)" ubuntu

    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
    chmod 440 /etc/sudoers.d/ubuntu
fi

log "Installing chsrc..."
curl https://chsrc.run/posix | bash -s -- -d /usr/local/bin
log "The chsrc installed successfully"

log "Installing starship..."
curl -sS https://starship.rs/install.sh | sh -s -- -y -b /usr/local/bin
log "Starship installed successfully"


log "User configuration completed"