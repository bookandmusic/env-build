FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
SHELL ["/bin/bash", "-c"]

# 层1: 所有 root 操作 + 设置脚本权限
COPY scripts/ /tmp/scripts/
RUN chmod +x /tmp/scripts/*.sh && \
    /tmp/scripts/root-setup.sh && \
    chown -R ubuntu:ubuntu /tmp/scripts

# 层2: 用户级操作 + 清理脚本
USER ubuntu  
WORKDIR /home/ubuntu
SHELL ["/bin/zsh", "-lc"]
RUN /tmp/scripts/user-setup.sh && \
    rm -rf /tmp/scripts

CMD ["zsh"]