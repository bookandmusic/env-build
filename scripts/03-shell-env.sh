#!/bin/bash
# Shell 环境配置（ubuntu 用户执行）

setup_oh_my_zsh() {
    log "Installing Oh My Zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi

    # 插件
    local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
    safe_git_clone "https://github.com/zsh-users/zsh-autosuggestions.git" "$plugins_dir/zsh-autosuggestions"
    safe_git_clone "https://github.com/zsh-users/zsh-syntax-highlighting.git" "$plugins_dir/zsh-syntax-highlighting"
    safe_git_clone "https://github.com/zsh-users/zsh-completions.git" "$plugins_dir/zsh-completions"

    # .zshrc
    create_config_file "$HOME/.zshrc" \
'export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git sudo z zsh-autosuggestions zsh-syntax-highlighting zsh-completions python golang starship)
source $ZSH/oh-my-zsh.sh'
}

setup_starship() {
    log "Installing starship..."
    check_command "curl"
    check_command "jq"

    local starship_arch asset_url
    case "$(uname -m)" in
        x86_64|amd64)   starship_arch="x86_64-unknown-linux-musl" ;;
        aarch64|arm64)   starship_arch="aarch64-unknown-linux-musl" ;;
        *)               error "Unsupported architecture for starship: $(uname -m)" ;;
    esac

    asset_url=$(curl -fsSL https://api.github.com/repos/starship/starship/releases/latest \
        | jq -r ".assets[].browser_download_url | select(endswith(\"${starship_arch}.tar.gz\"))") || \
        error "Failed to fetch starship release info"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    curl -fsSL "$asset_url" | tar xz -C "$tmp_dir"
    mv "$tmp_dir/starship" "$HOME/.local/bin/starship"
    chmod +x "$HOME/.local/bin/starship"
    rm -rf "$tmp_dir"

    mkdir -p "$HOME/.config"
    starship preset plain-text-symbols -o "$HOME/.config/starship.toml"
    add_to_zshrc 'eval "$(starship init zsh)"'
}

setup_vim() {
    log "Setting up vim config..."
    local vimrc_src="${SCRIPT_DIR}/configs/vimrc"
    if [ -f "$vimrc_src" ]; then
        cp "$vimrc_src" "$HOME/.vimrc"
    else
        warn "vimrc config not found at $vimrc_src, skipping"
    fi
}

setup_oh_my_zsh
setup_starship
setup_vim

log "Shell environment setup completed"
