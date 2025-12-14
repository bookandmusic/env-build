#!/bin/bash
set -e

# 动态获取脚本根目录
SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

log "Installing code-server..."

# 官方安装脚本
curl -fsSL https://code-server.dev/install.sh | sh

# 创建默认配置目录
mkdir -p ~/.config/code-server

# 写入默认配置文件
cat <<EOF > ~/.config/code-server/config.yaml
bind-addr: 0.0.0.0:8080
auth: password
password: "changeme"
cert: false
EOF

log "code-server installed successfully, default password is 'changeme', port 8080"
