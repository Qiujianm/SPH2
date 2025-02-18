#!/bin/bash

# 引入所有需要的脚本文件
SCRIPT_DIR="/usr/local/SPH2"
source "${SCRIPT_DIR}/constants.sh"
source "${SCRIPT_DIR}/server_manager.sh"
source "${SCRIPT_DIR}/client_manager.sh"

# 检查脚本文件
check_files() {
    for file in "constants.sh" "server_manager.sh" "client_manager.sh"; do
        if [ ! -f "${SCRIPT_DIR}/${file}" ]; then
            echo -e "${RED}错误：找不到 ${file}${NC}"
            echo -e "${YELLOW}请重新运行安装脚本${NC}"
            exit 1
        fi
    done
}

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用root用户运行此脚本${NC}"
    exit 1
fi

# 检查文件完整性
check_files

# 主菜单逻辑
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
                ;;
            2)
                server_menu
                ;;
            3)
                client_menu
                ;;
            4)
                system_optimize
                ;;
            5)
                check_update
                ;;
            6)
                show_status
                ;;
            7)
                uninstall_all
                ;;
            0)
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                sleep 0.5
                ;;
        esac
    done
}

# 启动主菜单
main_menu
