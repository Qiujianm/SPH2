#!/bin/bash
source ./constants.sh
source ./server_manager.sh
source ./client_manager.sh

# 安装 Hysteria
install_hysteria() {
    echo -e "${YELLOW}[1/3] 正在安装 Hysteria...${NC}"
    LATEST_VER=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | jq -r .tag_name)
    ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
    BIN_URL="https://github.com/apernet/hysteria/releases/download/$LATEST_VER/hysteria-linux-$ARCH"
    
    wget -qO /usr/local/bin/hysteria "$BIN_URL"
    chmod +x /usr/local/bin/hysteria
    
    # 创建必要的目录
    mkdir -p "$HYSTERIA_ROOT" "$CLIENT_DIR" "$CLIENT_CONFIG_DIR"
    
    echo -e "${GREEN}[1/3] Hysteria 安装完成！${NC}"
}

# 创建服务文件
create_service_files() {
    echo -e "${YELLOW}[2/3] 正在创建服务文件...${NC}"
    
    # 创建服务端服务文件
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Hysteria VPN Server Service
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/hysteria server -c $HYSTERIA_CONFIG
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=hysteria-server

[Install]
WantedBy=multi-user.target
EOF

    # 创建客户端服务文件
    cat > "$CLIENT_SERVICE_FILE" <<EOF
[Unit]
Description=Hysteria Clients Service
After=network.target

[Service]
Type=forking
WorkingDirectory=/root
ExecStart=/root/start-hysteria-clients.sh
ExecStop=/bin/bash -c "pkill -f '/usr/local/bin/hysteria -c' || true"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # 创建客户端启动脚本
    cat > "/root/start-hysteria-clients.sh" <<EOF
#!/bin/bash
for config in $CLIENT_CONFIG_DIR/*.json; do
    if [ -f "\$config" ]; then
        /usr/local/bin/hysteria client -c "\$config" &
    fi
done
EOF

    chmod +x "/root/start-hysteria-clients.sh"
    systemctl daemon-reload
    echo -e "${GREEN}[2/3] 服务文件创建完成！${NC}"
}

# 系统优化
optimize_system() {
    echo -e "${YELLOW}正在进行系统优化...${NC}"
    echo -e "1. BBR 拥塞控制算法"
    echo -e "2. Brutal 拥塞控制算法"
    echo -e "0. 返回"
    
    read -p "请选择优化方案 [0-2]: " opt_choice
    case $opt_choice in
        1|2)
            # 系统限制优化
            cat >> /etc/security/limits.conf <<EOF
* soft nofile 65535
* hard nofile 65535
EOF
            # 内核参数优化
            cat >> /etc/sysctl.conf <<EOF
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_congestion_control=$([ "$opt_choice" == "1" ] && echo "bbr" || echo "brutal")
net.ipv4.tcp_fastopen=3
EOF
            sysctl -p
            echo -e "${GREEN}系统优化完成！${NC}"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac
}

# 检查运行状态
check_running_status() {
    echo -e "${YELLOW}正在检查运行状态...${NC}"
    
    # 检查服务端状态
    echo -e "\n服务端状态："
    if systemctl is-active --quiet hysteria; then
        echo -e "${GREEN}服务端运行中${NC}"
        systemctl status hysteria --no-pager | grep Memory
        systemctl status hysteria --no-pager | grep CPU
    else
        echo -e "${RED}服务端未运行${NC}"
    fi
    
    # 检查客户端状态
    echo -e "\n客户端状态："
    if systemctl is-active --quiet clients; then
        echo -e "${GREEN}客户端运行中${NC}"
        systemctl status clients --no-pager | grep Memory
        systemctl status clients --no-pager | grep CPU
    else
        echo -e "${RED}客户端未运行${NC}"
    fi
    
    # 检查端口占用
    echo -e "\n端口监听状态："
    netstat -tunlp | grep hysteria
    
    # 检查系统资源
    echo -e "\n系统资源使用："
    echo "CPU 使用率:"
    top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}'
    echo "内存使用率:"
    free -m | awk 'NR==2{printf "%.2f%%\n", $3*100/$2}'
}

# 安装模式
install_mode() {
    echo -e "${YELLOW}正在执行安装模式...${NC}"
    
    # 检查系统环境
    check_system
    
    # 安装依赖
    echo -e "${YELLOW}[1/4] 正在安装依赖...${NC}"
    if [[ "$ID" == "centos" ]]; then
        yum install -y wget curl tar jq qrencode
    else
        apt update
        apt install -y wget curl tar jq qrencode
    fi
    
    # 安装 Hysteria
    install_hysteria
    
    # 创建服务文件
    create_service_files
    
    # 询问是否进行系统优化
    read -p "是否进行系统优化？(y/n): " do_optimize
    if [ "$do_optimize" = "y" ]; then
        optimize_system
    fi
    
    echo -e "${GREEN}安装完成！${NC}"
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
            1)
                install_mode
                sleep 0.5
                ;;
            2)
                server_menu
                sleep 0.5
                ;;
            3)
                client_menu
                sleep 0.5
                ;;
            4)
                optimize_system
                sleep 0.5
                ;;
            5)
                check_update
                sleep 0.5
                ;;
            6)
                check_running_status
                sleep 0.5
                ;;
            7)
                uninstall
                sleep 0.5
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

# 检查系统环境
check_system
main_menu
