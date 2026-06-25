# opencode 服务容器生命周期解耦设计

## 问题

opencode 自更新后重启，导致容器退出。根因：`start.sh` 作为容器主进程（PID 1），内部通过 `kill -0` 轮询监控 opencode 的固定 PID。opencode 自更新重启时 PID 变化 → 监控判定进程死亡 → `exit 1` → 容器退出。

本质问题：opencode 服务的生命周期与容器生命周期不当耦合。

## 目标

- opencode 自更新重启时容器保持运行
- opencode 崩溃时自动恢复
- 容器作为稳定开发环境独立存在

## 方案：引入 supervisord 作为容器主进程（仅 ubuntu-dev）

supervisord 替代 `start.sh` 成为 ubuntu-dev 容器 PID 1，管理 sshd 和 opencode 两个子程序，均配置 `autorestart=true`。

### 两变体对比

| 组件 | ubuntu-dev | ubuntu-wsl |
|------|-----------|-----------|
| opencode 管理 | supervisord | systemd + init script |
| supervisor 包 | 安装 | 不安装 |
| supervisord 配置 | 写入 | 不写入 |
| start-opencode.sh | 写入 | 不写入 |
| opencode.init | 不安装 | 安装到 /etc/init.d/ |
| start.sh (容器入口) | 移除，CMD 改为 supervisord | 不变 (ENTRYPOINT /sbin/init) |

### 架构变化（ubuntu-dev）

```
之前：容器 CMD → start.sh → sudo service opencode start (SysV init)
之后：容器 CMD → supervisord ─┬─ sshd -D
                              └─ opencode serve (exec)
```

### 自愈机制

- opencode 自更新时若 exec 自身（PID 不变）→ supervisord 无感知，正常
- opencode 自更新时若退出旧进程起新进程 → supervisord 检测退出，`autorestart=true` 自动拉起
- opencode 异常崩溃 → supervisord 自动拉起
- opencode 反复崩溃 → supervisord 指数退避重试，容器不退
- 容器仅 `docker stop` 时退出

---

## 文件改动

### 1. `setup.sh` (root 阶段)

三处条件判断，按 `IMAGE_VARIANT` 分支：

```bash
# ═══ supervisor (仅 ubuntu-dev) ═══
if [ "$IMAGE_VARIANT" = "ubuntu-dev" ]; then
    # 安装 supervisor
    install_apt_packages supervisor

    # 写入 supervisord 程序配置
    cat > /etc/supervisor/conf.d/opencode.conf << 'SUPERVISOR_EOF'
[program:sshd]
command=/usr/sbin/sshd -D
autorestart=true
stdout_logfile=/var/log/sshd.log

[program:opencode]
command=/usr/local/bin/start-opencode.sh
user=ubuntu
autorestart=true
stdout_logfile=/var/log/opencode.log
redirect_stderr=true
stopasgroup=true
stopsignal=TERM
SUPERVISOR_EOF

    # 写入 opencode 启动包装脚本
    cat > /usr/local/bin/start-opencode.sh << 'START_EOF'
#!/bin/bash
export HOME=/home/ubuntu
eval "$(/home/ubuntu/.local/bin/mise activate bash)"
exec opencode serve --hostname 0.0.0.0 --port ${OPENCODE_PORT:-4096}
START_EOF
    chmod +x /usr/local/bin/start-opencode.sh

# ═══ SysV init (仅 ubuntu-wsl) ═══
elif [ "$IMAGE_VARIANT" = "ubuntu-wsl" ]; then
    [ -f /tmp/opencode.init ] || error "opencode.init not found at /tmp/opencode.init"
    cp /tmp/opencode.init /etc/init.d/opencode
    chmod +x /etc/init.d/opencode
    update-rc.d opencode defaults
fi
```

关键点：
- `sshd -D`：前台模式
- `stopasgroup=true`：停止时向进程组发信号
- `exec opencode serve`：确保 opencode 是 supervisord 直接子进程

### 2. `Dockerfile`

仅 ubuntu-dev 的 CMD 行改动：

```dockerfile
# ubuntu-dev 变体
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
```

base 阶段的 `COPY start.sh`、`COPY opencode.init` 以及 ubuntu-dev 的 `sudo cp /tmp/start.sh ...` 行全部**保留不动**——setup.sh 的 IMAGE_VARIANT 条件判断负责决定是否使用。

`-n`：前台运行（nodamon），作为容器 PID 1。

### 3. `start.sh`（保留在仓库，docker 不再使用）

仓库中保留文件，ubuntu-dev 的 CMD 不再调用它，WSL 场景不受影响。

---

## 错误处理

| 场景 | 行为 |
|------|------|
| opencode 自更新重启（exec 自身） | PID 不变，supervisord 无感知 |
| opencode 自更新重启（新进程） | supervisord 检测退出，autorestart 拉起 |
| opencode 异常崩溃 | supervisord 检测退出，autorestart 拉起 |
| opencode 反复崩溃 | supervisord 指数退避重试，不退出容器 |
| sshd 崩溃 | supervisord 自动拉起 |
| 容器 `docker stop` | supervisord 收 SIGTERM，优雅停止子程序后退出 |

---

## 验证方法

1. `docker build --target ubuntu-dev -t ubuntu-dev:test .`
2. `docker run -d --name test-container ubuntu-dev:test`
3. `docker exec test-container supervisorctl status` → opencode + sshd RUNNING
4. `docker exec test-container supervisorctl restart opencode`
5. `docker ps | grep test-container` → 容器仍在运行
6. `docker exec test-container tail /var/log/opencode.log`
