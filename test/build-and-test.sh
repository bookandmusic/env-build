#!/bin/bash
# ============================================================
# build-and-test.sh — 构建 ubuntu-test 镜像并验证修复
# 用法:
#   ./build-and-test.sh                  # 无代理直连构建
#   ./build-and-test.sh --proxy http://127.0.0.1:7890  # 带代理构建
# ============================================================
set -eo pipefail

PROXY=""
IMAGE_NAME="ubuntu-test:latest"
CONTAINER_NAME="ubuntu-test-$$"

# ============================================================
# 参数解析
# ============================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --proxy)
            PROXY="$2"
            shift 2
            ;;
        --help|-h)
            echo "用法: $0 [--proxy <url>]"
            echo "  --proxy <url>  构建时代理地址（如 http://127.0.0.1:7890）"
            exit 0
            ;;
        *)
            echo "未知参数: $1" >&2
            exit 1
            ;;
    esac
done

log() { echo "[$(date +'%H:%M:%S')] $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

# ============================================================
# 构建镜像
# ============================================================
log "Building ${IMAGE_NAME} ..."

BUILD_ARGS=(--target ubuntu-dev -t "${IMAGE_NAME}" -f Dockerfile .)
if [ -n "$PROXY" ]; then
    # Docker 容器内 127.0.0.1 指向容器自身，需映射为宿主机
    CONTAINER_PROXY="$PROXY"
    if echo "$PROXY" | grep -q '127\.0\.0\.1'; then
        BUILD_ARGS+=(--add-host=host.docker.internal:host-gateway)
        CONTAINER_PROXY=$(echo "$PROXY" | sed 's/127\.0\.0\.1/host.docker.internal/')
        log "Proxy remapped: ${PROXY} → ${CONTAINER_PROXY} (container)"
    fi
    log "Using proxy: ${CONTAINER_PROXY}"
    BUILD_ARGS+=(
        --build-arg "HTTP_PROXY=${CONTAINER_PROXY}"
        --build-arg "HTTPS_PROXY=${CONTAINER_PROXY}"
        --build-arg "ALL_PROXY=${CONTAINER_PROXY}"
    )
else
    log "No proxy, direct connection"
fi

docker build "${BUILD_ARGS[@]}" || fail "Build failed"

# ============================================================
# 启动容器（以 sshd -D 前台运行，后台 -d）
# ============================================================
log "Starting container ${CONTAINER_NAME} ..."
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
docker run -d --name "${CONTAINER_NAME}" "${IMAGE_NAME}" /usr/sbin/sshd -D

# 等待容器启动
sleep 2
docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" | grep -q true || fail "Container not running"

PASS=0
TOTAL=4
cleanup() {
    log "Cleaning up container ${CONTAINER_NAME} ..."
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

# ============================================================
# 测试 1: opencode.init 修复验证
# ============================================================
log "[1/4] Verifying opencode.init fix ..."
if docker exec "${CONTAINER_NAME}" bash -c '
    test -f /etc/init.d/opencode &&
    grep -q "{run,logs}" /etc/init.d/opencode
'; then
    log "  ✅ opencode.init present and brace expansion syntax correct"
    PASS=$((PASS + 1))
else
    log "  ❌ opencode.init verification failed"
fi

# ============================================================
# 测试 2: opencode 服务启动测试
# ============================================================
log "[2/4] Testing opencode service start ..."
if docker exec "${CONTAINER_NAME}" bash -c '
    service opencode start &&
    sleep 3 &&
    nc -z 0.0.0.0 4096
'; then
    log "  ✅ opencode service started and listening on port 4096"
    PASS=$((PASS + 1))
else
    log "  ❌ opencode service failed to start (check: service opencode status)"
    docker exec "${CONTAINER_NAME}" bash -c 'service opencode status; cat ~/.opencode-server/logs/opencode.log 2>/dev/null | tail -20' || true
fi

# ============================================================
# 测试 3: 工具链完整性
# ============================================================
log "[3/4] Checking toolchain completeness ..."
TOOLS_OK=true
# su - ubuntu 以非交互式 zsh 启动，不加载 .zshrc，需手动设置 PATH
MISE_EVAL='export HOME=/home/ubuntu; export PATH="$HOME/.local/bin:$PATH"; eval "$(mise activate bash)"'
for tool_cmd in "mise --version" "node --version" "python --version" "go version" "gopls version" "dlv version"; do
    if ! docker exec "${CONTAINER_NAME}" bash -c "${MISE_EVAL} && ${tool_cmd}" >/dev/null 2>&1; then
        log "  ❌ ${tool_cmd} failed"
        TOOLS_OK=false
    fi
done
if ! docker exec "${CONTAINER_NAME}" starship --version >/dev/null 2>&1; then
    log "  ❌ starship --version failed"
    TOOLS_OK=false
fi
if [ "$TOOLS_OK" = true ]; then
    log "  ✅ All tools available: mise, node, python, go, gopls, dlv, starship"
    PASS=$((PASS + 1))
else
    log "  ❌ Some tools missing"
fi

# ============================================================
# 测试 4: SSH 服务测试
# ============================================================
log "[4/4] Checking SSH service ..."
if docker exec "${CONTAINER_NAME}" ss -tln | grep -q ':22 '; then
    log "  ✅ SSH listening on port 22"
    PASS=$((PASS + 1))
else
    log "  ❌ SSH not listening on port 22"
fi

# ============================================================
# 结果汇总
# ============================================================
echo ""
echo "============================================"
if [ "$PASS" -eq "$TOTAL" ]; then
    echo "✅ All checks passed (${PASS}/${TOTAL})"
    exit 0
else
    echo "⚠️  ${PASS}/${TOTAL} checks passed"
    exit 1
fi
