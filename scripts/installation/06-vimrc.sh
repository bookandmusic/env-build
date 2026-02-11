#!/bin/bash
set -eo pipefail

# 标准脚本初始化
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

log "Installing vimrc..."

safe_git_clone "https://github.com/amix/vimrc.git" "$HOME/.vim_runtime"
sh ~/.vim_runtime/install_awesome_vimrc.sh

log "vimrc installed successfully"