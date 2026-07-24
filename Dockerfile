# ============ 基础阶段 ============
FROM ubuntu:24.04 AS base

LABEL org.opencontainers.image.source="https://github.com/bookandmusic/env-build"
LABEL org.opencontainers.image.description="Ubuntu 24.04 development environment with Node/Python/Go/Rust/Android toolchain"

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

# 复制脚本（利用层缓存：脚本不变则不重建）
COPY --chmod=755 scripts/ /tmp/scripts/

# ============ Root 阶段 ============
# 系统依赖 → 用户创建 → Docker CLI → 额外工具 → 服务脚本
RUN /tmp/scripts/setup.sh

# ============ User 阶段 ============
USER ubuntu
WORKDIR /home/ubuntu

# Shell 环境 → 工具链（mise/rust/android）
RUN ["/bin/bash", "/tmp/scripts/setup.sh"]

# ============ AI 工具（只放文件，不安装） ============
COPY --chown=ubuntu:ubuntu --chmod=755 ai-tools/ai-tools /home/ubuntu/.local/bin/ai-tools
COPY --chown=ubuntu:ubuntu ai-tools/ai-tools.yaml /home/ubuntu/.config/ai-tools/ai-tools.yaml

# ============ 收尾 ============
USER root
RUN rm -rf /tmp/scripts \
    && mkdir -p /run/sshd

EXPOSE 22 3001 4096

HEALTHCHECK --interval=30s --timeout=3s \
    CMD ss -tln | grep -q ':22 ' || exit 1

CMD ["/usr/sbin/sshd", "-D"]
