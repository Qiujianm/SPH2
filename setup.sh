#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 基础目录
SCRIPT_DIR="/usr/local/SPH2"

cleanup_old_installation() {
    echo -e "${YELLOW}清理旧的安装...${NC}"
    systemctl stop hysteria-server 2>/dev/null || true
    systemctl disable hysteria-server 2>/dev/null || true
    pkill -f hysteria || true
    rm -rf /etc/hysteria
    rm -rf /root/H2
    rm -rf /usr/local/SPH2
    rm -f /etc/systemd/system/hysteria-server.service
    rm -f /usr/local/bin/h2
    rm -f /usr/local/bin/hysteria
    systemctl daemon-reload
    echo -e "${GREEN}清理完成${NC}"
}

install_hysteria() {
    echo -e "${YELLOW}开始安装 Hysteria...${NC}"
    if ping -c 1 google.com >/dev/null 2>&1; then
        curl -fsSL https://get.hy2.dev/ | bash
    else
        HYSTERIA_URL="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        wget -O /usr/local/bin/hysteria $HYSTERIA_URL
        chmod +x /usr/local/bin/hysteria
    fi

    if ! command -v hysteria >/dev/null; then
        echo -e "${RED}Hysteria 安装失败${NC}"
        return 1
    fi
    echo -e "${GREEN}Hysteria 安装成功${NC}"
    return 0
}

download_scripts() {
    mkdir -p "$SCRIPT_DIR"
    echo -e "${YELLOW}正在下载脚本文件...${NC}"
    FILES=("main.sh" "constants.sh" "server_manager.sh" "client_manager.sh")
    for file in "${FILES[@]}"; do
        wget -q -O "${SCRIPT_DIR}/${file}" "https://raw.githubusercontent.com/Qiujianm/SPH2/main/${file}"
        if [ $? -ne 0 ]; then
            echo -e "${RED}下载 ${file} 失败${NC}"
            return 1
        fi
    done
    chmod +x "${SCRIPT_DIR}"/*.sh
    return 0
}

create_command_link() {
    cat > /usr/local/bin/h2 << 'EOF'
#!/bin/bash
SCRIPT_DIR="/usr/local/SPH2"

if [ "$EUID" -ne 0 ]; then
    echo -e "\033[0;31m请使用root用户运行此脚本\033[0m"
    exit 1
fi

source "${SCRIPT_DIR}/constants.sh"
source "${SCRIPT_DIR}/server_manager.sh"
source "${SCRIPT_DIR}/client_manager.sh"

bash "${SCRIPT_DIR}/main.sh"
EOF

    chmod +x /usr/local/bin/h2
}

main_install() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}请使用root用户运行此脚本${NC}"
        exit 1
    fi

    cleanup_old_installation
    
    if command -v apt >/dev/null; then
        apt update
        apt install -y openssl curl wget
    elif command -v yum >/dev/null; then
        yum install -y openssl curl wget
    fi
    
    install_hysteria || exit 1
    
    mkdir -p /etc/hysteria
    mkdir -p /root/H2
    
    download_scripts || exit 1
    create_command_link

    echo -e "${GREEN}安装完成！${NC}"
    echo -e "使用 ${YELLOW}h2${NC} 命令启动管理面板"
}

main_install
