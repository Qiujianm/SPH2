#!/bin/bash

VERSION="2025-02-19"
AUTHOR="Qiujianm"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 检查root权限
[ "$EUID" -ne 0 ] && echo -e "${RED}请使用root权限运行此脚本${NC}" && exit 1

# 打印状态函数
print_status() {
    local type=$1
    local message=$2
    case "$type" in
        "info")
            printf "%b[信息]%b %s\n" "${GREEN}" "${NC}" "$message"
            ;;
        "warn")
            printf "%b[警告]%b %s\n" "${YELLOW}" "${NC}" "$message"
            ;;
        "error")
            printf "%b[错误]%b %s\n" "${RED}" "${NC}" "$message"
            ;;
    esac
}

# 创建并赋权所有模块脚本
create_all_scripts() {
    print_status "info" "创建所有模块脚本...\n"
    
    # 创建目录
    mkdir -p /root/hysteria

    # 创建并赋权 main.sh
cat > /root/hysteria/main.sh << 'MAINEOF'
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
MAINEOF
    chmod +x /root/hysteria/main.sh

    # 创建并赋权 server.sh
cat > /root/hysteria/server.sh << 'SERVEREOF'
#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

HYSTERIA_BIN="/usr/local/bin/hysteria"
SYSTEMD_DIR="/etc/systemd/system"
CONFIG_DIR="/etc/hysteria"

check_env() {
    if ! command -v openssl >/dev/null 2>&1; then
        echo "请先安装 openssl"
        exit 1
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo "请先安装 curl"
        exit 1
    fi
    if [ ! -f "$HYSTERIA_BIN" ]; then
        echo "请先安装 hysteria"
        exit 1
    fi
    mkdir -p "$CONFIG_DIR"
}

gen_cert() {
    local domain=$1
    local crt="$CONFIG_DIR/server_${domain}.crt"
    local key="$CONFIG_DIR/server_${domain}.key"
    if [ ! -f "$crt" ] || [ ! -f "$key" ]; then
        openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 365 \
            -keyout "$key" -out "$crt" -subj "/CN=$domain" 2>/dev/null
    fi
    echo "$crt|$key"
}

create_systemd_unit() {
    local port=$1
    local config_file=$2
    local unit_file="${SYSTEMD_DIR}/hysteria-server@${port}.service"
    cat >"$unit_file" <<EOF
[Unit]
Description=Hysteria2 Server Instance on port $port
After=network.target

[Service]
ExecStart=$HYSTERIA_BIN server -c $config_file
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "hysteria-server@${port}.service" >/dev/null 2>&1
}

is_port_in_use() {
    local port=$1
    ss -lnt | awk '{print $4}' | grep -q ":$port\$"
}

generate_instances_batch() {
    echo -e "${YELLOW}请输入每个实例的带宽上下行限制（单位 mbps，直接回车为默认185）：${NC}"
    read -p "上行带宽 [185]: " up_bw
    read -p "下行带宽 [185]: " down_bw
    up_bw=${up_bw:-185}
    down_bw=${down_bw:-185}

    echo -e "${YELLOW}请粘贴所有代理（每行为一组，格式: IP:端口:用户名:密码），输入完毕后Ctrl+D:${NC}"
    proxies=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        proxies+="$line"$'\n'
    done

    read -p "请输入批量新建实例的起始端口: " start_port
    current_port="$start_port"

    local domain=$(curl -s ipinfo.io/ip || curl -s myip.ipip.net | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" || curl -s https://api.ip.sb/ip)
    if [ -z "$domain" ]; then
        read -p "请输入服务器公网IP: " domain
    fi
    local crt_and_key; crt_and_key=$(gen_cert "$domain")
    local crt=$(echo "$crt_and_key" | cut -d'|' -f1)
    local key=$(echo "$crt_and_key" | cut -d'|' -f2)

    while read -r proxy_raw; do
        [[ -z "$proxy_raw" ]] && continue
        while is_port_in_use "$current_port" || [ -f "$CONFIG_DIR/config_${current_port}.yaml" ]; do
            echo "端口 $current_port 已被占用，尝试下一个端口..."
            current_port=$((current_port + 1))
        done

        IFS=':' read -r proxy_ip proxy_port proxy_user proxy_pass <<< "$proxy_raw"
        http_port="$current_port"
        current_port=$((current_port + 1))
        password=$(openssl rand -base64 16)
        proxy_url="http://$proxy_user:$proxy_pass@$proxy_ip:$proxy_port"
        config_file="$CONFIG_DIR/config_${http_port}.yaml"

        cat >"$config_file" <<EOF
listen: :$http_port

tls:
  cert: $crt
  key: $key

auth:
  type: password
  password: $password

masquerade:
  proxy:
    url: https://www.bing.com
    rewriteHost: true

quic:
  initStreamReceiveWindow: 26843545
  maxStreamReceiveWindow: 26843545
  initConnReceiveWindow: 67108864
  maxConnReceiveWindow: 67108864

bandwidth:
  up: ${up_bw} mbps
  down: ${down_bw} mbps

outbounds:
  - name: my_proxy
    type: http
    http:
      url: $proxy_url

acl:
  inline:
    - my_proxy(all)
EOF

        create_systemd_unit "$http_port" "$config_file"
        systemctl restart "hysteria-server@${http_port}.service"

        local client_cfg="/root/${domain}_${http_port}.json"
        cat >"$client_cfg" <<EOF
{
    "server": "$domain:$http_port",
    "auth": "$password",
    "transport": {
        "type": "udp",
        "udp": {
            "hopInterval": "10s"
        }
    },
    "tls": {
        "sni": "https://www.bing.com",
        "insecure": true,
        "alpn": ["h3"]
    },
    "quic": {
        "initStreamReceiveWindow": 26843545,
        "maxStreamReceiveWindow": 26843545,
        "initConnReceiveWindow": 67108864,
        "maxConnReceiveWindow": 67108864
    },
    "bandwidth": {
        "up": "${up_bw} mbps",
        "down": "${down_bw} mbps"
    },
    "http": {
        "listen": "0.0.0.0:$http_port"
    }
}
EOF
        echo -e "\n${GREEN}已生成端口 $http_port 实例，密码：$password"
        echo "服务端配置: $config_file"
        echo "客户端配置: $client_cfg"
        echo "--------------------------------------${NC}"
    done <<< "$proxies"
}

list_instances_and_delete() {
    echo -e "${GREEN}当前已部署的实例:${NC}"
    ls $CONFIG_DIR/config_*.yaml 2>/dev/null | while read -r config; do
        port=$(basename "$config" | sed 's/^config_//;s/\.yaml$//')
        status=$(systemctl is-active hysteria-server@"$port".service 2>/dev/null)
        echo "端口: $port | 配置: $config | 状态: $status"
    done
    echo
    read -p "要删除请输入端口号，输入 all 删除所有，直接回车仅查看: " port
    if [[ "$port" == "all" ]]; then
        for f in $CONFIG_DIR/config_*.yaml; do
            p=$(basename "$f" | sed 's/^config_//;s/\.yaml$//')
            delete_instance "$p"
        done
        echo -e "${GREEN}所有实例已删除。${NC}"
    elif [[ -n "$port" ]]; then
        delete_instance "$port"
    fi
}

delete_instance() {
    port="$1"
    config_file="$CONFIG_DIR/config_${port}.yaml"
    unit_file="${SYSTEMD_DIR}/hysteria-server@${port}.service"
    if [ -f "$config_file" ]; then
        systemctl stop "hysteria-server@${port}.service" >/dev/null 2>&1
        systemctl disable "hysteria-server@${port}.service" >/dev/null 2>&1
        rm -f "$config_file" "$unit_file"
        systemctl daemon-reload
        echo "实例 $port 已删除。"
    else
        echo -e "${RED}未找到端口 $port 的配置。${NC}"
    fi
}

manage_single_instance() {
    read -p "请输入实例端口号: " port
    echo "1. 启动  2. 停止  3. 重启"
    read -p "请选择操作[1-3]: " act
    case "$act" in
        1) systemctl start hysteria-server@$port.service ;;
        2) systemctl stop hysteria-server@$port.service ;;
        3) systemctl restart hysteria-server@$port.service ;;
        *) echo "无效选择" ;;
    esac
}

status_single_instance() {
    read -p "请输入实例端口号: " port
    systemctl status hysteria-server@$port.service
}

manage_all_instances() {
    echo "1. 启动全部  2. 停止全部  3. 重启全部"
    read -p "请选择操作[1-3]: " act
    for f in $CONFIG_DIR/config_*.yaml; do
        port=$(basename "$f" | sed 's/^config_//;s/\.yaml$//')
        case "$act" in
            1) systemctl start hysteria-server@$port.service ;;
            2) systemctl stop hysteria-server@$port.service ;;
            3) systemctl restart hysteria-server@$port.service ;;
            *) echo "无效选择" ;;
        esac
    done
}

status_all_instances() {
    for f in $CONFIG_DIR/config_*.yaml; do
        port=$(basename "$f" | sed 's/^config_//;s/\.yaml$//')
        status=$(systemctl is-active hysteria-server@$port.service 2>/dev/null)
        echo "端口: $port | 状态: $status"
    done
}

generate_instance_auto() {
    echo -e "${YELLOW}自动生成单实例配置:${NC}"
    while true; do
        read -p "请输入实例监听端口（如9202）: " http_port
        [[ "$http_port" =~ ^[0-9]+$ ]] && [ "$http_port" -ge 1 ] && [ "$http_port" -le 65535 ] && break
        echo -e "${RED}无效端口，请重新输入${NC}"
    done

    if is_port_in_use "$http_port" || [ -f "$CONFIG_DIR/config_${http_port}.yaml" ]; then
        echo -e "${RED}端口 $http_port 已被占用或已存在实例，请换一个端口。${NC}"
        return
    fi

    echo -e "${YELLOW}请输入带宽限制（单位 mbps，直接回车为默认185）：${NC}"
    read -p "上行带宽 [185]: " up_bw
    read -p "下行带宽 [185]: " down_bw
    up_bw=${up_bw:-185}
    down_bw=${down_bw:-185}

    local domain=$(curl -s ipinfo.io/ip || curl -s myip.ipip.net | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" || curl -s https://api.ip.sb/ip)
    if [ -z "$domain" ]; then
        read -p "请输入服务器公网IP: " domain
    fi
    local crt_and_key; crt_and_key=$(gen_cert "$domain")
    local crt=$(echo "$crt_and_key" | cut -d'|' -f1)
    local key=$(echo "$crt_and_key" | cut -d'|' -f2)

    password=$(openssl rand -base64 16)
    echo -e "${YELLOW}本实例自动生成的密码:${NC} $password"

    read -p "是否为该实例添加代理出口？(y/n): " add_proxy

    local proxy_config=""
    if [[ "$add_proxy" == "y" ]]; then
        read -p "请输入代理信息（格式: IP:端口:用户名:密码）: " proxy_raw
        IFS=':' read -r proxy_ip proxy_port proxy_user proxy_pass <<< "$proxy_raw"
        proxy_url="http://$proxy_user:$proxy_pass@$proxy_ip:$proxy_port"
        proxy_config="
outbounds:
  - name: my_proxy
    type: http
    http:
      url: $proxy_url

acl:
  inline:
    - my_proxy(all)"
    fi

    local config_file="$CONFIG_DIR/config_${http_port}.yaml"
    cat >"$config_file" <<EOF
listen: :$http_port

tls:
  cert: $crt
  key: $key

auth:
  type: password
  password: $password

masquerade:
  proxy:
    url: https://www.bing.com
    rewriteHost: true

quic:
  initStreamReceiveWindow: 26843545
  maxStreamReceiveWindow: 26843545
  initConnReceiveWindow: 67108864
  maxConnReceiveWindow: 67108864

bandwidth:
  up: ${up_bw} mbps
  down: ${down_bw} mbps
$proxy_config
EOF

    create_systemd_unit "$http_port" "$config_file"
    systemctl restart "hysteria-server@${http_port}.service"

    local client_cfg="/root/${domain}_${http_port}.json"
    cat >"$client_cfg" <<EOF
{
    "server": "$domain:$http_port",
    "auth": "$password",
    "transport": {
        "type": "udp",
        "udp": {
            "hopInterval": "10s"
        }
    },
    "tls": {
        "sni": "https://www.bing.com",
        "insecure": true,
        "alpn": ["h3"]
    },
    "quic": {
        "initStreamReceiveWindow": 26843545,
        "maxStreamReceiveWindow": 26843545,
        "initConnReceiveWindow": 67108864,
        "maxConnReceiveWindow": 67108864
    },
    "bandwidth": {
        "up": "${up_bw} mbps",
        "down": "${down_bw} mbps"
    },
    "http": {
        "listen": "0.0.0.0:$http_port"
    }
}
EOF

    echo -e "${GREEN}实例已创建并启动。${NC}"
    echo "服务端配置文件: $config_file"
    echo "客户端配置文件: $client_cfg"
    echo "服务器IP: $domain"
    echo "监听端口: $http_port"
    echo "密码: $password"
}

main_menu() {
    check_env
    while true; do
        echo -e "${GREEN}===== Hysteria2 多实例批量管理 =====${NC}"
        echo "1. 批量新建实例"
        echo "2. 查看所有实例 & 删除某实例/所有实例"
        echo "3. 启动/停止/重启某实例"
        echo "4. 查看某实例状态"
        echo "5. 启动/停止/重启所有实例"
        echo "6. 查看所有实例状态"
        echo "7. 全自动生成单实例配置"
        echo "0. 退出"
        read -p "请选择[0-7]: " opt
        case "$opt" in
            1) generate_instances_batch ;;
            2) list_instances_and_delete; read -p "按回车返回..." ;;
            3) manage_single_instance ;;
            4) status_single_instance ;;
            5) manage_all_instances ;;
            6) status_all_instances; read -p "按回车返回..." ;;
            7) generate_instance_auto ;;
            0) exit 0 ;;
            *) echo "无效选择" ;;
        esac
    done
}

main_menu

case "$1" in
    "install")
        generate_server_config
        ;;
    "manage")
        server_menu
        ;;
    *)
        echo "用法: $0 {install|manage}"
        exit 1
        ;;
esac
SERVEREOF
    chmod +x /root/hysteria/server.sh

    # 创建并赋权 client.sh
cat > /root/hysteria/client.sh << 'CLIENTEOF'
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
CLIENTEOF
    chmod +x /root/hysteria/client.sh

    # 创建并赋权 config.sh
cat > /root/hysteria/config.sh << 'CONFIGEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 系统优化
optimize() {
    printf "%b正在优化系统配置...%b\n" "${YELLOW}" "${NC}"
    
    # 提供用户选择模式
    printf "%b请选择拥塞控制模式:%b\n" "${YELLOW}" "${NC}"
    echo "1. Brutal 拥塞控制"
    echo "2. BBR 拥塞控制"
    echo "3. 两者结合 (BBR+FQ)"
    read -p "请输入选择 [1-3]: " congestion_control_choice

    case "$congestion_control_choice" in
        1)
            congestion_control="brutal"
            ;;
        2)
            congestion_control="bbr"
            ;;
        3)
            congestion_control="bbr"
            default_qdisc="fq"
            ;;
        *)
            printf "%b无效选择，默认使用 Brutal 拥塞控制%b\n" "${RED}" "${NC}"
            congestion_control="brutal"
            ;;
    esac
    
    # 确保 BBR 可用
    if [[ "$congestion_control" == "bbr" ]]; then
        if ! lsmod | grep -q bbr; then
            printf "%bBBR 未启用，正在安装...%b\n" "${YELLOW}" "${NC}"
            echo "tcp_bbr" | tee /etc/modules-load.d/bbr.conf
            modprobe tcp_bbr
            cat >> /etc/sysctl.d/99-bbr.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
            sysctl --system
            printf "%bBBR 已成功启用！%b\n" "${GREEN}" "${NC}"
        else
            printf "%bBBR 已经启用，无需重复安装。%b\n" "${GREEN}" "${NC}"
        fi
    fi
    
    # 创建 sysctl 配置文件
    cat > /etc/sysctl.d/99-hysteria.conf << EOF
# 设置16MB缓冲区
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=16777216
net.core.wmem_default=16777216
# TCP缓冲区设置
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 87380 16777216
# 启用 $congestion_control 拥塞控制
net.ipv4.tcp_congestion_control=$congestion_control
EOF

    # 如果选择了 BBR+FQ，添加 default_qdisc 设置
    if [ "$default_qdisc" == "fq" ]; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.d/99-hysteria.conf
    fi
    
    # 其他网络优化
    cat >> /etc/sysctl.d/99-hysteria.conf << EOF
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
# Hysteria QUIC优化
net.ipv4.ip_forward=1
net.ipv4.tcp_mtu_probing=1
EOF
    
    # 立即应用 sysctl 设置
    sysctl -p /etc/sysctl.d/99-hysteria.conf
    
    # 设置系统文件描述符限制
    cat > /etc/security/limits.d/99-hysteria.conf << EOF
* soft nofile 1000000
* hard nofile 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF

    # 创建优先级配置文件
    mkdir -p /etc/systemd/system/hysteria-server.service.d
    cat > /etc/systemd/system/hysteria-server.service.d/priority.conf << EOF
[Service]
CPUSchedulingPolicy=rr
CPUSchedulingPriority=99
EOF

    # 重载 systemd 配置文件并重启服务
    systemctl daemon-reload
    systemctl restart hysteria-server.service

    # 立即设置当前会话的缓冲区
    sysctl -w net.core.rmem_max=16777216
    sysctl -w net.core.wmem_max=16777216

    printf "%b系统优化完成，已设置：%b\n" "${GREEN}" "${NC}"
    echo "1. 发送/接收缓冲区: 16MB"
    echo "2. 文件描述符限制: 1000000"
    echo "3. 拥塞控制: $congestion_control"
    [ "$default_qdisc" == "fq" ] && echo "4. 默认队列规则: fq"
    echo "5. TCP Fast Open"
    echo "6. QUIC优化"
    echo "7. CPU 调度优先级"
    sleep 2
}

# 版本更新
update() {
    printf "%b正在检查更新...%b\n" "${YELLOW}" "${NC}"
    
    # 备份当前配置
    cp /etc/hysteria/config.yaml /etc/hysteria/config.yaml.bak 2>/dev/null
    
    # 根据地理位置选择下载源
    if curl -s http://ipinfo.io | grep -q '"country": "CN"'; then
        local url="https://hub.gitmirror.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    else
        local url="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    fi
    
    printf "%b尝试从 %s 下载...%b\n" "${YELLOW}" "$url" "${NC}"
    if wget -O /usr/local/bin/hysteria.new "$url" && 
       chmod +x /usr/local/bin/hysteria.new &&
       /usr/local/bin/hysteria.new version >/dev/null 2>&1; then
        mv /usr/local/bin/hysteria.new /usr/local/bin/hysteria
        printf "%b更新成功%b\n" "${GREEN}" "${NC}"
    else
        printf "%b更新失败%b\n" "${RED}" "${NC}"
        [ -f /etc/hysteria/config.yaml.bak ] && mv /etc/hysteria/config.yaml.bak /etc/hysteria/config.yaml
        return 1
    fi
    
    systemctl restart hysteria-server
    sleep 2
}

# 完全卸载
uninstall() {
    printf "%b═══════ 卸载确认 ═══════%b\n" "${YELLOW}" "${NC}"
    read -p "确定要卸载Hysteria吗？(y/n): " confirm
    if [[ $confirm == [yY] ]]; then
        printf "%b正在卸载...%b\n" "${YELLOW}" "${NC}"
        
        systemctl stop hysteria-server
        systemctl disable hysteria-server
        
        rm -rf /etc/hysteria
        rm -rf /root/H2
        rm -f /usr/local/bin/hysteria
        rm -f /usr/local/bin/h2
        rm -f /etc/systemd/system/hysteria-server.service
        rm -f /etc/sysctl.d/99-hysteria.conf
        rm -f /etc/security/limits.d/99-hysteria.conf
        rm -f /root/{main,server,client,config}.sh
        
        systemctl daemon-reload
        
        printf "%b卸载完成%b\n" "${GREEN}" "${NC}"
        exit 0
    fi
}

# 根据参数执行对应功能
case "$1" in
    "optimize")
        optimize
        ;;
    "update")
        update
        ;;
    "uninstall")
        uninstall
        ;;
    *)
        echo "用法: $0 {optimize|update|uninstall}"
        exit 1
        ;;
esac
CONFIGEOF
    chmod +x /root/hysteria/config.sh

    # 创建启动器命令
    cat > /usr/local/bin/h2 << 'CMDEOF'
#!/bin/bash
cd /root/hysteria
[ "$EUID" -ne 0 ] && printf "\033[0;31m请使用root权限运行此脚本\033[0m\n" && exit 1
bash ./main.sh
CMDEOF
chmod +x /usr/local/bin/h2

    printf "%b所有模块脚本创建完成%b\n" "${GREEN}" "${NC}"
}

# 清理旧的安装
cleanup_old_installation() {
    printf "%b清理旧的安装...%b\n" "${YELLOW}" "${NC}"
    systemctl stop hysteria-server 2>/dev/null
    systemctl disable hysteria-server 2>/dev/null
    pkill -f hysteria
    
    rm -rf /etc/hysteria
    rm -rf /root/H2
    rm -f /usr/local/bin/hysteria
    rm -f /usr/local/bin/h2
    rm -f /etc/systemd/system/hysteria-server.service
    rm -f /etc/sysctl.d/99-hysteria.conf
    rm -f /etc/security/limits.d/99-hysteria.conf
    rm -f /root/{main,server,client,config}.sh
    
    systemctl daemon-reload
}

# 安装基础依赖
install_base() {
    printf "%b安装基础依赖...%b\n" "${YELLOW}" "${NC}"
    if [ -f /etc/debian_version ]; then
        apt update
        apt install -y curl wget openssl net-tools
    elif [ -f /etc/redhat-release ]; then
        yum install -y curl wget openssl net-tools
    else
        printf "%b不支持的系统%b\n" "${RED}" "${NC}"
        exit 1
    fi
}

# 安装Hysteria
install_hysteria() {
    printf "%b开始安装Hysteria...%b\n" "${YELLOW}" "${NC}"
    
    local urls=(
        "https://47.76.180.181:34164/down/ZMeXKe2ndY8z"
        "https://gh.ddlc.top/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://hub.gitmirror.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    )
    
    for url in "${urls[@]}"; do
        printf "%b尝试从 %s 下载...%b\n" "${YELLOW}" "$url" "${NC}"
        
        # 使用 wget 下载文件并检查是否成功
        if wget --no-check-certificate -O /usr/local/bin/hysteria "$url" && \
           chmod +x /usr/local/bin/hysteria && \
           /usr/local/bin/hysteria version >/dev/null 2>&1; then
            printf "%bHysteria安装成功%b\n" "${GREEN}" "${NC}"
            return 0
        else
            printf "%b从 %s 下载失败...%b\n" "${RED}" "$url" "${NC}"
        fi
    done
    
    # 如果所有下载源都失败，尝试使用 curl 安装
    if curl -fsSL https://get.hy2.dev/ | bash; then
        printf "%bHysteria安装成功%b\n" "${GREEN}" "${NC}"
        return 0
    fi

    printf "%bHysteria安装失败%b\n" "${RED}" "${NC}"
    return 1
}

# 创建systemd服务
create_systemd_service() {
    printf "%b创建systemd服务...%b\n" "${YELLOW}" "${NC}"
    
    cat > /etc/systemd/system/hysteria-server.service << EOF
[Unit]
Description=Hysteria Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable hysteria-server
    printf "%bSystemd服务创建完成%b\n" "${GREEN}" "${NC}"
}

# 主函数
main() {
    clear
    printf "%b════════ Hysteria 管理脚本 安装程序 ════════%b\n" "${GREEN}" "${NC}"
    printf "%b作者: ${AUTHOR}%b\n" "${GREEN}" "${NC}"
    printf "%b版本: ${VERSION}%b\n" "${GREEN}" "${NC}"
    printf "%b============================================%b\n" "${GREEN}" "${NC}"
    
    cleanup_old_installation
    install_base || exit 1
    install_hysteria || exit 1
    create_all_scripts
    create_systemd_service
    
    printf "\n%b安装完成！%b\n" "${GREEN}" "${NC}"
    printf "使用 %bh2%b 命令启动管理面板\n" "${YELLOW}" "${NC}"
}

main
