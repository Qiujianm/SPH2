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
SERVICE_FILE="/etc/systemd/system/hysteria.service"
CLIENT_SERVICE_FILE="/etc/systemd/system/clients.service"