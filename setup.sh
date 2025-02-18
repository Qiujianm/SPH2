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
install_dependencies() {
    echo -e "${YELLOW}正在安装基本依赖...${NC}"
    if [ -f /etc/redhat-release ]; then
        yum install -y wget curl systemd
    elif [ -f /etc/debian_version ]; then
        apt-get update && apt-get install -y wget curl systemd
    fi
}

# 停止所有相关进程
stop_all_processes() {
    echo -e "${YELLOW}停止所有相关进程...${NC}"
    systemctl stop hysteria-server 2>/dev/null || true
    systemctl stop clients 2>/dev/null || true
    pkill -f /usr/local/bin/hysteria || true
    sleep 2
}

# 主安装函数
main_install() {
    # 停止所有进程
    stop_all_processes
    
    # 安装依赖
    install_dependencies
    
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

    # 创建全局命令
    create_global_command

    echo -e "${GREEN}安装完成！${NC}"
    echo -e "使用 ${YELLOW}h2${NC} 命令启动管理面板"
}

# 创建全局命令
create_global_command() {
    cat > /usr/local/bin/h2 << 'EOF'
#!/bin/bash
SCRIPT_DIR="/usr/local/SPH2"

# 错误处理
set -e
trap 'echo -e "\033[0;31m错误: 脚本执行失败\033[0m" >&2' ERR

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[0;31m请使用root用户运行此脚本\033[0m"
    exit 1
fi

# 导入所有需要的模块
source "$SCRIPT_DIR/constants.sh"
source "$SCRIPT_DIR/server_manager.sh"
source "$SCRIPT_DIR/client_manager.sh"

# 启动主程序
exec "$SCRIPT_DIR/main.sh"
EOF

    chmod +x /usr/local/bin/h2
}

# 运行主安装函数
main_install