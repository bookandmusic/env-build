#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRE_SCRIPT="$BASE_DIR/pre.sh"
OHMYZSH_SCRIPT="$BASE_DIR/ohmyzsh.sh"
SOFT_DIR="$BASE_DIR/soft"
VIRT_DIR="$BASE_DIR/virt"

echo "🚀 开始一键安装环境..."

# ===============================
# 1️⃣ 执行 pre.sh 安装系统基础依赖
# ===============================
if [[ -f "$PRE_SCRIPT" ]]; then
    echo "🔧 执行 pre.sh 安装系统基础依赖..."
    bash "$PRE_SCRIPT"
else
    echo "⚠️ 未找到 pre.sh，跳过系统依赖检测"
fi

# ===============================
# 2️⃣ 配置 oh-my-zsh
# ===============================
if [[ -f "$OHMYZSH_SCRIPT" ]]; then
    echo "🔧 配置 oh-my-zsh..."
    bash "$OHMYZSH_SCRIPT"
else
    echo "⚠️ 未找到 ohmyzsh.sh，跳过 Zsh 配置"
fi

# ===============================
# 3️⃣ 安装 soft 目录下软件
# ===============================
if [[ -d "$SOFT_DIR" ]]; then
    echo "🔧 安装 soft 目录软件..."
    for script in "$SOFT_DIR"/*.sh; do
        if [[ -f "$script" ]]; then
            echo "➡️ 执行 $script ..."
            bash "$script"
        fi
    done
else
    echo "⚠️ 未找到 soft 目录，跳过"
fi

# ===============================
# 4️⃣ 安装 virt 目录下容器/虚拟化软件
# ===============================
if [[ -d "$VIRT_DIR" ]]; then
    echo "🔧 安装 virt 目录软件..."
    VIRT_SCRIPTS=("docker.sh" "containerd.sh" "kubernetes.sh")
    for script_name in "${VIRT_SCRIPTS[@]}"; do
        script_path="$VIRT_DIR/$script_name"
        if [[ -f "$script_path" ]]; then
            echo "➡️ 执行 $script_path ..."
            bash "$script_path"
        else
            echo "⚠️ 未找到 $script_path，跳过"
        fi
    done
else
    echo "⚠️ 未找到 virt 目录，跳过"
fi

echo "🎉 一键安装完成！系统依赖、Zsh 配置、通用软件和容器工具已就绪"
