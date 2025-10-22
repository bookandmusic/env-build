#!/bin/bash
set -e

source /tmp/scripts/common.sh

log "Installing vimrc..."

git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime
sh ~/.vim_runtime/install_awesome_vimrc.sh

log "vimrc installed successfully"