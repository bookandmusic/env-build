#!/bin/bash
set -eo pipefail

# 通用函数和配置
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') $*" >&2
    exit 1
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "Command $1 not found"
    fi
}

# 配置清华镜像源
export TSINGHUA_MIRROR="https://mirrors.tuna.tsinghua.edu.cn"
export PYPI_MIRROR="${TSINGHUA_MIRROR}/pypi/web/simple"
export NPM_MIRROR="https://registry.npmmirror.com"
export DOCKER_MIRROR="https://docker.1ms.run"
export BREW_BOTTLE_DOMAIN="${TSINGHUA_MIRROR}/homebrew-bottles"
export GOPROXY="https://goproxy.io,direct"