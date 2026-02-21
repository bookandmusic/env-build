#!/bin/bash
set -eo pipefail

# 标准脚本初始化
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

# 使用环境变量控制WSL配置
if [ "${WSL_CONFIG}" = "true" ]; then
    log "Configuring WSL environment..."
    
    # 复制 WSL 配置文件
    if [ -f "$SCRIPT_DIR/configs/wsl.conf" ]; then
        cp "$SCRIPT_DIR/configs/wsl.conf" /etc/wsl.conf
        log "WSL config copied to /etc/wsl.conf"
    fi
fi

# 仅对选择的用户配置代码块使用CONFIG_USER环境变量
if [ "${CONFIG_USER}" = "true" ]; then
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
fi

log "Installing chsrc..."
check_command "curl"
curl https://chsrc.run/posix | bash -s -- -d /usr/local/bin
log "The chsrc installed successfully"

log "Installing starship..."
curl -sS https://starship.rs/install.sh | sh -s -- -y -b /usr/local/bin
log "Starship installed successfully"

log "User configuration completed"