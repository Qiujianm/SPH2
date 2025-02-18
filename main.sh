#!/bin/bash
source ./constants.sh
source ./server_manager.sh
source ./client_manager.sh

# 错误处理
set -e
trap 'echo -e "${RED}错误: 脚本执行失败${NC}" >&2' ERR

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "${YELLOW}正在安装 $1...${NC}"
        if [ -f /etc/redhat-release ]; then
            yum install -y "$1"
        elif [ -f /etc/debian_version ]; then
            apt-get update && apt-get install -y "$1"
        fi
    fi
}

# 检查系统环境
check_system() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}请使用root用户运行此脚本${NC}"
        exit 1
    fi
    check_command "git"
    check_command "wget"
    check_command "curl"
}

# 检查运行状态
check_running_status() {
    check_server_status
    check_client_status
    sleep 0.5
}

# 系统优化
optimize_system() {
    echo -e "${YELLOW}正在优化系统配置...${NC}"
    cat > /etc/sysctl.d/99-hysteria.conf <<EOF
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 87380 16777216
EOF
    sysctl --system >/dev/null 2>&1
    echo -e "${GREEN}系统优化完成${NC}"
    sleep 0.5
}

# 安装模式
install_mode() {
    echo -e "${YELLOW}开始安装 Hysteria...${NC}"
    
    # 下载 Hysteria 二进制文件
    mkdir -p /usr/local/bin
    wget -O /usr/local/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
    chmod +x /usr/local/bin/hysteria
    
    # 创建目录结构
    mkdir -p "$HYSTERIA_ROOT"
    mkdir -p "$CLIENT_CONFIG_DIR"
    
    # 创建启动脚本
    cp start_clients.sh "$START_CLIENTS_SCRIPT"
    chmod +x "$START_CLIENTS_SCRIPT"
    
    # 创建服务端服务文件
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Hysteria Server Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c ${HYSTERIA_CONFIG}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # 创建客户端服务文件
    cat > "$CLIENT_SERVICE_FILE" <<EOF
[Unit]
Description=Hysteria Clients Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash ${START_CLIENTS_SCRIPT}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # 重载服务
    systemctl daemon-reload
    
    # 设置开机启动
    systemctl enable hysteria
    systemctl enable clients
    
    # 启动服务
    systemctl start hysteria
    systemctl start clients
    
    # 优化系统
    optimize_system
    
    echo -e "${GREEN}Hysteria 安装完成！${NC}"
    sleep 0.5
}

# 完全卸载
uninstall() {
    echo -e "${YELLOW}正在卸载 Hysteria...${NC}"
    
    # 停止服务
    systemctl stop hysteria clients 2>/dev/null
    systemctl disable hysteria clients 2>/dev/null
    
    # 备份配置
    if [ -d "$HYSTERIA_ROOT" ]; then
        backup_dir="/root/hysteria_backup_$(date +%Y%m%d%H%M%S)"
        mkdir -p "$backup_dir"
        cp -r "$HYSTERIA_ROOT" "$backup_dir/"
        cp -r "$CLIENT_CONFIG_DIR" "$backup_dir/"
        echo -e "${GREEN}配置已备份至: $backup_dir${NC}"
    fi
    
    # 删除文件
    rm -f "$SERVICE_FILE" "$CLIENT_SERVICE_FILE"
    rm -rf "$HYSTERIA_ROOT" "$CLIENT_CONFIG_DIR"
    rm -f /usr/local/bin/hysteria
    
    echo -e "${GREEN}Hysteria 已完全卸载！${NC}"
    sleep 0.5
}

# 主菜单
main_menu() {
    while true; do
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
                read -p "确定要卸载 Hysteria 吗？(y/n): " confirm
                if [ "$confirm" = "y" ]; then
                    uninstall
                fi
                ;;
            0) 
                echo -e "${GREEN}感谢使用！${NC}"
                exit 0 
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                sleep 0.5
                ;;
        esac
    done
}

check_system
main_menu