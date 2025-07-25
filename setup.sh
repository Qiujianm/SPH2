#!/bin/bash

VERSION="2025-07-25"
AUTHOR="Qiujianm"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

[ "$EUID" -ne 0 ] && echo -e "${RED}请使用root权限运行此脚本${NC}" && exit 1

print_status() {
    local type=$1
    local message=$2
    case "$type" in
        "info") printf "%b[信息]%b %s\n" "${GREEN}" "${NC}" "$message" ;;
        "warn") printf "%b[警告]%b %s\n" "${YELLOW}" "${NC}" "$message" ;;
        "error") printf "%b[错误]%b %s\n" "${RED}" "${NC}" "$message" ;;
    esac
}

create_all_scripts() {
    print_status "info" "创建所有模块脚本...\n"
    mkdir -p /root/hysteria
    mkdir -p /root/H2

cat > /root/hysteria/main.sh << 'MAINEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m]'

VERSION="2025-07-25"
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
        6) systemctl status 'hysteria-server@*.service' ; read -t 30 -n 1 -s -r -p "按任意键继续..." ;;
        7) bash ./config.sh uninstall ;;
        0) exit 0 ;;
        *) printf "%b无效选择%b\n" "${RED}" "${NC}" ; sleep 1 ;;
    esac
done
MAINEOF
chmod +x /root/hysteria/main.sh

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
    for dep in openssl curl; do
        command -v $dep >/dev/null 2>&1 || { echo "请先安装 $dep"; exit 1; }
    done
    [ -f "$HYSTERIA_BIN" ] || { echo "请先安装 hysteria"; exit 1; }
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
    echo -e "${YELLOW}请输入带宽限制（单位 mbps，回车默认185）：${NC}"
    read -p "上行带宽 [185]: " up_bw; up_bw=${up_bw:-185}
    read -p "下行带宽 [185]: " down_bw; down_bw=${down_bw:-185}
    echo -e "${YELLOW}粘贴所有代理（IP:端口:用户名:密码，每行为一组），Ctrl+D结束:${NC}"
    proxies=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue; proxies+="$line"$'\n'
    done

    read -p "批量新建实例起始端口: " start_port
    current_port="$start_port"

    local domain=$(curl -s ipinfo.io/ip || curl -s myip.ipip.net | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" || curl -s https://api.ip.sb/ip)
    [ -z "$domain" ] && read -p "请输入服务器公网IP: " domain
    local crt_and_key; crt_and_key=$(gen_cert "$domain")
    local crt=$(echo "$crt_and_key" | cut -d'|' -f1)
    local key=$(echo "$crt_and_key" | cut -d'|' -f2)

    while read -r proxy_raw; do
        [[ -z "$proxy_raw" ]] && continue
        while is_port_in_use "$current_port" || [ -f "$CONFIG_DIR/config_${current_port}.yaml" ]; do
            echo "端口 $current_port 已被占用，尝试下一个端口..."; current_port=$((current_port + 1))
        done

        IFS=':' read -r proxy_ip proxy_port proxy_user proxy_pass <<< "$proxy_raw"
        http_port="$current_port"; current_port=$((current_port + 1))
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

        local client_cfg="/root/H2/${domain}_${http_port}.json"
        cat >"$client_cfg" <<EOF
{
    "server": "$domain:$http_port",
    "auth": "$password",
    "transport": { "type": "udp", "udp": { "hopInterval": "10s" }},
    "tls": { "sni": "https://www.bing.com", "insecure": true, "alpn": ["h3"] },
    "quic": {
        "initStreamReceiveWindow": 26843545,
        "maxStreamReceiveWindow": 26843545,
        "initConnReceiveWindow": 67108864,
        "maxConnReceiveWindow": 67108864
    },
    "bandwidth": { "up": "${up_bw} mbps", "down": "${down_bw} mbps" },
    "http": { "listen": "0.0.0.0:$http_port" }
}
EOF
        echo -e "\n${GREEN}已生成端口 $http_port 实例，密码：$password"
        echo "服务端配置: $config_file"
        echo "客户端配置: $client_cfg"
        echo "--------------------------------------${NC}"
    done <<< "$proxies"
}

main_menu() {
    check_env
    while true; do
        echo -e "${GREEN}===== Hysteria2 多实例批量管理 =====${NC}"
        echo "1. 批量新建实例"
        echo "0. 退出"
        read -p "请选择[0-1]: " opt
        case "$opt" in
            1) generate_instances_batch ;;
            0) exit 0 ;;
            *) echo "无效选择" ;;
        esac
    done
}
main_menu
SERVEREOF
chmod +x /root/hysteria/server.sh

cat > /root/hysteria/client.sh << 'CLIENTEOF'
#!/bin/bash
SERVICE_FILE="/etc/systemd/system/hysteriaclient@.service"
if [ ! -f "$SERVICE_FILE" ]; then
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Hysteria Client Instance %i
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria client -c /root/H2/%i.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'

auto_systemd_enable_all() {
    echo -e "${YELLOW}自动写入并启动/root/H2/*.json配置到 systemd ...${NC}"
    shopt -s nullglob
    for cfg in /root/H2/*.json; do
        name=$(basename "${cfg%.json}")
        systemctl enable --now hysteriaclient@"$name" &>/dev/null
        echo -e "${GREEN}守护实例：$name${NC}"
    done
}

while true; do
    clear
    echo -e "${GREEN}==== Hysteria Client Systemd 管理 ====${NC}"
    echo "1. 自动注册并启动所有配置到 systemd"
    echo "0. 退出"
    read -t 60 -p "请选择 [0-1]: " choice || exit 0
    case $choice in
        1) auto_systemd_enable_all ;;
        0) exit ;;
        *) echo -e "${RED}无效选择${NC}" ;;
    esac
    read -n 1 -s -r -p "按任意键继续..."
done
CLIENTEOF
chmod +x /root/hysteria/client.sh

cat > /root/hysteria/config.sh << 'CONFIGEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

optimize() {
    printf "%b正在优化系统配置...%b\n" "${YELLOW}" "${NC}"
    printf "%b请选择拥塞控制模式:%b\n" "${YELLOW}" "${NC}"
    echo "1. Brutal 拥塞控制"
    echo "2. BBR 拥塞控制"
    echo "3. BBR+FQ"
    read -p "请输入选择 [1-3]: " congestion_control_choice
    case "$congestion_control_choice" in
        1) congestion_control="brutal" ;;
        2) congestion_control="bbr" ;;
        3) congestion_control="bbr"; default_qdisc="fq";;
        *) congestion_control="brutal";;
    esac
    if [[ "$congestion_control" == "bbr" ]]; then
        if ! lsmod | grep -q bbr; then
            echo "tcp_bbr" | tee /etc/modules-load.d/bbr.conf
            modprobe tcp_bbr
            cat >> /etc/sysctl.d/99-bbr.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
            sysctl --system
        fi
    fi
    cat > /etc/sysctl.d/99-hysteria.conf << EOF
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 87380 16777216
net.ipv4.tcp_congestion_control=$congestion_control
EOF
    [ "$default_qdisc" == "fq" ] && echo "net.core.default_qdisc=fq" >> /etc/sysctl.d/99-hysteria.conf
    cat >> /etc/sysctl.d/99-hysteria.conf << EOF
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.ip_forward=1
net.ipv4.tcp_mtu_probing=1
EOF
    sysctl -p /etc/sysctl.d/99-hysteria.conf
    cat > /etc/security/limits.d/99-hysteria.conf << EOF
* soft nofile 1000000
* hard nofile 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF
    mkdir -p /etc/systemd/system/hysteria-server.service.d
    cat > /etc/systemd/system/hysteria-server.service.d/priority.conf << EOF
[Service]
CPUSchedulingPolicy=rr
CPUSchedulingPriority=99
EOF
    systemctl daemon-reload
    printf "%b系统优化完成%b\n" "${GREEN}" "${NC}"
    sleep 2
}

update() {
    printf "%b正在检查更新...%b\n" "${YELLOW}" "${NC}"
    if curl -s http://ipinfo.io | grep -q '"country": "CN"'; then
        url="https://hub.gitmirror.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    else
        url="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    fi
    printf "%b下载: %s ...%b\n" "${YELLOW}" "$url" "${NC}"
    if wget -O /usr/local/bin/hysteria.new "$url" && chmod +x /usr/local/bin/hysteria.new && /usr/local/bin/hysteria.new version >/dev/null 2>&1; then
        mv /usr/local/bin/hysteria.new /usr/local/bin/hysteria
        printf "%b更新成功%b\n" "${GREEN}" "${NC}"
    else
        printf "%b更新失败%b\n" "${RED}" "${NC}"
        return 1
    fi
}

uninstall() {
    printf "%b═══════ 卸载确认 ═══════%b\n" "${YELLOW}" "${NC}"
    read -p "确定要卸载Hysteria吗？(y/n): " confirm
    if [[ $confirm == [yY] ]]; then
        printf "%b正在卸载...%b\n" "${YELLOW}" "${NC}"
        pkill -f hysteria
        systemctl stop 'hysteria-server@*.service' 2>/dev/null
        systemctl disable 'hysteria-server@*.service' 2>/dev/null
        rm -rf /etc/hysteria
        rm -rf /root/H2
        rm -f /usr/local/bin/hysteria
        rm -f /usr/local/bin/h2
        rm -f /etc/systemd/system/hysteria-server@*.service
        rm -f /etc/sysctl.d/99-hysteria.conf
        rm -f /etc/security/limits.d/99-hysteria.conf
        rm -f /root/hysteria/{main,server,client,config}.sh
        systemctl daemon-reload
        printf "%b卸载完成%b\n" "${GREEN}" "${NC}"
        exit 0
    fi
}

case "$1" in
    "optimize") optimize ;;
    "update") update ;;
    "uninstall") uninstall ;;
    *) echo "用法: $0 {optimize|update|uninstall}"; exit 1 ;;
esac
CONFIGEOF
chmod +x /root/hysteria/config.sh

cat > /usr/local/bin/h2 << 'CMDEOF'
#!/bin/bash
cd /root/hysteria
[ "$EUID" -ne 0 ] && printf "\033[0;31m请使用root权限运行此脚本\033[0m\n" && exit 1
bash ./main.sh
CMDEOF
chmod +x /usr/local/bin/h2

print_status "info" "所有模块脚本创建完成"
}

cleanup_old_installation() {
    print_status "warn" "清理旧的安装..."
    pkill -f hysteria
    systemctl stop 'hysteria-server@*.service' 2>/dev/null
    systemctl disable 'hysteria-server@*.service' 2>/dev/null
    rm -rf /etc/hysteria
    rm -rf /root/H2
    rm -f /usr/local/bin/hysteria
    rm -f /usr/local/bin/h2
    rm -f /etc/systemd/system/hysteria-server@*.service
    rm -f /etc/sysctl.d/99-hysteria.conf
    rm -f /etc/security/limits.d/99-hysteria.conf
    rm -f /root/hysteria/{main,server,client,config}.sh
    systemctl daemon-reload
}

install_base() {
    print_status "info" "安装基础依赖..."
    if [ -f /etc/debian_version ]; then
        apt update && apt install -y curl wget openssl net-tools
    elif [ -f /etc/redhat-release ]; then
        yum install -y curl wget openssl net-tools
    else
        print_status "error" "不支持的系统"
        exit 1
    fi
    hash curl wget openssl netstat 2>/dev/null || exit 1
}

install_hysteria() {
    print_status "info" "开始安装Hysteria..."
    local urls=(
        "https://gh.ddlc.top/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://hub.gitmirror.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    )
    for url in "${urls[@]}"; do
        print_status "info" "尝试从 $url 下载..."
        if wget --no-check-certificate -O /usr/local/bin/hysteria "$url" && chmod +x /usr/local/bin/hysteria && /usr/local/bin/hysteria version >/dev/null 2>&1; then
            print_status "info" "Hysteria安装成功"
            return 0
        else
            print_status "warn" "下载失败: $url"
        fi
    done
    print_status "error" "Hysteria安装失败"
    return 1
}

main() {
    clear
    printf "%b════════ Hysteria 管理脚本 安装程序 ════════%b\n" "${GREEN}" "${NC}"
    printf "%b作者: ${AUTHOR}%b\n" "${GREEN}" "${NC}"
    printf "%b版本: ${VERSION}%b\n" "${GREEN}" "${NC}"
    cleanup_old_installation
    install_base || exit 1
    install_hysteria || exit 1
    create_all_scripts
    printf "\n%b安装完成！%b\n" "${GREEN}" "${NC}"
    printf "使用 %bh2%b 命令启动管理面板\n" "${YELLOW}" "${NC}"
}
main
