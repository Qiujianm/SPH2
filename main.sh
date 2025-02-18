#!/bin/bash
source ./constants.sh
source ./server_manager.sh
source ./client_manager.sh

# 完全卸载功能
uninstall() {
    echo -e "${YELLOW}正在卸载 Hysteria...${NC}"
    
    # 停止并禁用服务
    systemctl stop hysteria clients 2>/dev/null
    systemctl disable hysteria clients 2>/dev/null
    
    # 删除服务文件
    rm -f "$SERVICE_FILE" "$CLIENT_SERVICE_FILE"
    
    # 删除配置目录
    rm -rf "$HYSTERIA_ROOT" "$CLIENT_CONFIG_DIR"
    
    # 删除二进制文件
    rm -f /usr/local/bin/hysteria
    
    # 删除日志文件
    rm -f "$LOG_FILE"
    
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
                read -p "确定要卸载 Hysteria 吗？(y/n): " confirm
                if [ "$confirm" = "y" ]; then
                    uninstall
                else
                    echo -e "${YELLOW}已取消卸载${NC}"
                    sleep 0.5
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

# 检查系统环境
check_system
main_menu
