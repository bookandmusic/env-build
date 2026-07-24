#!/bin/bash
set -eo pipefail

# 本地构建测试
IMAGE_NAME="${1:-env-build:local}"

echo "=== Syntax check ==="
for f in scripts/*.sh scripts/services/*.init ai-tools/ai-tools; do
    echo "Checking $f..."
    bash -n "$f"
done

echo ""
echo "=== Building image: $IMAGE_NAME ==="
docker build -t "$IMAGE_NAME" .

echo ""
echo "=== Quick smoke test ==="
CONTAINER_ID=$(docker run -d "$IMAGE_NAME")
sleep 3

# 检查 sshd 运行
docker exec "$CONTAINER_ID" ss -tln | grep -q ':22' && echo "✓ sshd running" || echo "✗ sshd not running"

# 检查 ubuntu 用户
docker exec "$CONTAINER_ID" id ubuntu && echo "✓ ubuntu user exists" || echo "✗ ubuntu user missing"

# 检查 mise
docker exec -u ubuntu "$CONTAINER_ID" bash -c '~/.local/bin/mise --version' && echo "✓ mise installed" || echo "✗ mise missing"

# 检查 rust
docker exec -u ubuntu "$CONTAINER_ID" bash -c 'source ~/.cargo/env && rustc --version' && echo "✓ rust installed" || echo "✗ rust missing"

# 检查 ai-tools 脚本
docker exec -u ubuntu "$CONTAINER_ID" bash -c 'ai-tools list' && echo "✓ ai-tools available" || echo "✗ ai-tools missing"

# 清理
docker stop "$CONTAINER_ID" > /dev/null
docker rm "$CONTAINER_ID" > /dev/null

echo ""
echo "=== Done ==="
