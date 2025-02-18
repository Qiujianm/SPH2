#!/bin/bash
source /usr/local/SPH2/constants.sh

# 启动所有客户端配置
start_all_clients() {
    echo -e "${YELLOW}正在启动所有客户端...${NC}"
    mkdir -p "$CLIENT_CONFIG_DIR"
    
    # 检查配置文件
    if [ -z "$(ls -A $CLIENT_CONFIG_DIR/*.json 2>/dev/null)" ]; then
        echo -e "${RED}没有找到客户端配置文件${NC}"
        return 1
    fi

    # 启动每个配置
    for config in "$CLIENT_CONFIG_DIR"/*.json; do
        if [ -f "$config" ]; then
            echo -e "${GREEN}启动配置：${config}${NC}"
            hysteria -c "$config" &
        fi
    done
    echo -e "${GREEN}所有客户端已启动${NC}"
}

# 停止所有客户端
stop_all_clients() {
    echo -e "${YELLOW}停止所有客户端...${NC}"
    pkill -f "/usr/local/bin/hysteria" || true
    echo -e "${GREEN}所有客户端已停止${NC}"
}

# 检查命令行参数
case "${1:-start}" in
    "start")
        start_all_clients
        ;;
    "stop")
        stop_all_clients
        ;;
    "restart")
        stop_all_clients
        sleep 2
        start_all_clients
        ;;
    *)
        echo "用法: $0 [start|stop|restart]"
        exit 1
        ;;
esac