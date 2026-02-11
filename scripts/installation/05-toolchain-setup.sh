#!/bin/bash
set -eo pipefail

# 标准脚本初始化
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SCRIPT_DIR/configs/common.sh"

log "Setting up development toolchain..."

# 安装 mise
check_command "curl"
curl https://mise.run | MISE_INSTALL_PATH="$HOME/.local/bin/mise" sh
add_to_zshrc 'eval "$($HOME/.local/bin/mise activate zsh)"'

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
safe_git_clone "${TSINGHUA_MIRROR}/git/homebrew/install.git" "$HOME/brew-install"
/bin/bash "$HOME/brew-install/install.sh"
rm -rf "$HOME/brew-install"

# 配置 Homebrew 环境
add_to_zshrc 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
add_to_zshrc "export HOMEBREW_PIP_INDEX_URL=\"${PYPI_MIRROR}\""
add_to_zshrc "export HOMEBREW_BOTTLE_DOMAIN=\"${BREW_BOTTLE_DOMAIN}\""

log "Homebrew setup completed"
