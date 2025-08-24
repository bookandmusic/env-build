#!/bin/bash
set -euo pipefail

echo "🔧 配置 containerd..."

# 内核模块
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# 系统参数
cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

# 安装 containerd
apt-get install -y containerd

# 配置 containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's#sandbox_image = "registry.k8s.io/pause:[^"]*"#sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"#' /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 配置镜像加速器
mkdir -p /etc/containerd/certs.d/docker.io
cat > /etc/containerd/certs.d/docker.io/hosts.toml <<EOF
server = "https://docker.io"
[host."https://dockerproxy.cn"]
  capabilities = ["pull", "resolve"]
EOF

systemctl enable --now containerd
systemctl restart containerd

echo "✅ containerd 配置完成"
