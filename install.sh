#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

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

# 安装基本依赖
echo -e "${YELLOW}正在安装基本依赖...${NC}"
check_command "wget"
check_command "git"
check_command "curl"

# 克隆项目
echo -e "${YELLOW}正在下载脚本...${NC}"
if [ -d "SPH2" ]; then
    rm -rf SPH2
fi
git clone https://github.com/Qiujianm/SPH2.git
cd SPH2

# 设置权限
chmod +x *.sh

# 运行主脚本
echo -e "${GREEN}安装完成，正在启动主脚本...${NC}"
sleep 0.5
./main.sh

exit 0