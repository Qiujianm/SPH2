#!/bin/bash
source ./constants.sh

# 检查服务器状态
check_server_status() {
    if systemctl is-active --quiet hysteria-server; then
        echo -e "${GREEN}服务器正在运行${NC}"
        return 0
    else
        echo -e "${YELLOW}服务器未运行${NC}"
        return 1
    fi
}

# 生成服务器配置
generate_config() {
    echo -e "${YELLOW}正在生成服务器配置...${NC}"

    # 获取服务器IP
    SERVER_IP=$(curl -s ipv4.icanhazip.com)
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(curl -s ipinfo.io/ip)
    fi
    if [ -z "$SERVER_IP" ]; then
        echo -e "${RED}无法获取服务器IP地址${NC}"
        return 1
    fi

    # 设置服务器端口
    read -p "请输入服务器端口 (默认: 443): " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-443}

    # 设置认证密码
    read -p "请设置认证密码 (默认: hysteria): " AUTH_STR
    AUTH_STR=${AUTH_STR:-hysteria}

    # 设置伪装URL
    read -p "请输入伪装URL (默认: https://www.microsoft.com): " MASQ_URL
    MASQ_URL=${MASQ_URL:-https://www.microsoft.com}

    # 设置是否重写Host
    read -p "是否重写Host? (默认: true) [true/false]: " REWRITE_HOST
    REWRITE_HOST=${REWRITE_HOST:-true}

    # 设置带宽限制
    read -p "请输入上行带宽限制 (Mbps) (默认: 200): " UP_MBPS
    UP_MBPS=${UP_MBPS:-200}
    read -p "请输入下行带宽限制 (Mbps) (默认: 200): " DOWN_MBPS
    DOWN_MBPS=${DOWN_MBPS:-200}

    # 生成证书
    cert_path="/etc/hysteria/cert.crt"
    key_path="/etc/hysteria/private.key"
    if [ ! -f "$cert_path" ] || [ ! -f "$key_path" ]; then
        echo -e "${YELLOW}正在生成自签名证书...${NC}"
        mkdir -p /etc/hysteria
        openssl req -x509 -nodes -newkey rsa:4096 -keyout "$key_path" -out "$cert_path" -days 365 -subj "/CN=www.microsoft.com"
    fi

    # 生成服务器配置文件
    mkdir -p $(dirname $HYSTERIA_CONFIG)
    cat > $HYSTERIA_CONFIG <<EOF
{
    "listen": ":${SERVER_PORT}",
    "protocol": "udp",
    "cert": "${cert_path}",
    "key": "${key_path}",
    "auth": {
        "mode": "password",
        "config": ["${AUTH_STR}"]
    },
    "masquerade": {
        "type": "proxy",
        "proxy": {
            "url": "${MASQ_URL}",
            "rewriteHost": ${REWRITE_HOST}
        }
    },
    "bandwidth": {
        "up": "${UP_MBPS} mbps",
        "down": "${DOWN_MBPS} mbps"
    },
    "ignoreClientBandwidth": true,
    "disableUDP": false,
    "udpIdleTimeout": 60
}
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}服务器配置已生成！${NC}"
        
        # 显示客户端配置信息
        echo -e "\n${GREEN}请记录以下客户端配置参数：${NC}"
        echo -e "${YELLOW}服务器地址：${NC}${SERVER_IP}"
        echo -e "${YELLOW}端口：${NC}${SERVER_PORT}"
        echo -e "${YELLOW}认证密码：${NC}${AUTH_STR}"
        echo -e "${YELLOW}上行速度：${NC}${UP_MBPS} Mbps"
        echo -e "${YELLOW}下行速度：${NC}${DOWN_MBPS} Mbps"
        
        # 生成客户端配置示例
        echo -e "\n${GREEN}客户端配置示例：${NC}"
        cat << EOF
{
    "server": "${SERVER_IP}:${SERVER_PORT}",
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
        "listen": "0.0.0.0:8080"
    }
}
EOF
        
        systemctl restart hysteria-server
    else
        echo -e "${RED}服务器配置生成失败！${NC}"
    fi
    sleep 0.5
}

# 服务器管理菜单
server_menu() {
    while true; do
        echo -e "${GREEN}═══════ Hysteria 服务器管理 ═══════${NC}"
        echo "1. 启动服务器"
        echo "2. 停止服务器"
        echo "3. 重启服务器"
        echo "4. 查看服务器状态"
        echo "5. 查看服务器日志"
        echo "6. 查看配置文件"
        echo "7. 重新生成配置"
        echo "0. 返回主菜单"
        
        read -p "请选择 [0-7]: " choice
        case $choice in
            1)
                systemctl start hysteria-server
                echo -e "${GREEN}服务器已启动${NC}"
                sleep 0.5
                ;;
            2)
                systemctl stop hysteria-server
                echo -e "${YELLOW}服务器已停止${NC}"
                sleep 0.5
                ;;
            3)
                systemctl restart hysteria-server
                echo -e "${GREEN}服务器已重启${NC}"
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
                if [ -f "$HYSTERIA_CONFIG" ]; then
                    echo -e "${GREEN}当前配置文件内容：${NC}"
                    cat "$HYSTERIA_CONFIG"
                else
                    echo -e "${RED}配置文件不存在${NC}"
                fi
                sleep 0.5
                ;;
            7)
                generate_config
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
