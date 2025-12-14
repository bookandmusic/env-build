#!/bin/bash
set -e

# 动态获取脚本根目录
SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

log "Installing vimrc..."

git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime
sh ~/.vim_runtime/install_awesome_vimrc.sh

log "vimrc installed successfully"