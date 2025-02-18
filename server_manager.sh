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

# 自动生成配置
generate_auto_config() {
    echo -e "${YELLOW}正在生成配置...${NC}"
    
    read -p "请输入本地HTTP端口 (默认: 8080): " HTTP_PORT
    HTTP_PORT=${HTTP_PORT:-8080}
    
    SERVER_PORT=443
    PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
    SERVER_IP=$(curl -s ipv4.icanhazip.com)
    
    # 生成服务端配置(YAML格式)
    mkdir -p /etc/hysteria
    cat > /etc/hysteria/config.yaml <<EOF
listen: :${SERVER_PORT}
protocol: udp
up_mbps: 200
down_mbps: 200
auth:
  type: password
  password: ${PASSWORD}
EOF

    # 生成客户端配置(JSON格式)
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
        echo -e "${YELLOW}服务端配置已保存至：${NC}${GREEN}/etc/hysteria/config.yaml${NC}"
        echo -e "${YELLOW}客户端配置已保存至：${NC}${GREEN}${CLIENT_CONFIG_DIR}/${HTTP_PORT}.json${NC}"
        echo -e "${YELLOW}客户端HTTP代理端口：${NC}${GREEN}${HTTP_PORT}${NC}"
    else
        echo -e "${RED}配置生成失败！${NC}"
    fi
    sleep 0.5
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
    
    # 生成服务端配置(YAML格式)
    mkdir -p /etc/hysteria
    cat > /etc/hysteria/config.yaml <<EOF
listen: :${SERVER_PORT}
protocol: udp
up_mbps: ${UP_MBPS}
down_mbps: ${DOWN_MBPS}
auth:
  type: password
  password: ${PASSWORD}
EOF

    # 生成客户端配置(JSON格式)
    mkdir -p "$CLIENT_CONFIG_DIR"
    cat > "$CLIENT_CONFIG_DIR/${HTTP_PORT}.json" <<EOF
{
    "server": "${SERVER_IP}:${SERVER_PORT}",
    "protocol": "udp",
    "up_mbps": ${UP_MBPS},
    "down_mbps": ${DOWN_MBPS},
    "auth": "${PASSWORD}",
    "http": {
        "listen": "127.0.0.1:${HTTP_PORT}"
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

# 其他函数保持不变...
