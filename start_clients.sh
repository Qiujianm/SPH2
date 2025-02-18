#!/bin/bash
source /etc/hysteria/constants.sh

# 停止所有已存在的客户端进程
pkill -f "hysteria client"

# 遍历所有配置文件并启动
for config in "$CLIENT_CONFIG_DIR"/*.json; do
    if [ -f "$config" ]; then
        /usr/local/bin/hysteria client -c "$config" &
    fi
done

wait