#!/bin/bash
source ./constants.sh

# 检查服务端状态
check_server_status() {
    if systemctl is-active --quiet hysteria-server; then
        echo -e "${GREEN}服务端正在运行${NC}"
        return 0
    else
        echo -e "${YELLOW}服务端未运行${NC}"
        return 1
    fi
}

# 全自动生成配置
auto_generate_config() {
    echo -e "${YELLOW}正在生成服务端配置...${NC}"

    # 获取服务器IP
    SERVER_IP=$(curl -s ipv4.icanhazip.com)
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(curl -s ipinfo.io/ip)
    fi
    if [ -z "$SERVER_IP" ]; then
        echo -e "${RED}无法获取服务器IP地址${NC}"
        return 1
    }

    # 只需要用户输入HTTP端口
    read -p "请输入HTTP端口: " HTTP_PORT
    
    # 使用预设值
    SERVER_PORT=443
    AUTH_STR="hysteria"
    UP_MBPS=200
    DOWN_MBPS=200

    # 生成配置文件
    mkdir -p "$CLIENT_CONFIG_DIR"
    cat > "$CLIENT_CONFIG_DIR/${HTTP_PORT}.json" <<EOF
{
    "server": "${SERVER_IP}:${SERVER_PORT}",
    "auth": "${AUTH_STR}",
    "transport": {
        "type": "udp",
        "udp": {
            "hopInterval": "30s"
        }
    },
    "tls": {
        "insecure": true,
        "alpn": ["h3"]
    },
    "quic": {
        "initStreamReceiveWindow": 26843545,
        "maxStreamReceiveWindow": 26843545,
        "initConnReceiveWindow": 53687090,
        "maxConnReceiveWindow": 53687090
    },
    "bandwidth": {
        "up": "${UP_MBPS} mbps",
        "down": "${DOWN_MBPS} mbps"
    },
    "fastOpen": true,
    "http": {
        "listen": "0.0.0.0:${HTTP_PORT}"
    }
}
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}客户端配置已生成：${HTTP_PORT}.json${NC}"
        echo -e "\n${GREEN}配置信息：${NC}"
        echo -e "${YELLOW}服务器地址：${NC}${SERVER_IP}:${SERVER_PORT}"
        echo -e "${YELLOW}认证密码：${NC}${AUTH_STR}"
        echo -e "${YELLOW}HTTP端口：${NC}${HTTP_PORT}"
        echo -e "${YELLOW}带宽限制：${NC}上行${UP_MBPS}Mbps / 下行${DOWN_MBPS}Mbps"
    else
        echo -e "${RED}配置生成失败！${NC}"
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
        echo "6. 全自动生成配置"
        echo "7. 手动生成配置"
        echo "8. 查看当前配置"
        echo "0. 返回主菜单"
        
        read -p "请选择 [0-8]: " choice
        case $choice in
            1)
                systemctl start hysteria-server
                echo -e "${GREEN}服务端已启动${NC}"
                sleep 0.5
                ;;
            2)
                systemctl stop hysteria-server
                echo -e "${YELLOW}服务端已停止${NC}"
                sleep 0.5
                ;;
            3)
                systemctl restart hysteria-server
                echo -e "${GREEN}服务端已重启${NC}"
                sleep 0.5
                ;;
            4)
                systemctl status hysteria-server --no-pager
                sleep 0.5
                ;;
            5)
                journalctl -u hysteria-server -n 50 --no-pager
                sleep 0.5
                ;;
            6)
                auto_generate_config
                ;;
            7)
                manual_generate_config
                ;;
            8)
                if [ -f "$HYSTERIA_CONFIG" ]; then
                    echo -e "${GREEN}当前配置文件内容：${NC}"
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
