#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 配置文件路径
HYSTERIA_CONFIG="/etc/hysteria/config.yaml"

# 生成服务端配置
generate_server_config() {
    local mode=$1  # auto 或 manual
    local domain port password socks_port

    if [ "$mode" = "auto" ]; then
        # 自动模式
        domain=$(curl -s ipv4.domains.google.com || curl -s ifconfig.me)
        port=443
        password=$(openssl rand -base64 16)
        read -p "请输入SOCKS5端口 [1080]: " socks_port
        socks_port=${socks_port:-1080}
        
        # 检查端口是否被占用
        if netstat -tuln | grep -q ":$socks_port "; then
            echo -e "${RED}警告: 端口 $socks_port 已被占用${NC}"
            return 1
        fi
    else
        # 手动模式
        read -p "请输入域名 (留空使用服务器IP): " domain
        domain=${domain:-$(curl -s ipv4.domains.google.com || curl -s ifconfig.me)}
        
        read -p "请输入服务端口 [443]: " port
        port=${port:-443}
        
        read -p "请输入验证密码 [随机生成]: " password
        password=${password:-$(openssl rand -base64 16)}
        
        read -p "请输入SOCKS5端口 [1080]: " socks_port
        socks_port=${socks_port:-1080}
        
        # 检查端口是否被占用
        if netstat -tuln | grep -q ":$socks_port "; then
            echo -e "${RED}警告: 端口 $socks_port 已被占用${NC}"
            return 1
        fi
    fi

    # 创建必要的目录
    mkdir -p /etc/hysteria
    mkdir -p /root/H2

    # 生成证书
    openssl req -x509 -newkey rsa:4096 -nodes -sha256 -days 365 \
        -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt \
        -subj "/CN=$domain" 2>/dev/null

    # 生成服务端配置
    cat > ${HYSTERIA_CONFIG} << EOF
listen: :$port

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $password

masquerade:
  type: default
  response:
    code: 200
    headers:
      Server: nginx/1.24.0
      Content-Type: text/html; charset=utf-8

quic:
  initStreamReceiveWindow: 26843545
  maxStreamReceiveWindow: 26843545
  initConnReceiveWindow: 53687090
  maxConnReceiveWindow: 53687090

bandwidth:
  up: 200 mbps
  down: 200 mbps
EOF

    # 生成客户端配置
    local client_config="/root/H2/client_${port}_${socks_port}.json"
    cat > "$client_config" << EOF
{
    "server": "$domain:$port",
    "auth": "$password",
    "transport": {
        "type": "udp",
        "udp": {
            "hopInterval": "10s"
        }
    },
    "tls": {
        "sni": "$domain",
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
    "socks5": {
        "listen": "0.0.0.0:$socks_port"
    }
}
EOF

    # 生成systemd服务文件
    cat > /etc/systemd/system/hysteria-server.service << EOF
[Unit]
Description=Hysteria Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    
    echo -e "${GREEN}配置生成完成：${NC}"
    echo -e "服务端配置：${HYSTERIA_CONFIG}"
    echo -e "客户端配置：${client_config}"
    echo -e "服务端口：${port}"
    echo -e "SOCKS5端口：${socks_port}"
    echo -e "验证密码：${password}"
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
        echo "6. 全自动生成配置"
        echo "7. 手动生成配置"
        echo "0. 返回主菜单"
        echo -e "${GREEN}====================================${NC}"
        
        read -p "请选择 [0-7]: " option
        case $option in
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
                clear
                systemctl status hysteria-server
                read -n 1 -s -r -p "按任意键继续..."
                ;;
            6)
                generate_server_config "auto"
                read -n 1 -s -r -p "按任意键继续..."
                ;;
            7)
                generate_server_config "manual"
                read -n 1 -s -r -p "按任意键继续..."
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