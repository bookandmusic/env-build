#!/bin/bash
set -eo pipefail

# 标准脚本初始化
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

# 预检查
run_preflight_checks

log "Starting root-level setup..."

log "1. Installing system dependencies..."
"$SCRIPT_DIR/installation/01-system-deps.sh"

log "2. Configuring user environment..."
"$SCRIPT_DIR/installation/03-user-config.sh"

log "3. Setting up Docker..."
case "${DOCKER_MODE}" in
    cli-only)
        log "Installing Docker CLI only..."
        "$SCRIPT_DIR/installation/02-docker-cli-setup.sh"
        ;;
    full)
        log "Installing Docker Engine (full)..."
        "$SCRIPT_DIR/installation/02-docker-engine-setup.sh"
        ;;
    none)
        log "Skipping Docker setup (DOCKER_MODE=none)"
        ;;
    *)
        warn "Unknown DOCKER_MODE: ${DOCKER_MODE}, skipping Docker setup"
        ;;
esac

log "Root-level setup completed successfully"