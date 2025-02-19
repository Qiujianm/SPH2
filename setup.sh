#!/bin/bash

# 脚本信息
VERSION="2025-02-19"
AUTHOR="Qiujianm"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 检查root权限
[ "$EUID" -ne 0 ] && echo -e "${RED}请使用root权限运行此脚本${NC}" && exit 1

# 清理旧安装
cleanup_old_installation() {
    echo -e "${YELLOW}清理旧的安装...${NC}"
    systemctl stop hysteria-server 2>/dev/null || true
    systemctl disable hysteria-server 2>/dev/null || true
    pkill -f hysteria || true
    
    rm -rf /etc/hysteria
    rm -rf /root/H2
    rm -f /usr/local/bin/hysteria
    rm -f /usr/local/bin/h2
    rm -f /etc/systemd/system/hysteria-server.service
    rm -f /etc/sysctl.d/99-hysteria.conf
    rm -f /etc/security/limits.d/99-hysteria.conf
    rm -f /root/main.sh
    
    systemctl daemon-reload
}

# 安装基础依赖
install_base() {
    echo -e "${YELLOW}安装基础依赖...${NC}"
    if [ -f /etc/debian_version ]; then
        apt update
        apt install -y curl wget openssl
    elif [ -f /etc/redhat-release ]; then
        yum install -y curl wget openssl
    else
        echo -e "${RED}不支持的系统${NC}"
        exit 1
    fi
}

# 安装Hysteria
install_hysteria() {
    echo -e "${YELLOW}开始安装Hysteria...${NC}"
    
    local urls=(
        "https://mirror.ghproxy.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://gh.ddlc.top/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://hub.gitmirror.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    )
    
    for url in "${urls[@]}"; do
        echo -e "${YELLOW}尝试从 ${url} 下载...${NC}"
        if wget -O /usr/local/bin/hysteria "$url" && 
           chmod +x /usr/local/bin/hysteria && 
           /usr/local/bin/hysteria version >/dev/null 2>&1; then
            echo -e "${GREEN}Hysteria安装成功${NC}"
            return 0
        fi
    done
    
    if curl -fsSL https://get.hy2.dev/ | bash; then
        echo -e "${GREEN}Hysteria安装成功${NC}"
        return 0
    fi

    echo -e "${RED}Hysteria安装失败${NC}"
    return 1
}

# 创建主程序
create_main_script() {
    echo -e "${YELLOW}创建主程序...${NC}"
    
    # 创建主脚本
    cat > /root/main.sh << 'MAINEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 服务端安装
install_server() {
    clear
    echo -e "${GREEN}开始安装 Hysteria 服务端...${NC}"
    
    # 获取公网IP
    domain=$(curl -s ipv4.domains.google.com || curl -s ifconfig.me)
    port=443
    password=$(openssl rand -base64 16)
    socks_port=1080
    
    mkdir -p /etc/hysteria
    mkdir -p /root/H2
    
    # 生成自签证书
    openssl req -x509 -newkey rsa:4096 -nodes -sha256 -days 365 \
        -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt \
        -subj "/CN=$domain" 2>/dev/null
    
    # 生成服务端配置
    cat > /etc/hysteria/config.yaml << EOF
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
    cat > "/root/H2/client_${port}_${socks_port}.json" << EOF
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
    
    # 创建服务
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
    systemctl enable hysteria-server
    systemctl start hysteria-server
    
    echo -e "${GREEN}安装完成！${NC}"
    echo -e "服务端配置：/etc/hysteria/config.yaml"
    echo -e "客户端配置：/root/H2/client_${port}_${socks_port}.json"
    echo -e "服务端口：${port}"
    echo -e "SOCKS5端口：${socks_port}"
    echo -e "验证密码：${password}"
    sleep 3
}

# 系统优化
optimize_system() {
    echo -e "${YELLOW}正在优化系统配置...${NC}"
    
    cat > /etc/sysctl.d/99-hysteria.conf << EOF
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.core.rmem_default=4194304
net.core.wmem_default=4194304
net.ipv4.tcp_rmem=4096 87380 4194304
net.ipv4.tcp_wmem=4096 87380 4194304
EOF
    
    sysctl -p /etc/sysctl.d/99-hysteria.conf
    
    cat > /etc/security/limits.d/99-hysteria.conf << EOF
* soft nofile 65535
* hard nofile 65535
EOF

    echo -e "${GREEN}系统优化完成${NC}"
    sleep 2
}

# 版本更新
update_version() {
    echo -e "${YELLOW}正在检查更新...${NC}"
    if curl -fsSL https://get.hy2.dev/ | bash; then
        echo -e "${GREEN}更新成功${NC}"
        systemctl restart hysteria-server
    else
        echo -e "${RED}更新失败${NC}"
    fi
    sleep 2
}

# 完全卸载
uninstall() {
    echo -e "${YELLOW}正在卸载...${NC}"
    
    systemctl stop hysteria-server
    systemctl disable hysteria-server
    
    rm -rf /etc/hysteria
    rm -rf /root/H2
    rm -f /usr/local/bin/hysteria
    rm -f /usr/local/bin/h2
    rm -f /etc/systemd/system/hysteria-server.service
    rm -f /etc/sysctl.d/99-hysteria.conf
    rm -f /etc/security/limits.d/99-hysteria.conf
    rm -f /root/main.sh
    
    systemctl daemon-reload
    
    echo -e "${GREEN}卸载完成${NC}"
    exit 0
}

# 主菜单
while true; do
    clear
    echo -e "${GREEN}════════ Hysteria 管理脚本 ════════${NC}"
    echo -e "${GREEN}作者: Qiujianm${NC}"
    echo -e "${GREEN}版本: 2025-02-19${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo "1. 安装服务端"
    echo "2. 服务端管理"
    echo "3. 客户端管理"
    echo "4. 系统优化"
    echo "5. 版本更新"
    echo "6. 运行状态"
    echo "7. 完全卸载"
    echo "0. 退出脚本"
    echo -e "${GREEN}====================================${NC}"
    
    read -p "请选择 [0-7]: " choice
    case $choice in
        1) install_server ;;
        2)
            clear
            echo -e "${GREEN}═══════ 服务端管理 ═══════${NC}"
            echo "1. 启动服务"
            echo "2. 停止服务"
            echo "3. 重启服务"
            echo "4. 查看状态"
            echo "5. 查看日志"
            echo "0. 返回主菜单"
            echo -e "${GREEN}=========================${NC}"
            read -p "请选择 [0-5]: " schoice
            case $schoice in
                1) systemctl start hysteria-server ;;
                2) systemctl stop hysteria-server ;;
                3) systemctl restart hysteria-server ;;
                4) systemctl status hysteria-server ;;
                5) journalctl -u hysteria-server ;;
                0) continue ;;
                *) echo -e "${RED}无效选择${NC}" ;;
            esac
            ;;
        3)
            clear
            echo -e "${GREEN}═══════ 客户端管理 ═══════${NC}"
            echo "1. 查看客户端配置"
            echo "0. 返回主菜单"
            echo -e "${GREEN}=========================${NC}"
            read -p "请选择 [0-1]: " cchoice
            case $cchoice in
                1) ls -l /root/H2/ ;;
                0) continue ;;
                *) echo -e "${RED}无效选择${NC}" ;;
            esac
            ;;
        4) optimize_system ;;
        5) update_version ;;
        6) systemctl status hysteria-server ;;
        7) uninstall ;;
        0) exit 0 ;;
        *) 
            echo -e "${RED}无效选择${NC}"
            sleep 2
            ;;
    esac
done
MAINEOF
    
    chmod +x /root/main.sh
}

# 创建目录和命令链接
setup_environment() {
    mkdir -p /etc/hysteria
    mkdir -p /root/H2
    
    cat > /usr/local/bin/h2 << 'EOF'
#!/bin/bash
cd /root
[ "$EUID" -ne 0 ] && echo -e "\033[0;31m请使用root权限运行此脚本\033[0m" && exit 1
bash ./main.sh
EOF
    chmod +x /usr/local/bin/h2
}

# 主函数
main() {
    clear
    echo -e "${GREEN}════════ Hysteria 管理脚本 安装程序 ════════${NC}"
    echo -e "${GREEN}作者: ${AUTHOR}${NC}"
    echo -e "${GREEN}版本: ${VERSION}${NC}"
    echo -e "${GREEN}============================================${NC}"
    
    cleanup_old_installation
    install_base
    
    install_hysteria || {
        echo -e "${RED}Hysteria 安装失败，请检查网络或手动安装${NC}"
        exit 1
    }
    
    create_main_script
    setup_environment
    
    echo -e "\n${GREEN}安装完成！${NC}"
    echo -e "使用 ${YELLOW}h2${NC} 命令启动管理面板"
}

main