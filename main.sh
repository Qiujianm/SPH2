#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

VERSION="2025-02-19"
AUTHOR="Qiujianm"

while true; do
    clear
    printf "%b════════ Hysteria 管理脚本 ════════%b\n" "${GREEN}" "${NC}"
    printf "%b作者: ${AUTHOR}%b\n" "${GREEN}" "${NC}"
    printf "%b版本: ${VERSION}%b\n" "${GREEN}" "${NC}"
    printf "%b====================================%b\n" "${GREEN}" "${NC}"
    echo "1. 安装模式"
    echo "2. 服务端管理"
    echo "3. 客户端管理"
    echo "4. 系统优化"
    echo "5. 检查更新"
    echo "6. 运行状态"
    echo "7. 完全卸载"
    echo "0. 退出脚本"
    printf "%b====================================%b\n" "${GREEN}" "${NC}"
    
    read -t 60 -p "请选择 [0-7]: " choice || {
        printf "\n%b操作超时，退出脚本%b\n" "${YELLOW}" "${NC}"
        exit 1
    }
    
    case $choice in
        1) bash ./server.sh install ;;
        2) bash ./server.sh manage ;;
        3) bash ./client.sh ;;
        4) bash ./config.sh optimize ;;
        5) bash ./config.sh update ;;
        6)
            systemctl status hysteria-server
            read -t 30 -n 1 -s -r -p "按任意键继续..."
            ;;
        7) bash ./config.sh uninstall ;;
        0) exit 0 ;;
        *)
            printf "%b无效选择%b\n" "${RED}" "${NC}"
            sleep 1
            ;;
    esac
done
