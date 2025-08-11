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

# 直接调用主菜单
main_menu() {
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
            1) bash ./config.sh install ;;
            2) bash ./server.sh ;;
            3) bash ./client.sh ;;
            4) bash ./config.sh optimize ;;
            5) bash ./config.sh update ;;
            6)
                echo -e "${YELLOW}服务端状态:${NC}"
                systemctl status hysteria-server@* --no-pager 2>/dev/null || echo "没有运行的服务端实例"
                echo
                echo -e "${YELLOW}客户端状态:${NC}"
                systemctl status hysteriaclient@* --no-pager 2>/dev/null || echo "没有运行的客户端实例"
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
}

# 启动主菜单
main_menu
MAINEOF
    chmod +x /root/hysteria/main.sh

    # 创建并赋权 server.sh
cat > /root/hysteria/server.sh << 'SERVEREOF'
#!/bin/bash

# 移除 set -e，避免在删除操作中因非关键错误而退出
# set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

HYSTERIA_BIN="/usr/local/bin/hysteria"
SYSTEMD_DIR="/etc/systemd/system"
CONFIG_DIR="/etc/hysteria"

check_env() {
    echo -e "${YELLOW}检查环境依赖...${NC}"
    
    if ! command -v openssl >/dev/null 2>&1; then
        echo -e "${RED}错误: 请先安装 openssl${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ openssl 已安装${NC}"
    
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${RED}错误: 请先安装 curl${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ curl 已安装${NC}"
    
    if [ ! -f "$HYSTERIA_BIN" ]; then
        echo -e "${RED}错误: 请先安装 hysteria${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ hysteria 已安装${NC}"
    
    # 检查systemd是否可用
    if ! command -v systemctl >/dev/null 2>&1; then
        echo -e "${RED}错误: systemd 不可用${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ systemd 可用${NC}"
    
    # 创建配置目录
    mkdir -p "$CONFIG_DIR"
    echo -e "${GREEN}✓ 配置目录已创建${NC}"
    
    echo -e "${GREEN}环境检查完成${NC}"
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
    
    # 创建systemd服务文件
    cat >"$unit_file" <<EOF
[Unit]
Description=Hysteria2 Server Instance on port $port
After=network.target

[Service]
Type=simple
ExecStart=$HYSTERIA_BIN server -c $config_file
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    # 启用服务（不重新加载systemd）
    if systemctl enable "hysteria-server@${port}.service" >/dev/null 2>&1; then
        echo -e "${GREEN}服务 hysteria-server@${port}.service 已启用${NC}"
    else
        echo -e "${RED}启用服务 hysteria-server@${port}.service 失败${NC}"
        return 1
    fi
}

create_systemd_unit_batch() {
    local port=$1
    local config_file=$2
    local unit_file="${SYSTEMD_DIR}/hysteria-server@${port}.service"
    
    # 创建systemd服务文件
    cat >"$unit_file" <<EOF
[Unit]
Description=Hysteria2 Server Instance on port $port
After=network.target

[Service]
Type=simple
ExecStart=$HYSTERIA_BIN server -c $config_file
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    # 启用服务（不重新加载systemd）
    if systemctl enable "hysteria-server@${port}.service" >/dev/null 2>&1; then
        echo -e "${GREEN}服务 hysteria-server@${port}.service 已启用${NC}"
    else
        echo -e "${RED}启用服务 hysteria-server@${port}.service 失败${NC}"
        return 1
    fi
}

# 创建服务端统一服务
create_server_unified_service() {
    local unit_file="${SYSTEMD_DIR}/hysteria-server-manager.service"
    
    # 创建统一服务文件
    cat >"$unit_file" <<EOF
[Unit]
Description=Hysteria2 Server Manager - Manages all server configurations
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'for cfg in $CONFIG_DIR/config_*.yaml; do if [ -f "\$cfg" ]; then $HYSTERIA_BIN server -c "\$cfg" &; fi; done; wait'
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    # 启用服务
    if systemctl enable "hysteria-server-manager.service" >/dev/null 2>&1; then
        echo -e "${GREEN}统一服务 hysteria-server-manager.service 已启用${NC}"
    else
        echo -e "${RED}启用统一服务 hysteria-server-manager.service 失败${NC}"
        return 1
    fi
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

    # 选择双端部署模式
    echo -e "${YELLOW}双端部署模式选择:${NC}"
    echo "1. 双端同机（客户端和服务器在同一台机器）"
    echo "2. 双端不同机（客户端和服务器在不同机器）"
    read -p "请选择部署模式 [1-2]: " deploy_mode
    
    case "$deploy_mode" in
        1)
            server_address="127.0.0.1"
            ;;
        2)
            server_address="$domain"
            ;;
        *)
            echo -e "${RED}无效选择，默认使用双端不同机模式${NC}"
            server_address="$domain"
            ;;
    esac
    
    # 配置客户端代理认证信息
    echo -e "${YELLOW}客户端代理认证配置（HTTP和SOCKS5使用相同认证信息）:${NC}"
    read -p "代理用户名（直接回车跳过）: " proxy_username
    read -p "代理密码（直接回车跳过）: " proxy_password
    read -p "HTTP代理认证域 [hy2-proxy]: " http_realm
    http_realm=${http_realm:-hy2-proxy}
    
    # 生成代理认证配置
    proxy_config=""
    if [[ -n "$proxy_username" && -n "$proxy_password" ]]; then
        proxy_config=",
    \"username\": \"$proxy_username\",
    \"password\": \"$proxy_password\""
    fi

    read -p "请输入批量新建实例的起始端口: " start_port
    current_port="$start_port"

    local domain=$(curl -s ipinfo.io/ip || curl -s myip.ipip.net | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" || curl -s https://api.ip.sb/ip)
    if [ -z "$domain" ]; then
        read -p "请输入服务器公网IP: " domain
    fi
    local crt_and_key; crt_and_key=$(gen_cert "$domain")
    local crt=$(echo "$crt_and_key" | cut -d'|' -f1)
    local key=$(echo "$crt_and_key" | cut -d'|' -f2)

    # 收集要创建的端口列表
    ports_to_create=()
    configs_to_create=()
    
    while read -r proxy_raw; do
        [[ -z "$proxy_raw" ]] && continue
        while is_port_in_use "$current_port" || [ -f "$CONFIG_DIR/config_${current_port}.yaml" ]; do
            echo "端口 $current_port 已被占用，尝试下一个端口..."
            current_port=$((current_port + 1))
        done

        IFS=':' read -r proxy_ip proxy_port proxy_user proxy_pass <<< "$proxy_raw"
        server_port="$current_port"
        current_port=$((current_port + 1))
        password=$(openssl rand -base64 16)
        proxy_url="http://$proxy_user:$proxy_pass@$proxy_ip:$proxy_port"
        config_file="$CONFIG_DIR/config_${server_port}.yaml"

        cat >"$config_file" <<EOF
listen: :$server_port

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

        # 收集端口和配置文件信息
        ports_to_create+=("$server_port")
        configs_to_create+=("$config_file")

        local client_cfg="/root/${domain}_${server_port}.json"
        cat >"$client_cfg" <<EOF
{
  "server": "$server_address:$server_port",
  "auth": "$password",
  "transport": {
    "type": "udp",
    "udp": {
      "hopInterval": "10s"
    }
  },
  "tls": {
    "sni": "www.bing.com",
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
    "listen": "0.0.0.0:$server_port",
    "username": "$proxy_username",
    "password": "$proxy_password",
    "realm": "$http_realm"
  },
  "socks5": {
    "listen": "0.0.0.0:$server_port",
    "username": "$proxy_username",
    "password": "$proxy_password"
  }
}
EOF
        echo -e "\n${GREEN}已生成端口 $server_port 实例，密码：$password"
        echo "服务端配置: $config_file"
        echo "客户端配置: $client_cfg"
        echo "--------------------------------------${NC}"
    done <<< "$proxies"
    
    # 询问启动方式
    echo -e "${YELLOW}选择启动方式：${NC}"
    echo "1. 使用统一服务管理（推荐，一个服务管理所有配置）"
    echo "2. 使用多实例服务（每个配置一个服务）"
    echo "3. 直接启动进程（速度快，但重启后需要手动启动）"
    read -p "请选择 [1-3]: " create_service
    
    case "$create_service" in
        1)
            # 统一服务模式
            echo -e "${YELLOW}正在创建统一服务管理所有配置...${NC}"
            if create_server_unified_service; then
                echo -e "${GREEN}✓ 统一服务创建成功${NC}"
                
                # 重新加载systemd配置
                echo -e "${YELLOW}正在重新加载systemd配置...${NC}"
                systemctl daemon-reload
                
                # 启动统一服务
                echo -e "${YELLOW}正在启动统一服务...${NC}"
                if systemctl start "hysteria-server-manager.service"; then
                    echo -e "${GREEN}✓ 统一服务启动成功，正在管理所有配置文件${NC}"
                    # 显示正在管理的配置文件
                    for i in "${!ports_to_create[@]}"; do
                        local port="${ports_to_create[$i]}"
                        echo -e "${GREEN}  - 管理配置：端口 $port${NC}"
                    done
                else
                    echo -e "${RED}✗ 统一服务启动失败${NC}"
                    systemctl status "hysteria-server-manager.service" --no-pager
                fi
            else
                echo -e "${RED}✗ 统一服务创建失败${NC}"
            fi
            ;;
        2)
            # 多实例服务模式
            echo -e "${YELLOW}正在批量创建systemd服务...${NC}"
            for i in "${!ports_to_create[@]}"; do
                if create_systemd_unit_batch "${ports_to_create[$i]}" "${configs_to_create[$i]}"; then
                    echo -e "${GREEN}✓ 服务 hysteria-server@${ports_to_create[$i]}.service 创建成功${NC}"
                else
                    echo -e "${RED}✗ 创建服务 hysteria-server@${ports_to_create[$i]}.service 失败${NC}"
                fi
            done
            
            # 一次性重新加载systemd配置
            echo -e "${YELLOW}正在重新加载systemd配置...${NC}"
            systemctl daemon-reload
            
            # 批量启动所有服务
            echo -e "${YELLOW}正在批量启动所有服务...${NC}"
            for port in "${ports_to_create[@]}"; do
                if systemctl start "hysteria-server@${port}.service"; then
                    echo -e "${GREEN}✓ 服务 hysteria-server@${port}.service 启动成功${NC}"
                else
                    echo -e "${RED}✗ 服务 hysteria-server@${port}.service 启动失败${NC}"
                    systemctl status "hysteria-server@${port}.service" --no-pager
                fi
            done
            ;;
        3)
            # 直接进程模式
            echo -e "${YELLOW}正在直接启动hysteria进程...${NC}"
            for i in "${!ports_to_create[@]}"; do
                local port="${ports_to_create[$i]}"
                local config="${configs_to_create[$i]}"
                
                # 检查是否已有进程在运行
                if pgrep -f "hysteria.*server.*-c.*$config" >/dev/null; then
                    echo -e "${YELLOW}端口 $port 的进程已在运行，跳过${NC}"
                    continue
                fi
                
                # 后台启动hysteria进程
                nohup $HYSTERIA_BIN server -c "$config" >/dev/null 2>&1 &
                local pid=$!
                
                # 等待一下确保进程启动
                sleep 0.5
                
                # 检查进程是否成功启动
                if kill -0 "$pid" 2>/dev/null; then
                    echo -e "${GREEN}✓ 端口 $port 的hysteria进程启动成功 (PID: $pid)${NC}"
                else
                    echo -e "${RED}✗ 端口 $port 的hysteria进程启动失败${NC}"
                fi
            done
            ;;
    esac
}

list_instances_and_delete() {
    echo -e "${GREEN}当前已部署的实例:${NC}"
    
    # 检查是否有配置文件
    if ! ls $CONFIG_DIR/config_*.yaml 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有已部署的实例${NC}"
        echo
        read -p "按回车键返回..."
        return
    fi
    
    # 使用进程替换避免子shell问题
    while IFS= read -r config; do
        port=$(basename "$config" | sed 's/^config_//;s/\.yaml$//')
        status=$(systemctl is-active hysteria-server@"$port".service 2>/dev/null || echo "inactive")
        echo "端口: $port | 配置: $config | 状态: $status"
    done < <(ls $CONFIG_DIR/config_*.yaml 2>/dev/null)
    
    echo
    echo -e "${YELLOW}删除选项:${NC}"
    echo "1. 输入单个端口号 (如: 56000)"
    echo "2. 输入端口范围 (如: 56000-56005)"
    echo "3. 输入 'all' 删除所有实例"
    echo "4. 直接回车仅查看"
    read -p "请选择删除方式: " port
    
    if [[ "$port" == "all" ]]; then
        echo -e "${YELLOW}确认删除所有实例？(y/n): ${NC}"
        read -p "" confirm
        if [[ "$confirm" == [yY] ]]; then
            deleted_count=0
            while IFS= read -r f; do
                p=$(basename "$f" | sed 's/^config_//;s/\.yaml$//')
                if delete_instance "$p"; then
                    ((deleted_count++))
                fi
            done < <(ls $CONFIG_DIR/config_*.yaml 2>/dev/null)
            echo -e "${GREEN}已删除 $deleted_count 个实例${NC}"
        else
            echo -e "${YELLOW}取消删除操作${NC}"
        fi
    elif [[ -n "$port" ]]; then
        # 检查是否为端口范围 (格式: start-end)
        if [[ "$port" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start_port=${BASH_REMATCH[1]}
            end_port=${BASH_REMATCH[2]}
            
            # 验证端口范围
            if [ "$start_port" -gt "$end_port" ]; then
                echo -e "${RED}端口范围错误：起始端口不能大于结束端口${NC}"
            else
                echo -e "${YELLOW}确认删除端口范围 $start_port-$end_port 的所有实例？(y/n): ${NC}"
                read -p "" confirm
                if [[ "$confirm" == [yY] ]]; then
                    deleted_count=0
                    ports_to_delete=()
                    
                    # 先收集要删除的端口
                    while IFS= read -r f; do
                        p=$(basename "$f" | sed 's/^config_//;s/\.yaml$//')
                        if [ "$p" -ge "$start_port" ] && [ "$p" -le "$end_port" ]; then
                            ports_to_delete+=("$p")
                        fi
                    done < <(ls $CONFIG_DIR/config_*.yaml 2>/dev/null)
                    
                    echo -e "${YELLOW}找到 ${#ports_to_delete[@]} 个实例在指定范围内${NC}"
                    
                    # 执行删除操作
                    for p in "${ports_to_delete[@]}"; do
                        echo -e "${YELLOW}正在删除端口 $p...${NC}"
                        if delete_instance "$p"; then
                            ((deleted_count++))
                        fi
                    done
                    
                    # 重新加载systemd配置
                    systemctl daemon-reload
                    
                    if [ $deleted_count -eq 0 ]; then
                        echo -e "${YELLOW}在指定端口范围内没有找到实例${NC}"
                    else
                        echo -e "${GREEN}已删除 $deleted_count 个实例${NC}"
                    fi
                else
                    echo -e "${YELLOW}取消删除操作${NC}"
                fi
            fi
        else
            # 单个端口删除
            delete_instance "$port"
        fi
    fi
    
    echo
    read -p "按回车键返回..."
}

delete_instance() {
    port="$1"
    config_file="$CONFIG_DIR/config_${port}.yaml"
    unit_file="${SYSTEMD_DIR}/hysteria-server@${port}.service"
    
    if [ -f "$config_file" ]; then
        # 停止服务（忽略错误）
        systemctl stop "hysteria-server@${port}.service" >/dev/null 2>&1 || true
        # 禁用服务（忽略错误）
        systemctl disable "hysteria-server@${port}.service" >/dev/null 2>&1 || true
        # 删除配置文件和服务文件（忽略错误）
        rm -f "$config_file" "$unit_file" 2>/dev/null || true
        echo -e "${GREEN}实例 $port 已删除。${NC}"
        return 0
    else
        echo -e "${YELLOW}端口 $port 的配置文件不存在，跳过删除。${NC}"
        return 1
    fi
}

manage_single_instance() {
    read -p "请输入实例端口号: " port
    
    # 验证端口号
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}无效的端口号${NC}"
        return
    fi
    
    # 检查配置文件是否存在
    if [ ! -f "$CONFIG_DIR/config_${port}.yaml" ]; then
        echo -e "${RED}端口 $port 的配置文件不存在${NC}"
        return
    fi
    
    echo "1. 启动  2. 停止  3. 重启"
    read -p "请选择操作[1-3]: " act
    case "$act" in
        1) 
            if systemctl start hysteria-server@$port.service >/dev/null 2>&1; then
                echo -e "${GREEN}✓ 已启动端口 $port${NC}"
            else
                echo -e "${RED}✗ 启动端口 $port 失败${NC}"
                systemctl status hysteria-server@$port.service --no-pager
            fi
            ;;
        2) 
            if systemctl stop hysteria-server@$port.service >/dev/null 2>&1; then
                echo -e "${YELLOW}✓ 已停止端口 $port${NC}"
            else
                echo -e "${RED}✗ 停止端口 $port 失败${NC}"
            fi
            ;;
        3) 
            if systemctl restart hysteria-server@$port.service >/dev/null 2>&1; then
                echo -e "${GREEN}✓ 已重启端口 $port${NC}"
            else
                echo -e "${RED}✗ 重启端口 $port 失败${NC}"
                systemctl status hysteria-server@$port.service --no-pager
            fi
            ;;
        *) echo -e "${RED}无效选择${NC}" ;;
    esac
}

status_single_instance() {
    read -p "请输入实例端口号: " port
    
    # 验证端口号
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}无效的端口号${NC}"
        return
    fi
    
    # 检查配置文件是否存在
    if [ ! -f "$CONFIG_DIR/config_${port}.yaml" ]; then
        echo -e "${RED}端口 $port 的配置文件不存在${NC}"
        return
    fi
    
    systemctl status hysteria-server@$port.service --no-pager
}

manage_all_instances() {
    echo -e "${GREEN}批量管理实例:${NC}"
    echo "1. 管理所有实例"
    echo "2. 管理指定端口范围的实例"
    read -p "请选择管理方式[1-2]: " manage_type
    
    case "$manage_type" in
        1)
            manage_all_instances_internal
            ;;
        2)
            manage_port_range_instances
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return
            ;;
    esac
}

manage_all_instances_internal() {
    echo "1. 启动全部  2. 停止全部  3. 重启全部"
    read -p "请选择操作[1-3]: " act
    
    # 检查是否有配置文件
    if ! ls $CONFIG_DIR/config_*.yaml 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有已部署的实例${NC}"
        return
    fi
    
    # 询问管理方式
    echo -e "${YELLOW}选择管理方式：${NC}"
    echo "1. 使用统一服务管理（如果使用统一服务）"
    echo "2. 使用多实例服务管理（如果使用多实例服务）"
    echo "3. 自动检测并管理（推荐）"
    read -p "请选择 [1-3]: " manage_method
    
    case "$manage_method" in
        1)
            # 统一服务管理
            case "$act" in
                1) 
                    if systemctl start hysteria-server-manager.service >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ 统一服务启动成功，所有实例已启动${NC}"
                    else
                        echo -e "${RED}✗ 统一服务启动失败${NC}"
                    fi
                    ;;
                2) 
                    if systemctl stop hysteria-server-manager.service >/dev/null 2>&1; then
                        echo -e "${YELLOW}✓ 统一服务停止成功，所有实例已停止${NC}"
                    else
                        echo -e "${RED}✗ 统一服务停止失败${NC}"
                    fi
                    ;;
                3) 
                    if systemctl restart hysteria-server-manager.service >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ 统一服务重启成功，所有实例已重启${NC}"
                    else
                        echo -e "${RED}✗ 统一服务重启失败${NC}"
                    fi
                    ;;
                *) echo -e "${RED}无效选择${NC}" ;;
            esac
            ;;
        2)
            # 多实例服务管理
            while IFS= read -r f; do
                port=$(basename "$f" | sed 's/^config_//;s/\.yaml$//')
                case "$act" in
                    1) 
                        if systemctl start hysteria-server@$port.service >/dev/null 2>&1; then
                            echo -e "${GREEN}✓ 已启动端口 $port${NC}"
                        else
                            echo -e "${RED}✗ 启动端口 $port 失败${NC}"
                        fi
                        ;;
                    2) 
                        if systemctl stop hysteria-server@$port.service >/dev/null 2>&1; then
                            echo -e "${YELLOW}✓ 已停止端口 $port${NC}"
                        else
                            echo -e "${RED}✗ 停止端口 $port 失败${NC}"
                        fi
                        ;;
                    3) 
                        if systemctl restart hysteria-server@$port.service >/dev/null 2>&1; then
                            echo -e "${GREEN}✓ 已重启端口 $port${NC}"
                        else
                            echo -e "${RED}✗ 重启端口 $port 失败${NC}"
                        fi
                        ;;
                    *) echo -e "${RED}无效选择${NC}" ;;
                esac
            done < <(ls $CONFIG_DIR/config_*.yaml 2>/dev/null)
            ;;
        3)
            # 自动检测并管理
            if systemctl is-active --quiet hysteria-server-manager.service 2>/dev/null; then
                # 是统一服务
                case "$act" in
                    1) 
                        if systemctl start hysteria-server-manager.service >/dev/null 2>&1; then
                            echo -e "${GREEN}✓ 统一服务启动成功，所有实例已启动${NC}"
                        else
                            echo -e "${RED}✗ 统一服务启动失败${NC}"
                        fi
                        ;;
                    2) 
                        if systemctl stop hysteria-server-manager.service >/dev/null 2>&1; then
                            echo -e "${YELLOW}✓ 统一服务停止成功，所有实例已停止${NC}"
                        else
                            echo -e "${RED}✗ 统一服务停止失败${NC}"
                        fi
                        ;;
                    3) 
                        if systemctl restart hysteria-server-manager.service >/dev/null 2>&1; then
                            echo -e "${GREEN}✓ 统一服务重启成功，所有实例已重启${NC}"
                        else
                            echo -e "${RED}✗ 统一服务重启失败${NC}"
                        fi
                        ;;
                    *) echo -e "${RED}无效选择${NC}" ;;
                esac
            else
                # 是多实例服务
                while IFS= read -r f; do
                    port=$(basename "$f" | sed 's/^config_//;s/\.yaml$//')
                    case "$act" in
                        1) 
                            if systemctl start hysteria-server@$port.service >/dev/null 2>&1; then
                                echo -e "${GREEN}✓ 已启动端口 $port${NC}"
                            else
                                echo -e "${RED}✗ 启动端口 $port 失败${NC}"
                            fi
                            ;;
                        2) 
                            if systemctl stop hysteria-server@$port.service >/dev/null 2>&1; then
                                echo -e "${YELLOW}✓ 已停止端口 $port${NC}"
                            else
                                echo -e "${RED}✗ 停止端口 $port 失败${NC}"
                            fi
                            ;;
                        3) 
                            if systemctl restart hysteria-server@$port.service >/dev/null 2>&1; then
                                echo -e "${GREEN}✓ 已重启端口 $port${NC}"
                            else
                                echo -e "${RED}✗ 重启端口 $port 失败${NC}"
                            fi
                            ;;
                        *) echo -e "${RED}无效选择${NC}" ;;
                    esac
                done < <(ls $CONFIG_DIR/config_*.yaml 2>/dev/null)
            fi
            ;;
    esac
}

manage_port_range_instances() {
    echo -e "${GREEN}管理指定端口范围的实例:${NC}"
    read -p "请输入端口范围 (格式: 56000-56005): " port_range
    
    # 验证端口范围格式
    if [[ ! "$port_range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        echo -e "${RED}端口范围格式错误，请使用 起始端口-结束端口 格式${NC}"
        return
    fi
    
    start_port=${BASH_REMATCH[1]}
    end_port=${BASH_REMATCH[2]}
    
    # 验证端口范围
    if [ "$start_port" -gt "$end_port" ]; then
        echo -e "${RED}端口范围错误：起始端口不能大于结束端口${NC}"
        return
    fi
    
    echo "1. 启动  2. 停止  3. 重启"
    read -p "请选择操作[1-3]: " act
    
    # 检查是否有配置文件
    if ! ls $CONFIG_DIR/config_*.yaml 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有已部署的实例${NC}"
        return
    fi
    
    # 使用进程替换避免子shell问题
    while IFS= read -r f; do
        port=$(basename "$f" | sed 's/^config_//;s/\.yaml$//')
        if [ "$port" -ge "$start_port" ] && [ "$port" -le "$end_port" ]; then
            case "$act" in
                1) 
                    if systemctl start hysteria-server@$port.service >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ 已启动端口 $port${NC}"
                    else
                        echo -e "${RED}✗ 启动端口 $port 失败${NC}"
                    fi
                    ;;
                2) 
                    if systemctl stop hysteria-server@$port.service >/dev/null 2>&1; then
                        echo -e "${YELLOW}✓ 已停止端口 $port${NC}"
                    else
                        echo -e "${RED}✗ 停止端口 $port 失败${NC}"
                    fi
                    ;;
                3) 
                    if systemctl restart hysteria-server@$port.service >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ 已重启端口 $port${NC}"
                    else
                        echo -e "${RED}✗ 重启端口 $port 失败${NC}"
                    fi
                    ;;
                *) echo -e "${RED}无效选择${NC}" ;;
            esac
        fi
    done < <(ls $CONFIG_DIR/config_*.yaml 2>/dev/null)
}

status_all_instances() {
    echo -e "${GREEN}查看实例状态:${NC}"
    echo "1. 查看所有实例状态"
    echo "2. 查看指定端口范围的实例状态"
    echo "3. 查看统一服务状态"
    read -p "请选择查看方式[1-3]: " view_type
    
    case "$view_type" in
        1)
            status_all_instances_internal
            ;;
        2)
            status_port_range_instances
            ;;
        3)
            status_server_unified_service
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return
            ;;
    esac
}

# 查看服务端统一服务状态
status_server_unified_service() {
    echo -e "${YELLOW}服务端统一服务状态:${NC}"
    
    if systemctl is-active --quiet hysteria-server-manager.service 2>/dev/null; then
        echo -e "${GREEN}✓ 统一服务正在运行${NC}"
        echo "服务名称: hysteria-server-manager.service"
        echo "运行时间: $(systemctl show hysteria-server-manager.service --property=ActiveEnterTimestamp | cut -d= -f2)"
        
        echo -e "\n${YELLOW}正在管理的配置文件:${NC}"
        shopt -s nullglob
        for cfg in $CONFIG_DIR/config_*.yaml; do
            [ -f "$cfg" ] || continue
            port=$(basename "$cfg" | sed 's/^config_//;s/\.yaml$//')
            echo -e "${GREEN}  - 端口: $port${NC}"
        done
        
        # 显示进程信息
        echo -e "\n${YELLOW}相关进程:${NC}"
        pids=$(pgrep -f "hysteria.*server.*-c.*$CONFIG_DIR/config_.*\.yaml")
        if [ -n "$pids" ]; then
            for pid in $pids; do
                echo -e "${GREEN}  - PID: $pid${NC}"
            done
        else
            echo -e "${YELLOW}  未找到相关进程${NC}"
        fi
    else
        echo -e "${RED}✗ 统一服务未运行${NC}"
    fi
}

status_all_instances_internal() {
    echo -e "${YELLOW}所有实例状态:${NC}"
    
    # 检查是否有配置文件
    if ! ls $CONFIG_DIR/config_*.yaml 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有已部署的实例${NC}"
        return
    fi
    
    # 使用进程替换避免子shell问题
    while IFS= read -r f; do
        port=$(basename "$f" | sed 's/^config_//;s/\.yaml$//')
        status=$(systemctl is-active hysteria-server@$port.service 2>/dev/null || echo "inactive")
        echo "端口: $port | 状态: $status"
    done < <(ls $CONFIG_DIR/config_*.yaml 2>/dev/null)
}

status_port_range_instances() {
    echo -e "${GREEN}查看指定端口范围的实例状态:${NC}"
    read -p "请输入端口范围 (格式: 56000-56005): " port_range
    
    # 验证端口范围格式
    if [[ ! "$port_range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        echo -e "${RED}端口范围格式错误，请使用 起始端口-结束端口 格式${NC}"
        return
    fi
    
    start_port=${BASH_REMATCH[1]}
    end_port=${BASH_REMATCH[2]}
    
    # 验证端口范围
    if [ "$start_port" -gt "$end_port" ]; then
        echo -e "${RED}端口范围错误：起始端口不能大于结束端口${NC}"
        return
    fi
    
    echo -e "${YELLOW}端口范围 $start_port-$end_port 的实例状态:${NC}"
    
    # 检查是否有配置文件
    if ! ls $CONFIG_DIR/config_*.yaml 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有已部署的实例${NC}"
        return
    fi
    
    # 使用进程替换避免子shell问题
    while IFS= read -r f; do
        port=$(basename "$f" | sed 's/^config_//;s/\.yaml$//')
        if [ "$port" -ge "$start_port" ] && [ "$port" -le "$end_port" ]; then
            status=$(systemctl is-active hysteria-server@$port.service 2>/dev/null || echo "inactive")
            echo "端口: $port | 状态: $status"
        fi
    done < <(ls $CONFIG_DIR/config_*.yaml 2>/dev/null)
}

generate_instance_auto() {
    echo -e "${YELLOW}自动生成单实例配置:${NC}"
    while true; do
        read -p "请输入实例监听端口（如9202）: " server_port
        [[ "$server_port" =~ ^[0-9]+$ ]] && [ "$server_port" -ge 1 ] && [ "$server_port" -le 65535 ] && break
        echo -e "${RED}无效端口，请重新输入${NC}"
    done

    if is_port_in_use "$server_port" || [ -f "$CONFIG_DIR/config_${server_port}.yaml" ]; then
        echo -e "${RED}端口 $server_port 已被占用或已存在实例，请换一个端口。${NC}"
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

    # 选择双端部署模式
    echo -e "${YELLOW}双端部署模式选择:${NC}"
    echo "1. 双端同机（客户端和服务器在同一台机器）"
    echo "2. 双端不同机（客户端和服务器在不同机器）"
    read -p "请选择部署模式 [1-2]: " deploy_mode
    
    case "$deploy_mode" in
        1)
            server_address="127.0.0.1"
            ;;
        2)
            server_address="$domain"
            ;;
        *)
            echo -e "${RED}无效选择，默认使用双端不同机模式${NC}"
            server_address="$domain"
            ;;
    esac
    
    # 配置客户端代理认证信息
    echo -e "${YELLOW}客户端代理认证配置（HTTP和SOCKS5使用相同认证信息）:${NC}"
    read -p "代理用户名（直接回车跳过）: " proxy_username
    read -p "代理密码（直接回车跳过）: " proxy_password
    read -p "HTTP代理认证域 [hy2-proxy]: " http_realm
    http_realm=${http_realm:-hy2-proxy}
    
    # 生成代理认证配置
    proxy_config=""
    if [[ -n "$proxy_username" && -n "$proxy_password" ]]; then
        proxy_config=",
    \"username\": \"$proxy_username\",
    \"password\": \"$proxy_password\""
    fi

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

    local config_file="$CONFIG_DIR/config_${server_port}.yaml"
    cat >"$config_file" <<EOF
listen: :$server_port

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

    # 询问启动方式
    echo -e "${YELLOW}选择启动方式：${NC}"
    echo "1. 使用统一服务管理（推荐，一个服务管理所有配置）"
    echo "2. 使用多实例服务（每个配置一个服务）"
    echo "3. 直接启动进程（速度快，但重启后需要手动启动）"
    read -p "请选择 [1-3]: " create_service
    
    case "$create_service" in
        1)
            # 统一服务模式
            echo -e "${YELLOW}正在创建统一服务管理所有配置...${NC}"
            if create_server_unified_service; then
                echo -e "${GREEN}✓ 统一服务创建成功${NC}"
                
                # 重新加载systemd配置
                echo -e "${YELLOW}正在重新加载systemd配置...${NC}"
                systemctl daemon-reload
                
                # 启动统一服务
                echo -e "${YELLOW}正在启动统一服务...${NC}"
                if systemctl start "hysteria-server-manager.service"; then
                    echo -e "${GREEN}✓ 统一服务启动成功，正在管理所有配置文件${NC}"
                    echo -e "${GREEN}  - 管理配置：端口 $server_port${NC}"
                else
                    echo -e "${RED}✗ 统一服务启动失败${NC}"
                    systemctl status "hysteria-server-manager.service" --no-pager
                fi
            else
                echo -e "${RED}✗ 统一服务创建失败${NC}"
            fi
            ;;
        2)
            # 多实例服务模式
            create_systemd_unit "$server_port" "$config_file"
            systemctl restart "hysteria-server@${server_port}.service"
            ;;
        3)
            # 直接进程模式
            echo -e "${YELLOW}正在直接启动hysteria进程...${NC}"
            
            # 检查是否已有进程在运行
            if pgrep -f "hysteria.*server.*-c.*$config_file" >/dev/null; then
                echo -e "${YELLOW}端口 $server_port 的进程已在运行，正在停止...${NC}"
                pkill -f "hysteria.*server.*-c.*$config_file"
                sleep 1
            fi
            
            # 后台启动hysteria进程
            nohup $HYSTERIA_BIN server -c "$config_file" >/dev/null 2>&1 &
            local pid=$!
            
            # 等待一下确保进程启动
            sleep 0.5
            
            # 检查进程是否成功启动
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${GREEN}✓ 端口 $server_port 的hysteria进程启动成功 (PID: $pid)${NC}"
            else
                echo -e "${RED}✗ 端口 $server_port 的hysteria进程启动失败${NC}"
            fi
            ;;
    esac

    local client_cfg="/root/${domain}_${server_port}.json"
    cat >"$client_cfg" <<EOF
{
  "server": "$server_address:$server_port",
  "auth": "$password",
  "transport": {
    "type": "udp",
    "udp": {
      "hopInterval": "10s"
    }
  },
  "tls": {
    "sni": "www.bing.com",
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
    "listen": "0.0.0.0:$server_port",
    "username": "$proxy_username",
    "password": "$proxy_password",
    "realm": "$http_realm"
  },
  "socks5": {
    "listen": "0.0.0.0:$server_port",
    "username": "$proxy_username",
    "password": "$proxy_password"
  }
}
EOF

    echo -e "${GREEN}实例已创建并启动。${NC}"
    echo "服务端配置文件: $config_file"
    echo "客户端配置文件: $client_cfg"
    echo "服务器IP: $domain"
    echo "监听端口: $server_port"
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

# 自动生成统一的 systemd 服务模板（如已存在则跳过）
SERVICE_FILE="/etc/systemd/system/hysteria-client-manager.service"
if [ ! -f "$SERVICE_FILE" ]; then
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Hysteria Client Manager - Manages all client configurations
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'for cfg in /root/*.json; do if [ -f "\$cfg" ]; then /usr/local/bin/hysteria client -c "\$cfg" &; fi; done; wait'
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF
  echo -e "\033[1;32m已自动生成统一服务 $SERVICE_FILE\033[0m"
  systemctl daemon-reload
fi

# 保留原有的多实例模板用于兼容性
SERVICE_FILE_MULTI="/etc/systemd/system/hysteriaclient@.service"
if [ ! -f "$SERVICE_FILE_MULTI" ]; then
  cat > "$SERVICE_FILE_MULTI" <<EOF
[Unit]
Description=Hysteria Client Instance %i
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria client -c /root/%i.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
  echo -e "\033[1;32m已自动生成多实例服务 $SERVICE_FILE_MULTI\033[0m"
  systemctl daemon-reload
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 【自动批量注册 systemd 实例，支持 auto_enable_all 参数，可用于开机自启动】
if [[ "$1" == "auto_enable_all" ]]; then
  shopt -s nullglob
  for cfg in /root/*.json; do
    name=$(basename "${cfg%.json}")
    systemctl enable --now hysteriaclient@"$name"
  done
  exit 0
fi

# 自动注册并启动所有配置到 systemd
auto_systemd_enable_all() {
    echo -e "${YELLOW}正在自动写入并启动/root/*.json配置到 systemd ...${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    # 询问启动方式
    echo -e "${YELLOW}选择启动方式：${NC}"
    echo "1. 使用统一服务管理（推荐，一个服务管理所有配置）"
    echo "2. 使用多实例服务（每个配置一个服务）"
    echo "3. 直接启动进程（速度快，但重启后需要手动启动）"
    read -p "请选择 [1-3]: " create_service
    
    shopt -s nullglob
    found=0
    
    case "$create_service" in
        1)
            # 统一服务模式
            echo -e "${YELLOW}正在启动统一服务管理所有配置...${NC}"
            if systemctl enable --now hysteria-client-manager.service &>/dev/null; then
                echo -e "${GREEN}✓ 统一服务启动成功，正在管理所有配置文件${NC}"
                # 显示正在管理的配置文件
                for cfg in /root/*.json; do
                    [ -f "$cfg" ] || continue
                    name=$(basename "${cfg%.json}")
                    echo -e "${GREEN}  - 管理配置：$name${NC}"
                    found=1
                done
            else
                echo -e "${RED}✗ 统一服务启动失败${NC}"
                systemctl status hysteria-client-manager.service --no-pager
            fi
            ;;
        2)
            # 多实例服务模式
            for cfg in /root/*.json; do
                [ -f "$cfg" ] || continue
                name=$(basename "${cfg%.json}")
                if systemctl enable --now hysteriaclient@"$name" &>/dev/null; then
                    echo -e "${GREEN}✓ 已注册并启动/守护实例：$name${NC}"
                else
                    echo -e "${RED}✗ 注册实例 $name 失败${NC}"
                    systemctl status hysteriaclient@"$name" --no-pager
                fi
                found=1
            done
            ;;
        3)
            # 直接进程模式
            for cfg in /root/*.json; do
                [ -f "$cfg" ] || continue
                name=$(basename "${cfg%.json}")
                
                # 检查是否已有进程在运行
                if pgrep -f "hysteria.*client.*-c.*$cfg" >/dev/null; then
                    echo -e "${YELLOW}客户端 $name 的进程已在运行，跳过${NC}"
                    continue
                fi
                
                # 后台启动hysteria客户端进程
                nohup /usr/local/bin/hysteria client -c "$cfg" >/dev/null 2>&1 &
                local pid=$!
                
                # 等待一下确保进程启动
                sleep 0.5
                
                # 检查进程是否成功启动
                if kill -0 "$pid" 2>/dev/null; then
                    echo -e "${GREEN}✓ 客户端 $name 进程启动成功 (PID: $pid)${NC}"
                else
                    echo -e "${RED}✗ 客户端 $name 进程启动失败${NC}"
                fi
                found=1
            done
            ;;
    esac
    
    if [ $found -eq 0 ]; then
        echo -e "${RED}未发现/root下的配置文件！${NC}"
    fi
}

# 启动剩余未启动的实例
start_remaining_instances() {
    echo -e "${YELLOW}正在启动剩余未启动的实例...${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    # 询问是否创建系统服务
    echo -e "${YELLOW}是否创建系统服务？${NC}"
    echo "1. 创建系统服务（开机自启动，但速度较慢）"
    echo "2. 直接启动进程（速度快，但重启后需要手动启动）"
    read -p "请选择 [1-2]: " create_service
    
    shopt -s nullglob
    found=0
    
    if [[ "$create_service" == "1" ]]; then
        # 系统服务模式
        for cfg in /root/*.json; do
            [ -f "$cfg" ] || continue
            name=$(basename "${cfg%.json}")
            if ! systemctl is-active --quiet hysteriaclient@"$name"; then
                if systemctl enable --now hysteriaclient@"$name" &>/dev/null; then
                    echo -e "${GREEN}✓ 已启动新增实例：$name${NC}"
                else
                    echo -e "${RED}✗ 启动实例 $name 失败${NC}"
                    systemctl status hysteriaclient@"$name" --no-pager
                fi
                found=1
            fi
        done
    else
        # 直接进程模式
        for cfg in /root/*.json; do
            [ -f "$cfg" ] || continue
            name=$(basename "${cfg%.json}")
            
            # 检查是否已有进程在运行
            if pgrep -f "hysteria.*client.*-c.*$cfg" >/dev/null; then
                echo -e "${YELLOW}客户端 $name 的进程已在运行，跳过${NC}"
                continue
            fi
            
            # 后台启动hysteria客户端进程
            nohup /usr/local/bin/hysteria client -c "$cfg" >/dev/null 2>&1 &
            local pid=$!
            
            # 等待一下确保进程启动
            sleep 0.5
            
            # 检查进程是否成功启动
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${GREEN}✓ 客户端 $name 进程启动成功 (PID: $pid)${NC}"
            else
                echo -e "${RED}✗ 客户端 $name 进程启动失败${NC}"
            fi
            found=1
        done
    fi
    
    if [ $found -eq 0 ]; then
        echo -e "${YELLOW}没有剩余未启动的实例${NC}"
    fi
}

# 停止全部客户端
stop_all() {
    echo -e "${GREEN}批量停止客户端:${NC}"
    echo "1. 停止所有客户端"
    echo "2. 停止指定端口范围的客户端"
    read -p "请选择停止方式[1-2]: " stop_type
    
    case "$stop_type" in
        1)
            stop_all_clients_internal
            ;;
        2)
            stop_port_range_clients
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return
            ;;
    esac
}

stop_all_clients_internal() {
    echo -e "${YELLOW}正在停止所有客户端...${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    # 询问停止方式
    echo -e "${YELLOW}选择停止方式：${NC}"
    echo "1. 停止统一服务（如果使用统一服务管理）"
    echo "2. 停止systemd服务（如果使用多实例服务）"
    echo "3. 停止进程（如果直接启动进程）"
    echo "4. 自动检测并停止（推荐）"
    read -p "请选择 [1-4]: " stop_method
    
    shopt -s nullglob
    stopped_count=0
    
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        
        case "$stop_method" in
            1)
                # 停止统一服务
                if systemctl stop hysteria-client-manager.service &>/dev/null; then
                    echo -e "${GREEN}✓ 已停止统一服务，所有客户端已停止${NC}"
                    stopped_count=1
                    break
                else
                    echo -e "${RED}✗ 停止统一服务失败${NC}"
                fi
                ;;
            2)
                # 停止systemd服务
                if systemctl stop hysteriaclient@"$name" &>/dev/null; then
                    echo -e "${GREEN}✓ 已停止systemd服务 $name${NC}"
                    ((stopped_count++))
                else
                    echo -e "${RED}✗ 停止systemd服务 $name 失败${NC}"
                fi
                ;;
            3)
                # 停止进程
                if pkill -f "hysteria.*client.*-c.*$cfg" >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ 已停止进程 $name${NC}"
                    ((stopped_count++))
                else
                    echo -e "${RED}✗ 停止进程 $name 失败${NC}"
                fi
                ;;
            4)
                # 自动检测并停止
                if systemctl is-active --quiet hysteria-client-manager.service 2>/dev/null; then
                    # 是统一服务
                    if systemctl stop hysteria-client-manager.service &>/dev/null; then
                        echo -e "${GREEN}✓ 已停止统一服务，所有客户端已停止${NC}"
                        stopped_count=1
                        break
                    else
                        echo -e "${RED}✗ 停止统一服务失败${NC}"
                    fi
                elif systemctl is-active --quiet hysteriaclient@"$name" 2>/dev/null; then
                    # 是systemd服务
                    if systemctl stop hysteriaclient@"$name" &>/dev/null; then
                        echo -e "${GREEN}✓ 已停止systemd服务 $name${NC}"
                        ((stopped_count++))
                    else
                        echo -e "${RED}✗ 停止systemd服务 $name 失败${NC}"
                    fi
                elif pgrep -f "hysteria.*client.*-c.*$cfg" >/dev/null; then
                    # 是直接进程
                    if pkill -f "hysteria.*client.*-c.*$cfg" >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ 已停止进程 $name${NC}"
                        ((stopped_count++))
                    else
                        echo -e "${RED}✗ 停止进程 $name 失败${NC}"
                    fi
                else
                    echo -e "${YELLOW}客户端 $name 未运行${NC}"
                fi
                ;;
        esac
    done
    
    if [ $stopped_count -gt 0 ]; then
        echo -e "${GREEN}成功停止 $stopped_count 个客户端${NC}"
    fi
}

stop_port_range_clients() {
    echo -e "${GREEN}停止指定端口范围的客户端:${NC}"
    read -p "请输入端口范围 (格式: 20000-20005): " port_range
    
    # 验证端口范围格式
    if [[ ! "$port_range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        echo -e "${RED}端口范围格式错误，请使用 起始端口-结束端口 格式${NC}"
        return
    fi
    
    start_port=${BASH_REMATCH[1]}
    end_port=${BASH_REMATCH[2]}
    
    # 验证端口范围
    if [ "$start_port" -gt "$end_port" ]; then
        echo -e "${RED}端口范围错误：起始端口不能大于结束端口${NC}"
        return
    fi
    
    echo -e "${YELLOW}正在停止端口范围 $start_port-$end_port 的客户端...${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    stopped_count=0
    shopt -s nullglob
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        # 从配置名称中提取端口号
        port=$(echo "$name" | grep -oE '[0-9]+$' || echo "")
        if [[ -n "$port" && "$port" -ge "$start_port" && "$port" -le "$end_port" ]]; then
            if systemctl stop hysteriaclient@"$name" &>/dev/null; then
                echo -e "${GREEN}✓ 已停止 $name${NC}"
                ((stopped_count++))
            else
                echo -e "${RED}✗ 停止 $name 失败${NC}"
            fi
        fi
    done
    
    if [ $stopped_count -gt 0 ]; then
        echo -e "${GREEN}成功停止 $stopped_count 个客户端${NC}"
    else
        echo -e "${YELLOW}在指定端口范围内没有找到客户端${NC}"
    fi
}

# 重启全部客户端
restart_all() {
    echo -e "${GREEN}批量重启客户端:${NC}"
    echo "1. 重启所有客户端"
    echo "2. 重启指定端口范围的客户端"
    read -p "请选择重启方式[1-2]: " restart_type
    
    case "$restart_type" in
        1)
            restart_all_clients_internal
            ;;
        2)
            restart_port_range_clients
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return
            ;;
    esac
}

restart_all_clients_internal() {
    echo -e "${YELLOW}正在重启所有客户端...${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    # 询问重启方式
    echo -e "${YELLOW}选择重启方式：${NC}"
    echo "1. 重启统一服务（如果使用统一服务管理）"
    echo "2. 重启systemd服务（如果使用多实例服务）"
    echo "3. 重启进程（如果直接启动进程）"
    echo "4. 自动检测并重启（推荐）"
    read -p "请选择 [1-4]: " restart_method
    
    shopt -s nullglob
    restarted_count=0
    
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        
        case "$restart_method" in
            1)
                # 重启统一服务
                if systemctl restart hysteria-client-manager.service &>/dev/null; then
                    echo -e "${GREEN}✓ 已重启统一服务，所有客户端已重启${NC}"
                    restarted_count=1
                    break
                else
                    echo -e "${RED}✗ 重启统一服务失败${NC}"
                fi
                ;;
            2)
                # 重启systemd服务
                if systemctl restart hysteriaclient@"$name" &>/dev/null; then
                    echo -e "${GREEN}✓ 已重启systemd服务 $name${NC}"
                    ((restarted_count++))
                else
                    echo -e "${RED}✗ 重启systemd服务 $name 失败${NC}"
                fi
                ;;
            3)
                # 重启进程
                if pkill -f "hysteria.*client.*-c.*$cfg" >/dev/null 2>&1; then
                    sleep 1
                    nohup /usr/local/bin/hysteria client -c "$cfg" >/dev/null 2>&1 &
                    local pid=$!
                    sleep 0.5
                    if kill -0 "$pid" 2>/dev/null; then
                        echo -e "${GREEN}✓ 已重启进程 $name (PID: $pid)${NC}"
                        ((restarted_count++))
                    else
                        echo -e "${RED}✗ 重启进程 $name 失败${NC}"
                    fi
                else
                    echo -e "${RED}✗ 停止进程 $name 失败${NC}"
                fi
                ;;
            4)
                # 自动检测并重启
                if systemctl is-active --quiet hysteria-client-manager.service 2>/dev/null; then
                    # 是统一服务
                    if systemctl restart hysteria-client-manager.service &>/dev/null; then
                        echo -e "${GREEN}✓ 已重启统一服务，所有客户端已重启${NC}"
                        restarted_count=1
                        break
                    else
                        echo -e "${RED}✗ 重启统一服务失败${NC}"
                    fi
                elif systemctl is-active --quiet hysteriaclient@"$name" 2>/dev/null; then
                    # 是systemd服务
                    if systemctl restart hysteriaclient@"$name" &>/dev/null; then
                        echo -e "${GREEN}✓ 已重启systemd服务 $name${NC}"
                        ((restarted_count++))
                    else
                        echo -e "${RED}✗ 重启systemd服务 $name 失败${NC}"
                    fi
                elif pgrep -f "hysteria.*client.*-c.*$cfg" >/dev/null; then
                    # 是直接进程
                    if pkill -f "hysteria.*client.*-c.*$cfg" >/dev/null 2>&1; then
                        sleep 1
                        nohup /usr/local/bin/hysteria client -c "$cfg" >/dev/null 2>&1 &
                        local pid=$!
                        sleep 0.5
                        if kill -0 "$pid" 2>/dev/null; then
                            echo -e "${GREEN}✓ 已重启进程 $name (PID: $pid)${NC}"
                            ((restarted_count++))
                        else
                            echo -e "${RED}✗ 重启进程 $name 失败${NC}"
                        fi
                    else
                        echo -e "${RED}✗ 停止进程 $name 失败${NC}"
                    fi
                else
                    echo -e "${YELLOW}客户端 $name 未运行${NC}"
                fi
                ;;
        esac
    done
    
    if [ $restarted_count -gt 0 ]; then
        echo -e "${GREEN}成功重启 $restarted_count 个客户端${NC}"
    fi
}

restart_port_range_clients() {
    echo -e "${GREEN}重启指定端口范围的客户端:${NC}"
    read -p "请输入端口范围 (格式: 20000-20005): " port_range
    
    # 验证端口范围格式
    if [[ ! "$port_range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        echo -e "${RED}端口范围格式错误，请使用 起始端口-结束端口 格式${NC}"
        return
    fi
    
    start_port=${BASH_REMATCH[1]}
    end_port=${BASH_REMATCH[2]}
    
    # 验证端口范围
    if [ "$start_port" -gt "$end_port" ]; then
        echo -e "${RED}端口范围错误：起始端口不能大于结束端口${NC}"
        return
    fi
    
    echo -e "${YELLOW}正在重启端口范围 $start_port-$end_port 的客户端...${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    restarted_count=0
    shopt -s nullglob
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        # 从配置名称中提取端口号
        port=$(echo "$name" | grep -oE '[0-9]+$' || echo "")
        if [[ -n "$port" && "$port" -ge "$start_port" && "$port" -le "$end_port" ]]; then
            if systemctl restart hysteriaclient@"$name" &>/dev/null; then
                echo -e "${GREEN}✓ 已重启 $name${NC}"
                ((restarted_count++))
            else
                echo -e "${RED}✗ 重启 $name 失败${NC}"
            fi
        fi
    done
    
    if [ $restarted_count -gt 0 ]; then
        echo -e "${GREEN}成功重启 $restarted_count 个客户端${NC}"
    else
        echo -e "${YELLOW}在指定端口范围内没有找到客户端${NC}"
    fi
}

# 查看所有客户端 systemd 状态
status_all() {
    echo -e "${GREEN}查看客户端状态:${NC}"
    echo "1. 查看所有客户端状态"
    echo "2. 查看指定端口范围的客户端状态"
    echo "3. 查看统一服务状态"
    read -p "请选择查看方式[1-3]: " view_type
    
    case "$view_type" in
        1)
            status_all_clients_internal
            ;;
        2)
            status_port_range_clients
            ;;
        3)
            status_unified_service
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return
            ;;
    esac
}

# 查看统一服务状态
status_unified_service() {
    echo -e "${YELLOW}统一服务状态:${NC}"
    
    if systemctl is-active --quiet hysteria-client-manager.service 2>/dev/null; then
        echo -e "${GREEN}✓ 统一服务正在运行${NC}"
        echo "服务名称: hysteria-client-manager.service"
        echo "运行时间: $(systemctl show hysteria-client-manager.service --property=ActiveEnterTimestamp | cut -d= -f2)"
        
        echo -e "\n${YELLOW}正在管理的配置文件:${NC}"
        shopt -s nullglob
        for cfg in /root/*.json; do
            [ -f "$cfg" ] || continue
            name=$(basename "${cfg%.json}")
            echo -e "${GREEN}  - $name${NC}"
        done
        
        # 显示进程信息
        echo -e "\n${YELLOW}相关进程:${NC}"
        pids=$(pgrep -f "hysteria.*client.*-c.*/root/.*\.json")
        if [ -n "$pids" ]; then
            for pid in $pids; do
                echo -e "${GREEN}  - PID: $pid${NC}"
            done
        else
            echo -e "${YELLOW}  未找到相关进程${NC}"
        fi
    else
        echo -e "${RED}✗ 统一服务未运行${NC}"
    fi
}

status_all_clients_internal() {
    echo -e "${YELLOW}所有客户端 systemd 状态：${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    shopt -s nullglob
    found=0
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        found=1
        
        echo -e "${GREEN}[$name]${NC}"
        
        # 检查服务是否存在
        if systemctl list-unit-files | grep -q "hysteriaclient@$name.service"; then
            # 获取服务状态
            status=$(systemctl is-active hysteriaclient@"$name" 2>/dev/null || echo "inactive")
            loaded=$(systemctl is-enabled hysteriaclient@"$name" 2>/dev/null || echo "disabled")
            
            echo "  状态: $status"
            echo "  启用: $loaded"
            
            # 如果服务正在运行，显示更多信息
            if [ "$status" = "active" ]; then
                echo "  运行时间: $(systemctl show hysteriaclient@$name --property=ActiveEnterTimestamp | cut -d= -f2)"
            fi
        else
            echo "  服务未注册"
        fi
        
        echo "---------------------------------------"
    done
    
    if [ $found -eq 0 ]; then
        echo -e "${YELLOW}没有找到任何客户端配置文件${NC}"
    fi
}

status_port_range_clients() {
    echo -e "${GREEN}查看指定端口范围的客户端状态:${NC}"
    read -p "请输入端口范围 (格式: 20000-20005): " port_range
    
    # 验证端口范围格式
    if [[ ! "$port_range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        echo -e "${RED}端口范围格式错误，请使用 起始端口-结束端口 格式${NC}"
        return
    fi
    
    start_port=${BASH_REMATCH[1]}
    end_port=${BASH_REMATCH[2]}
    
    # 验证端口范围
    if [ "$start_port" -gt "$end_port" ]; then
        echo -e "${RED}端口范围错误：起始端口不能大于结束端口${NC}"
        return
    fi
    
    echo -e "${YELLOW}端口范围 $start_port-$end_port 的客户端状态：${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    found_count=0
    shopt -s nullglob
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        # 从配置名称中提取端口号
        port=$(echo "$name" | grep -oE '[0-9]+$' || echo "")
        if [[ -n "$port" && "$port" -ge "$start_port" && "$port" -le "$end_port" ]]; then
            found_count=1
            
            echo -e "${GREEN}[$name]${NC}"
            
            # 检查服务是否存在
            if systemctl list-unit-files | grep -q "hysteriaclient@$name.service"; then
                # 获取服务状态
                status=$(systemctl is-active hysteriaclient@"$name" 2>/dev/null || echo "inactive")
                loaded=$(systemctl is-enabled hysteriaclient@"$name" 2>/dev/null || echo "disabled")
                
                echo "  状态: $status"
                echo "  启用: $loaded"
                
                # 如果服务正在运行，显示更多信息
                if [ "$status" = "active" ]; then
                    echo "  运行时间: $(systemctl show hysteriaclient@$name --property=ActiveEnterTimestamp | cut -d= -f2)"
                fi
            else
                echo "  服务未注册"
            fi
            
            echo "---------------------------------------"
        fi
    done
    
    if [ $found_count -eq 0 ]; then
        echo -e "${YELLOW}在指定端口范围内没有找到客户端${NC}"
    fi
}

# 删除客户端配置并禁用服务（支持单个、范围和全部）
delete_config() {
    echo -e "${YELLOW}可用的配置文件：${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    # 显示配置文件列表
    ls -l /root/*.json 2>/dev/null || echo "无配置文件"
    
    echo
    echo -e "${YELLOW}删除选项:${NC}"
    echo "1. 输入单个配置名称 (如: 47.251.58.77_20000)"
    echo "2. 输入端口范围 (如: 20000-20005)"
    echo "3. 输入 'all' 删除所有配置"
    echo "4. 直接回车仅查看"
    read -p "请选择删除方式: " name
    
    if [ "$name" == "all" ]; then
        echo -e "${YELLOW}确认删除所有客户端配置？(y/n): ${NC}"
        read -p "" confirm
        if [[ "$confirm" == [yY] ]]; then
            deleted_count=0
            for cfg in /root/*.json; do
                [ -f "$cfg" ] || continue
                cname=$(basename "${cfg%.json}")
                if delete_client_config "$cname"; then
                    ((deleted_count++))
                fi
            done
            echo -e "${GREEN}已删除 $deleted_count 个客户端配置${NC}"
        else
            echo -e "${YELLOW}取消删除操作${NC}"
        fi
    elif [[ -n "$name" ]]; then
        # 检查是否为端口范围 (格式: start-end)
        if [[ "$name" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start_port=${BASH_REMATCH[1]}
            end_port=${BASH_REMATCH[2]}
            
            # 验证端口范围
            if [ "$start_port" -gt "$end_port" ]; then
                echo -e "${RED}端口范围错误：起始端口不能大于结束端口${NC}"
            else
                echo -e "${YELLOW}确认删除端口范围 $start_port-$end_port 的所有客户端配置？(y/n): ${NC}"
                read -p "" confirm
                if [[ "$confirm" == [yY] ]]; then
                    deleted_count=0
                    configs_to_delete=()
                    
                    # 先收集要删除的配置
                    for cfg in /root/*.json; do
                        [ -f "$cfg" ] || continue
                        cname=$(basename "${cfg%.json}")
                        # 从配置名称中提取端口号
                        port=$(echo "$cname" | grep -oE '[0-9]+$' || echo "")
                        if [[ -n "$port" && "$port" -ge "$start_port" && "$port" -le "$end_port" ]]; then
                            configs_to_delete+=("$cname")
                        fi
                    done
                    
                    echo -e "${YELLOW}找到 ${#configs_to_delete[@]} 个配置在指定端口范围内${NC}"
                    
                    # 执行删除操作
                    for cname in "${configs_to_delete[@]}"; do
                        echo -e "${YELLOW}正在删除配置 $cname...${NC}"
                        if delete_client_config "$cname"; then
                            ((deleted_count++))
                        fi
                    done
                    
                    if [ $deleted_count -eq 0 ]; then
                        echo -e "${YELLOW}在指定端口范围内没有找到配置${NC}"
                    else
                        echo -e "${GREEN}已删除 $deleted_count 个客户端配置${NC}"
                    fi
                else
                    echo -e "${YELLOW}取消删除操作${NC}"
                fi
            fi
        else
            # 单个配置删除
            if [ -f "/root/$name.json" ]; then
                delete_client_config "$name"
            else
                echo -e "${RED}配置文件 $name 不存在${NC}"
            fi
        fi
    fi
    
    echo
    read -p "按回车键返回..."
}

# 删除单个客户端配置的辅助函数
delete_client_config() {
    local cname="$1"
    local config_file="/root/$cname.json"
    
    if [ -f "$config_file" ]; then
        # 停止并禁用服务（忽略错误）
        systemctl disable --now hysteriaclient@"$cname" >/dev/null 2>&1 || true
        # 删除配置文件（忽略错误）
        rm -f "$config_file" 2>/dev/null || true
        # 删除日志文件（忽略错误）
        rm -f "/var/log/hysteria-client-$cname.log" 2>/dev/null || true
        echo -e "${GREEN}配置文件 $cname 已删除并禁用服务${NC}"
        return 0
    else
        echo -e "${YELLOW}配置文件 $cname 不存在，跳过删除${NC}"
        return 1
    fi
}

# 展示所有配置
list_configs() {
    echo -e "${YELLOW}可用的配置文件：${NC}"
    ls -l /root/*.json 2>/dev/null || echo "无配置文件"
}

while true; do
    clear
    echo -e "${GREEN}==== Hysteria Client Systemd 管理 ====${NC}"
    echo "1. 自动注册并启动所有配置到 systemd"
    echo "2. 停止全部客户端"
    echo "3. 重启全部客户端"
    echo "4. 查看所有客户端状态"
    echo "5. 删除单个/全部客户端配置和实例"
    echo "6. 展示所有配置"
    echo "7. 启动剩余未启动的实例"
    echo "0. 退出"
    read -t 60 -p "请选择 [0-7]: " choice || exit 0

    case $choice in
        1) auto_systemd_enable_all ;;
        2) stop_all ;;
        3) restart_all ;;
        4) status_all ;;
        5) delete_config ;;
        6) list_configs ;;
        7) start_remaining_instances ;;
        0) exit ;;
        *) echo -e "${RED}无效选择${NC}" ;;
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
    
    # 停止所有hysteria服务
    systemctl stop hysteria-server 2>/dev/null
    systemctl stop hysteria-server@* 2>/dev/null
    systemctl disable hysteria-server 2>/dev/null
    systemctl disable hysteria-server@* 2>/dev/null
    
    # 杀死所有hysteria进程
    pkill -f hysteria 2>/dev/null
    
    # 清理文件和目录
    rm -rf /etc/hysteria
    rm -rf /root/H2
    rm -rf /root/hysteria
    rm -f /usr/local/bin/hysteria
    rm -f /usr/local/bin/h2
    rm -f /etc/systemd/system/hysteria-server.service
    rm -f /etc/systemd/system/hysteria-server@*.service
    rm -f /etc/sysctl.d/99-hysteria.conf
    rm -f /etc/security/limits.d/99-hysteria.conf
    rm -f /root/{main,server,client,config}.sh
    
    # 清理客户端配置文件
    rm -f /root/*.json
    
    # 重新加载systemd
    systemctl daemon-reload
    
    printf "%b清理完成%b\n" "${GREEN}" "${NC}"
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
    
    # 清理可能存在的空文件
    if [ -f "/usr/local/bin/hysteria" ] && [ ! -s "/usr/local/bin/hysteria" ]; then
        printf "%b发现空的hysteria文件，正在清理...%b\n" "${YELLOW}" "${NC}"
        rm -f /usr/local/bin/hysteria
    fi
    
    local urls=(
        "https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://gh.ddlc.top/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://hub.gitmirror.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://47.76.180.181:34164/down/ZMeXKe2ndY8z"
    )
    
    for url in "${urls[@]}"; do
        printf "%b尝试从 %s 下载...%b\n" "${YELLOW}" "$url" "${NC}"
        
        # 使用 wget 下载文件
        if wget --no-check-certificate --timeout=30 --tries=3 -O /usr/local/bin/hysteria.tmp "$url"; then
            printf "%b下载完成，正在验证...%b\n" "${YELLOW}" "${NC}"
            
            # 检查文件大小
            if [ ! -s "/usr/local/bin/hysteria.tmp" ]; then
                printf "%b下载的文件为空%b\n" "${RED}" "${NC}"
                rm -f /usr/local/bin/hysteria.tmp
                continue
            fi
            
            # 设置执行权限
            chmod +x /usr/local/bin/hysteria.tmp
            
            # 验证可执行文件
            if /usr/local/bin/hysteria.tmp version >/dev/null 2>&1; then
                mv /usr/local/bin/hysteria.tmp /usr/local/bin/hysteria
                printf "%b✓ Hysteria安装成功%b\n" "${GREEN}" "${NC}"
                
                # 显示版本信息
                local version=$(/usr/local/bin/hysteria version 2>/dev/null | head -1)
                printf "%b版本: %s%b\n" "${GREEN}" "$version" "${NC}"
                return 0
            else
                printf "%b文件验证失败%b\n" "${RED}" "${NC}"
                rm -f /usr/local/bin/hysteria.tmp
            fi
        else
            printf "%b从 %s 下载失败%b\n" "${RED}" "$url" "${NC}"
        fi
    done
    
    # 如果所有下载源都失败，尝试使用官方安装脚本
    printf "%b尝试使用官方安装脚本...%b\n" "${YELLOW}" "${NC}"
    if curl -fsSL https://get.hy2.dev/ | bash; then
        # 验证安装
        if /usr/local/bin/hysteria version >/dev/null 2>&1; then
            printf "%b✓ Hysteria安装成功%b\n" "${GREEN}" "${NC}"
            local version=$(/usr/local/bin/hysteria version 2>/dev/null | head -1)
            printf "%b版本: %s%b\n" "${GREEN}" "$version" "${NC}"
            return 0
        fi
    fi

    printf "%b✗ Hysteria安装失败，请检查网络连接%b\n" "${RED}" "${NC}"
    return 1
}

# 验证安装
verify_installation() {
    printf "%b验证安装...%b\n" "${YELLOW}" "${NC}"
    
    # 检查 hysteria 二进制文件
    if [ ! -f "/usr/local/bin/hysteria" ]; then
        printf "%b✗ Hysteria 二进制文件不存在%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    if [ ! -x "/usr/local/bin/hysteria" ]; then
        printf "%b✗ Hysteria 二进制文件没有执行权限%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 检查文件大小
    local size=$(stat -c%s /usr/local/bin/hysteria 2>/dev/null || echo "0")
    if [ "$size" -lt 1000000 ]; then  # 小于1MB可能是损坏的
        printf "%b✗ Hysteria 二进制文件可能损坏 (大小: %s bytes)%b\n" "${RED}" "$size" "${NC}"
        return 1
    fi
    
    # 检查版本命令
    if ! /usr/local/bin/hysteria version >/dev/null 2>&1; then
        printf "%b✗ Hysteria 版本命令执行失败%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 检查管理脚本
    if [ ! -f "/root/hysteria/main.sh" ]; then
        printf "%b✗ 主管理脚本不存在%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    if [ ! -f "/root/hysteria/server.sh" ]; then
        printf "%b✗ 服务端管理脚本不存在%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    if [ ! -f "/root/hysteria/client.sh" ]; then
        printf "%b✗ 客户端管理脚本不存在%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 检查默认服务文件
    if [ ! -f "/etc/systemd/system/hysteria-server.service" ]; then
        printf "%b✗ 默认服务文件不存在%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    printf "%b✓ 安装验证通过%b\n" "${GREEN}" "${NC}"
    return 0
}

# 创建systemd服务
create_systemd_service() {
    printf "%b创建systemd服务...%b\n" "${YELLOW}" "${NC}"
    
    # 创建配置目录
    mkdir -p /etc/hysteria
    
    # 创建默认配置文件
    cat > /etc/hysteria/config.yaml << EOF
listen: :8443

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $(openssl rand -base64 16)

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
  up: 185 mbps
  down: 185 mbps
EOF

    # 生成默认证书
    openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 365 \
        -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt \
        -subj "/CN=localhost" 2>/dev/null

    # 创建systemd服务文件
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

# 验证安装
verify_installation() {
    printf "%b验证安装...%b\n" "${YELLOW}" "${NC}"
    
    # 检查hysteria可执行文件
    if [ ! -f "/usr/local/bin/hysteria" ] || [ ! -x "/usr/local/bin/hysteria" ]; then
        printf "%b✗ hysteria可执行文件不存在或无法执行%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 检查文件大小
    if [ ! -s "/usr/local/bin/hysteria" ]; then
        printf "%b✗ hysteria文件为空%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 测试版本命令
    if ! /usr/local/bin/hysteria version >/dev/null 2>&1; then
        printf "%b✗ hysteria版本检查失败%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 检查脚本文件
    if [ ! -f "/root/hysteria/main.sh" ] || [ ! -x "/root/hysteria/main.sh" ]; then
        printf "%b✗ 管理脚本不存在或无法执行%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    # 检查systemd服务
    if [ ! -f "/etc/systemd/system/hysteria-server.service" ]; then
        printf "%b✗ systemd服务文件不存在%b\n" "${RED}" "${NC}"
        return 1
    fi
    
    printf "%b✓ 安装验证通过%b\n" "${GREEN}" "${NC}"
    return 0
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
    
    # 验证安装
    if verify_installation; then
        printf "\n%b✓ 安装完成！%b\n" "${GREEN}" "${NC}"
        printf "使用 %bh2%b 命令启动管理面板\n" "${YELLOW}" "${NC}"
        
        # 显示版本信息
        local version=$(/usr/local/bin/hysteria version 2>/dev/null | head -1)
        printf "%bHysteria版本: %s%b\n" "${GREEN}" "$version" "${NC}"
    else
        printf "\n%b✗ 安装验证失败，请检查错误信息%b\n" "${RED}" "${NC}"
        exit 1
    fi
}

main
