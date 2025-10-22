#!/bin/bash
set -e

source /tmp/scripts/common.sh

log "Installing system dependencies..."

apt-get update && \
apt-get install -y --no-install-recommends \
    net-tools iproute2 iputils-ping dnsutils traceroute \
    curl wget sudo git vim unzip tar gnupg lsb-release software-properties-common \
    ca-certificates zsh build-essential procps jq htop gnupg2 lsb-release \
    openssh-client openssh-server tree

rm -rf /var/lib/apt/lists/*

# 设置 vim 为默认编辑器
update-alternatives --install /usr/bin/editor editor /usr/bin/vim 100
update-alternatives --set editor /usr/bin/vim

log "System dependencies installed successfully"
