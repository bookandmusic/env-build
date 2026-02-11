#!/bin/bash
set -eo pipefail

# 标准脚本初始化
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

if [ "${INSTALL_DOCKER}" != "true" ]; then
    log "Skipping Docker setup (INSTALL_DOCKER=${INSTALL_DOCKER})"
    exit 0
fi

log "Setting up Docker..."

# 准备 Docker 仓库
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

create_config_file "/etc/apt/sources.list.d/docker.list" \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${TSINGHUA_MIRROR}/docker-ce/linux/ubuntu $(lsb_release -cs) stable"

install_apt_packages \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 配置 Docker 用户和镜像
usermod -aG docker ubuntu
mkdir -p /etc/docker

create_config_file "/etc/docker/daemon.json" \
    '{
    "registry-mirrors": ["'"${DOCKER_MIRROR}"'"]
}'

log "Docker setup completed"