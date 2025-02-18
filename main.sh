#!/bin/bash
source /usr/local/SPH2/constants.sh
source /usr/local/SPH2/install.sh
source /usr/local/SPH2/server_manager.sh
source /usr/local/SPH2/client_manager.sh

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${GREEN}═══════ Hysteria 管理面板 ═══════${NC}"
        echo "1. 安装 Hysteria"
        echo "2. 服务端管理"
        echo "3. 客户端配置管理"
        echo "4. 系统优化"
        echo "5. 检查更新"
        echo "6. 运行状态"
        echo "7. 完全卸载"
        echo "0. 退出"
        
        read -p "请选择 [0-7]: " choice
        case $choice in
            1)
                install_hysteria
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

main_menu