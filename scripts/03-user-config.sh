#!/bin/bash
set -e

source /tmp/scripts/common.sh

log "Configuring user environment..."

# 创建用户和权限
echo "ubuntu:1" | chpasswd
usermod -aG sudo ubuntu
chsh -s "$(which zsh)" ubuntu

echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
chmod 440 /etc/sudoers.d/ubuntu

# WSL 配置
mkdir -p /etc
cat > /etc/wsl.conf << EOF
[boot]
systemd=true
[user]
default=ubuntu
EOF

log "Installing chsrc..."
curl https://chsrc.run/posix | bash -s -- -d /usr/local/bin
log "The chsrc installed successfully"

log "Installing starship..."
curl -sS https://starship.rs/install.sh | sh -s -- -y -b /usr/local/bin
log "Starship installed successfully"


log "User configuration completed"