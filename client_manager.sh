#!/bin/bash
source /usr/local/SPH2/constants.sh

# 检查客户端状态
check_client_status() {
    if systemctl is-active --quiet clients; then
        echo -e "${GREEN}客户端正在运行${NC}"
        return 0
    else
        echo -e "${YELLOW}客户端未运行${NC}"
        return 1
    fi
}

# 客户端管理菜单
client_menu() {
    while true; do
        echo -e "${GREEN}═══════ Hysteria 客户端管理 ═══════${NC}"
        echo "1. 启动客户端"
        echo "2. 停止客户端"
        echo "3. 重启客户端"
        echo "4. 查看客户端状态"
        echo "5. 查看客户端日志"
        echo "6. 添加客户端配置"
        echo "0. 返回主菜单"
        
        read -p "请选择 [0-6]: " choice
        case $choice in
            1)
                systemctl start clients
                echo -e "${GREEN}客户端已启动${NC}"
                sleep 0.5
                ;;
            2)
                systemctl stop clients
                echo -e "${YELLOW}客户端已停止${NC}"
                sleep 0.5
                ;;
            3)
                systemctl restart clients
                echo -e "${GREEN}客户端已重启${NC}"
                sleep 0.5
                ;;
            4)
                systemctl status clients --no-pager
                sleep 0.5
                ;;
            5)
                journalctl -u clients -n 50 --no-pager
                sleep 0.5
                ;;
            6)
                add_client_config
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                sleep 0.5
                ;;
        esac
    done
}