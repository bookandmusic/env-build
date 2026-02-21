# ============ 基础阶段 ============
FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    CONFIG_USER=true

SHELL ["/bin/bash", "-c"]

COPY scripts/ /tmp/scripts/
RUN find /tmp/scripts -type f -name "*.sh" -exec chmod +x {} \; && \
    cp /tmp/scripts/configs/start-services.sh /usr/local/bin/ && \
    chmod +x /usr/local/bin/start-services.sh

# ============ code-server 变体 ============
FROM base AS code-server

ENV IMAGE_VARIANT=code-server \
    DOCKER_MODE=cli-only \
    INSTALL_CODE_SERVER=true \
    WSL_CONFIG=false

RUN /tmp/scripts/orchestration/root-setup.sh && \
    chown -R ubuntu:ubuntu /tmp/scripts

USER ubuntu
WORKDIR /home/ubuntu
SHELL ["/bin/zsh", "-lc"]

RUN /tmp/scripts/orchestration/user-setup.sh && \
    rm -rf /tmp/scripts

EXPOSE 22 8080
ENTRYPOINT ["/usr/local/bin/start-services.sh"]
CMD ["sleep", "infinity"]

# ============ ubuntu-dev 变体 ============
FROM base AS ubuntu-dev

ENV IMAGE_VARIANT=ubuntu-dev \
    DOCKER_MODE=cli-only \
    INSTALL_CODE_SERVER=false \
    WSL_CONFIG=false

RUN /tmp/scripts/orchestration/root-setup.sh && \
    chown -R ubuntu:ubuntu /tmp/scripts

USER ubuntu
WORKDIR /home/ubuntu
SHELL ["/bin/zsh", "-lc"]

RUN /tmp/scripts/orchestration/user-setup.sh && \
    rm -rf /tmp/scripts

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/start-services.sh"]
CMD ["sleep", "infinity"]

# ============ ubuntu-wsl 变体 ============
FROM base AS ubuntu-wsl

ENV IMAGE_VARIANT=ubuntu-wsl \
    DOCKER_MODE=full \
    INSTALL_CODE_SERVER=false \
    WSL_CONFIG=true

RUN /tmp/scripts/orchestration/root-setup.sh && \
    chown -R ubuntu:ubuntu /tmp/scripts

USER ubuntu
WORKDIR /home/ubuntu
SHELL ["/bin/zsh", "-lc"]

RUN /tmp/scripts/orchestration/user-setup.sh && \
    rm -rf /tmp/scripts

USER root
WORKDIR /root
EXPOSE 22
ENTRYPOINT ["/sbin/init"]
CMD []
