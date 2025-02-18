# 创建全局命令的主脚本
create_main_command() {
    cat > /usr/local/bin/h2 <<'EOF'
#!/bin/bash
SCRIPT_DIR="/usr/local/SPH2"

# 首先确保所有依赖的脚本文件存在
for script in "constants.sh" "server_manager.sh" "client_manager.sh"; do
    if [ ! -f "${SCRIPT_DIR}/${script}" ]; then
        echo -e "\033[0;31m错误: ${SCRIPT_DIR}/${script} 不存在\033[0m"
        exit 1
    fi
done

# 使用绝对路径source所需文件
source "${SCRIPT_DIR}/constants.sh"
source "${SCRIPT_DIR}/server_manager.sh"
source "${SCRIPT_DIR}/client_manager.sh"

EOF

    # 将main.sh的内容附加到h2命令中，但去掉source语句
    sed '/^source/d' "${SCRIPT_DIR}/main.sh" >> /usr/local/bin/h2
    
    chmod +x /usr/local/bin/h2
}
