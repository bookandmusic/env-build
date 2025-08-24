# 使用支持 systemd 的 Ubuntu 24.04 基础镜像
FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/trfore/docker-ubuntu2404-systemd:latest

# 更新系统并安装基础软件
RUN apt-get update && \
    apt-get install -y openssh-server git curl wget tar iptables fuse-overlayfs zsh jq iputils-ping vim && \
    rm -rf /var/lib/apt/lists/*

# 设置 root 密码为 "1"
RUN echo 'root:1' | chpasswd

# 允许 root SSH 登录
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# 屏蔽问题服务 (修复 systemd 错误)
RUN systemctl mask kmod-static-nodes.service

# 启用 SSH 服务
RUN systemctl enable ssh

# 暴露 SSH 端口
EXPOSE 22

# 使用 init 作为入口点
CMD ["/sbin/init"]
