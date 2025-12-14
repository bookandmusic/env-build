#!/bin/zsh
set -e

# 动态获取脚本根目录
SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

log "Starting user-level setup..."

log "1. Setting up Oh My Zsh and plugins..."
"$SCRIPT_DIR/installation/04-oh-my-zsh-setup.sh"

log "2. Setting up development toolchain..."
"$SCRIPT_DIR/installation/05-toolchain-setup.sh"

log "3. Setting up vimrc..."
"$SCRIPT_DIR/installation/06-vimrc.sh"

if [ "${INSTALL_CODE_SERVER}" = "true" ]; then
    log "4. Installing code-server..."
    "$SCRIPT_DIR/installation/07-coder-server.sh"
else
    log "Skipping code-server installation."
fi

log "User-level setup completed successfully"

log "Cleaning up..."
rm -rf /home/ubuntu/.cache/*
log "Setup completed"