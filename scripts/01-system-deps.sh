#!/bin/bash
# 系统依赖安装（root 执行）

install_system_deps() {
    log "Installing system dependencies..."
    install_apt_packages \
        curl wget sudo git vim unzip zip tar gnupg \
        ca-certificates zsh jq netcat-openbsd procps \
        openssh-client openssh-server \
        iproute2 iputils-ping dnsutils net-tools \
        htop tmux lsof

    update-alternatives --install /usr/bin/editor editor /usr/bin/vim 100
    update-alternatives --set editor /usr/bin/vim
}

install_system_deps
