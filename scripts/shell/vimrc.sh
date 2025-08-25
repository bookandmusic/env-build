# ---------------------------
# 安装 vimrc
# ---------------------------
VIM_DIR="$HOME/.vim_runtime"
REPO_URL="https://github.com/amix/vimrc.git"

# 如果目录存在
if [ -d "$VIM_DIR" ]; then
    # 检查是否是合法 git 仓库
    if git -C "$VIM_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "🔄 目录 $VIM_DIR 是合法 git 仓库，执行更新..."
        git -C "$VIM_DIR" pull --ff-only
    else
        echo "⚠️ 目录 $VIM_DIR 不是合法 git 仓库，删除并重新克隆"
        rm -rf "$VIM_DIR"
        echo "⬇️ 克隆 vimrc 仓库..."
        git clone --depth=1 "$REPO_URL" "$VIM_DIR"
    fi
else
    echo "⬇️ 克隆 vimrc 仓库..."
    git clone --depth=1 "$REPO_URL" "$VIM_DIR"
fi

# 安装 vimrc
sh "$VIM_DIR/install_basic_vimrc.sh"
echo "✅ vimrc 安装完成"
