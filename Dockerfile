# ============ 基础阶段 ============
FROM ubuntu:24.04 AS base

LABEL org.opencontainers.image.source="https://github.com/bookandmusic/env-build"
LABEL org.opencontainers.image.description="Ubuntu 24.04 development environment"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

SHELL ["/bin/bash", "-c"]

COPY setup.sh /tmp/setup.sh
RUN chmod +x /tmp/setup.sh

# ============ ubuntu-dev 变体 ============
FROM base AS ubuntu-dev

ENV IMAGE_VARIANT=ubuntu-dev

COPY opencode.init /tmp/opencode.init
RUN /tmp/setup.sh

USER ubuntu
WORKDIR /home/ubuntu
RUN ["/bin/bash", "/tmp/setup.sh"]

USER root
RUN mkdir -p /run/sshd && ssh-keygen -A

EXPOSE 22
HEALTHCHECK --interval=30s --timeout=3s \
    CMD pgrep -x sshd > /dev/null || exit 1
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
WORKDIR /root
EXPOSE 22
HEALTHCHECK --interval=30s --timeout=3s \
    CMD systemctl is-active sshd >/dev/null 2>&1 || exit 1
ENTRYPOINT ["/sbin/init"]
CMD []
