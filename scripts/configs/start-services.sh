#!/bin/bash
set -eo pipefail

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting SSH service..." >&2
service ssh start

if [ $# -gt 0 ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Executing: $*" >&2
    exec "$@"
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] No command specified, keeping container alive..." >&2
    exec sleep infinity
fi
