#!/bin/bash
set -e

source /tmp/scripts/common.sh

log "Setting up development toolchain..."

# 安装 mise
curl https://mise.run | MISE_INSTALL_PATH="$HOME/.local/bin/mise" sh
echo 'eval "$($HOME/.local/bin/mise activate zsh)"' >> "$HOME/.zshrc"

# 激活 mise 环境
eval "$($HOME/.local/bin/mise activate zsh)"

# 配置 mise
mise settings experimental=true

# 安装工具
mise use -g bat eza uv duf fd fzf gdu lazydocker lazygit ripgrep poetry \
    python@3.13 go@1.25 node@24 pipx btop

# Go 工具
mise use -g \
    go:github.com/incu6us/goimports-reviser/v3@latest \
    go:mvdan.cc/gofumpt@latest \
    go:github.com/securego/gosec/v2/cmd/gosec@latest \
    go:github.com/fzipp/gocyclo/cmd/gocyclo@latest

# pipx 工具
mise use -g pipx:glances pipx:httpie pipx:ipython pipx:litecli pipx:mycli pipx:tldr

log "Toolchain setup completed"

log "Setting up Homebrew..."
# 安装 Homebrew
git clone --depth=1 "${TSINGHUA_MIRROR}/git/homebrew/install.git" "$HOME/brew-install"
/bin/bash "$HOME/brew-install/install.sh"
rm -rf "$HOME/brew-install"

# 配置 Homebrew 环境
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.zshrc"
echo "export HOMEBREW_PIP_INDEX_URL=\"${PYPI_MIRROR}\"" >> "$HOME/.zshrc"
echo "export HOMEBREW_BOTTLE_DOMAIN=\"${BREW_BOTTLE_DOMAIN}\"" >> "$HOME/.zshrc"

log "Homebrew setup completed"
