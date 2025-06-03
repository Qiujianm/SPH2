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
