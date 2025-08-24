#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${1:-myvm}"
CLOUD_INIT_FILE="${2:-my-cloud-init.yml}"
# 修改这里：指向 multipass 同级的 scripts
SCRIPTS_DIR="$(dirname "$(realpath "$0")")/../scripts"
MOUNT_POINT="/tmp/scripts"

# 检查 cloud-init.yml 和 scripts 目录
[[ -f "$CLOUD_INIT_FILE" ]] || { echo "❌ 找不到 $CLOUD_INIT_FILE"; exit 1; }
[[ -d "$SCRIPTS_DIR" ]] || { echo "❌ 找不到 $SCRIPTS_DIR"; exit 1; }

# 启动 Multipass 实例并挂载 scripts
multipass launch \
    --name "$VM_NAME" \
    --cloud-init "$CLOUD_INIT_FILE" \
    --mount "$SCRIPTS_DIR:$MOUNT_POINT" \
    --mem 4G \
    --disk 20G \
    --cpus 2

echo "✅ Multipass 实例 $VM_NAME 已启动并挂载 scripts"

# 等待 cloud-init 执行完成
multipass exec "$VM_NAME" -- cloud-init status --wait

# 执行挂载的 run.sh
multipass exec "$VM_NAME" -- bash "$MOUNT_POINT/run.sh"

# 卸载 scripts 挂载（可选）
if multipass exec "$VM_NAME" -- mountpoint -q "$MOUNT_POINT"; then
    multipass exec "$VM_NAME" -- sudo umount "$MOUNT_POINT"
fi

echo "🎉 Multipass 初始化完成！"
