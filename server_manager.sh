#!/bin/bash
source ./constants.sh

# 自动生成配置
generate_auto_config() {
    echo -e "${YELLOW}正在生成配置...${NC}"
    
    read -p "请输入本地HTTP端口 (默认: 8080): " HTTP_PORT
    HTTP_PORT=${HTTP_PORT:-8080}
    
    SERVER_PORT=443
    PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
    SERVER_IP=$(curl -s ipv4.icanhazip.com)
    
    # 生成自签名证书
    mkdir -p /etc/hysteria
    if [ ! -f "/etc/hysteria/server.crt" ] || [ ! -f "/etc/hysteria/server.key" ]; then
        openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
            -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt \
            -subj "/CN=${SERVER_IP}" 2>/dev/null
        
        chmod 644 /etc/hysteria/server.crt
        chmod 600 /etc/hysteria/server.key
    fi

    # 生成服务端配置
    cat > /etc/hysteria/config.yaml <<EOF
listen: :${SERVER_PORT}
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
    "auth": "${PASSWORD}",
    "tls": {
        "sni": "${SERVER_IP}",
        "insecure": true
    },
    "bandwidth": {
        "up": "200 mbps",
        "down": "200 mbps"
    },
    "http": {
        "listen": "127.0.0.1:${HTTP_PORT}"
    }
}
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}配置生成成功！${NC}"
        echo -e "${YELLOW}服务端配置已保存至：${NC}${GREEN}/etc/hysteria/config.yaml${NC}"
        echo -e "${YELLOW}客户端配置已保存至：${NC}${GREEN}${CLIENT_CONFIG_DIR}/${HTTP_PORT}.json${NC}"
        echo -e "${YELLOW}客户端HTTP代理端口：${NC}${GREEN}${HTTP_PORT}${NC}"
        
        # 重启服务
        systemctl restart hysteria
        sleep 2
        
        # 检查服务状态
        if systemctl is-active --quiet hysteria; then
            echo -e "${GREEN}服务启动成功！${NC}"
        else
            echo -e "${RED}服务启动失败，请检查日志${NC}"
            journalctl -u hysteria -n 20 --no-pager
        fi
    else
        echo -e "${RED}配置生成失败！${NC}"
    fi
}
