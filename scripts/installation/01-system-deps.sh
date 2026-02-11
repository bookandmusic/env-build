#!/bin/bash
set -eo pipefail

# 标准脚本初始化
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

log "Installing system dependencies..."

# 使用统一的包安装函数
install_apt_packages \
    net-tools iproute2 iputils-ping dnsutils traceroute \
    curl wget sudo git vim unzip tar gnupg lsb-release software-properties-common \
    ca-certificates zsh build-essential procps jq htop gnupg2 lsb-release \
    openssh-client openssh-server tree netcat-openbsd

# 设置 vim 为默认编辑器
update-alternatives --install /usr/bin/editor editor /usr/bin/vim 100
update-alternatives --set editor /usr/bin/vim

log "System dependencies installed successfully"
