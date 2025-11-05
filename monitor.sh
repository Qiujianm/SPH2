#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 流量数据存储目录
TRAFFIC_DATA_DIR="/var/log/hysteria/traffic"
mkdir -p "$TRAFFIC_DATA_DIR"

# 格式化字节数为可读格式
format_bytes() {
    local bytes=$1
    if [ -z "$bytes" ] || [ "$bytes" = "0" ]; then
        echo "0 B"
        return
    fi
    
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes} B"
    elif [ "$bytes" -lt $((1024 * 1024)) ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}") KB"
    elif [ "$bytes" -lt $((1024 * 1024 * 1024)) ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024/1024}") MB"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024/1024/1024}") GB"
    fi
}

# 格式化速率
format_rate() {
    local bytes_per_sec=$1
    if [ -z "$bytes_per_sec" ] || [ "$bytes_per_sec" = "0" ]; then
        echo "0 B/s"
        return
    fi
    
    if [ "$bytes_per_sec" -lt 1024 ]; then
        echo "${bytes_per_sec} B/s"
    elif [ "$bytes_per_sec" -lt $((1024 * 1024)) ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes_per_sec/1024}") KB/s"
    elif [ "$bytes_per_sec" -lt $((1024 * 1024 * 1024)) ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes_per_sec/1024/1024}") MB/s"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes_per_sec/1024/1024/1024}") GB/s"
    fi
}

# 获取网卡流量统计
get_interface_stats() {
    local interface=$1
    local rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo 0)
    local tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null || echo 0)
    echo "$rx_bytes $tx_bytes"
}

# 实时流量监控（按网卡）
realtime_interface_monitor() {
    echo -e "${GREEN}═══════ 实时网卡流量监控 ═══════${NC}"
    echo -e "${YELLOW}按 Ctrl+C 退出${NC}"
    echo ""
    
    # 获取所有活动网卡
    local interfaces=$(ls /sys/class/net | grep -v "lo")
    
    # 初始化上次的流量数据
    declare -A last_rx
    declare -A last_tx
    
    for iface in $interfaces; do
        local stats=$(get_interface_stats $iface)
        last_rx[$iface]=$(echo $stats | awk '{print $1}')
        last_tx[$iface]=$(echo $stats | awk '{print $2}')
    done
    
    sleep 1
    
    while true; do
        clear
        echo -e "${GREEN}═══════ 实时网卡流量监控 ═══════${NC}"
        echo -e "${YELLOW}更新时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo -e "${YELLOW}按 Ctrl+C 退出${NC}"
        echo ""
        printf "%-15s %-20s %-20s %-20s %-20s\n" "网卡" "下载速率" "上传速率" "总下载" "总上传"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        for iface in $interfaces; do
            local stats=$(get_interface_stats $iface)
            local current_rx=$(echo $stats | awk '{print $1}')
            local current_tx=$(echo $stats | awk '{print $2}')
            
            local rx_rate=$(( (current_rx - last_rx[$iface]) ))
            local tx_rate=$(( (current_tx - last_tx[$iface]) ))
            
            printf "%-15s %-20s %-20s %-20s %-20s\n" \
                "$iface" \
                "$(format_rate $rx_rate)" \
                "$(format_rate $tx_rate)" \
                "$(format_bytes $current_rx)" \
                "$(format_bytes $current_tx)"
            
            last_rx[$iface]=$current_rx
            last_tx[$iface]=$current_tx
        done
        
        sleep 1
    done
}

# 按端口统计流量
port_traffic_stats() {
    echo -e "${GREEN}═══════ 按端口流量统计 ═══════${NC}"
    echo ""
    
    # 查找所有 Hysteria2 实例端口
    local hysteria_ports=$(systemctl list-units --type=service --state=running | grep "hysteria-server@" | sed 's/.*@\([0-9]*\)\.service.*/\1/' | sort -n)
    
    if [ -z "$hysteria_ports" ]; then
        echo -e "${RED}未找到运行中的 Hysteria2 实例${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${YELLOW}使用 ss 命令统计各端口连接和流量...${NC}"
    echo ""
    printf "%-10s %-15s %-15s %-20s\n" "端口" "活动连接数" "监听状态" "配置文件"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for port in $hysteria_ports; do
        # 统计连接数
        local conn_count=$(ss -an | grep ":$port " | grep -c "ESTAB" || echo 0)
        
        # 检查监听状态
        local listen_status="未监听"
        if ss -ln | grep -q ":$port "; then
            listen_status="${GREEN}监听中${NC}"
        fi
        
        # 配置文件路径
        local config_file="/etc/hysteria/config_${port}.yaml"
        if [ ! -f "$config_file" ]; then
            config_file="${RED}不存在${NC}"
        else
            config_file="${GREEN}存在${NC}"
        fi
        
        printf "%-10s %-15s %-15b %-20b\n" "$port" "$conn_count" "$listen_status" "$config_file"
    done
    
    echo ""
    echo -e "${YELLOW}注意: 由于 UDP 协议特性，连接数统计可能不准确${NC}"
    read -p "按回车键继续..."
}

# 实时端口流量监控
realtime_port_monitor() {
    echo -e "${GREEN}═══════ 实时端口流量监控 ═══════${NC}"
    echo -e "${YELLOW}按 Ctrl+C 退出${NC}"
    echo ""
    
    # 查找所有 Hysteria2 实例端口
    local hysteria_ports=$(systemctl list-units --type=service --state=running | grep "hysteria-server@" | sed 's/.*@\([0-9]*\)\.service.*/\1/' | sort -n)
    
    if [ -z "$hysteria_ports" ]; then
        echo -e "${RED}未找到运行中的 Hysteria2 实例${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    # 初始化流量数据
    declare -A last_rx_packets
    declare -A last_tx_packets
    
    # 使用 iptables 规则来统计流量
    echo -e "${YELLOW}正在设置 iptables 流量统计规则...${NC}"
    for port in $hysteria_ports; do
        # 检查规则是否已存在
        if ! iptables -L INPUT -n -v -x | grep -q "udp dpt:$port"; then
            iptables -I INPUT -p udp --dport $port -j ACCEPT
        fi
        if ! iptables -L OUTPUT -n -v -x | grep -q "udp spt:$port"; then
            iptables -I OUTPUT -p udp --sport $port -j ACCEPT
        fi
    done
    
    sleep 1
    
    while true; do
        clear
        echo -e "${GREEN}═══════ 实时端口流量监控 ═══════${NC}"
        echo -e "${YELLOW}更新时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo -e "${YELLOW}按 Ctrl+C 退出${NC}"
        echo ""
        printf "%-10s %-15s %-15s %-20s %-20s\n" "端口" "连接数" "下载速率" "上传速率" "状态"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        for port in $hysteria_ports; do
            # 统计连接数
            local conn_count=$(ss -an | grep ":$port " | grep -c "ESTAB" || echo 0)
            
            # 从 iptables 获取流量统计
            local rx_packets=$(iptables -L INPUT -n -v -x | grep "udp dpt:$port" | awk '{print $2}' | head -1)
            local tx_packets=$(iptables -L OUTPUT -n -v -x | grep "udp spt:$port" | awk '{print $2}' | head -1)
            
            rx_packets=${rx_packets:-0}
            tx_packets=${tx_packets:-0}
            
            # 计算速率
            local rx_rate=0
            local tx_rate=0
            if [ -n "${last_rx_packets[$port]}" ]; then
                rx_rate=$(( rx_packets - last_rx_packets[$port] ))
                tx_rate=$(( tx_packets - last_tx_packets[$port] ))
            fi
            
            last_rx_packets[$port]=$rx_packets
            last_tx_packets[$port]=$tx_packets
            
            # 检查服务状态
            local status="${GREEN}运行中${NC}"
            if ! systemctl is-active --quiet "hysteria-server@${port}.service"; then
                status="${RED}已停止${NC}"
            fi
            
            printf "%-10s %-15s %-15s %-20s %-20b\n" \
                "$port" \
                "$conn_count" \
                "$(format_rate $rx_rate)" \
                "$(format_rate $tx_rate)" \
                "$status"
        done
        
        echo ""
        echo -e "${CYAN}提示: 流量统计基于 iptables 计数器，重启防火墙会重置计数${NC}"
        
        sleep 1
    done
}

# 连接统计详情
connection_stats() {
    echo -e "${GREEN}═══════ 连接统计详情 ═══════${NC}"
    echo ""
    
    # 查找所有 Hysteria2 实例端口
    local hysteria_ports=$(systemctl list-units --type=service --state=running | grep "hysteria-server@" | sed 's/.*@\([0-9]*\)\.service.*/\1/' | sort -n)
    
    if [ -z "$hysteria_ports" ]; then
        echo -e "${RED}未找到运行中的 Hysteria2 实例${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    echo "请选择要查看的端口:"
    echo "0. 查看所有端口"
    local port_array=($hysteria_ports)
    local i=1
    for port in $hysteria_ports; do
        echo "$i. 端口 $port"
        ((i++))
    done
    
    read -p "请选择 [0-$((i-1))]: " choice
    
    if [ "$choice" = "0" ]; then
        for port in $hysteria_ports; do
            show_port_connections "$port"
        done
    elif [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
        local selected_port=${port_array[$((choice-1))]}
        show_port_connections "$selected_port"
    else
        echo -e "${RED}无效选择${NC}"
    fi
    
    read -p "按回车键继续..."
}

# 显示指定端口的连接详情
show_port_connections() {
    local port=$1
    echo ""
    echo -e "${CYAN}【端口 $port 连接详情】${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 统计总连接数
    local total_conn=$(ss -an | grep ":$port " | wc -l)
    echo -e "总连接数: ${GREEN}$total_conn${NC}"
    
    # 统计各状态连接数
    echo ""
    echo "连接状态分布:"
    ss -an | grep ":$port " | awk '{print $2}' | sort | uniq -c | while read count state; do
        printf "  %-15s: %s\n" "$state" "$count"
    done
    
    # 显示 Top 10 连接来源IP
    echo ""
    echo -e "${YELLOW}Top 10 连接来源 IP:${NC}"
    printf "%-20s %-15s\n" "IP地址" "连接数"
    echo "────────────────────────────────────"
    ss -an | grep ":$port " | awk '{print $6}' | sed 's/\[//g;s/\]//g' | cut -d: -f1 | sort | uniq -c | sort -rn | head -10 | while read count ip; do
        printf "%-20s %-15s\n" "$ip" "$count"
    done
}

# 流量历史统计
traffic_history() {
    echo -e "${GREEN}═══════ 流量历史统计 ═══════${NC}"
    echo ""
    
    local stat_file="$TRAFFIC_DATA_DIR/traffic_history.log"
    
    if [ ! -f "$stat_file" ]; then
        echo -e "${YELLOW}暂无历史统计数据${NC}"
        echo -e "${YELLOW}提示: 系统会每小时自动记录流量数据${NC}"
        echo ""
        echo "是否现在开始收集流量数据？"
        echo "1. 是，开始收集"
        echo "2. 否，返回"
        read -p "请选择 [1-2]: " choice
        
        if [ "$choice" = "1" ]; then
            setup_traffic_collection
        fi
        read -p "按回车键继续..."
        return
    fi
    
    echo "选择查看时间范围:"
    echo "1. 最近 24 小时"
    echo "2. 最近 7 天"
    echo "3. 最近 30 天"
    echo "4. 全部历史"
    read -p "请选择 [1-4]: " choice
    
    local time_range=""
    case $choice in
        1) time_range="-24 hours" ;;
        2) time_range="-7 days" ;;
        3) time_range="-30 days" ;;
        4) time_range="" ;;
        *) echo -e "${RED}无效选择${NC}"; return ;;
    esac
    
    echo ""
    echo -e "${CYAN}流量历史记录:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ -z "$time_range" ]; then
        cat "$stat_file" | tail -100
    else
        local cutoff_time=$(date -d "$time_range" +%s)
        while IFS= read -r line; do
            local line_time=$(echo "$line" | awk '{print $1" "$2}')
            local line_timestamp=$(date -d "$line_time" +%s 2>/dev/null || echo 0)
            if [ "$line_timestamp" -ge "$cutoff_time" ]; then
                echo "$line"
            fi
        done < "$stat_file"
    fi
    
    read -p "按回车键继续..."
}

# 设置流量数据收集
setup_traffic_collection() {
    echo -e "${YELLOW}正在设置流量数据收集...${NC}"
    
    # 创建数据收集脚本
    cat > /usr/local/bin/hysteria-traffic-collector.sh << 'EOF'
#!/bin/bash
TRAFFIC_DATA_DIR="/var/log/hysteria/traffic"
mkdir -p "$TRAFFIC_DATA_DIR"
STAT_FILE="$TRAFFIC_DATA_DIR/traffic_history.log"

# 获取当前时间
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 获取所有网卡流量
INTERFACES=$(ls /sys/class/net | grep -v "lo")
for iface in $INTERFACES; do
    RX=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
    TX=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
    echo "$TIMESTAMP $iface RX:$RX TX:$TX" >> "$STAT_FILE"
done

# 清理30天前的数据
find "$TRAFFIC_DATA_DIR" -name "*.log" -mtime +30 -delete
EOF
    
    chmod +x /usr/local/bin/hysteria-traffic-collector.sh
    
    # 创建 cron 任务（每小时执行一次）
    cat > /etc/cron.d/hysteria-traffic << 'EOF'
# 每小时收集一次流量数据
0 * * * * root /usr/local/bin/hysteria-traffic-collector.sh
EOF
    
    # 立即执行一次
    /usr/local/bin/hysteria-traffic-collector.sh
    
    echo -e "${GREEN}✓ 流量数据收集已设置完成${NC}"
    echo -e "${GREEN}✓ 系统将每小时自动记录流量数据${NC}"
}

# 生成流量报表
generate_traffic_report() {
    echo -e "${GREEN}═══════ 生成流量报表 ═══════${NC}"
    echo ""
    
    local report_file="/root/traffic_report_$(date +%Y%m%d_%H%M%S).txt"
    
    echo "正在生成流量报表..."
    
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "          Hysteria2 流量监控报表"
        echo "          生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        echo "【系统信息】"
        echo "主机名: $(hostname)"
        echo "系统: $(uname -s) $(uname -r)"
        echo "运行时间: $(uptime -p)"
        echo ""
        
        echo "【网卡流量统计】"
        local interfaces=$(ls /sys/class/net | grep -v "lo")
        for iface in $interfaces; do
            local stats=$(get_interface_stats $iface)
            local rx=$(echo $stats | awk '{print $1}')
            local tx=$(echo $stats | awk '{print $2}')
            echo "网卡 $iface:"
            echo "  下载: $(format_bytes $rx)"
            echo "  上传: $(format_bytes $tx)"
        done
        echo ""
        
        echo "【Hysteria2 实例统计】"
        local hysteria_ports=$(systemctl list-units --type=service --state=running | grep "hysteria-server@" | sed 's/.*@\([0-9]*\)\.service.*/\1/' | sort -n)
        if [ -n "$hysteria_ports" ]; then
            for port in $hysteria_ports; do
                local conn_count=$(ss -an | grep ":$port " | grep -c "ESTAB" || echo 0)
                local status=$(systemctl is-active "hysteria-server@${port}.service")
                echo "端口 $port:"
                echo "  状态: $status"
                echo "  活动连接: $conn_count"
            done
        else
            echo "  未找到运行中的实例"
        fi
        echo ""
        
        echo "【系统资源使用】"
        echo "CPU 使用率: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
        echo "内存使用: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
        echo "磁盘使用: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
        echo ""
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "报表结束"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    } > "$report_file"
    
    echo -e "${GREEN}✓ 报表已生成: $report_file${NC}"
    echo ""
    echo "是否查看报表内容？"
    echo "1. 是"
    echo "2. 否"
    read -p "请选择 [1-2]: " choice
    
    if [ "$choice" = "1" ]; then
        cat "$report_file"
    fi
    
    read -p "按回车键继续..."
}

# Top 流量使用者
top_traffic_users() {
    echo -e "${GREEN}═══════ Top 流量使用者 ═══════${NC}"
    echo ""
    
    echo -e "${YELLOW}正在分析连接数据...${NC}"
    echo ""
    
    # 查找所有 Hysteria2 实例端口
    local hysteria_ports=$(systemctl list-units --type=service --state=running | grep "hysteria-server@" | sed 's/.*@\([0-9]*\)\.service.*/\1/' | sort -n)
    
    if [ -z "$hysteria_ports" ]; then
        echo -e "${RED}未找到运行中的 Hysteria2 实例${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${CYAN}【所有端口汇总 - Top 20 连接 IP】${NC}"
    printf "%-20s %-15s %-30s\n" "IP地址" "连接数" "涉及端口"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 收集所有连接的IP和端口信息
    declare -A ip_conn_count
    declare -A ip_ports
    
    for port in $hysteria_ports; do
        ss -an | grep ":$port " | awk '{print $6}' | sed 's/\[//g;s/\]//g' | cut -d: -f1 | while read ip; do
            if [ -n "$ip" ]; then
                ip_conn_count[$ip]=$((${ip_conn_count[$ip]:-0} + 1))
                if [ -z "${ip_ports[$ip]}" ]; then
                    ip_ports[$ip]="$port"
                else
                    if ! echo "${ip_ports[$ip]}" | grep -q "$port"; then
                        ip_ports[$ip]="${ip_ports[$ip]},$port"
                    fi
                fi
            fi
        done
    done
    
    # 显示 Top 20
    for ip in "${!ip_conn_count[@]}"; do
        echo "${ip_conn_count[$ip]} $ip ${ip_ports[$ip]}"
    done | sort -rn | head -20 | while read count ip ports; do
        printf "%-20s %-15s %-30s\n" "$ip" "$count" "$ports"
    done
    
    echo ""
    read -p "按回车键继续..."
}

# 清理 iptables 统计规则
cleanup_iptables_rules() {
    echo -e "${YELLOW}正在清理 iptables 流量统计规则...${NC}"
    
    local hysteria_ports=$(systemctl list-units --type=service | grep "hysteria-server@" | sed 's/.*@\([0-9]*\)\.service.*/\1/' | sort -n)
    
    for port in $hysteria_ports; do
        iptables -D INPUT -p udp --dport $port -j ACCEPT 2>/dev/null
        iptables -D OUTPUT -p udp --sport $port -j ACCEPT 2>/dev/null
    done
    
    echo -e "${GREEN}✓ 清理完成${NC}"
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${GREEN}═══════════════════════════════════════${NC}"
        echo -e "${GREEN}     Hysteria2 流量监控系统 v1.0     ${NC}"
        echo -e "${GREEN}═══════════════════════════════════════${NC}"
        echo ""
        echo -e "${CYAN}【实时监控】${NC}"
        echo "  1. 实时网卡流量监控"
        echo "  2. 实时端口流量监控"
        echo ""
        echo -e "${CYAN}【统计分析】${NC}"
        echo "  3. 按端口流量统计"
        echo "  4. 连接统计详情"
        echo "  5. Top 流量使用者"
        echo ""
        echo -e "${CYAN}【历史与报表】${NC}"
        echo "  6. 流量历史统计"
        echo "  7. 生成流量报表"
        echo "  8. 设置自动数据收集"
        echo ""
        echo -e "${CYAN}【系统管理】${NC}"
        echo "  9. 清理监控规则"
        echo "  0. 返回主菜单"
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════${NC}"
        
        read -t 60 -p "请选择 [0-9]: " choice || {
            echo -e "\n${YELLOW}操作超时，返回主菜单${NC}"
            exit 0
        }
        
        case $choice in
            1) realtime_interface_monitor ;;
            2) realtime_port_monitor ;;
            3) port_traffic_stats ;;
            4) connection_stats ;;
            5) top_traffic_users ;;
            6) traffic_history ;;
            7) generate_traffic_report ;;
            8) setup_traffic_collection; read -p "按回车键继续..." ;;
            9) cleanup_iptables_rules; read -p "按回车键继续..." ;;
            0) exit 0 ;;
            *)
                echo -e "${RED}无效选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# 捕获退出信号，清理规则
trap cleanup_iptables_rules EXIT INT TERM

# 启动主菜单
main_menu
