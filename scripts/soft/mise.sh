#!/usr/bin/env bash
# set -euo pipefail

# ------------------------
# 参数解析
# ------------------------
UPDATE=false
for arg in "$@"; do
    case $arg in
        --update)
            UPDATE=true
            shift
            ;;
    esac
done

# ------------------------
# 系统和架构检测
# ------------------------
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64) ARCH="x64" ;;
    aarch64|arm64) ARCH="arm64" ;;
esac

INSTALL_DIR="/usr/local/bin"
MISE_BIN="$INSTALL_DIR/mise"

# ------------------------
# 获取最新 release 版本
# ------------------------
echo "🔍 获取最新 mise 版本..."
LATEST_VERSION=$(curl -fsSL https://api.github.com/repos/jdx/mise/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')

if [ -z "$LATEST_VERSION" ]; then
    echo "❌ 无法获取最新版本，请检查网络"
    exit 1
fi

echo "最新版本: $LATEST_VERSION"

# ------------------------
# 判断是否需要安装/更新
# ------------------------
NEED_INSTALL=false

if [ ! -x "$MISE_BIN" ]; then
    echo "⚡ mise 未安装，将执行安装"
    NEED_INSTALL=true
else
    INSTALLED_VERSION=$("$MISE_BIN" --version || echo "")
    if [ "$INSTALLED_VERSION" != "$LATEST_VERSION" ]; then
        if [ "$UPDATE" = true ]; then
            echo "⚡ mise 当前版本 $INSTALLED_VERSION 与最新版本 $LATEST_VERSION 不一致，将更新"
            NEED_INSTALL=true
        else
            echo "✅ mise 已安装且为版本 $INSTALLED_VERSION，跳过安装"
        fi
    else
        echo "✅ mise 已是最新版本 $INSTALLED_VERSION"
    fi
fi

# ------------------------
# 下载并安装/更新 mise
# ------------------------
if [ "$NEED_INSTALL" = true ]; then
    echo "⬇️ 下载 mise $LATEST_VERSION for $OS-$ARCH ..."
    TMP_FILE=$(mktemp)
    MISE_URL="https://github.com/jdx/mise/releases/download/${LATEST_VERSION}/mise-${LATEST_VERSION}-${OS}-${ARCH}"
    curl -fsSL "$MISE_URL" -o "$TMP_FILE"
    chmod +x "$TMP_FILE"
    echo "📦 安装 mise 到 $MISE_BIN ..."
    sudo mv "$TMP_FILE" "$MISE_BIN"
    echo "✅ 安装完成: $("$MISE_BIN" --version)"
fi

# ------------------------
# 持久化配置
# ------------------------
RC_FILES=(
    "${ZDOTDIR-$HOME}/.zshrc"
    "${ZDOTDIR-$HOME}/.bashrc"
)

for RC_FILE in "${RC_FILES[@]}"; do
    if ! grep -Fxq 'eval "$(mise activate zsh)"' "$RC_FILE"; then
        echo 'eval "$(mise activate zsh)"' >> "$RC_FILE"
        echo "💾 已写入 $RC_FILE，终端重启后 mise 会自动激活"
    fi
done


CURRENT_SHELL=$(ps -p $$ -o comm=)

# 当前会话立即生效
eval "$($MISE_BIN activate $CURRENT_SHELL)"

# ------------------------
# 开启实验功能
# ------------------------
"$MISE_BIN" settings experimental=true

# ------------------------
# 添加插件
# ------------------------
"$MISE_BIN" plugin add python https://github.com/olofvndrhr/asdf-python.git
"$MISE_BIN" plugin add ansible https://github.com/wilsonlun/asdf-ansible.git

# ------------------------
# 工具列表
# ------------------------
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

# ------------------------
# 安装工具，每次刷新环境
# ------------------------
echo "⬇️ 开始安装工具..."
for tool in "${TOOLS[@]}"; do
    echo "👉 安装 $tool ..."
    "$MISE_BIN" use -g "$tool"
    eval "$($MISE_BIN activate $CURRENT_SHELL)"
done

echo "🎉 所有工具安装完成！"
