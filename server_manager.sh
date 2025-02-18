#!/bin/bash
source /usr/local/SPH2/constants.sh

check_server_status() {
    if systemctl is-active --quiet hysteria-server; then
        echo -e "${GREEN}服务端运行中${NC}"
        return 0
    else
        echo -e "${YELLOW}服务端未运行${NC}"
        return 1
    fi
}

auto_generate_config() {
    # 获取服务器IP
    SERVER_IP=$(curl -s -4 api64.ipify.org || curl -s ipv4.icanhazip.com)
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(curl -s ip.sb || curl -s ipinfo.io/ip)
    fi
    if [ -z "$SERVER_IP" ]; then
        echo -e "${RED}无法获取服务器IP地址${NC}"
        return 1
    }

    read -p "请输入本地代理端口 (1-65535): " LOCAL_PORT
    
    # 确保目录存在
    mkdir -p "$HYSTERIA_ROOT"
    mkdir -p "$CLIENT_CONFIG_DIR"

    # 生成服务端配置
    cat > "$HYSTERIA_CONFIG" <<EOF
listen: :443

auth:
  type: password
  password: hysteria

bandwidth:
  up: 200 mbps
  down: 200 mbps

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
EOF

    # 生成客户端配置
    cat > "$CLIENT_CONFIG_DIR/config_${LOCAL_PORT}.json" <<EOF
{
    "server": "${SERVER_IP}:443",
    "auth": "hysteria",
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
        "up": "200 mbps",
        "down": "200 mbps"
    },
    "http": {
        "listen": "127.0.0.1:${LOCAL_PORT}"
    }
}
EOF

    echo -e "${GREEN}配置文件已生成：${NC}"
    echo -e "服务端配置：${HYSTERIA_CONFIG}"
    echo -e "客户端配置：${CLIENT_CONFIG_DIR}/config_${LOCAL_PORT}.json"
}

manual_generate_config() {
    SERVER_IP=$(curl -s -4 api64.ipify.org || curl -s ipv4.icanhazip.com)
    
    read -p "请输入服务端口 [443]: " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-443}
    
    read -p "请输入认证密码 [hysteria]: " AUTH_STR
    AUTH_STR=${AUTH_STR:-hysteria}
    
    read -p "请输入本地代理端口 (1-65535): " LOCAL_PORT
    
    read -p "请输入上行带宽(Mbps) [200]: " UP_MBPS
    UP_MBPS=${UP_MBPS:-200}
    
    read -p "请输入下行带宽(Mbps) [200]: " DOWN_MBPS
    DOWN_MBPS=${DOWN_MBPS:-200}

    mkdir -p "$HYSTERIA_ROOT"
    mkdir -p "$CLIENT_CONFIG_DIR"

    # 生成服务端配置
    cat > "$HYSTERIA_CONFIG" <<EOF
listen: :${SERVER_PORT}

auth:
  type: password
  password: ${AUTH_STR}

bandwidth:
  up: ${UP_MBPS} mbps
  down: ${DOWN_MBPS} mbps

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
EOF

    # 生成客户端配置
    cat > "$CLIENT_CONFIG_DIR/config_${LOCAL_PORT}.json" <<EOF
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
    "http": {
        "listen": "127.0.0.1:${LOCAL_PORT}"
    }
}
EOF

    echo -e "${GREEN}配置文件已生成：${NC}"
    echo -e "服务端配置：${HYSTERIA_CONFIG}"
    echo -e "客户端配置：${CLIENT_CONFIG_DIR}/config_${LOCAL_PORT}.json"
}

server_menu() {
    while true; do
        clear
        echo -e "${GREEN}═══════ Hysteria 服务端管理 ═══════${NC}"
        echo "1. 启动服务端"
        echo "2. 停止服务端"
        echo "3. 重启服务端"
        echo "4. 查看服务端状态"
        echo "6. 全自动生成配置"
        echo "7. 手动生成配置"
        echo "0. 返回主菜单"
        
        read -p "请选择 [0-7]: " choice
        case $choice in
            1)
                systemctl start hysteria-server
                echo -e "${GREEN}服务端已启动${NC}"
                sleep 1
                ;;
            2)
                systemctl stop hysteria-server
                echo -e "${YELLOW}服务端已停止${NC}"
                sleep 1
                ;;
            3)
                systemctl restart hysteria-server
                echo -e "${GREEN}服务端已重启${NC}"
                sleep 1
                ;;
            4)
                check_server_status
                sleep 2
                ;;
            6)
                auto_generate_config
                sleep 2
                ;;
            7)
                manual_generate_config
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