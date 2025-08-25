ZSHRC="$HOME/.zshrc"

# ---------------------------
# 安装/更新 Starship
# ---------------------------
install_starship() {
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    armv7l) ARCH="arm" ;;
    *) echo "❌ 不支持的架构: $ARCH"; exit 1 ;;
  esac

  case "$OS" in
    linux)   TARGET="${ARCH}-unknown-linux-gnu" ;;
    darwin)  TARGET="${ARCH}-apple-darwin" ;;
    freebsd) TARGET="${ARCH}-unknown-freebsd" ;;
    *) echo "❌ 不支持的系统: $OS"; exit 1 ;;
  esac

  STARSHIP_REPO="starship/starship"
  API_URL="${GITHUB_PROXY:-}https://api.github.com/repos/$STARSHIP_REPO/releases/latest"

  LATEST_TAG=$(curl -sSL "$API_URL" | grep -oP '"tag_name":\s*"\K(.*?)(?=")')
  if [ -z "$LATEST_TAG" ]; then
      echo "❌ 获取 Starship 最新版本失败，请检查网络或代理"
      exit 1
  fi
  echo "最新 Starship 版本: $LATEST_TAG"

  # 去掉 v 前缀
  LATEST_TAG_CLEAN=${LATEST_TAG#v}

  # 检测本地版本（只取第一行第二列）
  LOCAL_VERSION=""
  if command -v starship >/dev/null 2>&1; then
      LOCAL_VERSION=$(starship --version | head -n1 | awk '{print $2}')
      echo "本地 Starship 版本: $LOCAL_VERSION"
  fi

  if [[ "$LOCAL_VERSION" == "$LATEST_TAG_CLEAN" ]]; then
      echo "✅ 本地已是最新版本，无需更新"
      return
  fi

  echo "📥 下载并安装 Starship..."
  TAR_NAME="starship-${TARGET}.tar.gz"
  DOWNLOAD_URL="https://github.com/starship/starship/releases/download/${LATEST_TAG}/${TAR_NAME}"
  DOWNLOAD_URL="${GITHUB_PROXY:-}${DOWNLOAD_URL}"

  TMPDIR=/tmp/starship_tmp
  rm -rf "$TMPDIR"
  mkdir -p "$TMPDIR"
  curl -L "$DOWNLOAD_URL" -o /tmp/$TAR_NAME
  tar -xzf /tmp/$TAR_NAME -C "$TMPDIR"

  BIN_FILE=$(find "$TMPDIR" -type f -name starship | head -n1)
  if [ -z "$BIN_FILE" ]; then
    echo "❌ 未找到 starship 可执行文件"
    exit 1
  fi

  sudo mv "$BIN_FILE" /usr/local/bin/starship
  sudo chmod +x /usr/local/bin/starship
  rm -rf "$TMPDIR"
  rm -f /tmp/$TAR_NAME

  echo "✅ Starship 安装/更新完成"
}

if ! command -v starship >/dev/null 2>&1 || $UPDATE_MODE; then
  install_starship
else
  echo "✅ Starship 已安装"
fi

if ! grep -q 'eval "$(starship init zsh)"' "$ZSHRC"; then
    echo 'eval "$(starship init zsh)"' >> "$ZSHRC"
fi

# ---------------------------
# 生成 Starship 配置
# ---------------------------
mkdir -p "$HOME/.config"
echo "🎨 生成 Starship 配置 gruvbox-rainbow..."
starship preset gruvbox-rainbow -o ~/.config/starship.toml || true
