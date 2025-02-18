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

# 生成服务端配置
generate_server_config() {
    echo -e "${YELLOW}正在生成服务器配置...${NC}"
    
    read -p "监听端口 (默认: 443): " PORT
    PORT=${PORT:-443}
    
    mkdir -p "$HYSTERIA_ROOT"
    
    cat > "$HYSTERIA_CONFIG" <<EOF
{
    "listen": ":$PORT",
    "protocol": "udp",
    "up_mbps": 200,
    "down_mbps": 200
}
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}服务器配置生成成功！${NC}"
    else
        echo -e "${RED}服务器配置生成失败！${NC}"
    fi
    sleep 0.5
}

# 服务端管理菜单
server_menu() {
    while true; do
        echo -e "${GREEN}═══════ Hysteria 服务端管理 ═══════${NC}"
        echo "1. 启动服务端"
        echo "2. 停止服务端"
        echo "3. 重启服务端"
        echo "4. 查看服务端状态"
        echo "5. 查看服务端日志"
        echo "6. 重新生成配置"
        echo "7. 查看当前配置"
        echo "0. 返回主菜单"
        
        read -p "请选择 [0-7]: " choice
        case $choice in
            1)
                systemctl start hysteria
                echo -e "${GREEN}服务端已启动${NC}"
                sleep 0.5
                ;;
            2)
                systemctl stop hysteria
                echo -e "${YELLOW}服务端已停止${NC}"
                sleep 0.5
                ;;
            3)
                systemctl restart hysteria
                echo -e "${GREEN}服务端已重启${NC}"
                sleep 0.5
                ;;
            4)
                systemctl status hysteria --no-pager
                sleep 0.5
                ;;
            5)
                journalctl -u hysteria -n 50 --no-pager
                sleep 0.5
                ;;
            6)
                generate_server_config
                systemctl restart hysteria
                sleep 0.5
                ;;
            7)
                if [ -f "$HYSTERIA_CONFIG" ]; then
                    cat "$HYSTERIA_CONFIG"
                else
                    echo -e "${RED}配置文件不存在${NC}"
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