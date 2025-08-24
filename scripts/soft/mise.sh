#!/usr/bin/env bash
set -euo pipefail

# 检测系统和架构
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64) ARCH="x64" ;;
    aarch64|arm64) ARCH="arm64" ;;
esac

# mise 下载地址
MISE_VERSION="v2025.8.18"
MISE_URL="https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-${OS}-${ARCH}"

# 安装目录
INSTALL_DIR="/usr/local/bin"
TMP_FILE="$(mktemp)"

# 确保有 sudo 权限
echo "🔑 检查 sudo 权限..."
sudo -v

echo "⬇️  下载 mise $MISE_VERSION for $OS-$ARCH ..."
curl -fsSL "$MISE_URL" -o "$TMP_FILE"
chmod +x "$TMP_FILE"

echo "📦 安装到 $INSTALL_DIR/mise ..."
sudo mv "$TMP_FILE" "$INSTALL_DIR/mise"

echo "✅ mise 安装完成: $(mise --version)"

echo 'eval "$(mise activate zsh)"' >> "${ZDOTDIR-$HOME}/.zshrc"

# 开启实验功能
"$INSTALL_DIR/mise" settings experimental=true

# 添加python插件
"$INSTALL_DIR/mise" plugin add python https://github.com/olofvndrhr/asdf-python.git
"$INSTALL_DIR/mise" plugin add ansible https://github.com/wilsonlun/asdf-ansible.git

# 工具列表
TOOLS=(
    "bat@0.25.0"
    "duf@0.8.1"
    "dust@1.2.3"
    "eza@0.23.0"
    "fd@10.2.0"
    "fzf@0.65.1"
    "gdu@5.31.0"
    "lazydocker@0.24.1"
    "lazygit@0.54.2"
    "lsd@1.1.5"
    "go@1.25.0"
    "go:github.com/incu6us/goimports-reviser/v3@latest"
    "go:mvdan.cc/gofumpt@0.8.0"
    "python@3.12.11"
    "ansible@11.9.0"
    "pipx@1.7.1"
    "pipx:bpytop@1.0.68"
    "pipx:glances@4.3.3"
    "pipx:httpie@3.2.4"
    "pipx:ipython@9.4.0"
    "pipx:litecli@1.16.0"
    "pipx:mycli@1.38.3"
    "pipx:thefuck@3.32"
    "pipx:tldr@3.4.1"
    "pipx:uv@0.8.13"
    "ripgrep@14.1.1"
)

echo "⬇️ 开始安装工具..."
for tool in "${TOOLS[@]}"; do
    echo "👉 安装 $tool ..."
    "$INSTALL_DIR/mise" use -g "$tool"
done

echo "🎉 所有工具安装完成！"
