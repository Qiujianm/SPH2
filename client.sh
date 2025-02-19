#!/bin/bash

# 客户端管理
start_client() {
    if [ ! -d "$CLIENT_DIR" ] || [ -z "$(ls -A $CLIENT_DIR/*.json 2>/dev/null)" ]; then
        echo -e "${RED}未找到客户端配置文件${NC}"
        return
    }

    echo -e "${YELLOW}可用的客户端配置：${NC}"
    ls -1 "$CLIENT_DIR"/*.json | nl
    echo
    read -p "请选择要启动的配置编号: " config_num
    
    selected_config=$(ls -1 "$CLIENT_DIR"/*.json | sed -n "${config_num}p")
    if [ -f "$selected_config" ]; then
        nohup hysteria client -c "$selected_config" >/dev/null 2>&1 &
        echo -e "${GREEN}已启动客户端配置：${selected_config}${NC}"
    else
        echo -e "${RED}无效的配置选择${NC}"
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

check_client_status() {
    clear
    echo -e "${GREEN}═══════ 客户端状态 ═══════${NC}"
    if pgrep -f "hysteria client" >/dev/null; then
        echo -e "${GREEN}运行中的客户端：${NC}"
        ps aux | grep "[h]ysteria client" | while read -r line; do
            config=$(echo "$line" | grep -o '\-c.*json' | cut -d' ' -f2)
            if [ ! -z "$config" ]; then
                echo "配置文件: $config"
                echo "SOCKS5端口: $(grep -o '"socks5".*"listen":.*".*"' "$config" | grep -o '[0-9]\+')"
                echo "HTTP端口: $(grep -o '"http".*"listen":.*".*"' "$config" | grep -o '[0-9]\+')"
                echo "-------------------"
            fi
        done
    else
        echo -e "${YELLOW}无运行中的客户端${NC}"
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

delete_client_config() {
    if [ ! -d "$CLIENT_DIR" ] || [ -z "$(ls -A $CLIENT_DIR/*.json 2>/dev/null)" ]; then
        echo -e "${RED}未找到客户端配置文件${NC}"
        return
    fi

    echo -e "${YELLOW}当前配置文件：${NC}"
    ls -1 "$CLIENT_DIR"/*.json | nl
    echo
    read -p "请选择要删除的配置编号: " config_num
    
    selected_config=$(ls -1 "$CLIENT_DIR"/*.json | sed -n "${config_num}p")
    if [ -f "$selected_config" ]; then
        if pgrep -f "hysteria.*$selected_config" >/dev/null; then
            pkill -f "hysteria.*$selected_config"
            echo -e "${YELLOW}已停止使用此配置的客户端${NC}"
        fi
        rm -f "$selected_config"
        echo -e "${GREEN}已删除配置文件：${selected_config}${NC}"
    else
        echo -e "${RED}无效的配置选择${NC}"
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
        echo -e "${GREEN}====================================${NC}"
        
        read -p "请选择 [0-5]: " option
        case $option in
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