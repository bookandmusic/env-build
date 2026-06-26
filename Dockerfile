# ============ 基础阶段 ============
FROM ubuntu:24.04 AS base

LABEL org.opencontainers.image.source="https://github.com/bookandmusic/env-build"
LABEL org.opencontainers.image.description="Ubuntu 24.04 development environment"

# 构建时代理（不传则无代理，直接连接）
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ENV HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    ALL_PROXY=${ALL_PROXY} \
    http_proxy=${HTTP_PROXY} \
    https_proxy=${HTTPS_PROXY} \
    all_proxy=${ALL_PROXY}

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

SHELL ["/bin/bash", "-c"]

COPY --chmod=755 setup.sh /tmp/setup.sh

# ============ ubuntu-dev 变体 ============
FROM base AS ubuntu-dev

ENV IMAGE_VARIANT=ubuntu-dev

COPY opencode.init /tmp/opencode.init
RUN /tmp/setup.sh

USER ubuntu
WORKDIR /home/ubuntu
RUN ["/bin/bash", "/tmp/setup.sh"]

USER root
RUN mkdir -p /run/sshd && ssh-keygen -A && rm -f /tmp/setup.sh /tmp/opencode.init

EXPOSE 22
HEALTHCHECK --interval=30s --timeout=3s \
    CMD ss -tln | grep -q ':22 ' || exit 1
CMD ["/usr/sbin/sshd", "-D"]

# ============ ubuntu-wsl 变体 ============
FROM base AS ubuntu-wsl

ENV IMAGE_VARIANT=ubuntu-wsl

COPY opencode.service /tmp/opencode.service
RUN /tmp/setup.sh

USER ubuntu
WORKDIR /home/ubuntu
RUN ["/bin/bash", "/tmp/setup.sh"]

USER root
RUN mkdir -p /run/sshd && ssh-keygen -A && rm -f /tmp/setup.sh /tmp/opencode.service
WORKDIR /root
EXPOSE 22
HEALTHCHECK --interval=30s --timeout=3s \
    CMD ss -tln | grep -q ':22 ' || exit 1
ENTRYPOINT ["/sbin/init"]
