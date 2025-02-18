#!/bin/bash
source /usr/local/SPH2/constants.sh

# 清理旧的安装
cleanup_old_installation() {
    echo -e "${YELLOW}清理旧的安装...${NC}"
    
    # 停止服务和进程
    systemctl stop hysteria-server 2>/dev/null || true
    systemctl disable hysteria-server 2>/dev/null || true
    pkill -f hysteria || true
    
    # 删除文件和目录
    rm -rf /etc/hysteria
    rm -rf /root/H2
    rm -rf /usr/local/SPH2
    rm -f /etc/systemd/system/hysteria-server.service
    rm -f /usr/local/bin/h2
    rm -f /usr/local/bin/hysteria
    
    # 重载systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}清理完成${NC}"
}

# 安装 Hysteria
install_hysteria() {
    echo -e "${YELLOW}开始安装 Hysteria...${NC}"
    
    # 国内外安装源判断
    if ping -c 1 google.com >/dev/null 2>&1; then
        curl -fsSL https://get.hy2.dev/ | bash
    else
        # 国内安装源
        echo -e "${YELLOW}使用国内镜像源安装...${NC}"
        HYSTERIA_URL="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        wget -O /usr/local/bin/hysteria $HYSTERIA_URL
        chmod +x /usr/local/bin/hysteria
    fi

    if ! command -v hysteria >/dev/null; then
        echo -e "${RED}Hysteria 安装失败${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Hysteria 安装成功${NC}"
}

# 下载脚本文件
download_scripts() {
    mkdir -p "$SCRIPT_DIR"
    
    echo -e "${YELLOW}正在下载脚本文件...${NC}"
    FILES=("main.sh" "constants.sh" "server_manager.sh" "client_manager.sh")
    for file in "${FILES[@]}"; do
        wget -q -O "${SCRIPT_DIR}/${file}" "https://raw.githubusercontent.com/Qiujianm/SPH2/main/${file}" || {
            echo -e "${RED}下载 ${file} 失败${NC}"
            return 1
        }
    done
    
    chmod +x "${SCRIPT_DIR}"/*.sh
}

# 创建命令链接
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

# 主安装函数
main_install() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}请使用root用户运行此脚本${NC}"
        exit 1
    }

    cleanup_old_installation
    install_hysteria
    
    mkdir -p /etc/hysteria
    mkdir -p /root/H2
    
    download_scripts
    create_command_link

    echo -e "${GREEN}安装完成！${NC}"
    echo -e "使用 ${YELLOW}h2${NC} 命令启动管理面板"
}

main_install