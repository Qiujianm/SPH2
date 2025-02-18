#!/bin/bash
source ./constants.sh

# 客户端状态检查
check_client_status() {
    if systemctl is-active --quiet clients; then
        echo -e "${GREEN}客户端正在运行${NC}"
        return 0
    else
        echo -e "${YELLOW}客户端未运行${NC}"
        return 1
    fi
}

# 生成客户端配置
generate_client_config() {
    echo -e "${YELLOW}正在生成客户端配置...${NC}"
    
    read -p "服务器地址: " SERVER_ADDR
    read -p "服务器端口 (默认: 443): " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-443}
    read -p "本地HTTP代理端口 (默认: 8080): " LOCAL_PORT
    LOCAL_PORT=${LOCAL_PORT:-8080}
    
    mkdir -p "$CLIENT_CONFIG_DIR"
    
    cat > "$CLIENT_CONFIG_DIR/$LOCAL_PORT.json" <<EOF
{
    "server": "${SERVER_ADDR}:${SERVER_PORT}",
    "protocol": "udp",
    "up_mbps": 200,
    "down_mbps": 200,
    "http": {
        "listen": "127.0.0.1:${LOCAL_PORT}"
    }
}
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}客户端配置生成成功！${NC}"
        return 0
    else
        echo -e "${RED}客户端配置生成失败！${NC}"
        return 1
    fi
}

# 列出配置文件
list_configs() {
    local configs=("$CLIENT_CONFIG_DIR"/*.json)
    local count=0
    echo -e "${GREEN}现有客户端配置：${NC}"
    
    # 检查目录是否为空
    if [ ! -f "$CLIENT_CONFIG_DIR"/*.json ]; then
        echo -e "${YELLOW}没有找到任何配置文件${NC}"
        return 1
    fi

    # 用数字列出所有配置文件
    for config in "${configs[@]}"; do
        if [ -f "$config" ]; then
            count=$((count + 1))
            echo "$count. $(basename "$config")"
        fi
    done
    
    return 0
}

# 客户端管理菜单
client_menu() {
    while true; do
        clear
        echo -e "${GREEN}═══════ Hysteria 客户端管理 ═══════${NC}"
        echo "1. 启动客户端"
        echo "2. 停止客户端"
        echo "3. 重启客户端"
        echo "4. 查看客户端状态"
        echo "5. 查看客户端日志"
        echo "6. 添加新客户端配置"
        echo "7. 查看现有客户端配置"
        echo "8. 删除客户端配置"
        echo "0. 返回主菜单"
        
        read -p "请选择 [0-8]: " choice
        case $choice in
            1)
                systemctl start clients
                echo -e "${GREEN}客户端已启动${NC}"
                ;;
            2)
                systemctl stop clients
                echo -e "${YELLOW}客户端已停止${NC}"
                ;;
            3)
                systemctl restart clients
                echo -e "${GREEN}客户端已重启${NC}"
                ;;
            4)
                systemctl status clients --no-pager
                ;;
            5)
                journalctl -u clients -n 50 --no-pager
                ;;
            6)
                generate_client_config
                ;;
            7)
                if list_configs; then
                    read -p "输入配置编号查看内容: " num
                    local configs=("$CLIENT_CONFIG_DIR"/*.json)
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt 0 ] && [ "$num" -le "${#configs[@]}" ]; then
                        echo -e "\n${GREEN}配置文件内容：${NC}"
                        cat "${configs[$((num-1))]}"
                        echo
                    else
                        echo -e "${RED}无效的配置编号${NC}"
                    fi
                fi
                ;;
            8)
                if list_configs; then
                    read -p "输入要删除的配置编号: " num
                    local configs=("$CLIENT_CONFIG_DIR"/*.json)
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt 0 ] && [ "$num" -le "${#configs[@]}" ]; then
                        rm -f "${configs[$((num-1))]}"
                        echo -e "${GREEN}配置已删除${NC}"
                        systemctl restart clients
                    else
                        echo -e "${RED}无效的配置编号${NC}"
                    fi
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                ;;
        esac
        read -p "按回车键继续..."
    done
}