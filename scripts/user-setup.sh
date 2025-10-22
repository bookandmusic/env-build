#!/bin/zsh
set -e

source /tmp/scripts/common.sh

log "Starting user-level setup..."

log "1. Setting up Oh My Zsh and plugins..."
/tmp/scripts/04-oh-my-zsh-setup.sh

log "2. Setting up development toolchain..."
/tmp/scripts/05-toolchain-setup.sh

log "3. Setting up vimrc..."
/tmp/scripts/06-vimrc.sh

if [ "${INSTALL_CODE_SERVER}" = "true" ]; then
    log "4. Installing code-server..."
    /tmp/scripts/07-coder-server.sh
else
    log "Skipping code-server installation."
fi

log "User-level setup completed successfully"

log "Cleaning up..."
rm -rf /home/ubuntu/.cache/*
log "Setup completed"