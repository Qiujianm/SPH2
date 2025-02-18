#!/bin/bash
source ./constants.sh

# 客户端状态检查
check_client_status() {
    if systemctl is-active --quiet clients; then
        echo -e "${GREEN}客户端正在运行${NC}"
        num_clients=$(pgrep -f "hysteria client" | wc -l)
        echo -e "${GREEN}当前运行的客户端数量: $num_clients${NC}"
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
    read -p "认证密码 (默认: hysteria): " AUTH_STR
    AUTH_STR=${AUTH_STR:-hysteria}
    read -p "上行速度 Mbps (默认: 200): " UP_MBPS
    UP_MBPS=${UP_MBPS:-200}
    read -p "下行速度 Mbps (默认: 200): " DOWN_MBPS
    DOWN_MBPS=${DOWN_MBPS:-200}
    
    mkdir -p "$CLIENT_CONFIG_DIR"
    
    cat > "$CLIENT_CONFIG_DIR/$LOCAL_PORT.json" <<EOF
{
    "server": "${SERVER_ADDR}:${SERVER_PORT}",
    "protocol": "udp",
    "up_mbps": ${UP_MBPS},
    "down_mbps": ${DOWN_MBPS},
    "auth_str": "${AUTH_STR}",
    "server_name": "www.microsoft.com",
    "insecure": true,
    "retry": 3,
    "retry_interval": 3,
    "idle_timeout": 60,
    "alpn": "h3",
    "http": {
        "listen": "0.0.0.0:${LOCAL_PORT}"
    }
}
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}客户端配置生成成功！${NC}"
        echo -e "HTTP代理: 0.0.0.0:${LOCAL_PORT}"
        systemctl restart clients
    else
        echo -e "${RED}客户端配置生成失败！${NC}"
    fi
    sleep 0.5
}

# 列出配置文件
list_configs() {
    local configs=("$CLIENT_CONFIG_DIR"/*.json)
    local count=0
    echo -e "${GREEN}现有客户端配置：${NC}"
    
    if [ ! -f "$CLIENT_CONFIG_DIR"/*.json ]; then
        echo -e "${YELLOW}没有找到任何配置文件${NC}"
        return 1
    fi

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
        echo -e "${GREEN}═══════ Hysteria 客户端管理 ═══════${NC}"
        echo "1. 启动客户端"
        echo "2. 停止客户端"
        echo "3. 重启客户端"
        echo "4. 查看客户端状态"
        echo "5. 查看客户端日志"
        echo "6. 管理配置文件"
        echo "0. 返回主菜单"
        
        read -p "请选择 [0-6]: " choice
        case $choice in
            1)
                systemctl start clients
                echo -e "${GREEN}客户端已启动${NC}"
                sleep 0.5
                ;;
            2)
                systemctl stop clients
                echo -e "${YELLOW}客户端已停止${NC}"
                sleep 0.5
                ;;
            3)
                systemctl restart clients
                echo -e "${GREEN}客户端已重启${NC}"
                sleep 0.5
                ;;
            4)
                systemctl status clients --no-pager
                ps aux | grep "hysteria client" | grep -v grep
                sleep 0.5
                ;;
            5)
                journalctl -u clients -n 50 --no-pager
                sleep 0.5
                ;;
            6)
                if list_configs; then
                    echo -e "\n请选择操作："
                    echo "1. 查看配置内容"
                    echo "2. 删除配置文件"
                    echo "0. 返回"
                    read -p "请选择 [0-2]: " sub_choice
                    case $sub_choice in
                        1)
                            read -p "输入配置编号查看内容: " num
                            local configs=("$CLIENT_CONFIG_DIR"/*.json)
                            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt 0 ] && [ "$num" -le "${#configs[@]}" ]; then
                                echo -e "\n${GREEN}配置文件内容：${NC}"
                                cat "${configs[$((num-1))]}"
                                echo
                            else
                                echo -e "${RED}无效的配置编号${NC}"
                            fi
                            ;;
                        2)
                            read -p "输入要删除的配置编号: " num
                            local configs=("$CLIENT_CONFIG_DIR"/*.json)
                            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt 0 ] && [ "$num" -le "${#configs[@]}" ]; then
                                rm -f "${configs[$((num-1))]}"
                                echo -e "${GREEN}配置已删除${NC}"
                                systemctl restart clients
                            else
                                echo -e "${RED}无效的配置编号${NC}"
                            fi
                            ;;
                        0) ;;
                        *)
                            echo -e "${RED}无效选择${NC}"
                            ;;
                    esac
                fi
                sleep 0.5
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                sleep 0.5
                ;;
        esac
    done
}
