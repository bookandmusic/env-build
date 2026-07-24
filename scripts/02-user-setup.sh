#!/bin/bash
# 创建 ubuntu 用户（root 执行）

setup_user_account() {
    if id -u ubuntu &>/dev/null; then
        log "User 'ubuntu' already exists, skipping creation"
        return 0
    fi

    log "Creating user 'ubuntu'..."
    useradd -m -s /usr/bin/zsh -G sudo ubuntu
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
    chmod 440 /etc/sudoers.d/ubuntu

    # 创建常用目录
    su - ubuntu -c 'mkdir -p ~/.local/bin ~/.config'
}

setup_user_account
