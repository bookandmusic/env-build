#!/bin/bash
set -e

# 动态获取脚本根目录
SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

log "Starting root-level setup..."

log "1. Installing system dependencies..."
"$SCRIPT_DIR/installation/01-system-deps.sh"

log "2. Setting up Docker..."
if [ "${INSTALL_DOCKER}" = "true" ]; then
    "$SCRIPT_DIR/installation/02-docker-setup.sh"
else
    log "Skipping Docker setup (INSTALL_DOCKER not 'true')."
fi

log "3. Configuring environment..."
"$SCRIPT_DIR/installation/03-user-config.sh"

log "Root-level setup completed successfully"