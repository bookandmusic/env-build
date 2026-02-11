FROM ubuntu:24.04

ARG INSTALL_CODE_SERVER=false
ARG WSL_CONFIG=false

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    INSTALL_DOCKER=false \
    CONFIG_USER=true \
    WSL_CONFIG=${WSL_CONFIG} \
    INSTALL_CODE_SERVER=${INSTALL_CODE_SERVER}

SHELL ["/bin/bash", "-c"]

COPY scripts/ /tmp/scripts/
RUN find /tmp/scripts -type f -name "*.sh" -exec chmod +x {} \; && \
    cp /tmp/scripts/configs/start-services.sh /usr/local/bin/ && \
    chmod +x /usr/local/bin/start-services.sh && \
    /tmp/scripts/orchestration/root-setup.sh && \
    chown -R ubuntu:ubuntu /tmp/scripts

USER ubuntu
WORKDIR /home/ubuntu
SHELL ["/bin/zsh", "-lc"]
RUN /tmp/scripts/orchestration/user-setup.sh && \
    rm -rf /tmp/scripts

EXPOSE 22 8080
ENTRYPOINT ["/usr/local/bin/start-services.sh"]
CMD ["sleep", "infinity"]
