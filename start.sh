#!/bin/bash
set -eo pipefail

sudo service ssh start || true
sudo service opencode start

PIDFILE="/var/run/opencode/opencode.pid"

# 等待 PID 文件生成
for i in $(seq 1 10); do
    if [ -f "$PIDFILE" ] && [ -s "$PIDFILE" ]; then
        break
    fi
    sleep 0.5
done

# 读取并验证 PID
read_pid() {
    if [ ! -f "$PIDFILE" ] || [ ! -s "$PIDFILE" ]; then
        return 1
    fi
    local pid
    pid=$(cat "$PIDFILE")
    if [ -n "$pid" ] && [ "$pid" -eq "$pid" ] 2>/dev/null; then
        echo "$pid"
    else
        return 1
    fi
}

# 监控 opencode 进程，崩溃时容器退出
PID=$(read_pid) || { echo "opencode PID file not found or invalid" >&2; exit 1; }
tail -f /var/log/opencode.log &
while kill -0 "$PID" 2>/dev/null; do
    sleep 2
done
echo "opencode exited unexpectedly" >&2
exit 1
