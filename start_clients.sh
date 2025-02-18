#!/bin/bash
source /usr/local/SPH2/constants.sh

start_all_clients() {
    echo -e "${YELLOW}正在启动所有客户端...${NC}"
    if [ -d "$CLIENT_CONFIG_DIR" ] && [ "$(ls -A $CLIENT_CONFIG_DIR/*.json 2>/dev/null)" ]; then
        for config in "$CLIENT_CONFIG_DIR"/*.json; do
            if [ -f "$config" ]; then
                echo -e "${GREEN}启动配置：${config}${NC}"
                hysteria -c "$config" &
            fi
        done
        echo -e "${GREEN}所有客户端已启动${NC}"
    else
        echo -e "${RED}未找到客户端配置文件${NC}"
        exit 1
    fi
}

case "${1:-start}" in
    "start")
        start_all_clients
        ;;
    "stop")
        pkill -f "/usr/local/bin/hysteria"
        echo -e "${GREEN}所有客户端已停止${NC}"
        ;;
    "restart")
        pkill -f "/usr/local/bin/hysteria"
        sleep 2
        start_all_clients
        ;;
    *)
        echo "用法: $0 [start|stop|restart]"
        exit 1
        ;;
esac