#!/usr/bin/env bash
set -euo pipefail

# ===============================
# 1️⃣ 安装基础依赖
# ===============================

REQUIRED_PACKAGES=(curl wget git tar xz-utils gzip zsh jq)

# 确保 sudo 存在
if ! command -v sudo >/dev/null 2>&1; then
    echo "⚠️ 未检测到 sudo，正在安装..."
    apt-get update -y
    apt-get install -y sudo
fi

SUDO="sudo"

# -------------------------------
# 检查哪些命令缺失
# -------------------------------
MISSING_PACKAGES=()

for pkg in "${REQUIRED_PACKAGES[@]}"; do
    # xz-utils 提供 xz 命令
    cmd="$pkg"
    if [ "$pkg" = "xz-utils" ]; then
        cmd="xz"
    fi

    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_PACKAGES+=("$pkg")
    else
        echo "✅ $pkg 已安装"
    fi
done

# -------------------------------
# 安装缺失的软件
# -------------------------------
if [ "${#MISSING_PACKAGES[@]}" -gt 0 ]; then
    echo "🔄 检测到缺失软件: ${MISSING_PACKAGES[*]}"
    echo "🔄 更新 apt 软件源..."
    $SUDO apt-get update -y

    echo "⬇️ 安装缺失软件..."
    $SUDO apt-get install -y "${MISSING_PACKAGES[@]}"
    # -------------------------------
    # 清理 apt 缓存
    # -------------------------------
    echo "🧹 清理 apt 缓存..."
    $SUDO rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

    echo "🎉 基础依赖安装完成"
else
    echo "✅ 所有必备软件已安装"
fi


