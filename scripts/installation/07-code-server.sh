#!/bin/bash
set -eo pipefail

# 标准脚本初始化
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

if [ "${INSTALL_CODE_SERVER}" != "true" ]; then
    log "Skipping code-server setup (INSTALL_CODE_SERVER=${INSTALL_CODE_SERVER})"
    exit 0
fi

log "Installing code-server..."

# 官方安装脚本
check_command "curl"
curl -fsSL https://code-server.dev/install.sh | sh

# 创建默认配置目录
mkdir -p ~/.config/code-server

# 写入默认配置文件
create_config_file ~/.config/code-server/config.yaml \
'bind-addr: 0.0.0.0:8080
auth: password
password: "changeme"
cert: false'

log "code-server installed successfully, default password is 'changeme', port 8080"
