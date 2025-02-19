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

# 创建并赋权所有模块脚本
create_all_scripts() {
    echo -e "${YELLOW}创建所有模块脚本...${NC}"
    
    # 创建目录
    mkdir -p /root/H2 /etc/hysteria

    # 创建并赋权 main.sh
    cat > /root/main.sh << 'MAINEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

VERSION="2025-02-19"
AUTHOR="Qiujianm"

while true; do
    clear
    echo -e "${GREEN}════════ Hysteria 管理脚本 ════════${NC}"
    echo -e "${GREEN}作者: ${AUTHOR}${NC}"
    echo -e "${GREEN}版本: ${VERSION}${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo "1. 安装模式"
    echo "2. 服务端管理"
    echo "3. 客户端管理"
    echo "4. 系统优化"
    echo "5. 检查更新"
    echo "6. 运行状态"
    echo "7. 完全卸载"
    echo "0. 退出脚本"
    echo -e "${GREEN}====================================${NC}"
    
    read -p "请选择 [0-7]: " choice
    case $choice in
        1)
            bash ./server.sh install
            ;;
        2)
            bash ./server.sh manage
            ;;
        3)
            bash ./client.sh
            ;;
        4)
            bash ./config.sh optimize
            ;;
        5)
            bash ./config.sh update
            ;;
        6)
            systemctl status hysteria-server
            read -n 1 -s -r -p "按任意键继续..."
            ;;
        7)
            bash ./config.sh uninstall
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            sleep 2
            ;;
    esac
done
MAINEOF
    chmod +x /root/main.sh

    # 创建并赋权 server.sh
    cat > /root/server.sh << 'SERVEREOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 服务端安装
install() {
    clear
    auto_generate_config
}

# 自动生成配置
auto_generate_config() {
    echo -e "${GREEN}正在生成服务端配置...${NC}"
    
    domain=$(curl -s ipv4.domains.google.com || curl -s ifconfig.me)
    port=443
    password=$(openssl rand -base64 16)
    
    generate_server_config "$domain" "$port" "$password"
}

# 手动生成配置
manual_generate_config() {
    read -p "请输入域名/IP: " domain
    read -p "请输入端口(默认443): " port
    port=${port:-443}
    read -p "请输入密码(留空自动生成): " password
    password=${password:-$(openssl rand -base64 16)}
    
    generate_server_config "$domain" "$port" "$password"
}

# 生成服务器配置
generate_server_config() {
    local domain=$1
    local port=$2
    local password=$3
    local socks_port=1080
    
    mkdir -p /etc/hysteria
    mkdir -p /root/H2
    
    # 生成证书
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
    cat > "/root/H2/client_${port}.json" << EOF
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
    
    echo -e "${GREEN}配置生成完成！${NC}"
    echo -e "服务端配置：/etc/hysteria/config.yaml"
    echo -e "客户端配置：/root/H2/client_${port}.json"
    echo -e "服务端口：${port}"
    echo -e "SOCKS5端口：${socks_port}"
    echo -e "验证密码：${password}"
    sleep 3
}

# 服务端管理菜单
manage() {
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
        echo -e "${GREEN}=========================${NC}"
        
        read -p "请选择 [0-7]: " choice
        case $choice in
            1)
                systemctl start hysteria-server
                echo -e "${GREEN}服务端已启动${NC}"
                sleep 2
                ;;
            2)
                systemctl stop hysteria-server
                echo -e "${YELLOW}服务端已停止${NC}"
                sleep 2
                ;;
            3)
                systemctl restart hysteria-server
                echo -e "${GREEN}服务端已重启${NC}"
                sleep 2
                ;;
            4)
                clear
                systemctl status hysteria-server
                read -n 1 -s -r -p "按任意键继续..."
                ;;
            6)
                auto_generate_config
                ;;
            7)
                manual_generate_config
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                sleep 2
                ;;
        esac
    done
}

case "$1" in
    "install")
        install
        ;;
    "manage")
        manage
        ;;
    *)
        echo "用法: $0 {install|manage}"
        exit 1
        ;;
esac
SERVEREOF
    chmod +x /root/server.sh

    # 创建并赋权 client.sh
    cat > /root/client.sh << 'CLIENTEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

while true; do
    clear
    echo -e "${GREEN}═══════ Hysteria 客户端管理 ═══════${NC}"
    echo "1. 启动客户端"
    echo "2. 停止客户端"
    echo "3. 重启客户端"
    echo "4. 查看客户端状态"
    echo "5. 删除客户端配置"
    echo "0. 返回主菜单"
    echo -e "${GREEN}=========================${NC}"
    
    read -p "请选择 [0-5]: " choice
    case $choice in
        1)
            if [ -f "/root/H2/hysteria-client.pid" ]; then
                echo -e "${YELLOW}客户端已在运行${NC}"
            else
                config_file=$(ls /root/H2/client_*.json | head -1)
                if [ -n "$config_file" ]; then
                    /usr/local/bin/hysteria client -c "$config_file" &
                    echo $! > /root/H2/hysteria-client.pid
                    echo -e "${GREEN}客户端已启动${NC}"
                else
                    echo -e "${RED}未找到客户端配置文件${NC}"
                fi
            fi
            sleep 2
            ;;
        2)
            if [ -f "/root/H2/hysteria-client.pid" ]; then
                kill $(cat /root/H2/hysteria-client.pid)
                rm -f /root/H2/hysteria-client.pid
                echo -e "${YELLOW}客户端已停止${NC}"
            else
                echo -e "${RED}客户端未运行${NC}"
            fi
            sleep 2
            ;;
        3)
            if [ -f "/root/H2/hysteria-client.pid" ]; then
                kill $(cat /root/H2/hysteria-client.pid)
                rm -f /root/H2/hysteria-client.pid
            fi
            config_file=$(ls /root/H2/client_*.json | head -1)
            if [ -n "$config_file" ]; then
                /usr/local/bin/hysteria client -c "$config_file" &
                echo $! > /root/H2/hysteria-client.pid
                echo -e "${GREEN}客户端已重启${NC}"
            else
                echo -e "${RED}未找到客户端配置文件${NC}"
            fi
            sleep 2
            ;;
        4)
            if [ -f "/root/H2/hysteria-client.pid" ]; then
                echo -e "${GREEN}客户端正在运行${NC}"
                ps -p $(cat /root/H2/hysteria-client.pid)
            else
                echo -e "${RED}客户端未运行${NC}"
            fi
            read -n 1 -s -r -p "按任意键继续..."
            ;;
        5)
            echo "可用的客户端配置文件："
            ls -1 /root/H2/client_*.json 2>/dev/null
            read -p "请输入要删除的配置文件名称: " filename
            if [ -f "/root/H2/$filename" ]; then
                rm -f "/root/H2/$filename"
                echo -e "${GREEN}配置文件已删除${NC}"
            else
                echo -e "${RED}文件不存在${NC}"
            fi
            sleep 2
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            sleep 2
            ;;
    esac
done
CLIENTEOF
    chmod +x /root/client.sh

    # 创建并赋权 config.sh
    cat > /root/config.sh << 'CONFIGEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 系统优化
optimize() {
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
update() {
    echo -e "${YELLOW}正在检查更新...${NC}"
    
    # 备份当前配置
    cp /etc/hysteria/config.yaml /etc/hysteria/config.yaml.bak
    
    if curl -fsSL https://get.hy2.dev/ | bash; then
        echo -e "${GREEN}更新成功${NC}"
        systemctl restart hysteria-server
    else
        echo -e "${RED}更新失败${NC}"
        # 恢复配置
        mv /etc/hysteria/config.yaml.bak /etc/hysteria/config.yaml
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
    rm -f /rm -f /root/{main,server,client,config}.sh
    
    systemctl daemon-reload
    
    echo -e "${GREEN}卸载完成${NC}"
    exit 0
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
cd /root
[ "$EUID" -ne 0 ] && echo -e "\033[0;31m请使用root权限运行此脚本\033[0m" && exit 1
bash ./main.sh
CMDEOF
    chmod +x /usr/local/bin/h2

    echo -e "${GREEN}所有模块脚本创建完成${NC}"
}

# 清理函数
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
    rm -f /root/{main,server,client,config}.sh
    
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

# 主函数
main() {
    clear
    echo -e "${GREEN}════════ Hysteria 管理脚本 安装程序 ════════${NC}"
    echo -e "${GREEN}作者: ${AUTHOR}${NC}"
    echo -e "${GREEN}版本: ${VERSION}${NC}"
    echo -e "${GREEN}============================================${NC}"
    
    # 清理旧安装
    cleanup_old_installation
    
    # 安装基础依赖
    install_base
    
    # 安装Hysteria
    install_hysteria || {
        echo -e "${RED}Hysteria 安装失败，请检查网络或手动安装${NC}"
        exit 1
    }
    
    # 创建所有脚本
    create_all_scripts
    
    echo -e "\n${GREEN}安装完成！${NC}"
    echo -e "使用 ${YELLOW}h2${NC} 命令启动管理面板"
}

main
