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

echo "🔄 更新 apt 软件源..."
$SUDO apt-get update -y

echo "🔧 安装必备软件..."
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if command -v "$pkg" >/dev/null 2>&1; then
        echo "✅ $pkg 已安装"
    else
        echo "⬇️ 安装 $pkg ..."
        $SUDO apt-get install -y "$pkg"
    fi
done

echo "🧹 清理 apt 缓存..."
$SUDO rm -rf /var/lib/apt/lists/* /var/cache/apt/archives
