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
START_CLIENTS_SCRIPT="$HYSTERIA_ROOT/start_clients.sh"