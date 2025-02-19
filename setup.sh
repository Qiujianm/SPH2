#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用root权限运行此脚本${NC}"
    exit 1
fi

# 安装基本依赖
if command -v apt >/dev/null; then
    apt update && apt install -y openssl curl wget
elif command -v yum >/dev/null; then
    yum install -y openssl curl wget
fi

# 安装Hysteria2
install_hysteria() {
    echo -e "${YELLOW}开始安装 Hysteria...${NC}"
    
    # 镜像列表
    MIRROR_URLS=(
        "https://mirror.ghproxy.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://gh.ddlc.top/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    )
    
    # 尝试官方安装
    if curl -fsSL https://get.hy2.dev/ | bash; then
        return 0
    fi
    
    # 尝试镜像
    for mirror in "${MIRROR_URLS[@]}"; do
        if wget -O /usr/local/bin/hysteria "$mirror" 2>/dev/null; then
            chmod +x /usr/local/bin/hysteria
            if /usr/local/bin/hysteria version >/dev/null 2>&1; then
                return 0
            fi
            rm -f /usr/local/bin/hysteria
        fi
    done
    
    return 1
}

install_hysteria || {
    echo -e "${RED}Hysteria 安装失败${NC}"
    exit 1
}

# 创建必要目录
mkdir -p /root/H2
mkdir -p /etc/hysteria

# 下载管理脚本
download_scripts() {
    cd /root
    FILES=("main.sh" "config.sh" "server.sh" "client.sh")
    
    for file in "${FILES[@]}"; do
        wget -O "/root/${file}" "https://raw.githubusercontent.com/Qiujianm/SPH2/main/${file}" || return 1
        chmod +x "/root/${file}"
    done
    
    return 0
}

download_scripts || {
    echo -e "${RED}脚本下载失败${NC}"
    exit 1
}

# 创建快捷命令
cat > /usr/local/bin/h2 << 'EOF'
#!/bin/bash
cd /root
bash ./main.sh
EOF
chmod +x /usr/local/bin/h2

echo -e "${GREEN}安装完成！${NC}"
echo -e "使用 ${YELLOW}h2${NC} 命令启动管理面板"