# Ubuntu Development Environment Builder

[中文版本](README.md) | [Docker Image Building Guide](doc/Docker.md)

This project provides a set of automation scripts to build standardized Ubuntu development environments. It supports Docker containers, WSL2, and physical machines/virtual machines, with flexible configuration for various development toolchains.

## Main Features

- System base dependencies installation (development tools, network tools, etc.)
- Docker environment configuration (optional)
- User environment configuration (Zsh, Oh My Zsh, vimrc, etc.)
- Code-Server online IDE support (optional)
- WSL2 environment optimization configuration (optional)

## Environment Variables

| Variable | Default | Description |
|----------|--------|------|
| `INSTALL_DOCKER` | `false` | Install Docker when set to `true` |
| `CONFIG_USER` | `false` | Create ubuntu user and set password & sudo permissions |
| `WSL_CONFIG` | `false` | Configure WSL2 specific settings (systemd support) |
| `INSTALL_CODE_SERVER` | `false` | Install Code-Server online IDE |

## Usage 1: Execute Scripts Separately

Applicable for configuring development environment on existing Ubuntu systems:

```bash
# 1. Run system-level setup as root
cd scripts/orchestration
sudo ./root-setup.sh

# 2. Switch to ubuntu user and run user-level setup
su - ubuntu
cd ~/projects/env-build/scripts/orchestration
./user-setup.sh
```

> Note: Set environment variables before execution, for example:
> ```bash
> export CONFIG_USER=true
> export WSL_CONFIG=true
> ```

## Usage 2: Use Pre-built Images

Start pre-built development environment containers:

```bash
# Start basic development environment
docker run -d -p 22:22 --name ubuntu-dev bookandmusic/ubuntu-dev:latest

# Start environment with Code-Server (port 8080)
docker run -d -p 22:22 -p 8080:8080 --name coder-server bookandmusic/coder-server:latest
```