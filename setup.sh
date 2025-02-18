#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 基础目录
SCRIPT_DIR="/usr/local/SPH2"

# 下载文件
download_file() {
    local file=$1
    local url="https://raw.githubusercontent.com/Qiujianm/SPH2/main/${file}"
    echo -e "${YELLOW}正在下载 ${file}...${NC}"
    wget -q -O "${SCRIPT_DIR}/${file}" "$url" || {
        echo -e "${RED}下载 ${file} 失败${NC}"
        return 1
    }
}

# 安装基本依赖
echo -e "${YELLOW}正在安装基本依赖...${NC}"
if [ -f /etc/redhat-release ]; then
    yum install -y wget curl
elif [ -f /etc/debian_version ]; then
    apt-get update && apt-get install -y wget curl
fi

# 创建并清理目录
rm -rf "$SCRIPT_DIR"
mkdir -p "$SCRIPT_DIR"

# 下载脚本文件
echo -e "${YELLOW}正在下载脚本文件...${NC}"
FILES=("main.sh" "constants.sh" "server_manager.sh" "client_manager.sh" "start_clients.sh")
for file in "${FILES[@]}"; do
    download_file "$file" || exit 1
done

# 设置权限
chmod +x "${SCRIPT_DIR}"/*.sh

# 停止所有可能使用 hysteria 文件的进程
pkill -f /usr/local/bin/hysteria || true

# 创建全局命令
cat > /usr/local/bin/h2 << 'EOF'
#!/bin/bash
SCRIPT_DIR="/usr/local/SPH2"

source "$SCRIPT_DIR/constants.sh"
source "$SCRIPT_DIR/server_manager.sh"
source "$SCRIPT_DIR/client_manager.sh"

# 错误处理
set -e
trap 'echo -e "\033[0;31m错误: 脚本执行失败\033[0m" >&2' ERR

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "\033[0;33m正在安装 $1...\033[0m"
        if [ -f /etc/redhat-release ]; then
            yum install -y "$1"
        elif [ -f /etc/debian_version ]; then
            apt-get update && apt-get install -y "$1"
        fi
    fi
}

# 检查系统环境
check_system() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[0;31m请使用root用户运行此脚本\033[0m"
        exit 1
    fi
    check_command "git"
    check_command "wget"
    check_command "curl"
}

# 检查运行状态
check_running_status() {
    check_server_status
    check_client_status
    sleep 0.5
}

# 系统优化
optimize_system() {
    echo -e "\033[0;33m正在优化系统配置...\033[0m"
    cat > /etc/sysctl.d/99-hysteria.conf <<EOL
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 87380 16777216
EOL
    sysctl --system >/dev/null 2>&1
    echo -e "\033[0;32m系统优化完成\033[0m"
    sleep 0.5
}

# 安装模式
install_mode() {
    echo -e "\033[0;33m开始安装 Hysteria...\033[0m"
    mkdir -p /usr/local/bin
    wget -O /usr/local/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
    chmod +x /usr/local/bin/hysteria

    # 创建服务文件
    cat > /etc/systemd/system/hysteria-server.service <<EOF
[Unit]
Description=Hysteria Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria -c ${HYSTERIA_CONFIG}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    mkdir -p "$HYSTERIA_ROOT"
    mkdir -p "$CLIENT_CONFIG_DIR"
    systemctl daemon-reload
    systemctl enable hysteria-server
    optimize_system
    echo -e "\033[0;32mHysteria 安装完成！\033[0m"
    sleep 0.5
}

# 主菜单
main_menu() {
    while true; do
        echo -e "\033[0;32m════════ Hysteria 管理脚本 ════════\033[0m"
        echo "1. 安装模式"
        echo "2. 服务端管理"
        echo "3. 客户端管理"
        echo "4. 系统优化"
        echo "5. 检查更新"
        echo "6. 运行状态"
        echo "7. 完全卸载"
        echo "0. 退出脚本"
        
        read -p "请选择 [0-7]: " choice
        case $choice in
            1) install_mode ;;
            2) server_menu ;;
            3) client_menu ;;
            4) optimize_system ;;
            5) check_update ;;
            6) check_running_status ;;
            7)
                read -p "确定要卸载 Hysteria 吗？(y/n): " confirm
                if [ "$confirm" = "y" ]; then
                    uninstall
                fi
                ;;
            0) 
                echo -e "\033[0;32m感谢使用！\033[0m"
                exit 0 
                ;;
            *)
                echo -e "\033[0;31m无效选择\033[0m"
                sleep 0.5
                ;;
        esac
    done
}

check_system
main_menu
EOF

chmod +x /usr/local/bin/h2

echo -e "${GREEN}安装完成！${NC}"
echo -e "使用 ${YELLOW}h2${NC} 命令启动管理脚本"

exit 0