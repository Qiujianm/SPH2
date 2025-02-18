#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 基础目录
SCRIPT_DIR="/usr/local/SPH2"

# 创建全局命令的主脚本
create_main_command() {
    cat > /usr/local/bin/h2 <<EOF
#!/bin/bash
source ${SCRIPT_DIR}/constants.sh
source ${SCRIPT_DIR}/server_manager.sh
source ${SCRIPT_DIR}/client_manager.sh
$(cat ${SCRIPT_DIR}/main.sh)
EOF

    chmod +x /usr/local/bin/h2
}

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
    local url="https://raw.githubusercontent.com/Qiujianm/SPH2/main/${file}"
    echo -e "${YELLOW}正在下载 ${file}...${NC}"
    wget -q -O "${SCRIPT_DIR}/${file}" "$url" || {
        echo -e "${RED}下载 ${file} 失败${NC}"
        return 1
    }
}

echo -e "${YELLOW}正在安装基本依赖...${NC}"
check_command "wget"
check_command "curl"

# 创建并清理目录
rm -rf "$SCRIPT_DIR"
mkdir -p "$SCRIPT_DIR"

# 下载所有脚本
echo -e "${YELLOW}正在下载脚本文件...${NC}"
FILES=("main.sh" "constants.sh" "server_manager.sh" "client_manager.sh" "start_clients.sh")
for file in "${FILES[@]}"; do
    download_file "$file" || exit 1
done

# 设置权限
chmod +x "${SCRIPT_DIR}"/*.sh

# 创建全局命令
create_main_command

echo -e "${GREEN}安装完成！${NC}"
echo -e "使用 ${YELLOW}h2${NC} 命令启动管理脚本"

# 直接运行命令
h2

exit 0
