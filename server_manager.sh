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

# 生成自签名证书
generate_cert() {
    mkdir -p /etc/hysteria
    if [ ! -f "/etc/hysteria/server.crt" ] || [ ! -f "/etc/hysteria/server.key" ]; then
        openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
            -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt \
            -subj "/CN=${SERVER_IP}" 2>/dev/null
        
        chmod 644 /etc/hysteria/server.crt
        chmod 600 /etc/hysteria/server.key
    fi
}

# 手动生成配置
generate_manual_config() {
    echo -e "${YELLOW}正在手动生成配置...${NC}"
    
    read -p "服务端监听端口 (默认: 443): " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-443}
    
    read -p "本地HTTP端口 (默认: 8080): " HTTP_PORT
    HTTP_PORT=${HTTP_PORT:-8080}
    
    read -p "上行带宽 Mbps (默认: 200): " UP_MBPS
    UP_MBPS=${UP_MBPS:-200}
    
    read -p "下行带宽 Mbps (默认: 200): " DOWN_MBPS
    DOWN_MBPS=${DOWN_MBPS:-200}
    
    read -p "自定义密码 (留空自动生成): " PASSWORD
    if [ -z "$PASSWORD" ]; then
        PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
    fi
    
    SERVER_IP=$(curl -s ipv4.icanhazip.com)
    
    # 生成证书
    generate_cert
    
    # 生成服务端配置
    mkdir -p "$HYSTERIA_ROOT"
    cat > "$HYSTERIA_CONFIG" <<EOF
listen: :${SERVER_PORT}
protocol: udp
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: ${PASSWORD}

bandwidth:
  up: ${UP_MBPS} mbps
  down: ${DOWN_MBPS} mbps

quic:
  initStreamReceiveWindow: 26843545
  maxStreamReceiveWindow: 26843545
  initConnReceiveWindow: 53687090
  maxConnReceiveWindow: 53687090

log:
  level: info
  timestamp: true
EOF

    # 生成客户端配置
    mkdir -p "$CLIENT_CONFIG_DIR"
    cat > "$CLIENT_CONFIG_DIR/${HTTP_PORT}.json" <<EOF
{
    "server": "${SERVER_IP}:${SERVER_PORT}",
    "protocol": "udp",
    "up_mbps": ${UP_MBPS},
    "down_mbps": ${DOWN_MBPS},
    "auth": "${PASSWORD}",
    "http": {
        "listen": "0.0.0.0:${HTTP_PORT}"
    }
}
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}配置生成成功！${NC}"
        echo -e "${YELLOW}配置信息：${NC}"
        echo -e "服务器IP：${GREEN}${SERVER_IP}${NC}"
        echo -e "服务端口：${GREEN}${SERVER_PORT}${NC}"
        echo -e "密码：${GREEN}${PASSWORD}${NC}"
        echo -e "HTTP端口：${GREEN}${HTTP_PORT}${NC}"
        echo -e "上行带宽：${GREEN}${UP_MBPS}${NC} Mbps"
        echo -e "下行带宽：${GREEN}${DOWN_MBPS}${NC} Mbps"
    else
        echo -e "${RED}配置生成失败！${NC}"
    fi
    sleep 0.5
}

# 自动生成配置
generate_auto_config() {
    echo -e "${YELLOW}正在生成配置...${NC}"
    
    read -p "请输入本地HTTP端口 (默认: 8080): " HTTP_PORT
    HTTP_PORT=${HTTP_PORT:-8080}
    
    SERVER_PORT=443
    PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
    SERVER_IP=$(curl -s ipv4.icanhazip.com)
    
    # 生成证书
    generate_cert
    
    # 生成服务端配置
    mkdir -p "$HYSTERIA_ROOT"
    cat > "$HYSTERIA_CONFIG" <<EOF
listen: :${SERVER_PORT}
protocol: udp
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: ${PASSWORD}

bandwidth:
  up: 200 mbps
  down: 200 mbps

quic:
  initStreamReceiveWindow: 26843545
  maxStreamReceiveWindow: 26843545
  initConnReceiveWindow: 53687090
  maxConnReceiveWindow: 53687090

log:
  level: info
  timestamp: true
EOF

    # 生成客户端配置
    mkdir -p "$CLIENT_CONFIG_DIR"
    cat > "$CLIENT_CONFIG_DIR/${HTTP_PORT}.json" <<EOF
{
    "server": "${SERVER_IP}:${SERVER_PORT}",
    "protocol": "udp",
    "up_mbps": 200,
    "down_mbps": 200,
    "auth": "${PASSWORD}",
    "http": {
        "listen": "127.0.0.1:${HTTP_PORT}"
    }
}
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}配置生成成功！${NC}"
        echo -e "${YELLOW}服务端配置已保存至：${NC}${GREEN}${HYSTERIA_CONFIG}${NC}"
        echo -e "${YELLOW}客户端配置已保存至：${NC}${GREEN}${CLIENT_CONFIG_DIR}/${HTTP_PORT}.json${NC}"
        echo -e "${YELLOW}客户端HTTP代理端口：${NC}${GREEN}${HTTP_PORT}${NC}"
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
                generate_auto_config
                systemctl restart hysteria
                ;;
            7)
                generate_manual_config
                systemctl restart hysteria
                ;;
            8)
                if [ -f "$HYSTERIA_CONFIG" ]; then
                    echo -e "${YELLOW}当前配置：${NC}"
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

# 如果直接运行此脚本，启动服务端管理菜单
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    server_menu
fi
