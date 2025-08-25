#!/bin/bash
set -euo pipefail

# === 配置环境变量 ===
GITHUB_PROXY="${GITHUB_PROXY:-}"         # GitHub 代理
DOCKER_VERSION="${DOCKER_VERSION:-}"     # Docker 版本，空则自动获取
COMPOSE_VERSION="${COMPOSE_VERSION:-}"   # docker-compose 版本，空则自动获取
BUILDX_VERSION="${BUILDX_VERSION:-}"     # docker-buildx 版本，空则自动获取

BIN_DIR="/usr/local/bin"
PLUGIN_DIR="/usr/libexec/docker/cli-plugins"
UPDATE_MODE=false

DEFAULT_BIP="172.18.0.1/16"
REGISTRY_MIRRORS="${REGISTRY_MIRRORS:-}"
INSECURE_REGISTRIES="${INSECURE_REGISTRIES:-}"
DEFAULT_HTTP_PROXY="${http_proxy:-}"
DEFAULT_HTTPS_PROXY="${https_proxy:-}"
DEFAULT_NO_PROXY="${no_proxy:-}"

DOCKER_DAEMON_JSON="/etc/docker/daemon.json"

# ---------------------------
# 参数解析
# ---------------------------
if [[ "${1:-}" == "--update" ]]; then
    UPDATE_MODE=true
    echo "🔄 启用更新模式"
fi

# nftables legacy 兼容（Debian/Ubuntu）
if command -v update-alternatives >/dev/null 2>&1; then
    sudo update-alternatives --set iptables /usr/sbin/iptables-legacy || true
    sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true
fi

# ---------------------------
# 检测架构
# ---------------------------
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) DOCKER_ARCH="x86_64"; COMPOSE_ARCH="x86_64"; BUILDX_ARCH="amd64" ;;
    aarch64|arm64) DOCKER_ARCH="aarch64"; COMPOSE_ARCH="aarch64"; BUILDX_ARCH="arm64" ;;
    *) echo "❌ 不支持的架构: $ARCH"; exit 1 ;;
esac
echo "🔧 检测到架构: Docker=$DOCKER_ARCH Compose=$COMPOSE_ARCH buildx=$BUILDX_ARCH"

# ---------------------------
# GitHub 代理
# ---------------------------
GITHUB_API="${GITHUB_PROXY:-}https://api.github.com"
GITHUB_COMPOSE_RELEASE="${GITHUB_PROXY:-}https://github.com/docker/compose/releases"
GITHUB_BUILDX_RELEASE="${GITHUB_PROXY:-}https://github.com/docker/buildx/releases"

# ---------------------------
# 获取最新版本
# ---------------------------
get_latest_version() {
    local repo=$1
    curl -s "${GITHUB_API}/repos/${repo}/releases/latest" \
        | grep -oP '"tag_name":\s*"\K(.*?)(?=")'
}

LATEST_DOCKER_VER=$(get_latest_version "moby/moby")
[ -z "$DOCKER_VERSION" ] && DOCKER_VERSION="${LATEST_DOCKER_VER#v}"
[ -z "$COMPOSE_VERSION" ] && COMPOSE_VERSION="$(get_latest_version "docker/compose")"
[ -z "$BUILDX_VERSION" ] && BUILDX_VERSION="$(get_latest_version "docker/buildx")"

echo "📦 Docker 最新版本: $DOCKER_VERSION"
echo "📦 docker-compose 最新版本: $COMPOSE_VERSION"
echo "📦 docker-buildx 最新版本: $BUILDX_VERSION"

# ---------------------------
# 本地版本检测
# ---------------------------
get_local_version() {
    local cmd=$1
    local version=""
    case "$cmd" in
        docker)
            version="$(docker --version | awk '{print $3}' | sed 's/,//')"
            ;;
        docker-compose)
            version=$(docker compose version 2>/dev/null | head -1 | grep -oP 'v?\d+\.\d+\.\d+')
            ;;
        docker-buildx)
            version=$(docker buildx version 2>/dev/null | head -1 | grep -oP 'v?\d+\.\d+\.\d+')
            ;;
    esac
    echo "$version"
}

LOCAL_DOCKER_VER=$(get_local_version docker)
LOCAL_COMPOSE_VER=$(get_local_version docker-compose)
LOCAL_BUILDX_VER=$(get_local_version docker-buildx)

echo "🔹 本地 Docker 版本: ${LOCAL_DOCKER_VER:-未安装}"
echo "🔹 本地 docker-compose 版本: ${LOCAL_COMPOSE_VER:-未安装}"
echo "🔹 本地 docker-buildx 版本: ${LOCAL_BUILDX_VER:-未安装}"

# ---------------------------
# 决定是否更新
# ---------------------------
UPDATE_DOCKER=true
UPDATE_COMPOSE=true
UPDATE_BUILDX=true

[ "$LOCAL_DOCKER_VER" = "$DOCKER_VERSION" ] && [ -n "$LOCAL_DOCKER_VER" ] && UPDATE_DOCKER=false
[ "$LOCAL_COMPOSE_VER" = "$COMPOSE_VERSION" ] && [ -n "$LOCAL_COMPOSE_VER" ] && UPDATE_COMPOSE=false
[ "$LOCAL_BUILDX_VER" = "$BUILDX_VERSION" ] && [ -n "$LOCAL_BUILDX_VER" ] && UPDATE_BUILDX=false

# ---------------------------
# 安装/更新 Docker
# ---------------------------
if $UPDATE_DOCKER; then
    echo "📥 安装/更新 Docker $DOCKER_VERSION ..."
    DOCKER_TGZ="docker-${DOCKER_VERSION}.tgz"   # 下载 URL 去掉 v 前缀
    curl -fLO "https://mirrors.aliyun.com/docker-ce/linux/static/stable/${DOCKER_ARCH}/${DOCKER_TGZ}"
    tar -xzf "$DOCKER_TGZ"
    echo "⚙ 安装 Docker 到 $BIN_DIR ..."
    sudo install -m 755 docker/* "$BIN_DIR"
else
    echo "✅ Docker 已是最新版本 $DOCKER_VERSION，跳过安装"
fi

# ---------------------------
# 配置 systemd service (二进制安装必需)
# ---------------------------
echo "⚙️ 配置 systemd service..."
sudo tee /etc/systemd/system/docker.service > /dev/null <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target docker.socket firewalld.service containerd.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=${BIN_DIR}/dockerd
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/docker.socket > /dev/null <<'EOF'
[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

# ---------------------------
# 配置 daemon.json (总是更新)
# ---------------------------
sudo mkdir -p /etc/docker

# registry-mirrors
if [ -z "$REGISTRY_MIRRORS" ]; then
    REGISTRY_MIRRORS_JSON="[]"
else
    IFS=',' read -ra RM_ARR <<< "$REGISTRY_MIRRORS"
    REGISTRY_MIRRORS_JSON=$(printf '%s\n' "${RM_ARR[@]}" | jq -R . | jq -s .)
fi

# insecure-registries
if [ -z "$INSECURE_REGISTRIES" ]; then
    INSECURE_REGISTRIES_JSON="[]"
else
    IFS=',' read -ra IR_ARR <<< "$INSECURE_REGISTRIES"
    INSECURE_REGISTRIES_JSON=$(printf '%s\n' "${IR_ARR[@]}" | jq -R . | jq -s .)
fi

echo "📝 更新 daemon.json 配置..."
sudo tee "$DOCKER_DAEMON_JSON" > /dev/null <<EOF
{
  "bip": "${DEFAULT_BIP}",
  "insecure-registries": ${INSECURE_REGISTRIES_JSON},
  "registry-mirrors": ${REGISTRY_MIRRORS_JSON},
  "proxies": {
    "http-proxy": "${DEFAULT_HTTP_PROXY}",
    "https-proxy": "${DEFAULT_HTTPS_PROXY}",
    "no-proxy": "${DEFAULT_NO_PROXY}"
  }
}
EOF

# ---------------------------
# 确保 Docker 服务正常
# ---------------------------
echo "🔧 检查 Docker 服务状态..."
if ! systemctl is-active --quiet docker; then
    echo "🚀 Docker 未运行，尝试启动..."
    sudo systemctl daemon-reload
    sudo systemctl enable docker.socket
    sudo systemctl start docker.socket
    sudo systemctl restart docker
    sleep 2
fi

docker info >/dev/null 2>&1 || { echo "❌ Docker 启动失败"; exit 1; }
echo "✅ Docker 服务运行正常"

# ---------------------------
# 安装/更新 docker-compose
# ---------------------------
sudo mkdir -p "$PLUGIN_DIR"
COMPOSE_PLUGIN="$PLUGIN_DIR/docker-compose"
if $UPDATE_COMPOSE; then
    echo "📥 安装/更新 docker-compose $COMPOSE_VERSION ..."
    sudo curl -fLo "$COMPOSE_PLUGIN" \
        "${GITHUB_COMPOSE_RELEASE}/download/${COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}"
    sudo chmod +x "$COMPOSE_PLUGIN"
else
    echo "✅ docker-compose 已是最新版本 $LOCAL_COMPOSE_VER，跳过安装"
fi

# ---------------------------
# 安装/更新 docker-buildx
# ---------------------------
BUILDX_PLUGIN="$PLUGIN_DIR/docker-buildx"
if $UPDATE_BUILDX; then
    echo "📥 安装/更新 docker-buildx $BUILDX_VERSION ..."
    sudo curl -fLo "$BUILDX_PLUGIN" \
        "${GITHUB_BUILDX_RELEASE}/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-${BUILDX_ARCH}"
    sudo chmod +x "$BUILDX_PLUGIN"
else
    echo "✅ docker-buildx 已是最新版本 $LOCAL_BUILDX_VER，跳过安装"
fi

# ---------------------------
# 验证安装
# ---------------------------
echo "🔍 验证 Docker ..."
docker version
docker info
echo "🔍 验证 docker-compose ..."
docker compose version
echo "🔍 验证 docker-buildx ..."
docker buildx version

echo "🎉 Docker 及插件安装/更新完成！"

