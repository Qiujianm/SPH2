#!/bin/bash

VERSION="2025-02-19"
AUTHOR="Qiujianm"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 检查root权限
[ "$EUID" -ne 0 ] && echo -e "${RED}请使用root权限运行此脚本${NC}" && exit 1

# 打印状态函数
print_status() {
    local type=$1
    local message=$2
    case "$type" in
        "info")
            printf "%b[信息]%b %s" "${GREEN}" "${NC}" "$message"
            ;;
        "warn")
            printf "%b[警告]%b %s" "${YELLOW}" "${NC}" "$message"
            ;;
        "error")
            printf "%b[错误]%b %s" "${RED}" "${NC}" "$message"
            ;;
    esac
}

# 创建并赋权所有模块脚本
create_all_scripts() {
    print_status "info" "创建所有模块脚本...\n"
    
    # 创建目录
    mkdir -p /root/hysteria

    # 创建并赋权 main.sh
cat > /root/hysteria/main.sh << 'MAINEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

VERSION="2025-02-19"
AUTHOR="Qiujianm"

while true; do
    clear
    printf "%b════════ Hysteria 管理脚本 ════════%b\n" "${GREEN}" "${NC}"
    printf "%b作者: ${AUTHOR}%b\n" "${GREEN}" "${NC}"
    printf "%b版本: ${VERSION}%b\n" "${GREEN}" "${NC}"
    printf "%b====================================%b\n" "${GREEN}" "${NC}"
    echo "1. 安装模式"
    echo "2. 服务端管理"
    echo "3. 客户端管理"
    echo "4. 系统优化"
    echo "5. 检查更新"
    echo "6. 运行状态"
    echo "7. 完全卸载"
    echo "0. 退出脚本"
    printf "%b====================================%b\n" "${GREEN}" "${NC}"
    
    read -t 60 -p "请选择 [0-7]: " choice || {
        printf "\n%b操作超时，退出脚本%b\n" "${YELLOW}" "${NC}"
        exit 1
    }
    
    case $choice in
        1) bash ./server.sh install ;;
        2) bash ./server.sh manage ;;
        3) bash ./client.sh ;;
        4) bash ./config.sh optimize ;;
        5) bash ./config.sh update ;;
        6)
            systemctl status hysteria-server
            read -t 30 -n 1 -s -r -p "按任意键继续..."
            ;;
        7) bash ./config.sh uninstall ;;
        0) exit 0 ;;
        *)
            printf "%b无效选择%b\n" "${RED}" "${NC}"
            sleep 1
            ;;
    esac
done
MAINEOF
    chmod +x /root/main.sh

    # 创建并赋权 server.sh
cat > /root/hysteria/server.sh << 'SERVEREOF'
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
SERVEREOF
    chmod +x /root/server.sh

    # 创建并赋权 client.sh
cat > /root/hysteria/client.sh << 'CLIENTEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 客户端状态检查函数
check_client_status() {
    printf "\n%b正在进行客户端检查...%b\n" "${YELLOW}" "${NC}"
    
    # 检查配置文件
    local config_file=$(ls /root/*.json 2>/dev/null | head -1)
    if [ ! -f "$config_file" ]; then
                printf "%b错误: 未找到配置文件%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 检查程序是否存在
    if [ ! -f "/usr/local/bin/hysteria" ]; then
        printf "%b错误: Hysteria程序不存在%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 检查运行状态
    if [ -f "/root/hysteria-client.pid" ]; then
        local pid=$(cat /root/hysteria-client.pid)
        if ps -p $pid >/dev/null 2>&1; then
            printf "%b客户端进程运行中 (PID: $pid)%b\n" "${GREEN}" "${NC}"
            
            # 检查SOCKS5端口
            local socks_port=$(grep -oP '"listen": "0.0.0.0:\K\d+' "$config_file")
            if netstat -tuln | grep -q ":$socks_port "; then
                printf "%bSOCKS5端口($socks_port)正常监听%b\n" "${GREEN}" "${NC}"
                netstat -tuln | grep ":$socks_port "
            else
                printf "%bSOCKS5端口($socks_port)未正常监听%b\n" "${RED}" "${NC}"
            fi
        else
            printf "%b客户端进程已终止 (PID文件存在但进程不存在)%b\n" "${RED}" "${NC}"
            rm -f /root/hysteria-client.pid
        fi
    else
        printf "%b客户端未运行%b\n" "${YELLOW}" "${NC}"
        # 显示上次运行日志
        if [ -f "/var/log/hysteria-client.log" ]; then
            printf "\n%b上次运行日志:%b\n" "${YELLOW}" "${NC}"
            tail -n 10 /var/log/hysteria-client.log
        fi
    fi
}

while true; do
    clear
    printf "%b═══════ Hysteria 客户端管理 ═══════%b\n" "${GREEN}" "${NC}"
    echo "1. 启动客户端"
    echo "2. 停止客户端"
    echo "3. 重启客户端"
    echo "4. 查看客户端状态"
    echo "5. 删除客户端配置"
    echo "0. 返回主菜单"
    printf "%b====================================%b\n" "${GREEN}" "${NC}"
    
    read -t 60 -p "请选择 [0-5]: " choice || {
        printf "\n%b操作超时，返回主菜单%b\n" "${YELLOW}" "${NC}"
        exit 0
    }

    case $choice in
        1)
            if [ -f "/root/hysteria-client.pid" ]; then
                printf "%b客户端已在运行%b\n" "${YELLOW}" "${NC}"
            else
                config_file=$(ls /root/*.json | head -1)
                if [ -n "$config_file" ]; then
                    printf "%b使用配置文件: %s%b\n" "${GREEN}" "$config_file" "${NC}"
                    /usr/local/bin/hysteria client -c "$config_file" \
                        --log-level info \
                        > /var/log/hysteria-client.log 2>&1 &
                    echo $! > /root/hysteria-client.pid
                    sleep 2
                    check_client_status
                else
                    printf "%b未找到客户端配置文件%b\n" "${RED}" "${NC}"
                fi
            fi
            read -t 30 -n 1 -s -r -p "按任意键继续..."
            ;;
        2)
            if [ -f "/root/hysteria-client.pid" ]; then
                kill $(cat /root/hysteria-client.pid) 2>/dev/null
                rm -f /root/hysteria-client.pid
                printf "%b客户端已停止%b\n" "${YELLOW}" "${NC}"
                if [ -f "/var/log/hysteria-client.log" ]; then
                    printf "\n%b最后的日志记录:%b\n" "${YELLOW}" "${NC}"
                    tail -n 5 /var/log/hysteria-client.log
                fi
            else
                printf "%b客户端未运行%b\n" "${RED}" "${NC}"
            fi
            read -t 30 -n 1 -s -r -p "按任意键继续..."
            ;;
        3)
            if [ -f "/root/hysteria-client.pid" ]; then
                kill $(cat /root/hysteria-client.pid) 2>/dev/null
                rm -f /root/hysteria-client.pid
            fi
            config_file=$(ls /root/*.json | head -1)
            if [ -n "$config_file" ]; then
                printf "%b使用配置文件: %s%b\n" "${GREEN}" "$config_file" "${NC}"
                /usr/local/bin/hysteria client -c "$config_file" \
                    --log-level info \
                    > /var/log/hysteria-client.log 2>&1 &
                echo $! > /root/hysteria-client.pid
                sleep 2
                check_client_status
            else
                printf "%b未找到客户端配置文件%b\n" "${RED}" "${NC}"
            fi
            read -t 30 -n 1 -s -r -p "按任意键继续..."
            ;;
        4)
            clear
            printf "%b═══════ 客户端状态检查 ═══════%b\n" "${GREEN}" "${NC}"
            check_client_status
            printf "%b═══════════════════════════%b\n" "${GREEN}" "${NC}"
            read -t 30 -n 1 -s -r -p "按任意键继续..."
            ;;
        5)
            printf "\n%b可用的客户端配置文件：%b\n" "${YELLOW}" "${NC}"
            ls -l /root/*.json 2>/dev/null || echo "无配置文件"
            echo
            read -t 60 -p "请输入要删除的配置文件名称: " filename
            if [ -f "/root/$filename" ]; then
                rm -f "/root/$filename"
                printf "%b配置文件已删除%b\n" "${GREEN}" "${NC}"
            else
                printf "%b文件不存在%b\n" "${RED}" "${NC}"
            fi
            read -t 30 -n 1 -s -r -p "按任意键继续..."
            ;;
        0)
            exit 0
            ;;
        *)
            printf "%b无效选择%b\n" "${RED}" "${NC}"
            sleep 1
            ;;
    esac
done
CLIENTEOF
    chmod +x /root/client.sh

    # 创建并赋权 config.sh
cat > /root/hysteria/config.sh << 'CONFIGEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 系统优化
optimize() {
    printf "%b正在优化系统配置...%b\n" "${YELLOW}" "${NC}"
    
    # 创建sysctl配置文件
    cat > /etc/sysctl.d/99-hysteria.conf << EOF
# 设置16MB缓冲区
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=16777216
net.core.wmem_default=16777216
# TCP缓冲区设置
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 87380 16777216
# 启用Brutal拥塞控制
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=brutal
# 其他网络优化
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
# Hysteria QUIC优化
net.ipv4.ip_forward=1
net.ipv4.tcp_mtu_probing=1
EOF
    
    # 立即应用sysctl设置
    sysctl -p /etc/sysctl.d/99-hysteria.conf
    
    # 设置系统文件描述符限制
    cat > /etc/security/limits.d/99-hysteria.conf << EOF
* soft nofile 1000000
* hard nofile 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF

    # 立即设置当前会话的缓冲区
    sysctl -w net.core.rmem_max=16777216
    sysctl -w net.core.wmem_max=16777216

    printf "%b系统优化完成，已设置：%b\n" "${GREEN}" "${NC}"
    echo "1. 发送/接收缓冲区: 16MB"
    echo "2. 文件描述符限制: 1000000"
    echo "3. Brutal拥塞控制"
    echo "4. TCP Fast Open"
    echo "5. QUIC优化"
    sleep 2
}

# 版本更新
update() {
    printf "%b正在检查更新...%b\n" "${YELLOW}" "${NC}"
    
    # 备份当前配置
    cp /etc/hysteria/config.yaml /etc/hysteria/config.yaml.bak 2>/dev/null
    
    # 尝试多个下载源
    local urls=(
        "https://mirror.ghproxy.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://gh.ddlc.top/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://hub.gitmirror.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    )
    
    local success=false
    for url in "${urls[@]}"; do
        printf "%b尝试从 %s 下载...%b\n" "${YELLOW}" "$url" "${NC}"
        if wget -O /usr/local/bin/hysteria.new "$url" && 
           chmod +x /usr/local/bin/hysteria.new &&
           /usr/local/bin/hysteria.new version >/dev/null 2>&1; then
            mv /usr/local/bin/hysteria.new /usr/local/bin/hysteria
            printf "%b更新成功%b\n" "${GREEN}" "${NC}"
            success=true
            break
        fi
        rm -f /usr/local/bin/hysteria.new
    done
    
    if ! $success; then
        if curl -fsSL https://get.hy2.dev/ | bash; then
            printf "%b更新成功%b\n" "${GREEN}" "${NC}"
        else
            printf "%b更新失败%b\n" "${RED}" "${NC}"
            [ -f /etc/hysteria/config.yaml.bak ] && \
                mv /etc/hysteria/config.yaml.bak /etc/hysteria/config.yaml
            return 1
        fi
    fi
    
    systemctl restart hysteria-server
    sleep 2
}

# 完全卸载
uninstall() {
    printf "%b═══════ 卸载确认 ═══════%b\n" "${YELLOW}" "${NC}"
    read -p "确定要卸载Hysteria吗？(y/n): " confirm
    if [[ $confirm == [yY] ]]; then
        printf "%b正在卸载...%b\n" "${YELLOW}" "${NC}"
        
        systemctl stop hysteria-server
        systemctl disable hysteria-server
        
        rm -rf /etc/hysteria
        rm -rf /root/H2
        rm -f /usr/local/bin/hysteria
        rm -f /usr/local/bin/h2
        rm -f /etc/systemd/system/hysteria-server.service
        rm -f /etc/sysctl.d/99-hysteria.conf
        rm -f /etc/security/limits.d/99-hysteria.conf
        rm -f /root/{main,server,client,config}.sh
        
        systemctl daemon-reload
        
        printf "%b卸载完成%b\n" "${GREEN}" "${NC}"
        exit 0
    fi
}

# 根据参数执行对应功能
case "$1" in
    "optimize")
        optimize
        ;;
    "update")
        update
        ;;
    "uninstall")
        uninstall
        ;;
    *)
        echo "用法: $0 {optimize|update|uninstall}"
        exit 1
        ;;
esac
CONFIGEOF
    chmod +x /root/config.sh

    # 创建启动器命令
    cat > /usr/local/bin/h2 << 'CMDEOF'
#!/bin/bash
cd /root/hysteria
[ "$EUID" -ne 0 ] && printf "\033[0;31m请使用root权限运行此脚本\033[0m\n" && exit 1
bash ./main.sh
CMDEOF
chmod +x /usr/local/bin/h2

    printf "%b所有模块脚本创建完成%b\n" "${GREEN}" "${NC}"
}

# 清理旧的安装
cleanup_old_installation() {
    printf "%b清理旧的安装...%b\n" "${YELLOW}" "${NC}"
    systemctl stop hysteria-server 2>/dev/null
    systemctl disable hysteria-server 2>/dev/null
    pkill -f hysteria
    
    rm -rf /etc/hysteria
    rm -rf /root/H2
    rm -f /usr/local/bin/hysteria
    rm -f /usr/local/bin/h2
    rm -f /etc/systemd/system/hysteria-server.service
    rm -f /etc/sysctl.d/99-hysteria.conf
    rm -f /etc/security/limits.d/99-hysteria.conf
        rm -f /root/{main,server,client,config}.sh
    
    systemctl daemon-reload
}

# 安装基础依赖
install_base() {
    printf "%b安装基础依赖...%b\n" "${YELLOW}" "${NC}"
    if [ -f /etc/debian_version ]; then
        apt update
        apt install -y curl wget openssl net-tools
    elif [ -f /etc/redhat-release ]; then
        yum install -y curl wget openssl net-tools
    else
        printf "%b不支持的系统%b\n" "${RED}" "${NC}"
        exit 1
    fi
}

# 安装Hysteria
install_hysteria() {
    printf "%b开始安装Hysteria...%b\n" "${YELLOW}" "${NC}"
    
    local urls=(
        "https://mirror.ghproxy.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://gh.ddlc.top/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://hub.gitmirror.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    )
    
    for url in "${urls[@]}"; do
        printf "%b尝试从 %s 下载...%b\n" "${YELLOW}" "$url" "${NC}"
        if wget -O /usr/local/bin/hysteria "$url" && 
           chmod +x /usr/local/bin/hysteria &&
           /usr/local/bin/hysteria version >/dev/null 2>&1; then
            printf "%bHysteria安装成功%b\n" "${GREEN}" "${NC}"
            return 0
        fi
    done
    
    if curl -fsSL https://get.hy2.dev/ | bash; then
        printf "%bHysteria安装成功%b\n" "${GREEN}" "${NC}"
        return 0
    fi

    printf "%bHysteria安装失败%b\n" "${RED}" "${NC}"
    return 1
}

# 创建systemd服务
create_systemd_service() {
    printf "%b创建systemd服务...%b\n" "${YELLOW}" "${NC}"
    
    cat > /etc/systemd/system/hysteria-server.service << EOF
[Unit]
Description=Hysteria Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable hysteria-server
    printf "%bSystemd服务创建完成%b\n" "${GREEN}" "${NC}"
}

# 主函数
main() {
    clear
    printf "%b════════ Hysteria 管理脚本 安装程序 ════════%b\n" "${GREEN}" "${NC}"
    printf "%b作者: ${AUTHOR}%b\n" "${GREEN}" "${NC}"
    printf "%b版本: ${VERSION}%b\n" "${GREEN}" "${NC}"
    printf "%b============================================%b\n" "${GREEN}" "${NC}"
    
    cleanup_old_installation
    install_base || exit 1
    install_hysteria || exit 1
    create_all_scripts
    create_systemd_service
    
    printf "\n%b安装完成！%b\n" "${GREEN}" "${NC}"
    printf "使用 %bh2%b 命令启动管理面板\n" "${YELLOW}" "${NC}"
}

main
