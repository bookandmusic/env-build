#!/bin/bash
set -eo pipefail

IMAGE_VARIANT="${IMAGE_VARIANT:-ubuntu-dev}"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting services for ${IMAGE_VARIANT}..." >&2

# 启动 SSH 服务
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting SSH service..." >&2
# 使用 sudo 执行需要 root 权限的命令
sudo mkdir -p /run/sshd
sudo service ssh start

# 根据镜像变体启动不同服务
case "${IMAGE_VARIANT}" in
    code-server)
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting Code-Server..." >&2
        if command -v code-server &>/dev/null; then
            su - ubuntu -c "code-server --bind-addr 0.0.0.0:8080 --auth none" &
        else
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: code-server not found" >&2
        fi
        ;;
    ubuntu-dev)
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] SSH-only mode, no additional services" >&2
        ;;
    ubuntu-wsl)
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] WSL mode should use systemd, not this script" >&2
        ;;
esac

if [ $# -gt 0 ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Executing: $*" >&2
    exec "$@"
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Keeping container alive..." >&2
    exec sleep infinity
fi
