#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 客户端状态检查函数
check_client_status() {
    printf "\n%b正在进行客户端检查...%b\n" "${YELLOW}" "${NC}"
    
    # 检查配置文件
    local config_file=$(ls /root/*.json 2>/dev/null | head -1)
    if [ ! -f "$config_file" ]; then
                printf "%b错误: 未找到配置文件%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 检查程序是否存在
    if [ ! -f "/usr/local/bin/hysteria" ]; then
        printf "%b错误: Hysteria程序不存在%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 检查运行状态
    if [ -f "/root/hysteria-client.pid" ]; then
        local pid=$(cat /root/hysteria-client.pid)
        if ps -p $pid >/dev/null 2>&1; then
            printf "%b客户端进程运行中 (PID: $pid)%b\n" "${GREEN}" "${NC}"
            
            # 检查SOCKS5端口
            local socks_port=$(grep -oP '"listen": "0.0.0.0:\K\d+' "$config_file")
            if netstat -tuln | grep -q ":$socks_port "; then
                printf "%bSOCKS5端口($socks_port)正常监听%b\n" "${GREEN}" "${NC}"
                netstat -tuln | grep ":$socks_port "
            else
                printf "%bSOCKS5端口($socks_port)未正常监听%b\n" "${RED}" "${NC}"
            fi
        else
            printf "%b客户端进程已终止 (PID文件存在但进程不存在)%b\n" "${RED}" "${NC}"
            rm -f /root/hysteria-client.pid
        fi
    else
        printf "%b客户端未运行%b\n" "${YELLOW}" "${NC}"
        # 显示上次运行日志
        if [ -f "/var/log/hysteria-client.log" ]; then
            printf "\n%b上次运行日志:%b\n" "${YELLOW}" "${NC}"
            tail -n 10 /var/log/hysteria-client.log
        fi
    fi
}

while true; do
    clear
    printf "%b═══════ Hysteria 客户端管理 ═══════%b\n" "${GREEN}" "${NC}"
    echo "1. 启动客户端"
    echo "2. 停止客户端"
    echo "3. 重启客户端"
    echo "4. 查看客户端状态"
    echo "5. 删除客户端配置"
    echo "0. 返回主菜单"
    printf "%b====================================%b\n" "${GREEN}" "${NC}"
    
    read -t 60 -p "请选择 [0-5]: " choice || {
        printf "\n%b操作超时，返回主菜单%b\n" "${YELLOW}" "${NC}"
        exit 0
    }

    case $choice in
        1)
            if [ -f "/root/hysteria-client.pid" ]; then
                printf "%b客户端已在运行%b\n" "${YELLOW}" "${NC}"
            else
                config_file=$(ls /root/*.json | head -1)
                if [ -n "$config_file" ]; then
                    printf "%b使用配置文件: %s%b\n" "${GREEN}" "$config_file" "${NC}"
                    /usr/local/bin/hysteria client -c "$config_file" \
                        --log-level info \
                        > /var/log/hysteria-client.log 2>&1 &
                    echo $! > /root/hysteria-client.pid
                    sleep 2
                    check_client_status
                else
                    printf "%b未找到客户端配置文件%b\n" "${RED}" "${NC}"
                fi
            fi
            read -t 30 -n 1 -s -r -p "按任意键继续..."
            ;;
        2)
            if [ -f "/root/hysteria-client.pid" ]; then
                kill $(cat /root/hysteria-client.pid) 2>/dev/null
                rm -f /root/hysteria-client.pid
                printf "%b客户端已停止%b\n" "${YELLOW}" "${NC}"
                if [ -f "/var/log/hysteria-client.log" ]; then
                    printf "\n%b最后的日志记录:%b\n" "${YELLOW}" "${NC}"
                    tail -n 5 /var/log/hysteria-client.log
                fi
            else
                printf "%b客户端未运行%b\n" "${RED}" "${NC}"
            fi
            read -t 30 -n 1 -s -r -p "按任意键继续..."
            ;;
        3)
            if [ -f "/root/hysteria-client.pid" ]; then
                kill $(cat /root/hysteria-client.pid) 2>/dev/null
                rm -f /root/hysteria-client.pid
            fi
            config_file=$(ls /root/*.json | head -1)
            if [ -n "$config_file" ]; then
                printf "%b使用配置文件: %s%b\n" "${GREEN}" "$config_file" "${NC}"
                /usr/local/bin/hysteria client -c "$config_file" \
                    --log-level info \
                    > /var/log/hysteria-client.log 2>&1 &
                echo $! > /root/hysteria-client.pid
                sleep 2
                check_client_status
            else
                printf "%b未找到客户端配置文件%b\n" "${RED}" "${NC}"
            fi
            read -t 30 -n 1 -s -r -p "按任意键继续..."
            ;;
        4)
            clear
            printf "%b═══════ 客户端状态检查 ═══════%b\n" "${GREEN}" "${NC}"
            check_client_status
            printf "%b═══════════════════════════%b\n" "${GREEN}" "${NC}"
            read -t 30 -n 1 -s -r -p "按任意键继续..."
            ;;
        5)
            printf "\n%b可用的客户端配置文件：%b\n" "${YELLOW}" "${NC}"
            ls -l /root/*.json 2>/dev/null || echo "无配置文件"
            echo
            read -t 60 -p "请输入要删除的配置文件名称: " filename
            if [ -f "/root/$filename" ]; then
                rm -f "/root/$filename"
                printf "%b配置文件已删除%b\n" "${GREEN}" "${NC}"
            else
                printf "%b文件不存在%b\n" "${RED}" "${NC}"
            fi
            read -t 30 -n 1 -s -r -p "按任意键继续..."
            ;;
        0)
            exit 0
            ;;
        *)
            printf "%b无效选择%b\n" "${RED}" "${NC}"
            sleep 1
            ;;
    esac
done
