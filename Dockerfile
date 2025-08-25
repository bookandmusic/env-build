# Ubuntu 24.04 LTS
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV container=docker

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus dbus-user-session \
      openssh-server sudo vim less curl ca-certificates locales tzdata \
      iproute2 iptables fuse-overlayfs iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# locale
RUN sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# journald dirs
RUN mkdir -p /var/log/journal /run/systemd && chmod 0755 /var/log/journal

# SSH config（启用密码登录并修改端口）
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#Port 22/Port 12121/' /etc/ssh/sshd_config && \
    sed -i 's/#\?PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config && \
    sed -i 's/#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config || true

# 创建/修正用户和密码（存在时也会设密码并解锁）
ARG USERNAME=ubuntu
ARG UID=1000
ARG GID=1000
RUN set -eux; \
    # 组：若同名组不存在则创建；存在则复用
    if ! getent group "${USERNAME}" >/dev/null; then \
        groupadd -g "${GID}" "${USERNAME}" || groupadd "${USERNAME}"; \
    fi; \
    # 用户：若不存在则按 UID/GID 创建；存在则确保 shell、home 正常
    if ! id -u "${USERNAME}" >/dev/null 2>&1; then \
        useradd -m -u "${UID}" -g "${USERNAME}" -s /bin/bash "${USERNAME}"; \
    else \
        usermod -s /bin/bash "${USERNAME}"; \
        mkdir -p "/home/${USERNAME}"; \
        chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"; \
    fi; \
    # 加 sudo 组
    usermod -aG sudo "${USERNAME}"; \
    # 设置并解锁密码（存在与否都执行）
    echo "${USERNAME}:ubuntu" | chpasswd; \
    passwd -u "${USERNAME}" || true; \
    echo "root:root" | chpasswd; \
    passwd -u root || true

# wsl.conf（导入 WSL 后直接启用 systemd，并默认用户为 ubuntu）
RUN printf '%s\n' \
  '[boot]' \
  'systemd=true' \
  '' \
  '[user]' \
  'default=ubuntu' \
  > /etc/wsl.conf

# 设定默认目标并启用 ssh 服务（构建期仅写链接，不需要 PID1）
RUN systemctl set-default multi-user.target && \
    systemctl enable ssh

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]