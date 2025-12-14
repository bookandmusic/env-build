FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai INSTALL_DOCKER=true CONFIG_USER=true INSTALL_CODE_SERVER=false WSL_CONFIG=true
SHELL ["/bin/bash", "-c"]

# 层1: 所有 root 操作 + 设置脚本权限
COPY scripts/ /tmp/scripts/
RUN find /tmp/scripts -type f -name "*.sh" -exec chmod +x {} \; && \
    /tmp/scripts/orchestration/root-setup.sh && \
    chown -R ubuntu:ubuntu /tmp/scripts

# 层2: 用户级操作 + 清理脚本
USER ubuntu
WORKDIR /home/ubuntu
SHELL ["/bin/zsh", "-lc"]
RUN /tmp/scripts/orchestration/user-setup.sh && \
    rm -rf /tmp/scripts

# 暴露SSH端口
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
