#!/bin/bash
source ./constants.sh

# 服务端状态检查
check_server_status() {
    if systemctl is-active --quiet hysteria; then
        echo -e "${GREEN}服务端正在运行${NC}"
        return 0
    else
        echo -e "${YELLOW}服务端未运行${NC}"
        return 1
    fi
}

# 服务端配置生成
generate_server_config() {
    echo -e "${YELLOW}正在生成服务器配置...${NC}"
    
    # 获取必要参数
    read -p "监听端口 (默认: 443): " PORT
    PORT=${PORT:-443}
    
    read -p "上行带宽 (默认: 200 mbps): " UP_BANDWIDTH
    UP_BANDWIDTH=${UP_BANDWIDTH:-200}
    UP_BANDWIDTH="${UP_BANDWIDTH} mbps"
    
    read -p "下行带宽 (默认: 200 mbps): " DOWN_BANDWIDTH
    DOWN_BANDWIDTH=${DOWN_BANDWIDTH:-200}
    DOWN_BANDWIDTH="${DOWN_BANDWIDTH} mbps"
    
    # 生成配置文件
    cat > "$HYSTERIA_CONFIG" <<EOF
listen: :$PORT
protocol: udp
auth:
  type: password
  password: $(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
bandwidth:
  up: $UP_BANDWIDTH
  down: $DOWN_BANDWIDTH
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}服务器配置生成成功！${NC}"
        return 0
    else
        echo -e "${RED}服务器配置生成失败！${NC}"
        return 1
    fi
}

# 服务端管理菜单
server_menu() {
    while true; do
        clear
        echo -e "${GREEN}═══════ Hysteria 服务端管理 ═══════${NC}"
        echo "1. 启动服务端"
        echo "2. 停止服务端"
        echo "3. 重启服务端"
        echo "4. 查看服务端状态"
        echo "5. 查看服务端日志"
        echo "6. 重新生成服务端配置"
        echo "7. 查看当前配置"
        echo "0. 返回主菜单"
        
        read -p "请选择 [0-7]: " choice
        case $choice in
            1)
                systemctl start hysteria
                echo -e "${GREEN}服务端已启动${NC}"
                ;;
            2)
                systemctl stop hysteria
                echo -e "${YELLOW}服务端已停止${NC}"
                ;;
            3)
                systemctl restart hysteria
                echo -e "${GREEN}服务端已重启${NC}"
                ;;
            4)
                systemctl status hysteria --no-pager
                ;;
            5)
                tail -n 50 "$LOG_FILE"
                ;;
            6)
                generate_server_config
                systemctl restart hysteria
                ;;
            7)
                if [ -f "$HYSTERIA_CONFIG" ]; then
                    cat "$HYSTERIA_CONFIG"
                else
                    echo -e "${RED}配置文件不存在${NC}"
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