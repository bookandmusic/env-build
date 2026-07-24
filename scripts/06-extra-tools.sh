#!/bin/bash
# 额外工具安装（root 执行）

install_chsrc() {
    log "Installing chsrc..."
    check_command "curl"

    local script
    script=$(curl -fsSL https://chsrc.run/posix) || error "Failed to download chsrc installer"
    [ -n "$script" ] || error "Empty response from chsrc.run"
    echo "$script" | bash -s -- -d /usr/local/bin || error "Failed to install chsrc"
    [ -x /usr/local/bin/chsrc ] || error "chsrc binary not found after installation"
}

install_chsrc
