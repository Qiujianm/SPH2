#!/bin/bash
# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 基础路径配置
HYSTERIA_ROOT="/etc/hysteria"
HYSTERIA_CONFIG="$HYSTERIA_ROOT/config.yaml"
SERVICE_FILE="/etc/systemd/system/hysteria.service"
CLIENT_SERVICE_FILE="/etc/systemd/system/clients.service"
CLIENT_DIR="$HYSTERIA_ROOT/clients"
LOG_FILE="/var/log/hysteria.log"
CLIENT_CONFIG_DIR="/root/H2"

# 错误处理函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    echo -e "${RED}错误发生在第 $line_number 行: 退出代码 $exit_code${NC}"
    logger -t hysteria-script "错误发生在第 $line_number 行: 退出代码 $exit_code"
}

# 设置错误处理
trap 'handle_error ${LINENO}' ERR