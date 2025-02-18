#!/bin/bash
source /usr/local/SPH2/constants.sh

# 启动所有客户端配置
start_all_clients() {
    for config in "$CLIENT_CONFIG_DIR"/*.json; do
        echo -e "${YELLOW}正在启动 $config...${NC}"
        hysteria -c "$config" &
    done
}

start_all_clients