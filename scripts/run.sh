#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRE_SCRIPT="$BASE_DIR/pre.sh"
OHMYZSH_SCRIPT="$BASE_DIR/ohmyzsh.sh"
SOFT_DIR="$BASE_DIR/soft"
VIRT_DIR="$BASE_DIR/virt"
SHELL_DIR="$BASE_DIR/shell"

echo "🚀 开始一键安装环境..."
SCRIPTS=(
    "$BASE_DIR/pre.sh"
    "$SHELL_DIR/ohmyzsh.sh"
    "$SHELL_DIR/starship.sh"
    "$SHELL_DIR/vimrc.sh"
    "$VIRT_DIR/docker.sh"
    "$VIRT_DIR/containerd.sh"
    "$VIRT_DIR/kubernetes.sh"
    "$SOFT_DIR/mise.sh"
)

for script in ${SCRIPTS[@]}; do
    if [[ -f "$script" ]]; then
        echo "➡️ 执行 $script ..."
        bash "$script"
    fi
done

echo "🎉 一键安装完成！系统依赖、Zsh 配置、通用软件和容器工具已就绪"
