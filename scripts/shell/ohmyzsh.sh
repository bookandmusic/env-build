#!/usr/bin/env bash
set -euo pipefail

OHMYZSH_DIR="$HOME/.oh-my-zsh"
ZSHRC="$HOME/.zshrc"
UPDATE_MODE=true

# ---------------------------
# 参数解析
# ---------------------------
if [[ "${1:-}" == "--no-update" ]]; then
  UPDATE_MODE=false
  echo "🔄 关闭更新模式"
fi

# ---------------------------
# GitHub 地址拼接函数
# ---------------------------
gh_url() {
  local repo="$1"
  echo "${GITHUB_PROXY:-}https://github.com/${repo}"
}

# ---------------------------
# 安装/更新 Oh My Zsh
# ---------------------------
if [ ! -d "$OHMYZSH_DIR" ]; then
  echo "📥 克隆 Oh My Zsh..."
  git clone "$(gh_url ohmyzsh/ohmyzsh).git" "$OHMYZSH_DIR"
else
  echo "✅ Oh My Zsh 已存在"
  if $UPDATE_MODE; then
    echo "🔄 更新 Oh My Zsh..."
    git -C "$OHMYZSH_DIR" pull --ff-only
  fi
fi

# 创建 zshrc
if [ ! -f "$ZSHRC" ]; then
  echo "📄 创建默认 .zshrc..."
  cp "$OHMYZSH_DIR/templates/zshrc.zsh-template" "$ZSHRC"
fi

ZSH_CUSTOM=${ZSH_CUSTOM:-$OHMYZSH_DIR/custom}

# ---------------------------
# 插件
# ---------------------------
EXTERNAL_PLUGINS=(
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-syntax-highlighting
  zsh-users/zsh-completions
)

echo "🔌 处理插件..."
for plugin in "${EXTERNAL_PLUGINS[@]}"; do
  name=$(basename "$plugin")
  if [ ! -d "$ZSH_CUSTOM/plugins/$name" ]; then
    git clone "$(gh_url "$plugin").git" "$ZSH_CUSTOM/plugins/$name"
  else
    echo "✅ 插件 $name 已存在"
    if $UPDATE_MODE; then
      echo "🔄 更新插件 $name..."
      git -C "$ZSH_CUSTOM/plugins/$name" pull --ff-only
    fi
  fi
done

ALL_PLUGINS=(git sudo z zsh-autosuggestions zsh-syntax-highlighting zsh-completions)

if grep -q "^plugins=" "$ZSHRC"; then
  sed -i.bak "s/^plugins=(.*)$/plugins=(${ALL_PLUGINS[*]})/" "$ZSHRC"
else
  echo "plugins=(${ALL_PLUGINS[*]})" >> "$ZSHRC"
fi

# ---------------------------
# 启用 zsh 并设置默认 shell
# ---------------------------
if [ "$SHELL" != "$(which zsh)" ]; then
  echo "🔧 设置 zsh 为默认 shell..."
  chsh -s "$(which zsh)"
fi

echo "🎉 安装/更新完成！请重新打开终端或运行: zsh"

