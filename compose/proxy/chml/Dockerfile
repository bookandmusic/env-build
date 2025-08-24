# 使用轻量级 Alpine 镜像
FROM alpine:3.21

# 设置工作目录
WORKDIR /app

# 创建目录结构
RUN mkdir -p /app/chmlfrp /app/config

# 下载并解压 ChmlFrp 到 /app/chmlfrp
RUN wget https://www.chmlfrp.cn/dw/ChmlFrp-0.51.2_240715_linux_amd64.tar.gz && \
    tar -xzf ChmlFrp-0.51.2_240715_linux_amd64.tar.gz && \
    mv ChmlFrp-0.51.2_240715_linux_amd64/frpc.ini /app/config/ && \
    mv ChmlFrp-0.51.2_240715_linux_amd64/frpc /app/chmlfrp/ && \
    rm ChmlFrp-0.51.2_240715_linux_amd64.tar.gz && \
    rm -rf ChmlFrp-0.51.2_240715_linux_amd64

# 暴露端口
EXPOSE 8080

# 默认启动命令，指定执行文件路径和配置文件路径
CMD ["/app/chmlfrp/frpc", "-c", "/app/config/frpc.ini"]
