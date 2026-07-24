#!/bin/bash
# 服务脚本安装（root 执行）
# opencode / cloudcli 均以 ubuntu 用户启动，保证和终端同一份配置

install_services() {
    log "Installing service scripts..."

    local services_dir="${SCRIPT_DIR}/services"

    # opencode 服务
    if [ -f "$services_dir/opencode.init" ]; then
        cp "$services_dir/opencode.init" /etc/init.d/opencode
        chmod 755 /etc/init.d/opencode
        update-rc.d opencode defaults 2>/dev/null || true
        log "opencode service installed"
    fi

    # cloudcli 服务
    if [ -f "$services_dir/cloudcli.init" ]; then
        cp "$services_dir/cloudcli.init" /etc/init.d/cloudcli
        chmod 755 /etc/init.d/cloudcli
        update-rc.d cloudcli defaults 2>/dev/null || true
        log "cloudcli service installed"
    fi

    # SSH 服务准备
    mkdir -p /run/sshd
    ssh-keygen -A
    log "SSH host keys generated"
}

install_services
