#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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
    systemctl enable "hysteria-server@${port}.service"
}

generate_instances_batch() {
    echo -e "${YELLOW}请粘贴所有代理（每行为一组，格式: IP:端口:用户名:密码），输入完毕后Ctrl+D:${NC}"
    proxies=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        proxies+="$line"$'\n'
    done

    # 本地或公网IP
    local domain=$(curl -s ipinfo.io/ip || curl -s myip.ipip.net | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" || curl -s https://api.ip.sb/ip)
    if [ -z "$domain" ]; then
        read -p "请输入服务器公网IP: " domain
    fi
    local crt_and_key; crt_and_key=$(gen_cert "$domain")
    local crt=$(echo "$crt_and_key" | cut -d'|' -f1)
    local key=$(echo "$crt_and_key" | cut -d'|' -f2)

    while read -r proxy_raw; do
        [[ -z "$proxy_raw" ]] && continue

        # 解析一行
        IFS=':' read -r proxy_ip proxy_port proxy_user proxy_pass <<< "$proxy_raw"
        http_port="$proxy_port"
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
  up: 195 mbps
  down: 195 mbps

outbounds:
  - name: my_proxy
    type: http
    http:
      url: $proxy_url

acl:
  inline:
    - my_proxy(all)
EOF

        # systemd 单元生成与启动
        create_systemd_unit "$http_port" "$config_file"
        systemctl restart "hysteria-server@${http_port}.service"

        # 客户端配置输出
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
        "up": "195 mbps",
        "down": "195 mbps"
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

list_instances() {
    echo -e "${GREEN}当前已部署的实例:${NC}"
    ls $CONFIG_DIR/config_*.yaml 2>/dev/null | while read -r config; do
        port=$(basename "$config" | sed 's/^config_//;s/\.yaml$//')
        status=$(systemctl is-active hysteria-server@"$port".service 2>/dev/null)
        echo "端口: $port | 配置: $config | 状态: $status"
    done
}

delete_instance() {
    read -p "请输入要删除的实例端口号: " port
    config_file="$CONFIG_DIR/config_${port}.yaml"
    unit_file="${SYSTEMD_DIR}/hysteria-server@${port}.service"
    if [ -f "$config_file" ]; then
        systemctl stop "hysteria-server@${port}.service"
        systemctl disable "hysteria-server@${port}.service"
        rm -f "$config_file" "$unit_file"
        systemctl daemon-reload
        echo "实例 $port 已删除。"
    else
        echo -e "${RED}未找到端口 $port 的配置。${NC}"
    fi
}

main_menu() {
    check_env
    while true; do
        echo -e "${GREEN}===== Hysteria2 多实例批量管理 =====${NC}"
        echo "1. 批量新建实例"
        echo "2. 查看所有实例"
        echo "3. 删除实例"
        echo "0. 退出"
        read -p "请选择[0-3]: " opt
        case "$opt" in
            1) generate_instances_batch ;;
            2) list_instances; read -p "按回车返回..." ;;
            3) delete_instance ;;
            0) exit 0 ;;
            *) echo "无效选择" ;;
        esac
    done
}

main_menu
