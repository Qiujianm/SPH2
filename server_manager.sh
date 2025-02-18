#!/bin/bash
source /usr/local/SPH2/constants.sh

# 检查服务端状态
check_server_status() {
    if systemctl is-active --quiet hysteria-server; then
        echo -e "${GREEN}服务端正在运行${NC}"
        return 0
    else
        echo -e "${YELLOW}服务端未运行${NC}"
        return 1
    fi
}

# 查看当前配置
view_current_config() {
    if [ -f "$HYSTERIA_CONFIG" ]; then
        echo -e "${YELLOW}当前配置文件内容：${NC}"
        cat "$HYSTERIA_CONFIG"
    else
        echo -e "${RED}未找到配置文件${NC}"
    fi
    sleep 0.5
}

# 服务端管理菜单
server_menu() {
    while true; do
        echo -e "${GREEN}═══════ Hysteria 服务端管理 ═══════${NC}"
        echo "1. 启动服务端"
        echo "2. 停止服务端"
        echo "3. 重启服务端"
        echo "4. 查看服务端状态"
        echo "5. 查看服务端日志"
        echo "6. 查看当前配置"
        echo "0. 返回主菜单"
        
        read -p "请选择 [0-6]: " choice
        case $choice in
            1)
                systemctl start hysteria-server
                echo -e "${GREEN}服务端已启动${NC}"
                sleep 0.5
                ;;
            2)
                systemctl stop hysteria-server
                echo -e "${YELLOW}服务端已停止${NC}"
                sleep 0.5
                ;;
            3)
                systemctl restart hysteria-server
                echo -e "${GREEN}服务端已重启${NC}"
                sleep 0.5
                ;;
            4)
                systemctl status hysteria-server --no-pager
                sleep 0.5
                ;;
            5)
                journalctl -u hysteria-server -n 50 --no-pager
                sleep 0.5
                ;;
            6)
                view_current_config
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