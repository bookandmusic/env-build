#!/bin/bash
set -e

source /tmp/scripts/common.sh

log "Starting root-level setup..."

log "1. Installing system dependencies..."
/tmp/scripts/01-system-deps.sh

log "2. Setting up Docker..."
/tmp/scripts/02-docker-setup.sh

log "3. Configuring user environment..."
/tmp/scripts/03-user-config.sh

log "Root-level setup completed successfully"