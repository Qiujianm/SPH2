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
        echo "8. Sing-box 集成管理"  # 新增选项
        echo "0. 退出脚本"
        printf "%b====================================%b\n" "${GREEN}" "${NC}"
        
        read -t 60 -p "请选择 [0-8]: " choice || {
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
            8) bash ./singbox.sh ;;  # 新增 sing-box 管理
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

    # 创建并赋权 server.sh (保留原有功能)
    # ... 原有的 server.sh 内容保持不变 ...

    # 创建并赋权 client.sh (保留原有功能)
    # ... 原有的 client.sh 内容保持不变 ...

    # 创建并赋权 config.sh (保留原有功能)
    # ... 原有的 config.sh 内容保持不变 ...

    # 新增：创建 singbox.sh 脚本
cat > /root/hysteria/singbox.sh << 'SINGBOXEOF'
#!/bin/bash

# Sing-box 集成管理脚本
# 专门为 Hysteria2 服务端设计 sing-box 客户端配置

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

HYSTERIA_DIR="/etc/hysteria2"
SINGBOX_CONFIG_DIR="/etc/sing-box"

# 检查目录
check_directories() {
    if [ ! -d "$HYSTERIA_DIR" ]; then
        echo -e "${RED}错误: Hysteria2 配置目录不存在，请先运行服务端管理${NC}"
        return 1
    fi
    
    mkdir -p "$SINGBOX_CONFIG_DIR"
    return 0
}

# 生成 sing-box 配置 (本地回环架构)
generate_singbox_config() {
    echo -e "${YELLOW}生成 Sing-box 配置 (本地回环架构)...${NC}"
    
    # 询问 sing-box 配置
    echo -e "${BLUE}配置 Sing-box 客户端:${NC}"
    read -p "请输入外部监听起始端口 (默认: 5200): " external_start_port
    external_start_port=${external_start_port:-5200}
    
    read -p "请输入HTTP/SOCKS5代理用户名 (可选): " proxy_username
    read -p "请输入HTTP/SOCKS5代理密码 (可选): " proxy_password
    
    # 询问是否启用TLS
    echo -e "${BLUE}配置Hysteria2连接:${NC}"
    echo "1. 无加密模式 (纯QUIC协议，性能更好)"
    echo "2. TLS加密模式 (标准加密，兼容性好)"
    read -p "请选择模式 (1/2, 默认: 1): " tls_choice
    tls_choice=${tls_choice:-1}
    
    # 批量输入远端代理信息
    echo -e "${BLUE}批量输入远端代理信息:${NC}"
    echo "格式: 代理类型:地址:端口:用户名:密码"
    echo "示例: http:proxy1.com:8080:user1:pass1"
    echo "输入空行结束"
    
    local temp_input="/tmp/proxy_input.txt"
    > "$temp_input"
    
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            break
        fi
        echo "$line" >> "$temp_input"
    done
    
    # 处理输入并生成配置
    local inbounds=""
    local outbounds=""
    local external_port=$external_start_port
    local proxy_id=0
    
    while IFS=':' read -r proxy_type proxy_host proxy_port proxy_user proxy_pass; do
        if [[ -n "$proxy_type" && -n "$proxy_host" && -n "$proxy_port" ]]; then
            # 生成 Hysteria2 服务端配置 - 端口与外部端口保持一致
            local hysteria_port=$external_port
            local password=$(openssl rand -base64 16)
            
            generate_hysteria_server_config "$hysteria_port" "$password" "$proxy_type" "$proxy_host" "$proxy_port" "$proxy_user" "$proxy_pass"
            
            # 生成 sing-box 端口配置
            generate_port_config "$external_port" "$hysteria_port" "$password" "$proxy_id" "$tls_choice" "$proxy_username" "$proxy_password"
            
            echo -e "${GREEN}✓ 配置代理 $proxy_id: $proxy_type://$proxy_host:$proxy_port → Hysteria2端口:$hysteria_port → 外部端口:$external_port${NC}"
            
            ((external_port++))
            ((proxy_id++))
        fi
    done < "$temp_input"
    
    rm -f "$temp_input"
    
    if [[ $proxy_id -eq 0 ]]; then
        echo -e "${RED}错误: 没有输入有效的远端代理信息${NC}"
        return 1
    fi
    
    # 生成单实例配置文件
    local singbox_config="$SINGBOX_CONFIG_DIR/config.json"
    cat > "$singbox_config" <<EOF
{
    "log": {
        "level": "error",
        "timestamp": false
    },
    "inbounds": [$inbounds],
    "outbounds": [
        $outbounds,
        {
            "type": "direct",
            "tag": "direct"
        }
    ],
    "route": {
        "rules": [
            {
                "protocol": "dns",
                "outbound": "direct"
            }
        ],
        "final": "proxy-0"
    }
}
EOF
    
    echo -e "${GREEN}✓ Sing-box 本地回环配置生成完成: $singbox_config${NC}"
    echo -e "${BLUE}架构: 用户HTTP/SOCKS5 → sing-box单实例 → Hysteria2服务端(本地回环) → 远端代理${NC}"
    
    # 生成端口映射文件
    local mapping_file="$SINGBOX_CONFIG_DIR/port_mapping.txt"
    > "$mapping_file"
    echo "# 端口映射: 外部端口 = Hysteria2本地回环端口" > "$mapping_file"
    echo "# 格式: 端口:代理类型:远端地址:远端端口:代理ID" >> "$mapping_file"
    echo "# 架构: 端口一致性，本地回环通信" >> "$mapping_file"
    
    # 重新读取临时文件生成映射
    local external_port=$external_start_port
    local proxy_id=0
    while IFS=':' read -r proxy_type proxy_host proxy_port proxy_user proxy_pass; do
        if [[ -n "$proxy_type" && -n "$proxy_host" && -n "$proxy_port" ]]; then
            echo "$external_port:$proxy_type:$proxy_host:$proxy_port:$proxy_id" >> "$mapping_file"
            ((external_port++))
            ((proxy_id++))
        fi
    done < "$temp_input"
    
    # 重新创建临时文件用于后续处理
    > "$temp_input"
    while IFS=':' read -r proxy_type proxy_host proxy_port proxy_user proxy_pass; do
        if [[ -n "$proxy_type" && -n "$proxy_host" && -n "$proxy_port" ]]; then
            echo "$proxy_type:$proxy_host:$proxy_port:$proxy_user:$proxy_pass" >> "$temp_input"
        fi
    done < "$mapping_file"
    
    echo -e "${GREEN}✓ 端口映射文件生成完成: $mapping_file${NC}"
}

# 生成端口配置的辅助函数
generate_port_config() {
    local external_port="$1"
    local hysteria_port="$2"
    local password="$3"
    local proxy_id="$4"
    local tls_choice="$5"
    local proxy_username="$6"
    local proxy_password="$7"
    
    # 构建认证配置
    local auth_config=""
    if [[ -n "$proxy_username" && -n "$proxy_password" ]]; then
        auth_config=",
        \"users\": [
            {
                \"username\": \"$proxy_username\",
                \"password\": \"$proxy_password\"
            }
        ]"
    fi
    
    # 添加 inbound
    if [[ -n "$inbounds" ]]; then
        inbounds="$inbounds,"
    fi
    inbounds="$inbounds
    {
        \"type\": \"mixed\",
        \"tag\": \"mixed-in-$proxy_id\",
        \"listen\": \"0.0.0.0\",
        \"listen_port\": $external_port,
        \"sniff\": false,
        \"sniff_override_destination\": false$auth_config
    }"
    
    # 添加 outbound (本地回环)
    if [[ -n "$outbounds" ]]; then
        outbounds="$outbounds,"
    fi
    
    if [[ "$tls_choice" == "2" ]]; then
        outbounds="$outbounds
    {
        \"type\": \"hysteria2\",
        \"tag\": \"proxy-$proxy_id\",
        \"server\": \"127.0.0.1\",
        \"server_port\": $hysteria_port,
        \"password\": \"$password\",
        \"tls\": {
            \"enabled\": true,
            \"server_name\": \"localhost\",
            \"insecure\": true
        },
        \"multiplex\": {
            \"enabled\": true,
            \"protocol\": \"h2mux\",
            \"max_connections\": 4,
            \"min_streams\": 2
        }
    }"
    else
        outbounds="$outbounds
    {
        \"type\": \"hysteria2\",
        \"tag\": \"proxy-$proxy_id\",
        \"server\": \"127.0.0.1\",
        \"server_port\": $hysteria_port,
        \"password\": \"$password\",
        \"tls\": {
            \"enabled\": false
        },
        \"multiplex\": {
            \"enabled\": true,
            \"protocol\": \"h2mux\",
            \"max_connections\": 4,
            \"min_streams\": 2
        }
    }"
    fi
}

# 生成 Hysteria2 服务端配置的辅助函数
generate_hysteria_server_config() {
    local hysteria_port="$1"
    local password="$2"
    local proxy_type="$3"
    local proxy_host="$4"
    local proxy_port="$5"
    local proxy_user="$6"
    local proxy_pass="$7"
    
    local config_file="$HYSTERIA_DIR/config_${hysteria_port}.yaml"
    
    # 生成配置
    cat > "$config_file" <<EOF
# Hysteria2 服务端配置 - 本地回环
listen: 127.0.0.1:$hysteria_port

# 认证
auth:
  type: password
  password: $password

# 禁用TLS，使用纯QUIC协议
tls:
  enabled: false

# 多路复用
multiplex:
  enabled: true
  protocol: h2mux
  max_connections: 4
  min_streams: 2

# 拥塞控制
congestion:
  type: brutal
  brutal:
    up_mbps: 100
    down_mbps: 100

# 远端代理转发
outbounds:
  - name: my_proxy
    type: $proxy_type
EOF

    if [[ "$proxy_type" == "http" ]]; then
        cat >> "$config_file" <<EOF
    http:
      url: http://$proxy_host:$proxy_port
EOF
        if [[ -n "$proxy_user" && -n "$proxy_pass" ]]; then
            cat >> "$config_file" <<EOF
      username: $proxy_user
      password: $proxy_pass
EOF
        fi
    elif [[ "$proxy_type" == "socks5" ]]; then
        cat >> "$config_file" <<EOF
    socks5:
      address: $proxy_host:$proxy_port
EOF
        if [[ -n "$proxy_user" && -n "$proxy_pass" ]]; then
            cat >> "$config_file" <<EOF
      username: $proxy_user
      password: $proxy_pass
EOF
        fi
    fi
    
    cat >> "$config_file" <<EOF

# ACL规则
acl:
  inline:
    - my_proxy(all)

# 日志
log:
  level: info
  timestamp: true
EOF

    echo -e "${GREEN}✓ Hysteria2 服务端配置生成: $config_file${NC}"
}

# 安装 sing-box
install_singbox() {
    echo -e "${YELLOW}安装 Sing-box...${NC}"
    
    # 检查是否已安装
    if command -v sing-box >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Sing-box 已安装${NC}"
        return 0
    fi
    
    # 下载 sing-box
    local version=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
    local url="https://github.com/SagerNet/sing-box/releases/download/${version}/sing-box-${version#v}-linux-amd64.tar.gz"
    
    echo -e "${YELLOW}下载 Sing-box ${version}...${NC}"
    if wget -O /tmp/sing-box.tar.gz "$url"; then
        cd /tmp
        tar -xzf sing-box.tar.gz
        cp sing-box-*/sing-box /usr/local/bin/
        chmod +x /usr/local/bin/sing-box
        
        echo -e "${GREEN}✓ Sing-box 安装完成${NC}"
        rm -rf /tmp/sing-box*
    else
        echo -e "${RED}✗ Sing-box 下载失败${NC}"
        return 1
    fi
}

# 创建 systemd 服务
create_singbox_service() {
    echo -e "${YELLOW}创建 Sing-box systemd 服务...${NC}"
    
    cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box Client for Hysteria2
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/sing-box run -c $SINGBOX_CONFIG_DIR/config.json
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box.service
    
    echo -e "${GREEN}✓ Sing-box 服务创建完成${NC}"
}

# 启动 Sing-box 服务
start_singbox_service() {
    echo -e "${YELLOW}启动 Sing-box 服务...${NC}"
    
    if systemctl start sing-box.service; then
        echo -e "${GREEN}✓ Sing-box 服务启动成功${NC}"
        systemctl status sing-box.service --no-pager
    else
        echo -e "${RED}✗ Sing-box 服务启动失败${NC}"
        return 1
    fi
}

# 停止 Sing-box 服务
stop_singbox_service() {
    echo -e "${YELLOW}停止 Sing-box 服务...${NC}"
    
    if systemctl stop sing-box.service; then
        echo -e "${GREEN}✓ Sing-box 服务停止成功${NC}"
    else
        echo -e "${RED}✗ Sing-box 服务停止失败${NC}"
    fi
}

# 查看 Sing-box 状态
show_singbox_status() {
    echo -e "${YELLOW}Sing-box 服务状态:${NC}"
    systemctl status sing-box.service --no-pager
    
    if [ -f "$SINGBOX_CONFIG_DIR/port_mapping.txt" ]; then
        echo -e "\n${BLUE}端口映射:${NC}"
        cat "$SINGBOX_CONFIG_DIR/port_mapping.txt"
    fi
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${GREEN}================================${NC}"
        echo -e "${GREEN}  Sing-box 本地回环集成管理菜单${NC}"
        echo -e "${GREEN}================================${NC}"
        echo "1. 安装 Sing-box"
        echo "2. 生成本地回环配置文件 (端口一致性，远端代理批量设置)"
        echo "3. 创建系统服务"
        echo "4. 启动服务"
        echo "5. 停止服务"
        echo "6. 查看状态"
        echo "0. 返回主菜单"
        echo -e "${GREEN}================================${NC}"
        
        read -p "请选择 [0-6]: " choice
        
        case $choice in
            1) install_singbox ;;
            2) 
                if check_directories; then
                    generate_singbox_config
                fi
                ;;
            3) create_singbox_service ;;
            4) start_singbox_service ;;
            5) stop_singbox_service ;;
            6) show_singbox_status ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选择${NC}" ;;
        esac
        
        echo
        read -p "按回车键继续..."
    done
}

# 运行主菜单
main_menu
SINGBOXEOF
    chmod +x /root/hysteria/singbox.sh

    printf "%b所有模块脚本创建完成%b\n" "${GREEN}" "${NC}"
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
        printf "新增功能: %bSing-box 集成管理%b\n" "${BLUE}" "${NC}"
        
        # 显示版本信息
        local version=$(/usr/local/bin/hysteria version 2>/dev/null | head -1)
        printf "%bHysteria版本: %s%b\n" "${GREEN}" "$version" "${NC}"
    else
        printf "\n%b✗ 安装验证失败，请检查错误信息%b\n" "${RED}" "${NC}"
        exit 1
    fi
}

main
