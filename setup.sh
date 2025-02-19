#!/bin/bash

# 脚本信息
VERSION="2025-02-19"
AUTHOR="Qiujianm"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 检查root权限
[ "$EUID" -ne 0 ] && echo -e "${RED}请使用root权限运行此脚本${NC}" && exit 1

# 清理旧安装
cleanup_old_installation() {
    echo -e "${YELLOW}清理旧的安装...${NC}"
    systemctl stop hysteria-server 2>/dev/null || true
    systemctl disable hysteria-server 2>/dev/null || true
    pkill -f hysteria || true
    
    rm -rf /etc/hysteria
    rm -rf /root/H2
    rm -f /usr/local/bin/hysteria
    rm -f /usr/local/bin/h2
    rm -f /etc/systemd/system/hysteria-server.service
    rm -f /etc/sysctl.d/99-hysteria.conf
    rm -f /etc/security/limits.d/99-hysteria.conf
    rm -f /root/{main,server,client,config}.sh
    
    systemctl daemon-reload
}

# 安装基础依赖
install_base() {
    echo -e "${YELLOW}安装基础依赖...${NC}"
    # 国内源
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list 2>/dev/null
        sed -i 's/security.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list 2>/dev/null
        sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list 2>/dev/null
        apt update
        apt install -y curl wget openssl
    elif [ -f /etc/redhat-release ]; then
        # CentOS
        if [ -f /etc/yum.repos.d/CentOS-Base.repo ]; then
            mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
            wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
            yum clean all
            yum makecache
        fi
        yum install -y curl wget openssl
    else
        echo -e "${RED}不支持的系统${NC}"
        exit 1
    fi
}

# 下载并安装Hysteria
install_hysteria() {
    echo -e "${YELLOW}开始安装Hysteria...${NC}"
    
    # 中国大陆优化的下载源
    local urls=(
        "https://mirror.ghproxy.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://gh.ddlc.top/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://hub.gitmirror.com/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
        "https://mirror.ghproxy.com/https://raw.githubusercontent.com/apernet/hysteria/master/install_server.sh"
    )
    
    # 先尝试镜像下载
    for url in "${urls[@]}"; do
        echo -e "${YELLOW}尝试从 ${url} 下载...${NC}"
        if [[ $url == *"install_server.sh"* ]]; then
            if curl -fsSL "$url" | bash; then
                echo -e "${GREEN}Hysteria安装成功${NC}"
                return 0
            fi
        else
            if wget -O /usr/local/bin/hysteria "$url" && 
               chmod +x /usr/local/bin/hysteria && 
               /usr/local/bin/hysteria version >/dev/null 2>&1; then
                echo -e "${GREEN}Hysteria安装成功${NC}"
                return 0
            fi
        fi
    done
    
    # 如果镜像都失败，尝试官方安装
    if curl -fsSL https://get.hy2.dev/ | bash; then
        echo -e "${GREEN}Hysteria安装成功${NC}"
        return 0
    fi

    echo -e "${RED}Hysteria安装失败${NC}"
    return 1
}

# 下载管理脚本
download_scripts() {
    echo -e "${YELLOW}下载管理脚本...${NC}"
    cd /root
    
    local files=("main.sh" "server.sh" "client.sh" "config.sh")
    # 中国大陆优化的镜像源
    local mirrors=(
        "https://mirror.ghproxy.com/https://raw.githubusercontent.com"
        "https://gh.ddlc.top/https://raw.githubusercontent.com"
        "https://raw.gitmirror.com"
        "https://raw.fastgit.org"
        "https://raw.githubusercontent.com"
    )
    
    for mirror in "${mirrors[@]}"; do
        echo -e "${YELLOW}尝试从 ${mirror} 下载...${NC}"
        local success=true
        
        for file in "${files[@]}"; do
            if ! wget -q -O "/root/${file}" "${mirror}/Qiujianm/SPH2/main/${file}"; then
                success=false
                break
            fi
            chmod +x "/root/${file}"
        done
        
        $success && {
            echo -e "${GREEN}脚本下载成功${NC}"
            return 0
        }
    done
    
    echo -e "${RED}脚本下载失败${NC}"
    return 1
}

# 创建目录和链接
setup_environment() {
    mkdir -p /etc/hysteria
    mkdir -p /root/H2
    
    cat > /usr/local/bin/h2 << 'EOF'
#!/bin/bash
cd /root
[ "$EUID" -ne 0 ] && echo -e "\033[0;31m请使用root权限运行此脚本\033[0m" && exit 1
bash ./main.sh
EOF
    chmod +x /usr/local/bin/h2
}

# 主函数
main() {
    clear
    echo -e "${GREEN}════════ Hysteria 管理脚本 安装程序 ════════${NC}"
    echo -e "${GREEN}作者: ${AUTHOR}${NC}"
    echo -e "${GREEN}版本: ${VERSION}${NC}"
    echo -e "${GREEN}============================================${NC}"
    
    cleanup_old_installation
    install_base
    
    install_hysteria || {
        echo -e "${RED}Hysteria 安装失败，请检查网络或手动安装${NC}"
        exit 1
    }
    
    download_scripts || {
        echo -e "${RED}管理脚本下载失败，请检查网络连接${NC}"
        exit 1
    }
    
    setup_environment
    
    echo -e "\n${GREEN}安装完成！${NC}"
    echo -e "使用 ${YELLOW}h2${NC} 命令启动管理面板"
}

main