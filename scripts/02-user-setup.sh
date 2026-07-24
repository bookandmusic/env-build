#!/bin/bash
# 创建/配置 ubuntu 用户（root 执行）

setup_user_account() {
    if id -u ubuntu &>/dev/null; then
        log "User 'ubuntu' already exists, configuring..."
    else
        log "Creating user 'ubuntu'..."
        useradd -m -s /usr/bin/zsh -G sudo ubuntu
    fi

    # 确保 sudo 免密（无论用户是否已存在）
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
    chmod 440 /etc/sudoers.d/ubuntu

    # 确保 shell 是 zsh
    chsh -s /usr/bin/zsh ubuntu

    # 设置密码（SSH 登录用，生产环境应使用密钥）
    echo "ubuntu:ubuntu" | chpasswd

    # 创建常用目录
    su - ubuntu -c 'mkdir -p ~/.local/bin ~/.config'

    log "User 'ubuntu' configured (shell=zsh, sudo=nopasswd)"
}

setup_user_account
