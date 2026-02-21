#!/bin/bash
set -eo pipefail

# 标准脚本初始化
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

if [ "${DOCKER_MODE}" != "cli-only" ]; then
    log "Skipping Docker CLI setup (DOCKER_MODE=${DOCKER_MODE})"
    exit 0
fi

log "Setting up Docker CLI..."

# 准备 Docker 仓库
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

create_config_file "/etc/apt/sources.list.d/docker.list" \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${TSINGHUA_MIRROR}/docker-ce/linux/ubuntu $(lsb_release -cs) stable"

# 仅安装 CLI 和插件
install_apt_packages docker-ce-cli docker-buildx-plugin docker-compose-plugin

log "Docker CLI setup completed"
