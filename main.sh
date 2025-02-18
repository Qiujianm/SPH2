#!/bin/bash
source /usr/local/SPH2/constants.sh

# 检查运行状态
check_running_status() {
    clear
    echo -e "${GREEN}═══════ 运行状态 ═══════${NC}"
    
    # 检查服务端状态
    if systemctl is-active --quiet hysteria-server; then
        echo -e "服务端状态: ${GREEN}运行中${NC}"
        echo -e "服务端配置文件: ${HYSTERIA_CONFIG}"
    else
        echo -e "服务端状态: ${RED}未运行${NC}"
    fi
    
    # 检查客户端状态
    echo -e "\n客户端状态:"
    if pgrep -f "hysteria client" >/dev/null; then
        echo -e "${GREEN}运行中的客户端:${NC}"
        ps aux | grep "[h]ysteria client" | while read -r line; do
            config=$(echo "$line" | grep -o '\-c.*json' | cut -d' ' -f2)
            if [ ! -z "$config" ]; then
                port=$(grep -o '"listen": "[^"]*"' "$config" | cut -d'"' -f4)
                echo "- 配置: $config (端口: $port)"
            fi
        done
    else
        echo -e "${YELLOW}无运行中的客户端${NC}"
    fi
    
    echo
    read -n 1 -s -r -p "按任意键继续..."
}

# 系统优化
optimize_system() {
    clear
    echo -e "${YELLOW}正在优化系统配置...${NC}"
    
    # 优化内核参数
    cat > /etc/sysctl.d/99-hysteria.conf <<EOF
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
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
EOF
    sysctl -p /etc/sysctl.d/99-hysteria.conf

    # 优化系统限制
    cat > /etc/security/limits.d/99-hysteria.conf <<EOF
* soft nofile 65535
* hard nofile 65535
EOF

    echo -e "${GREEN}系统优化完成${NC}"
    sleep 2
}

# 检查更新
check_update() {
    clear
    echo -e "${YELLOW}正在检查更新...${NC}"
    
    if command -v hysteria >/dev/null; then
        current_version=$(hysteria version | head -n1)
        echo "当前版本: $current_version"
        
        # 更新Hysteria
        curl -fsSL https://get.hy2.dev/ | bash
        
        new_version=$(hysteria version | head -n1)
        if [ "$current_version" != "$new_version" ]; then
            echo -e "${GREEN}已更新到新版本: $new_version${NC}"
        else
            echo -e "${GREEN}已是最新版本${NC}"
        fi
    else
        echo -e "${RED}Hysteria 未安装${NC}"
    fi

    sleep 2
}

# 完全卸载
uninstall() {
    clear
    echo -e "${YELLOW}开始卸载 Hysteria...${NC}"
    
    # 停止所有服务和进程
    systemctl stop hysteria-server 2>/dev/null || true
    systemctl disable hysteria-server 2>/dev/null || true
    pkill -f hysteria || true
    
    # 删除文件和目录
    rm -rf /etc/hysteria
    rm -rf /root/H2
    rm -rf /usr/local/SPH2
    rm -f /etc/systemd/system/hysteria-server.service
    rm -f /usr/local/bin/h2
    rm -f /usr/local/bin/hysteria
    rm -f /etc/sysctl.d/99-hysteria.conf
    rm -f /etc/security/limits.d/99-hysteria.conf
    
    # 重载系统配置
    systemctl daemon-reload
    sysctl --system >/dev/null 2>&1
    
    echo -e "${GREEN}卸载完成${NC}"
    sleep 2
    exit 0
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${GREEN}════════ Hysteria 管理脚本 ════════${NC}"
        echo -e "${GREEN}作者: Qiujianm${NC}"
        echo -e "${GREEN}版本: 2025-02-18${NC}"
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
                bash /usr/local/SPH2/setup.sh
                ;;
            2)
                server_menu
                ;;
            3)
                client_menu
                ;;
            4)
                optimize_system
                ;;
            5)
                check_update
                ;;
            6)
                check_running_status
                ;;
            7)
                echo -e "${RED}警告: 此操作将删除所有 Hysteria 相关文件和配置！${NC}"
                read -p "确定要卸载吗？(y/n): " confirm
                if [[ $confirm == [yY] ]]; then
                    uninstall
                fi
                ;;
            0)
                clear
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用root用户运行此脚本${NC}"
    exit 1
fi

# 运行主菜单
main_menu