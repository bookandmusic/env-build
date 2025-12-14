# Docker镜像构建指南

本指南详细介绍如何使用项目中的Dockerfile构建自定义开发环境镜像。

## 构建基础Ubuntu开发镜像

```bash
# 在项目根目录执行
docker build -t ubuntu-dev:latest .
```

## 构建Code-Server开发镜像

```bash
# 使用特定的Dockerfile-coder-server
docker build -f Dockerfile-coder-server -t coder-server:latest .
```

## 自定义构建参数

可以通过`--build-arg`传递构建参数：

```bash
# 例如，指定不同的Ubuntu版本
docker build --build-arg UBUNTU_VERSION=22.04 -t ubuntu-dev:22.04 .
```

## 多阶段构建说明

本项目采用多阶段构建策略：

1. **第一阶段**：以root身份安装系统依赖和配置
2. **第二阶段**：切换到ubuntu用户安装用户级工具
3. **最终镜像**：仅包含必要组件，保持轻量化

## 环境变量在构建中的作用

| 变量 | 用途 |
|------|------|
| `INSTALL_DOCKER=true` | 在镜像中安装Docker |
| `INSTALL_CODE_SERVER=true` | 安装Code-Server在线IDE |
| `WSL_CONFIG=true` | 启用WSL2优化配置 |
| `CONFIG_USER=true` | 配置用户环境（sudo免密等） |

> 注意：这些环境变量在构建时通过ENV指令设置，影响构建过程。