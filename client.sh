#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 启动单个客户端
start_single_client() {
    config_file=$1
    if [ ! -f "$config_file" ]; then
        printf "%b未找到配置文件: %s%b\n" "${RED}" "$config_file" "${NC}"
        return 1
    fi

    # 获取端口
    port=$(grep -oP '"listen": "0.0.0.0:\K\d+' "$config_file")
    pid_file="/root/hysteria-client-${port}.pid"

    printf "%b启动端口 %s 的客户端...%b\n" "${YELLOW}" "$port" "${NC}"
    
    # 如果已经运行，先停止
    if [ -f "$pid_file" ]; then
        kill $(cat "$pid_file") 2>/dev/null
        rm -f "$pid_file"
        sleep 1
    fi

    # 启动客户端
    nohup hysteria client -c "$config_file" --log-level info > "/var/log/hysteria-client-${port}.log" 2>&1 &
    pid=$!
    echo $pid > "$pid_file"

    # 等待启动
    printf "等待端口 %s " "$port"
    for i in {1..5}; do
        if ! ps -p $pid >/dev/null 2>&1; then
            printf "\n%b启动失败，查看日志: /var/log/hysteria-client-%s.log%b\n" "${RED}" "$port" "${NC}"
            rm -f "$pid_file"
            return 1
        fi

        if netstat -tuln | grep -q ":$port "; then
            printf "\n%b✓ 端口 %s 启动成功%b\n" "${GREEN}" "$port" "${NC}"
            return 0
        fi
        printf "."
        sleep 1
    done

    printf "\n%b! 进程运行但端口 %s 未监听%b\n" "${YELLOW}" "$port" "${NC}"
}

# 添加一个彻底清理进程的函数
cleanup_all_clients() {
    printf "%b清理所有客户端进程...%b\n" "${YELLOW}" "${NC}"
    
    # 通过 PID 文件清理
    for pid_file in /root/hysteria-client-*.pid; do
        if [ -f "$pid_file" ]; then
            kill $(cat "$pid_file") 2>/dev/null
            rm -f "$pid_file"
        fi
    done

    # 查找并清理所有 hysteria 客户端进程
    local pids=$(ps aux | grep 'hysteria client' | grep -v grep | awk '{print $2}')
    if [ -n "$pids" ]; then
        printf "发现遗留进程，正在清理...\n"
        for pid in $pids; do
            kill -9 $pid 2>/dev/null
            printf "%b终止进程 PID: %s%b\n" "${GREEN}" "$pid" "${NC}"
        done
    fi

    # 清理日志文件（可选）
    # rm -f /var/log/hysteria-client-*.log

    sleep 2 # 等待进程完全退出
}

# 重新启动所有客户端
restart_all_clients() {
    printf "%b开始重启所有客户端...%b\n" "${YELLOW}" "${NC}"
    
    # 1. 清理所有现有进程
    cleanup_all_clients
    
    # 2. 重新启动所有配置文件对应的客户端
    local configs=(/root/*.json)
    local success=0
    local failed=0

    for config in "${configs[@]}"; do
        if [ -f "$config" ]; then
            printf "\n%b正在启动 %s%b\n" "${GREEN}" "$(basename "$config")" "${NC}"
            if start_single_client "$config"; then
                ((success++))
            else
                ((failed++))
            fi
        fi
    done

    printf "\n%b重启完成: 成功 %d, 失败 %d%b\n" "${GREEN}" "$success" "$failed" "${NC}"
    
    # 3. 显示所有客户端状态
    printf "\n%b最终状态:%b\n" "${YELLOW}" "${NC}"
    check_all_clients
}

# 停止所有客户端
stop_all_clients() {
    printf "%b停止所有客户端...%b\n" "${YELLOW}" "${NC}"
    
    local count=0
    for pid_file in /root/hysteria-client-*.pid; do
        if [ -f "$pid_file" ]; then
            port=$(basename "$pid_file" | sed 's/hysteria-client-\([0-9]*\).pid/\1/')
            if kill $(cat "$pid_file") 2>/dev/null; then
                printf "%b✓ 已停止端口 %s 的客户端%b\n" "${GREEN}" "$port" "${NC}"
                ((count++))
            fi
            rm -f "$pid_file"
        fi
    done

    printf "%b共停止了 %d 个客户端%b\n" "${GREEN}" "$count" "${NC}"
}

# 状态检查函数
check_all_clients() {
    clear
    printf "%b═══════ 客户端状态检查 ═══════%b\n\n" "${GREEN}" "${NC}"
    local current_time=$(date "+%Y-%m-%d %H:%M:%S")
    printf "检查时间: %s\n\n" "$current_time"

    # 查找所有配置文件
    local configs=(/root/*.json)
    local config_count=${#configs[@]}

    # 获取所有运行中的hysteria进程的PID
    local pids=($(ps aux | grep 'hysteria client' | grep -v grep | awk '{print $2}'))
    local running_count=${#pids[@]}

    # 显示进程信息
    printf "%b运行中的Hysteria客户端进程：%b\n" "${GREEN}" "${NC}"
    printf "%-8s %-35s %-15s %-15s\n" "PID" "配置文件" "监听端口" "状态"
    printf "%-8s %-35s %-15s %-15s\n" "---" "--------" "--------" "----"

    for pid in "${pids[@]}"; do
        if ps -p $pid >/dev/null 2>&1; then
            local cmd=$(ps -p $pid -o args=)
            local config_file=$(echo "$cmd" | grep -o '/root/[^[:space:]]*\.json')
            if [ -f "$config_file" ]; then
                local base_config=$(basename "$config_file")
                local port=$(grep -oP '"listen": "0.0.0.0:\K\d+' "$config_file" || grep -oP '"socks5".*"listen": "0.0.0.0:\K\d+' "$config_file")
                printf "%-8s %-35s %-15s %-15s\n" \
                    "$pid" \
                    "$base_config" \
                    "$port" \
                    "运行正常"
            fi
        fi
    done

    # 显示端口监听信息
    printf "\n%b端口监听详情:%b\n" "${YELLOW}" "${NC}"
    netstat -tnlp | grep -E "$(echo "${pids[@]}" | tr ' ' '|')" | awk '{print $4}' | sort -n

    # 显示总结信息
    printf "\n%b总结:%b\n" "${GREEN}" "${NC}"
    printf "发现 %d 个配置文件\n" "$config_count"
    printf "运行 %d 个Hysteria客户端进程\n" "$running_count"

    # 如果没有运行的进程，显示提示信息
    if [ $running_count -eq 0 ]; then
        printf "\n%b未发现运行中的Hysteria客户端进程%b\n" "${RED}" "${NC}"
    fi
}

# 主菜单
while true; do
    clear
    printf "%b═══════ Hysteria 客户端管理 ═══════%b\n" "${GREEN}" "${NC}"
    echo "1. 启动单个客户端"
    echo "2. 启动所有客户端"
    echo "3. 停止所有客户端"
    echo "4. 重启所有客户端"
    echo "5. 查看客户端状态"
    echo "6. 删除客户端配置"
    echo "0. 返回主菜单"
    printf "%b====================================%b\n" "${GREEN}" "${NC}"
    
    read -t 60 -p "请选择 [0-6]: " choice || {
        printf "\n%b操作超时，返回主菜单%b\n" "${YELLOW}" "${NC}"
        exit 0
    }

    case $choice in
        1)
            clear
            printf "%b可用的配置文件：%b\n" "${YELLOW}" "${NC}"
            ls -l /root/*.json 2>/dev/null || echo "无配置文件"
            echo
            read -p "请输入要启动的配置文件名: " filename
            if [ -f "/root/$filename" ]; then
                start_single_client "/root/$filename"
            else
                printf "%b文件不存在%b\n" "${RED}" "${NC}"
            fi
            ;;
        2)
            restart_all_clients
            ;;
        3)
            stop_all_clients
            ;;
        4)
            restart_all_clients
            ;;
        5)
            check_all_clients
            ;;
        6)
            printf "\n%b可用的配置文件：%b\n" "${YELLOW}" "${NC}"
            ls -l /root/*.json 2>/dev/null || echo "无配置文件"
            echo
            read -p "请输入要删除的配置文件名称: " filename
            if [ -f "/root/$filename" ];then
                rm -f "/root/$filename"
                printf "%b配置文件已删除%b\n" "${GREEN}" "${NC}"
            else
                printf "%b文件不存在%b\n" "${RED}" "${NC}"
            fi
            ;;
        0)
            exit 0
            ;;
        *)
            printf "%b无效选择%b\n" "${RED}" "${NC}"
            ;;
    esac
    
    read -n 1 -s -r -p "按任意键继续..."
done
