#!/bin/bash
set -eo pipefail

# 标准脚本初始化
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

if [ "${DOCKER_MODE}" != "full" ]; then
    log "Skipping Docker Engine setup (DOCKER_MODE=${DOCKER_MODE})"
    exit 0
fi

log "Setting up Docker Engine..."

# 准备 Docker 仓库
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

create_config_file "/etc/apt/sources.list.d/docker.list" \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${TSINGHUA_MIRROR}/docker-ce/linux/ubuntu $(lsb_release -cs) stable"

# 安装完整 Docker Engine
install_apt_packages \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 配置 Docker 用户组（Engine 安装会自动创建 docker 组）
if id ubuntu &>/dev/null && getent group docker >/dev/null; then
    usermod -aG docker ubuntu
    log "Added ubuntu user to docker group"
fi

mkdir -p /etc/docker
create_config_file "/etc/docker/daemon.json" \
    '{
    "registry-mirrors": ["'"${DOCKER_MIRROR}"'"]
}'

log "Docker Engine setup completed"