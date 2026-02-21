#!/bin/bash
set -eo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

VERSION="${VERSION:-latest}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

cd "$PROJECT_ROOT"

log "Building code-server variant..."
docker build --target code-server -t "code-server:${VERSION}" .

log "Building ubuntu-dev variant..."
docker build --target ubuntu-dev -t "ubuntu-dev:${VERSION}" .

log "Building ubuntu-wsl variant..."
docker build --target ubuntu-wsl -t "ubuntu-dev-wsl:${VERSION}" .

log "Build completed successfully!"
log "Images:"
log "  - code-server:${VERSION}"
log "  - ubuntu-dev:${VERSION}"
log "  - ubuntu-dev-wsl:${VERSION}"
