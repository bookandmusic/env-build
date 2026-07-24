#!/bin/bash
# Docker CLI 安装（root 执行，仅 CLI 不装 daemon）

install_docker_cli() {
    log "Installing Docker CLI..."
    check_command "curl"

    # 添加 Docker 官方 apt 源，仅安装 CLI
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    apt-get install -y -qq --no-install-recommends docker-ce-cli
    rm -rf /var/lib/apt/lists/*

    # 将 ubuntu 用户加入 docker 组
    if getent group docker &>/dev/null; then
        usermod -aG docker ubuntu
    fi

    log "Docker CLI installed: $(docker --version)"
}

install_docker_cli
