#!/bin/bash
source /usr/local/SPH2/constants.sh

check_client_status() {
    local running=0
    if pgrep -f "hysteria client" >/dev/null; then
        echo -e "${GREEN}客户端运行中${NC}"
        running=1
    else
        echo -e "${YELLOW}客户端未运行${NC}"
    fi

    if [ $running -eq 1 ]; then
        echo -e "\n当前活跃的客户端连接："
        ps aux | grep "[h]ysteria client" | while read -r line; do
            config=$(echo "$line" | grep -o '\-c.*json' | cut -d' ' -f2)
            if [ ! -z "$config" ]; then
                echo "- 配置文件: $config"
                echo "  端口: $(grep -o '"listen": "[^"]*"' "$config" | cut -d'"' -f4)"
            fi
        done
    fi
}

start_client() {
    if [ -d "$CLIENT_CONFIG_DIR" ] && [ "$(ls -A $CLIENT_CONFIG_DIR/*.json 2>/dev/null)" ]; then
        echo -e "${YELLOW}可用的客户端配置：${NC}"
        ls -1 "$CLIENT_CONFIG_DIR"/*.json | nl
        echo
        read -p "请选择要启动的配置编号: " config_num
        
        selected_config=$(ls -1 "$CLIENT_CONFIG_DIR"/*.json | sed -n "${config_num}p")
        if [ -f "$selected_config" ]; then
            # 检查端口是否已被使用
            local port=$(grep -o '"listen": "[^"]*"' "$selected_config" | cut -d'"' -f4 | cut -d':' -f2)
            if netstat -tuln | grep -q ":$port "; then
                echo -e "${RED}端口 $port 已被占用${NC}"
                return 1
            fi
            
            nohup hysteria client -c "$selected_config" >/dev/null 2>&1 &
            echo -e "${GREEN}已启动客户端配置：${selected_config}${NC}"
        else
            echo -e "${RED}无效的配置选择${NC}"
        fi
    else
        echo -e "${RED}未找到任何客户端配置文件${NC}"
    fi
}

stop_client() {
    if pgrep -f "hysteria client" >/dev/null; then
        pkill -f "hysteria client"
        echo -e "${GREEN}已停止所有客户端${NC}"
    else
        echo -e "${YELLOW}没有运行中的客户端${NC}"
    fi
}

delete_client_config() {
    if [ -d "$CLIENT_CONFIG_DIR" ] && [ "$(ls -A $CLIENT_CONFIG_DIR/*.json 2>/dev/null)" ]; then
        echo -e "${YELLOW}当前客户端配置文件：${NC}"
        ls -1 "$CLIENT_CONFIG_DIR"/*.json | nl
        echo
        read -p "请选择要删除的配置编号: " config_num
        
        selected_config=$(ls -1 "$CLIENT_CONFIG_DIR"/*.json | sed -n "${config_num}p")
        if [ -f "$selected_config" ]; then
            # 如果配置正在运行，先停止它
            if pgrep -f "hysteria.*$selected_config" >/dev/null; then
                pkill -f "hysteria.*$selected_config"
                echo -e "${YELLOW}已停止使用此配置的客户端${NC}"
            fi
            rm -f "$selected_config"
            echo -e "${GREEN}已删除配置文件：${selected_config}${NC}"
        else
            echo -e "${RED}无效的配置选择${NC}"
        fi
    else
        echo -e "${RED}没有找到任何客户端配置文件${NC}"
    fi
}

client_menu() {
    while true; do
        clear
        echo -e "${GREEN}═══════ Hysteria 客户端管理 ═══════${NC}"
        echo "1. 启动客户端"
        echo "2. 停止客户端"
        echo "3. 重启客户端"
        echo "4. 查看客户端状态"
        echo "5. 删除客户端配置"
        echo "0. 返回主菜单"
        
        read -p "请选择 [0-5]: " choice
        case $choice in
            1)
                start_client
                sleep 2
                ;;
            2)
                stop_client
                sleep 2
                ;;
            3)
                stop_client
                sleep 1
                start_client
                sleep 2
                ;;
            4)
                check_client_status
                read -n 1 -s -r -p "按任意键继续..."
                ;;
            5)
                delete_client_config
                sleep 2
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                sleep 1
                ;;
        esac
    done
}