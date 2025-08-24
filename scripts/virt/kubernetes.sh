#!/bin/bash
set -euo pipefail

K8S_VERSION="${K8S_VERSION:-1.29.7}"
IMAGE_REPO="${IMAGE_REPO:-registry.aliyuncs.com/google_containers}"

echo "🔧 安装 Kubernetes $K8S_VERSION..."

# 镜像源
curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.29/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.29/deb/ /" | \
    tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y cri-tools kubernetes-cni kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF

rm -f /etc/cni/net.d/*.conf*
systemctl enable --now kubelet

# 拉取镜像并初始化集群
kubeadm config images pull --cri-socket=unix:///run/containerd/containerd.sock \
    --image-repository="${IMAGE_REPO}" --kubernetes-version="${K8S_VERSION}"

cat > /root/kubeadm-config.yaml <<EOF
kind: InitConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
---
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
imageRepository: ${IMAGE_REPO}
kubernetesVersion: ${K8S_VERSION}
apiServer:
  certSANs:
  - "127.0.0.1"
networking:
  podSubnet: "10.244.0.0/16"
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
EOF

kubeadm init --config /root/kubeadm-config.yaml

# 安装 Flannel 网络插件
kubectl apply -f https://mirror.ghproxy.com/https://raw.githubusercontent.com/flannel-io/flannel/v0.25.5/Documentation/kustomization/kube-flannel/kube-flannel.yml
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p ${HOME:-/root}/.kube
cp -f $KUBECONFIG ${HOME:-/root}/.kube/config

echo "✅ Kubernetes 安装完成"
