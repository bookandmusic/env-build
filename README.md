# Ubuntu 开发环境构建工具

[English Version](README_en.md) | [Docker镜像构建指南](doc/Docker.md)

本项目提供了一套自动化脚本，用于构建标准化的Ubuntu开发环境。支持Docker容器、WSL2以及物理机/虚拟机环境，可灵活配置各种开发工具链。

## 主要功能

- 系统基础依赖安装（开发工具、网络工具等）
- Docker环境配置（可选）
- 用户环境配置（Zsh、Oh My Zsh、vimrc等）
- Code-Server在线IDE支持（可选）
- WSL2环境优化配置（可选）

## 环境变量说明

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `INSTALL_DOCKER` | `false` | 是否安装Docker，设为`true`时安装 |
| `CONFIG_USER` | `false` | 是否创建ubuntu用户并设置密码和sudo权限 |
| `WSL_CONFIG` | `false` | 是否配置WSL2专用设置（systemd支持） |
| `INSTALL_CODE_SERVER` | `false` | 是否安装Code-Server在线IDE |

## 用法1：单独执行脚本

适用于在现有Ubuntu系统上配置开发环境：

```bash
# 1. 以root身份执行系统级配置
cd scripts/orchestration
sudo ./root-setup.sh

# 2. 切换到ubuntu用户执行用户级配置
su - ubuntu
cd ~/projects/env-build/scripts/orchestration
./user-setup.sh
```

> 注意：执行前请根据需要设置环境变量，例如：
> ```bash
> export CONFIG_USER=true
> export WSL_CONFIG=true
> ```

## 用法2：使用构建好的镜像

启动预构建的开发环境容器：

```bash
# 启动基础开发环境
docker run -d -p 22:22 --name ubuntu-dev bookandmusic/ubuntu-dev:latest

# 启动带Code-Server的环境（端口8080）
docker run -d -p 22:22 -p 8080:8080 --name coder-server bookandmusic/coder-server:latest
```

## 更多文档

- [Docker镜像构建指南](doc/Docker.md)