#!/bin/bash

# 默认参数
NETWORK_NAME="localNetwork"
NETWORK_DRIVER="bridge"
SUBNET="172.25.0.0/16"  # 默认子网，可修改

# 解析命令行参数（可选覆盖默认值）
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            NETWORK_NAME="$2"
            shift 2
            ;;
        -d|--driver)
            NETWORK_DRIVER="$2"
            shift 2
            ;;
        -s|--subnet)
            SUBNET="$2"
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            echo "用法: $0 [-n network_name] [-d driver] [-s subnet]"
            exit 1
            ;;
    esac
done

# 检查网络是否存在
if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "Docker 网络 '$NETWORK_NAME' 已存在"
else
    echo "Docker 网络 '$NETWORK_NAME' 不存在，正在创建..."
    docker network create --driver "$NETWORK_DRIVER" --subnet "$SUBNET" "$NETWORK_NAME"
    if [ $? -eq 0 ]; then
        echo "Docker 网络 '$NETWORK_NAME' 创建成功，子网为 $SUBNET"
    else
        echo "Docker 网络 '$NETWORK_NAME' 创建失败"
        exit 1
    fi
fi
