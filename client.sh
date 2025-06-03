#!/bin/bash

# 自动生成 systemd 多实例模板（如已存在则跳过）
SERVICE_FILE="/etc/systemd/system/hysteriaclient@.service"
if [ ! -f "$SERVICE_FILE" ]; then
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Hysteria Client Instance %i
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria client -c /root/%i.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
  echo -e "\033[1;32m已自动生成 $SERVICE_FILE\033[0m"
  systemctl daemon-reload
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 【自动批量注册 systemd 实例，支持 auto_enable_all 参数，可用于开机自启动】
if [[ "$1" == "auto_enable_all" ]]; then
  shopt -s nullglob
  for cfg in /root/*.json; do
    name=$(basename "${cfg%.json}")
    systemctl enable --now hysteriaclient@"$name"
  done
  exit 0
fi

# 自动注册并启动所有配置到 systemd
auto_systemd_enable_all() {
    echo -e "${YELLOW}正在自动写入并启动/root/*.json配置到 systemd ...${NC}"
    shopt -s nullglob
    found=0
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        systemctl enable --now hysteriaclient@"$name" &>/dev/null
        echo -e "${GREEN}已注册并启动/守护实例：$name${NC}"
        found=1
    done
    if [ $found -eq 0 ]; then
        echo -e "${RED}未发现/root下的配置文件！${NC}"
    fi
}

# 停止全部客户端
stop_all() {
    shopt -s nullglob
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        systemctl stop hysteriaclient@"$name" &>/dev/null
        echo -e "${YELLOW}已停止 $name${NC}"
    done
}

# 重启全部客户端
restart_all() {
    shopt -s nullglob
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        systemctl restart hysteriaclient@"$name" &>/dev/null
        echo -e "${GREEN}已重启 $name${NC}"
    done
}

# 查看所有客户端 systemd 状态
status_all() {
    echo -e "${YELLOW}所有客户端 systemd 状态：${NC}"
    shopt -s nullglob
    for cfg in /root/*.json; do
        name=$(basename "${cfg%.json}")
        echo -e "${GREEN}[$name]${NC}"
        systemctl --no-pager --full status hysteriaclient@"$name" | grep -E "Active:|Loaded:" | head -n 2
        echo "---------------------------------------"
    done
}

# 删除客户端配置并禁用服务
delete_config() {
    echo -e "${YELLOW}可用的配置文件：${NC}"
    ls -l /root/*.json 2>/dev/null || echo "无配置文件"
    read -p "请输入要删除的配置文件名称（不带.json）: " name
    if [ -f "/root/$name.json" ]; then
        systemctl disable --now hysteriaclient@"$name"
        rm -f "/root/$name.json"
        echo -e "${GREEN}配置文件 $name 已删除并禁用服务${NC}"
        rm -f "/var/log/hysteria-client-$name.log"
    else
        echo -e "${RED}文件不存在${NC}"
    fi
}

# 展示所有配置
list_configs() {
    echo -e "${YELLOW}可用的配置文件：${NC}"
    ls -l /root/*.json 2>/dev/null || echo "无配置文件"
}

while true; do
    clear
    echo -e "${GREEN}==== Hysteria Client Systemd 管理 ====${NC}"
    echo "1. 自动注册并启动所有配置到 systemd"
    echo "2. 停止全部客户端"
    echo "3. 重启全部客户端"
    echo "4. 查看所有客户端状态"
    echo "5. 删除客户端配置"
    echo "6. 展示所有配置"
    echo "0. 退出"
    read -t 60 -p "请选择 [0-6]: " choice || exit 0

    case $choice in
        1) auto_systemd_enable_all ;;
        2) stop_all ;;
        3) restart_all ;;
        4) status_all ;;
        5) delete_config ;;
        6) list_configs ;;
        0) exit ;;
        *) echo -e "${RED}无效选择${NC}" ;;
    esac

    read -n 1 -s -r -p "按任意键继续..."
done
