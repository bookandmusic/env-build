# ============ 基础阶段 ============
FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

SHELL ["/bin/bash", "-c"]

COPY setup.sh /tmp/setup.sh
RUN chmod +x /tmp/setup.sh

# ============ ubuntu-dev 变体 ============
FROM base AS ubuntu-dev

ENV IMAGE_VARIANT=ubuntu-dev

RUN /tmp/setup.sh

USER ubuntu
WORKDIR /home/ubuntu
RUN ["/bin/bash", "/tmp/setup.sh"]

EXPOSE 22
CMD ["sleep", "infinity"]

# ============ ubuntu-wsl 变体 ============
FROM base AS ubuntu-wsl

ENV IMAGE_VARIANT=ubuntu-wsl

RUN /tmp/setup.sh

USER ubuntu
WORKDIR /home/ubuntu
RUN ["/bin/bash", "/tmp/setup.sh"]

USER root
WORKDIR /root
EXPOSE 22
ENTRYPOINT ["/sbin/init"]
CMD []
