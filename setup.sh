#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

SCRIPT_DIR="/usr/local/SPH2"

install_hysteria() {
    echo -e "${YELLOW}开始安装 Hysteria...${NC}"
    
    # 定义多个下载源
    GITHUB_URL="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    MIRROR_URLS=(
        "https://mirror.ghproxy.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://gh.ddlc.top/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://github.91chi.fun/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    )
    
    # 尝试官方安装脚本
    if curl -fsSL https://get.hy2.dev/ | bash; then
        echo -e "${GREEN}通过官方脚本安装成功${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}官方安装失败，尝试直接下载...${NC}"
    
    # 尝试直接从 GitHub 下载
    if wget -O /usr/local/bin/hysteria "${GITHUB_URL}" 2>/dev/null; then
        chmod +x /usr/local/bin/hysteria
        echo -e "${GREEN}从 GitHub 直接下载安装成功${NC}"
        return 0
    fi
    
    # 尝试各个镜像源
    for mirror in "${MIRROR_URLS[@]}"; do
        echo -e "${YELLOW}尝试从镜像下载: ${mirror}${NC}"
        if wget -O /usr/local/bin/hysteria "${mirror}" 2>/dev/null; then
            chmod +x /usr/local/bin/hysteria
            if /usr/local/bin/hysteria version >/dev/null 2>&1; then
                echo -e "${GREEN}从镜像安装成功${NC}"
                return 0
            else
                rm -f /usr/local/bin/hysteria
            fi
        fi
    done
    
    echo -e "${RED}所有安装方式都失败${NC}"
    return 1
}

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
}

download_scripts() {
    mkdir -p "$SCRIPT_DIR"
    FILES=("main.sh" "constants.sh" "server_manager.sh" "client_manager.sh")
    local success=0
    
    # 尝试不同的代理
    GITHUB_PROXIES=(
        "https://raw.githubusercontent.com"
        "https://raw.gitmirror.com"
        "https://mirror.ghproxy.com/https://raw.githubusercontent.com"
        "https://gh.ddlc.top/https://raw.githubusercontent.com"
    )
    
    for proxy in "${GITHUB_PROXIES[@]}"; do
        echo -e "${YELLOW}尝试从 ${proxy} 下载脚本...${NC}"
        success=1
        for file in "${FILES[@]}"; do
            if ! wget -q -O "${SCRIPT_DIR}/${file}" "${proxy}/Qiujianm/SPH2/main/${file}"; then
                success=0
                break
            fi
            chmod +x "${SCRIPT_DIR}/${file}"
        done
        [ $success -eq 1 ] && break
    done
    
    if [ $success -eq 0 ]; then
        echo -e "${RED}脚本文件下载失败${NC}"
        return 1
    fi
    
    echo -e "${GREEN}脚本文件下载成功${NC}"
    return 0
}

create_command_link() {
    cat > /usr/local/bin/h2 << 'EOF'
#!/bin/bash
SCRIPT_DIR="/usr/local/SPH2"
[ "$EUID" -ne 0 ] && echo -e "\033[0;31m请使用root用户运行此脚本\033[0m" && exit 1
source "${SCRIPT_DIR}/constants.sh"
source "${SCRIPT_DIR}/server_manager.sh"
source "${SCRIPT_DIR}/client_manager.sh"
bash "${SCRIPT_DIR}/main.sh"
EOF
    chmod +x /usr/local/bin/h2
}

main() {
    [ "$EUID" -ne 0 ] && echo -e "${RED}请使用root用户运行此脚本${NC}" && exit 1
    
    cleanup_old_installation
    
    if command -v apt >/dev/null; then
        apt update && apt install -y openssl curl wget
    elif command -v yum >/dev/null; then
        yum install -y openssl curl wget
    fi
    
    if ! install_hysteria; then
        echo -e "${RED}Hysteria 安装失败，请检查网络连接或手动安装${NC}"
        exit 1
    fi
    
    mkdir -p /etc/hysteria
    mkdir -p /root/H2
    
    if ! download_scripts; then
        echo -e "${RED}脚本下载失败，请检查网络连接${NC}"
        exit 1
    fi
    
    create_command_link
    
    echo -e "${GREEN}安装完成！${NC}"
    echo -e "使用 ${YELLOW}h2${NC} 命令启动管理面板"
}

main
