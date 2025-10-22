#!/bin/bash
set -e

source /tmp/scripts/common.sh

log "Setting up Docker..."

# 准备 Docker 仓库
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${TSINGHUA_MIRROR}/docker-ce/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y --no-install-recommends \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 配置 Docker 用户和镜像
usermod -aG docker ubuntu
mkdir -p /etc/docker

cat > /etc/docker/daemon.json << EOF
{
    "registry-mirrors": ["${DOCKER_MIRROR}"]
}
EOF

log "Docker setup completed"