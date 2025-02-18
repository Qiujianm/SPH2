#!/bin/bash
source ./constants.sh

# 客户端管理菜单
client_menu() {
    while true; do
        echo -e "${GREEN}═══════ Hysteria 客户端管理 ═══════${NC}"
        echo "1. 启动客户端"
        echo "2. 停止客户端"
        echo "3. 重启客户端"
        echo "4. 查看客户端状态"
        echo "5. 查看客户端日志"
        echo "6. 管理配置文件"
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
                ps aux | grep "hysteria client" | grep -v grep
                sleep 0.5
                ;;
            5)
                journalctl -u clients -n 50 --no-pager
                sleep 0.5
                ;;
            6)
                if list_configs; then
                    echo -e "\n请选择操作："
                    echo "1. 查看配置内容"
                    echo "2. 删除配置文件"
                    echo "0. 返回上级菜单"
                    read -p "请选择 [0-2]: " sub_choice
                    case $sub_choice in
                        1)
                            read -p "输入配置编号查看内容: " num
                            local configs=("$CLIENT_CONFIG_DIR"/*.json)
                            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt 0 ] && [ "$num" -le "${#configs[@]}" ]; then
                                echo -e "\n${GREEN}配置文件内容：${NC}"
                                cat "${configs[$((num-1))]}"
                                echo
                            else
                                echo -e "${RED}无效的配置编号${NC}"
                            fi
                            ;;
                        2)
                            read -p "输入要删除的配置编号: " num
                            local configs=("$CLIENT_CONFIG_DIR"/*.json)
                            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt 0 ] && [ "$num" -le "${#configs[@]}" ]; then
                                rm -f "${configs[$((num-1))]}"
                                echo -e "${GREEN}配置已删除${NC}"
                                systemctl restart clients
                            else
                                echo -e "${RED}无效的配置编号${NC}"
                            fi
                            ;;
                        0)
                            continue
                            ;;
                        *)
                            echo -e "${RED}无效选择${NC}"
                            ;;
                    esac
                    sleep 0.5
                fi
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