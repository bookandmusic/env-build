#!/bin/bash
# 开发工具链安装（ubuntu 用户执行）
# mise（Node/Python/Go）+ rustup（Rust）+ Android SDK

setup_mise() {
    log "Installing mise..."
    mkdir -p "$HOME/.local/bin"

    local mise_script
    mise_script=$(curl -fsSL https://mise.run) || error "Failed to download mise installer"
    echo "$mise_script" | MISE_INSTALL_PATH="$HOME/.local/bin/mise" sh || error "Failed to install mise"

    add_to_zshrc 'export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"'
    add_to_zshrc 'eval "$($HOME/.local/bin/mise activate zsh)"'
    export PATH="$HOME/.local/bin:$PATH"
}

setup_languages() {
    log "Installing language toolchains via mise..."
    "$HOME/.local/bin/mise" settings set experimental true

    local tools=("python@3.13" "go@1.25" "node@24" "uv")
    for tool in "${tools[@]}"; do
        log "Installing $tool..."
        "$HOME/.local/bin/mise" use -g "$tool" || warn "Failed to install $tool, continuing..."
    done

    eval "$($HOME/.local/bin/mise activate bash)"

    # Go 工具
    log "Installing Go tools..."
    go install -v golang.org/x/tools/gopls@latest || warn "Failed to install gopls"
    go install -v github.com/go-delve/delve/cmd/dlv@latest || warn "Failed to install dlv"
}

setup_rust() {
    log "Installing Rust via rustup..."
    if command -v rustup &>/dev/null; then
        log "rustup already installed, updating..."
        rustup update stable
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    fi

    source "$HOME/.cargo/env"
    add_to_zshrc 'source "$HOME/.cargo/env"'

    # Android 交叉编译 targets
    log "Adding Android Rust targets..."
    rustup target add \
        aarch64-linux-android \
        armv7-linux-androideabi \
        x86_64-linux-android \
        i686-linux-android
}

setup_android_sdk() {
    log "Installing Android SDK..."

    # JDK 17（需要 root，通过 sudo）
    if ! command -v java &>/dev/null; then
        log "Installing JDK 17..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq --no-install-recommends openjdk-17-jdk-headless
        sudo rm -rf /var/lib/apt/lists/*
    fi

    export ANDROID_HOME="$HOME/Android/Sdk"
    mkdir -p "$ANDROID_HOME"

    # 下载 commandline-tools（使用固定已知版本 URL，避免网页解析）
    local cmdline_tools_dir="$ANDROID_HOME/cmdline-tools"
    if [ ! -d "$cmdline_tools_dir/latest" ]; then
        log "Downloading Android commandline-tools..."
        # 固定版本号，定期更新
        local cmdline_version="11076708"
        local url="https://dl.google.com/android/repository/commandlinetools-linux-${cmdline_version}_latest.zip"

        local tmp_zip="/tmp/cmdline-tools.zip"
        curl -fsSL "$url" -o "$tmp_zip" || error "Failed to download commandline-tools"
        mkdir -p "$cmdline_tools_dir"
        unzip -q "$tmp_zip" -d "$cmdline_tools_dir"
        mv "$cmdline_tools_dir/cmdline-tools" "$cmdline_tools_dir/latest"
        rm -f "$tmp_zip"
    fi

    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

    # 清除空代理变量（Dockerfile ENV 未传 ARG 时为空字符串，Java sdkmanager 无法解析）
    [ -z "$HTTP_PROXY" ] && unset HTTP_PROXY http_proxy
    [ -z "$HTTPS_PROXY" ] && unset HTTPS_PROXY https_proxy
    [ -z "$ALL_PROXY" ] && unset ALL_PROXY all_proxy

    # 接受 license
    log "Accepting Android SDK licenses..."
    yes | sdkmanager --licenses > /dev/null 2>&1 || true

    # 安装组件
    log "Installing Android SDK components..."
    sdkmanager --install \
        "platform-tools" \
        "platforms;android-35" \
        "build-tools;35.0.0" \
        "ndk;27.0.12077973" || error "Failed to install Android SDK components"

    # 环境变量
    add_to_zshrc 'export ANDROID_HOME="$HOME/Android/Sdk"'
    add_to_zshrc 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"'
}

setup_mise
setup_languages
setup_rust
setup_android_sdk

log "Toolchain setup completed"
