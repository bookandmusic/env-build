#!/bin/bash
# 启动SSH服务
service ssh start
# 执行主命令
exec "$@"