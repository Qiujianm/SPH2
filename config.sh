#!/bin/bash

# 配置文件路径
HYSTERIA_CONFIG="/etc/hysteria/config.yaml"
CLIENT_DIR="/root/H2"

# 系统优化
optimize_system() {
    cat > /etc/sysctl.d/99-hysteria.conf << EOF
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_mem=25600 51200 102400
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
EOF
    sysctl -p /etc/sysctl.d/99-hysteria.conf
    
    cat > /etc/security/limits.d/99-hysteria.conf << EOF
* soft nofile 65535
* hard nofile 65535
EOF

    echo -e "${GREEN}系统优化完成${NC}"
    sleep 2
}

# 检查更新
check_update() {
    echo -e "${YELLOW}正在检查更新...${NC}"
    bash setup.sh
    sleep 2
}

# 显示状态
show_status() {
    clear
    echo -e "${GREEN}═══════ 运行状态 ═══════${NC}"
    
    if systemctl is-active --quiet hysteria-server; then
        echo -e "服务端状态: ${GREEN}运行中${NC}"
    else
        echo -e "服务端状态: ${RED}未运行${NC}"
    fi
    
    if pgrep -f "hysteria client" >/dev/null; then
        echo -e "\n${GREEN}运行中的客户端:${NC}"
        ps aux | grep "[h]ysteria client"
    else
        echo -e "\n${YELLOW}无运行中的客户端${NC}"
    fi
    
    read -n 1 -s -r -p "按任意键继续..."
}

# 完全卸载
uninstall() {
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
    
    systemctl daemon-reload
    
    echo -e "${GREEN}卸载完成${NC}"
    exit 0
}