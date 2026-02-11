#!/bin/bash
set -eo pipefail

# 标准脚本初始化
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

# 使用环境变量控制WSL配置
if [ "${WSL_CONFIG}" = "true" ]; then
    log "Configuring WSL environment..."
    mkdir -p /etc
    create_config_file /etc/wsl.conf \
'[boot]
systemd=true
[user]
default=ubuntu'
fi

# 仅对选择的用户配置代码块使用CONFIG_USER环境变量
if [ "${CONFIG_USER}" = "true" ]; then
    log "Configuring user environment..."

    # 创建用户和权限
    echo "ubuntu:1" | chpasswd
    usermod -aG sudo ubuntu
    chsh -s "$(which zsh)" ubuntu

    create_config_file /etc/sudoers.d/ubuntu \
'ubuntu ALL=(ALL) NOPASSWD:ALL' 440
fi

log "Installing chsrc..."
check_command "curl"
curl https://chsrc.run/posix | bash -s -- -d /usr/local/bin
log "The chsrc installed successfully"

log "Installing starship..."
curl -sS https://starship.rs/install.sh | sh -s -- -y -b /usr/local/bin
log "Starship installed successfully"

log "User configuration completed"