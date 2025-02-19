#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用root权限运行此脚本${NC}"
    exit 1
fi

# 导入其他脚本
source ./config.sh
source ./server.sh
source ./client.sh

show_menu() {
    clear
    echo -e "${GREEN}════════ Hysteria 管理脚本 ════════${NC}"
    echo -e "${GREEN}作者: Qiujianm${NC}"
    echo -e "${GREEN}版本: 2025-02-19${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo "1. 安装服务端"
    echo "2. 服务端管理"
    echo "3. 客户端管理"
    echo "4. 系统优化"
    echo "5. 版本更新"
    echo "6. 运行状态"
    echo "7. 完全卸载"
    echo "0. 退出脚本"
    echo -e "${GREEN}====================================${NC}"
}

while true; do
    show_menu
    read -p "请选择 [0-7]: " choice
    case $choice in
        1) bash setup.sh ;;
        2) server_menu ;;
        3) client_menu ;;
        4) optimize_system ;;
        5) check_update ;;
        6) show_status ;;
        7) 
            read -p "确定要卸载吗？(y/n): " confirm
            [[ $confirm == [yY] ]] && uninstall
            ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选择${NC}" && sleep 1 ;;
    esac
done