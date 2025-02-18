#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 目录定义
HYSTERIA_ROOT="/etc/hysteria"
HYSTERIA_CONFIG="${HYSTERIA_ROOT}/config.yaml"
CLIENT_CONFIG_DIR="/root/H2"
SERVICE_FILE="/etc/systemd/system/hysteria-server.service"

# 默认配置参数
DEFAULT_TRANSPORT='{
    "type": "udp",
    "udp": {
        "hopInterval": "30s"
    }
}'

DEFAULT_TLS='{
    "insecure": true,
    "alpn": ["h3"]
}'

DEFAULT_QUIC='{
    "initStreamReceiveWindow": 26843545,
    "maxStreamReceiveWindow": 26843545,
    "initConnReceiveWindow": 53687090,
    "maxConnReceiveWindow": 53687090
}'

DEFAULT_BANDWIDTH='{
    "up": "200 mbps",
    "down": "200 mbps"
}'