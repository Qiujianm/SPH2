#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 基础目录
SCRIPT_DIR="/usr/local/hysteria"

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用root用户运行此脚本${NC}"
    exit 1
fi

# 检查并安装基本工具
check_command() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "${YELLOW}正在安装 $1...${NC}"
        if [ -f /etc/redhat-release ]; then
            yum install -y "$1"
        elif [ -f /etc/debian_version ]; then
            apt-get update && apt-get install -y "$1"
        fi
    fi
}

# 下载文件
download_file() {
    local file=$1
    local path=$2
    local url="https://raw.githubusercontent.com/Qiujianm/SPH2/main/${file}"
    echo -e "${YELLOW}正在下载 ${file}...${NC}"
    wget -q -O "${path}/${file}" "$url" || {
        echo -e "${RED}下载 ${file} 失败${NC}"
        return 1
    }
}

# 安装基本依赖
echo -e "${YELLOW}正在安装基本依赖...${NC}"
check_command "wget"
check_command "curl"

# 创建安装目录
mkdir -p "$SCRIPT_DIR"

# 下载所有脚本文件
echo -e "${YELLOW}正在下载脚本文件...${NC}"
FILES=("main.sh" "constants.sh" "server_manager.sh" "client_manager.sh" "start_clients.sh")
for file in "${FILES[@]}"; do
    download_file "$file" "$SCRIPT_DIR" || exit 1
done

# 设置权限
chmod +x "$SCRIPT_DIR"/*.sh

# 创建到 /root 目录的软链接
ln -sf "$SCRIPT_DIR/main.sh" /root/h2

# 创建全局命令快捷方式
ln -sf "$SCRIPT_DIR/main.sh" /usr/local/bin/h2

echo -e "${GREEN}安装完成！${NC}"
echo -e "您可以通过以下任意方式运行脚本："
echo -e "1. 在 root 目录下运行: ${YELLOW}./h2${NC}"
echo -e "2. 使用快捷命令: ${YELLOW}h2${NC}"

# 运行主脚本
cd "$SCRIPT_DIR"
./main.sh

exit 0
