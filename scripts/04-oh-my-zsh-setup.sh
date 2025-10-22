#!/bin/bash
set -e

source /tmp/scripts/common.sh

log "Setting up Oh My Zsh and plugins..."

# 克隆 Oh My Zsh
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"

# 创建插件目录
mkdir -p "$HOME/.oh-my-zsh/custom/plugins"

# 安装插件
plugins=(
    "zsh-users/zsh-autosuggestions"
    "zsh-users/zsh-syntax-highlighting"
    "zsh-users/zsh-completions"
)

for plugin in "${plugins[@]}"; do
    name=$(basename "$plugin")
    git clone --depth=1 "https://github.com/${plugin}" "$HOME/.oh-my-zsh/custom/plugins/${name}"
done

# 配置 .zshrc
cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"

# 更新主题和插件
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' "$HOME/.zshrc"
sed -i 's/plugins=(git)/plugins=(git sudo z zsh-autosuggestions zsh-syntax-highlighting zsh-completions python golang starship)/g' "$HOME/.zshrc"

mkdir -p ~/.config
starship preset plain-text-symbols -o ~/.config/starship.toml

log "Oh My Zsh setup completed"