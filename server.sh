#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 配置文件路径
HYSTERIA_CONFIG="/etc/hysteria/config.yaml"

# 端口检查函数
check_port() {
    local port=$1
    if netstat -tuln | grep -qE ":${port}\b"; then
        printf "%b端口 $port 已被占用%b\n" "${RED}" "${NC}"
        return 1
    fi
    return 0
}

# 服务检查函数
check_service() {
    printf "%b正在检查服务状态...%b\n" "${YELLOW}" "${NC}"
    
    # 检查配置文件
    if [ ! -f "$HYSTERIA_CONFIG" ]; then
        printf "%b错误: 配置文件不存在%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 检查证书文件
    if [ ! -f "/etc/hysteria/server.crt" ] || [ ! -f "/etc/hysteria/server.key" ]; then
        printf "%b错误: 证书文件不存在%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 检查程序
    if [ ! -f "/usr/local/bin/hysteria" ]; then
        printf "%b错误: Hysteria程序不存在%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    return 0
}

# 生成服务端配置
# 在 server.sh 中修改 generate_server_config 函数
generate_server_config() {
    printf "%b开始生成配置...%b\n" "${YELLOW}" "${NC}"
    
    # 获取 SOCKS5 端口
    local socks_port
    while true; do
        read -p "请输入SOCKS5端口 [1080]: " socks_port
        socks_port=${socks_port:-1080}
        
        # 检查端口合法性
        if ! [[ "$socks_port" =~ ^[0-9]+$ ]] || [ "$socks_port" -lt 1 ] || [ "$socks_port" -gt 65535 ]; then
            printf "%b错误: 请输入有效的端口号 (1-65535)%b\n" "${RED}" "${NC}"
            continue
        fi
        
        # 检查端口占用
        if netstat -tuln | grep -q ":$socks_port "; then
            printf "%b端口 %s 已被占用，请选择其他端口%b\n" "${RED}" "$socks_port" "${NC}"
            continue
        fi
        break
    done
    
    # 获取IP地址
    printf "%b正在获取服务器IP...%b\n" "${YELLOW}" "${NC}"
# 使用国内可以稳定访问的IP查询服务
local domain=$(curl -s ipinfo.io/ip || curl -s myip.ipip.net | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" || curl -s https://api.ip.sb/ip)
if [ -z "$domain" ]; then
    printf "%b警告: 无法自动获取公网IP，请手动输入%b\n" "${YELLOW}" "${NC}"
    read -p "请输入服务器公网IP: " domain
fi

    # 设置其他参数
    local port=443
    local password=$(openssl rand -base64 16)
    
    printf "%b创建配置目录...%b\n" "${YELLOW}" "${NC}"
    # 创建必要的目录
    mkdir -p /etc/hysteria
    
    printf "%b生成SSL证书...%b\n" "${YELLOW}" "${NC}"
    # 生成证书
    if ! openssl req -x509 -newkey rsa:4096 -nodes -sha256 -days 365 \
        -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt \
        -subj "/CN=$domain" 2>/dev/null; then
        printf "%b证书生成失败%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    printf "%b生成服务端配置...%b\n" "${YELLOW}" "${NC}"
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
  proxy:
    url: https://www.bing.com
    rewriteHost: true

quic:
  initStreamReceiveWindow: 26843545
  maxStreamReceiveWindow: 26843545
  initConnReceiveWindow: 53687090
  maxConnReceiveWindow: 53687090

bandwidth:
  up: 200 mbps
  down: 200 mbps
EOF
    
    printf "%b生成客户端配置...%b\n" "${YELLOW}" "${NC}"
    # 生成客户端配置
    local client_config="/root/${domain}_${port}_${socks_port}.json"
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

    printf "%b配置生成完成：%b\n" "${GREEN}" "${NC}"
    echo "服务端配置：${HYSTERIA_CONFIG}"
    echo "客户端配置：${client_config}"
    echo "服务器IP：${domain}"
    echo "服务端口：${port}"
    echo "SOCKS5端口：${socks_port}"
    echo "验证密码：${password}"
    
    return 0
}

# 服务控制函数
service_control() {
    local action=$1
    local max_wait=5
    
    # 辅助函数：检查具体错误
    check_error() {
        printf "\n%b正在进行故障诊断...%b\n" "${YELLOW}" "${NC}"
        
        # 检查配置文件
        printf "\n%b检查配置文件内容:%b\n" "${YELLOW}" "${NC}"
        cat "$HYSTERIA_CONFIG"
        
        # 检查端口占用
        printf "\n%b检查端口占用:%b\n" "${YELLOW}" "${NC}"
        local port=$(grep -Po 'listen: :\K\d+' "$HYSTERIA_CONFIG")
        if netstat -tuln | grep -q ":$port "; then
            printf "%b端口 $port 已被占用%b\n" "${RED}" "${NC}"
            netstat -tuln | grep ":$port "
        fi
        
        # 检查证书文件
        printf "\n%b检查证书文件:%b\n" "${YELLOW}" "${NC}"
        if ! [ -r "/etc/hysteria/server.crt" ] || ! [ -r "/etc/hysteria/server.key" ]; then
            printf "%b证书文件不存在或无法读取%b\n" "${RED}" "${NC}"
            ls -l /etc/hysteria/server.{crt,key}
        fi
        
        # 检查日志
        printf "\n%b最近的错误日志:%b\n" "${YELLOW}" "${NC}"
        journalctl -u hysteria-server --no-pager -n 20
    }
    
    case "$action" in
        "start")
            printf "%b正在启动服务...%b" "${GREEN}" "${NC}"
            systemctl start hysteria-server &
            for ((i=1; i<=max_wait; i++)); do
                if systemctl is-active hysteria-server >/dev/null 2>&1; then
                    printf "\r%b[成功]%b 服务启动成功\n" "${GREEN}" "${NC}"
                    return 0
                fi
                printf "."
                sleep 1
            done
            printf "\r%b[失败]%b 服务启动失败\n" "${RED}" "${NC}"
            check_error
            ;;
        "stop")
            printf "%b正在停止服务...%b" "${GREEN}" "${NC}"
            systemctl stop hysteria-server &
            for ((i=1; i<=max_wait; i++)); do
                if ! systemctl is-active hysteria-server >/dev/null 2>&1; then
                    printf "\r%b[完成]%b 服务已停止\n" "${YELLOW}" "${NC}"
                    return 0
                fi
                printf "."
                sleep 1
            done
            printf "\r%b[失败]%b 服务停止失败\n" "${RED}" "${NC}"
            ;;
        "restart")
            printf "%b正在重启服务...%b" "${GREEN}" "${NC}"
            systemctl restart hysteria-server &
            for ((i=1; i<=max_wait; i++)); do
                if systemctl is-active hysteria-server >/dev/null 2>&1; then
                    printf "\r%b[成功]%b 服务重启成功\n" "${GREEN}" "${NC}"
                    return 0
                fi
                printf "."
                sleep 1
            done
            printf "\r%b[失败]%b 服务重启失败\n" "${RED}" "${NC}"
            check_error
            ;;
        "status")
            if ! timeout 2 systemctl status hysteria-server; then
                printf "\n%b[错误]%b 服务状态异常\n" "${RED}" "${NC}"
                check_error
            fi
            ;;
    esac
}

# 服务端管理菜单
server_menu() {
    while true; do
        clear
        printf "%b═══════ Hysteria 服务端管理 ═══════%b\n" "${GREEN}" "${NC}"
        echo "1. 启动服务端"
        echo "2. 停止服务端"
        echo "3. 重启服务端"
        echo "4. 查看服务端状态"
        echo "6. 全自动生成配置"
        echo "7. 手动生成配置"
        echo "0. 返回主菜单"
        printf "%b====================================%b\n" "${GREEN}" "${NC}"
        
        read -t 60 -p "请选择 [0-7]: " option || {
            printf "\n%b操作超时，返回主菜单%b\n" "${YELLOW}" "${NC}"
            return
        }

        case $option in
            1|2|3|4)
                case $option in
                    1) service_control "start";;
                    2) service_control "stop";;
                    3) service_control "restart";;
                    4) service_control "status";;
                esac
                read -t 30 -n 1 -s -r -p "按任意键继续..."
                ;;
            6|7)
                generate_server_config
                service_control "restart"
                read -t 30 -n 1 -s -r -p "按任意键继续..."
                ;;
            0)
                return
                ;;
            *)
                printf "%b无效选择%b\n" "${RED}" "${NC}"
                sleep 1
                ;;
        esac
    done
}

case "$1" in
    "install")
        generate_server_config
        ;;
    "manage")
        server_menu
        ;;
    *)
        echo "用法: $0 {install|manage}"
        exit 1
        ;;
esac
