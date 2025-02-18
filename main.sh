#!/bin/bash

# 导入所需模块
SCRIPT_DIR="/usr/local/SPH2"
source "${SCRIPT_DIR}/constants.sh"
source "${SCRIPT_DIR}/server_manager.sh"
source "${SCRIPT_DIR}/client_manager.sh"

# 检查运行状态
check_running_status() {
    clear
    echo -e "${GREEN}═══════ 运行状态 ═══════${NC}"
    check_server_status
    check_client_status
    read -n 1 -s -r -p "按任意键继续..."
}

# 安装模式
install_mode() {
    clear
    echo -e "${YELLOW}进入安装模式...${NC}"
    
    # 停止所有相关进程
    systemctl stop hysteria-server 2>/dev/null || true
    systemctl stop clients 2>/dev/null || true
    pkill -f /usr/local/bin/hysteria || true
    
    # 等待进程完全停止
    sleep 2
    
    echo -e "${GREEN}所有相关进程已停止${NC}"
    echo -e "${YELLOW}开始安装...${NC}"
    
    # 下载并安装 Hysteria
    wget -N --no-check-certificate https://hysteria.network/install.sh && bash install.sh

    # 创建服务
    create_services
    
    echo -e "${GREEN}安装完成！${NC}"
    sleep 1
}

# 创建服务
create_services() {
    # 创建服务端服务
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Hysteria Server Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
WorkingDirectory=/etc/hysteria
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # 创建客户端服务
    cat > "$CLIENT_SERVICE_FILE" << EOF
[Unit]
Description=Hysteria Clients Service
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/SPH2/start_clients.sh
ExecStop=/usr/local/SPH2/start_clients.sh stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # 设置权限
    chmod 644 "$SERVICE_FILE" "$CLIENT_SERVICE_FILE"

    # 重载服务
    systemctl daemon-reload
}

# 系统优化
optimize_system() {
    clear
    echo -e "${YELLOW}正在优化系统配置...${NC}"
    
    # 设置系统参数
    cat > /etc/sysctl.d/99-hysteria.conf << EOF
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_fastopen=3
EOF
    sysctl -p /etc/sysctl.d/99-hysteria.conf

    echo -e "${GREEN}系统优化完成${NC}"
    sleep 1
}

# 检查更新
check_update() {
    clear
    echo -e "${YELLOW}正在检查更新...${NC}"
    
    # 检查 Hysteria 更新
    wget -N --no-check-certificate https://hysteria.network/install.sh
    bash install.sh

    echo -e "${GREEN}更新检查完成${NC}"
    sleep 1
}

# 完全卸载
uninstall() {
    clear
    echo -e "${YELLOW}开始卸载...${NC}"
    
    # 停止所有服务
    systemctl stop hysteria-server 2>/dev/null || true
    systemctl stop clients 2>/dev/null || true
    
    # 禁用服务
    systemctl disable hysteria-server 2>/dev/null || true
    systemctl disable clients 2>/dev/null || true
    
    # 删除服务文件
    rm -f "$SERVICE_FILE" "$CLIENT_SERVICE_FILE"
    
    # 删除配置文件和目录
    rm -rf "$HYSTERIA_ROOT"
    rm -rf "$CLIENT_CONFIG_DIR"
    rm -rf "$SCRIPT_DIR"
    
    # 删除系统优化配置
    rm -f /etc/sysctl.d/99-hysteria.conf
    
    # 删除全局命令
    rm -f /usr/local/bin/h2
    
    # 删除 Hysteria
    rm -f /usr/local/bin/hysteria
    
    # 重载系统配置
    systemctl daemon-reload
    sysctl -p
    
    echo -e "${GREEN}卸载完成${NC}"
    sleep 1
    exit 0
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${GREEN}════════ Hysteria 管理脚本 ════════${NC}"
        echo "1. 安装模式"
        echo "2. 服务端管理"
        echo "3. 客户端管理"
        echo "4. 系统优化"
        echo "5. 检查更新"
        echo "6. 运行状态"
        echo "7. 完全卸载"
        echo "0. 退出脚本"
        
        read -p "请选择 [0-7]: " choice
        case $choice in
            1) install_mode ;;
            2) server_menu ;;
            3) client_menu ;;
            4) optimize_system ;;
            5) check_update ;;
            6) check_running_status ;;
            7) 
                read -p "确定要卸载吗？(y/n): " confirm
                [ "$confirm" = "y" ] && uninstall
                ;;
            0)
                echo -e "${GREEN}感谢使用！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用 root 用户运行此脚本${NC}"
    exit 1
fi

# 启动主菜单
main_menu