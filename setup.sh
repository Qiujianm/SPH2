#!/bin/bash

# 创建客户端启动脚本
CLIENT_SCRIPT="/usr/local/bin/hysteria-client-manager.sh"
cat > "$CLIENT_SCRIPT" <<'EOF'
#!/bin/bash
# Hysteria Client Manager Script

CONFIG_DIR="/root"
HYSTERIA_BIN="/usr/local/bin/hysteria"
PID_FILE="/var/run/hysteria-client-manager.pid"

# 创建PID文件目录
mkdir -p "$(dirname "$PID_FILE")"

# 停止已存在的进程
if [ -f "$PID_FILE" ]; then
    pkill -F "$PID_FILE" 2>/dev/null || true
    rm -f "$PID_FILE"
fi

# 启动所有配置文件（优化性能）
pids=()
config_count=0

for cfg in "$CONFIG_DIR"/*.json; do
    if [ -f "$cfg" ]; then
        config_count=$((config_count + 1))
        
        echo "Starting client with config: $cfg (${config_count})"
        "$HYSTERIA_BIN" client -c "$cfg" &
        pids+=($!)
        
        # 进一步减少延迟，提高启动速度
        sleep 0.05
    fi
done

echo "总共启动了 $config_count 个客户端配置"

# 保存PID到文件
echo "${pids[@]}" > "$PID_FILE"

# 等待所有进程
wait
EOF
  chmod +x "$CLIENT_SCRIPT"
  echo -e "\033[1;32m已更新客户端启动脚本 $CLIENT_SCRIPT\033[0m"

# 自动生成统一的 systemd 服务模板（如已存在则跳过）
SERVICE_FILE="/etc/systemd/system/hysteria-client-manager.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Hysteria Client Manager - Manages all client configurations
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria-client-manager.sh
Restart=always
RestartSec=1
User=root
PIDFile=/var/run/hysteria-client-manager.pid
Nice=-10
IOSchedulingClass=1
IOSchedulingPriority=4
TimeoutStartSec=15
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF
echo -e "\033[1;32m已更新统一服务 $SERVICE_FILE\033[0m"
systemctl daemon-reload

# 保留原有的多实例模板用于兼容性
SERVICE_FILE_MULTI="/etc/systemd/system/hysteriaclient@.service"
if [ ! -f "$SERVICE_FILE_MULTI" ]; then
  cat > "$SERVICE_FILE_MULTI" <<EOF
[Unit]
Description=Hysteria Client Instance %i
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria client -c /root/%i.json
Restart=always
RestartSec=1
Nice=-5
IOSchedulingClass=1
IOSchedulingPriority=4
CPUSchedulingPolicy=rr
CPUSchedulingPriority=50
TimeoutStartSec=10
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF
  echo -e "\033[1;32m已自动生成多实例服务 $SERVICE_FILE_MULTI\033[0m"
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
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    # 统计配置数量
    local config_count=0
    for cfg in /root/*.json; do
        if [ -f "$cfg" ]; then
            config_count=$((config_count + 1))
        fi
    done
    echo -e "${GREEN}检测到 ${config_count} 个配置文件${NC}"
    
    # 询问启动方式
    echo -e "${YELLOW}选择启动方式：${NC}"
    echo "1. 使用统一服务管理（推荐，一个服务管理所有配置）"
    echo "2. 使用多实例服务（每个配置一个服务，支持并行启动）"
    echo "3. 直接启动进程（速度快，但重启后需要手动启动）"
    echo "4. 超快速启动模式（大量实例专用，并行启动，无systemd）"
    read -p "请选择 [1-4]: " create_service
    
    shopt -s nullglob
    found=0
    
    case "$create_service" in
        1)
            # 统一服务模式
            echo -e "${YELLOW}正在启动统一服务管理所有配置...${NC}"
            if systemctl enable --now hysteria-client-manager.service &>/dev/null; then
                echo -e "${GREEN}✓ 统一服务启动成功，正在管理所有配置文件${NC}"
                # 显示正在管理的配置文件
                for cfg in /root/*.json; do
                    [ -f "$cfg" ] || continue
                    name=$(basename "${cfg%.json}")
                    echo -e "${GREEN}  - 管理配置：$name${NC}"
                    found=1
                done
            else
                echo -e "${RED}✗ 统一服务启动失败${NC}"
                systemctl status hysteria-client-manager.service --no-pager
            fi
            ;;
        2)
            # 多实例服务模式（并行优化）
            echo -e "${YELLOW}正在批量启动多实例服务...${NC}"
            local started_count=0
            local failed_count=0
            
            # 并行启动服务
            for cfg in /root/*.json; do
                [ -f "$cfg" ] || continue
                name=$(basename "${cfg%.json}")
                
                (
                    if systemctl enable --now hysteriaclient@"$name" &>/dev/null; then
                        echo -e "${GREEN}✓ 已启动新增实例：$name${NC}"
                        ((started_count++))
                    else
                        echo -e "${RED}✗ 启动失败：$name${NC}"
                        ((failed_count++))
                    fi
                ) &
                
                # 控制并发数量，避免系统负载过高
                if (( $(jobs -r | wc -l) >= 10 )); then
                    wait -n
                fi
                found=1
            done
            
            # 等待所有后台任务完成
            wait
            
            echo -e "${GREEN}批量启动完成：成功 $started_count 个，失败 $failed_count 个${NC}"
            ;;
        3)
            # 直接进程模式（并行优化）
            echo -e "${YELLOW}正在直接启动hysteria客户端进程...${NC}"
            local started_count=0
            local failed_count=0
            local skipped_count=0
            
            for cfg in /root/*.json; do
                [ -f "$cfg" ] || continue
                name=$(basename "${cfg%.json}")
                
                # 检查是否已有进程在运行
                if pgrep -f "hysteria.*client.*-c.*$cfg" >/dev/null; then
                    echo -e "${YELLOW}客户端 $name 的进程已在运行，跳过${NC}"
                    ((skipped_count++))
                    continue
                fi
                
                # 后台启动hysteria客户端进程
                (
                    nohup /usr/local/bin/hysteria client -c "$cfg" >/dev/null 2>&1 &
                    local pid=$!
                    
                    # 短暂等待确保进程启动
                    sleep 0.1
                    
                    # 检查进程是否成功启动
                    if kill -0 "$pid" 2>/dev/null; then
                        echo -e "${GREEN}✓ 已启动新增实例：$name (PID: $pid)${NC}"
                        ((started_count++))
                    else
                        echo -e "${RED}✗ 启动失败：$name${NC}"
                        ((failed_count++))
                    fi
                ) &
                
                # 控制并发数量
                if (( $(jobs -r | wc -l) >= 20 )); then
                    wait -n
                fi
                found=1
            done
            
            # 等待所有后台任务完成
            wait
            
            echo -e "${GREEN}批量启动完成：成功 $started_count 个，失败 $failed_count 个，跳过 $skipped_count 个${NC}"
            ;;
        4)
            # 超快速启动模式（大量实例专用）
            echo -e "${YELLOW}超快速启动模式（大量实例专用）...${NC}"
            local started_count=0
            local failed_count=0
            
            # 创建快速启动脚本
            local fast_start_script="/tmp/hysteria_client_fast_start_$$.sh"
            cat > "$fast_start_script" << EOF
#!/bin/bash
# 超快速启动脚本

CONFIG_DIR="/root"
HYSTERIA_BIN="/usr/local/bin/hysteria"

# 并行启动所有实例
for cfg in /root/*.json; do
    [ -f "\$cfg" ] || continue
    name=\$(basename "\${cfg%.json}")
    
    # 检查是否已有进程在运行
    if ! pgrep -f "hysteria.*client.*-c.*\$cfg" >/dev/null; then
        # 后台启动hysteria客户端进程（无延迟）
        nohup \$HYSTERIA_BIN client -c "\$cfg" >/dev/null 2>&1 &
        echo -e "\033[32m✓ 已启动新增实例：\$name\033[0m"
        ((started_count++))
    else
        echo -e "\033[33m⚠ 实例 \$name 已在运行\033[0m"
    fi
    
    # 控制并发数量，避免系统负载过高
    if (( \$(jobs -r | wc -l) >= 50 )); then
        wait -n
    fi
done

# 等待所有后台任务完成
wait
echo -e "\033[32m超快速启动完成：成功 \$started_count 个实例\033[0m"
EOF
            
            chmod +x "$fast_start_script"
            
            # 执行快速启动脚本
            echo -e "${YELLOW}正在执行超快速启动...${NC}"
            bash "$fast_start_script"
            
            # 清理临时脚本
            rm -f "$fast_start_script"
            
            echo -e "${GREEN}✓ 超快速启动模式完成${NC}"
            ;;
    esac
    
    if [ $found -eq 0 ]; then
        echo -e "${RED}未发现/root下的配置文件！${NC}"
    fi
}

# 启动剩余未启动的实例
start_remaining_instances() {
    echo -e "${YELLOW}正在启动剩余未启动的实例...${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    # 询问是否创建系统服务
    echo -e "${YELLOW}选择启动方式：${NC}"
    echo "1. 创建系统服务（开机自启动，但速度较慢）"
    echo "2. 直接启动进程（速度快，但重启后需要手动启动）"
    echo "3. 超快速启动模式（大量实例专用，并行启动）"
    read -p "请选择 [1-3]: " create_service
    
    shopt -s nullglob
    found=0
    
    if [[ "$create_service" == "1" ]]; then
        # 系统服务模式
        for cfg in /root/*.json; do
            [ -f "$cfg" ] || continue
            name=$(basename "${cfg%.json}")
            if ! systemctl is-active --quiet hysteriaclient@"$name"; then
                if systemctl enable --now hysteriaclient@"$name" &>/dev/null; then
                    echo -e "${GREEN}✓ 已启动新增实例：$name${NC}"
                else
                    echo -e "${RED}✗ 启动实例 $name 失败${NC}"
                    systemctl status hysteriaclient@"$name" --no-pager
                fi
                found=1
            fi
        done
    elif [[ "$create_service" == "2" ]]; then
        # 直接进程模式（并行优化）
        echo -e "${YELLOW}正在直接启动hysteria客户端进程...${NC}"
        local started_count=0
        local failed_count=0
        local skipped_count=0
        
        for cfg in /root/*.json; do
            [ -f "$cfg" ] || continue
            name=$(basename "${cfg%.json}")
            
            # 检查是否已有进程在运行
            if pgrep -f "hysteria.*client.*-c.*$cfg" >/dev/null; then
                echo -e "${YELLOW}客户端 $name 的进程已在运行，跳过${NC}"
                ((skipped_count++))
                continue
            fi
            
            # 后台启动hysteria客户端进程
            (
                nohup /usr/local/bin/hysteria client -c "$cfg" >/dev/null 2>&1 &
                local pid=$!
                
                # 短暂等待确保进程启动
                sleep 0.1
                
                # 检查进程是否成功启动
                if kill -0 "$pid" 2>/dev/null; then
                    echo -e "${GREEN}✓ 已启动新增实例：$name (PID: $pid)${NC}"
                    ((started_count++))
                else
                    echo -e "${RED}✗ 启动失败：$name${NC}"
                    ((failed_count++))
                fi
            ) &
            
            # 控制并发数量
            if (( $(jobs -r | wc -l) >= 20 )); then
                wait -n
            fi
            found=1
        done
        
        # 等待所有后台任务完成
        wait
        
        echo -e "${GREEN}批量启动完成：成功 $started_count 个，失败 $failed_count 个，跳过 $skipped_count 个${NC}"
    elif [[ "$create_service" == "3" ]]; then
        # 超快速启动模式（大量实例专用）
        echo -e "${YELLOW}超快速启动模式（大量实例专用）...${NC}"
        local started_count=0
        local failed_count=0
        
        # 创建快速启动脚本
        local fast_start_script="/tmp/hysteria_client_fast_start_$$.sh"
        cat > "$fast_start_script" << EOF
#!/bin/bash
# 超快速启动脚本

CONFIG_DIR="/root"
HYSTERIA_BIN="/usr/local/bin/hysteria"

# 并行启动所有实例
for cfg in /root/*.json; do
    [ -f "\$cfg" ] || continue
    name=\$(basename "\${cfg%.json}")
    
    # 检查是否已有进程在运行
    if ! pgrep -f "hysteria.*client.*-c.*\$cfg" >/dev/null; then
        # 后台启动hysteria客户端进程（无延迟）
        nohup \$HYSTERIA_BIN client -c "\$cfg" >/dev/null 2>&1 &
        echo -e "\033[32m✓ 已启动新增实例：\$name\033[0m"
        ((started_count++))
    else
        echo -e "\033[33m⚠ 实例 \$name 已在运行\033[0m"
    fi
    
    # 控制并发数量，避免系统负载过高
    if (( \$(jobs -r | wc -l) >= 50 )); then
        wait -n
    fi
done

# 等待所有后台任务完成
wait
echo -e "\033[32m超快速启动完成：成功 \$started_count 个实例\033[0m"
EOF
        
        chmod +x "$fast_start_script"
        
        # 执行快速启动脚本
        echo -e "${YELLOW}正在执行超快速启动...${NC}"
        bash "$fast_start_script"
        
        # 清理临时脚本
        rm -f "$fast_start_script"
        
        echo -e "${GREEN}✓ 超快速启动模式完成${NC}"
        found=1
    fi
    
    if [ $found -eq 0 ]; then
        echo -e "${YELLOW}没有剩余未启动的实例${NC}"
    fi
}

# 停止全部客户端
stop_all() {
    echo -e "${GREEN}批量停止客户端:${NC}"
    echo "1. 停止所有客户端"
    echo "2. 停止指定端口范围的客户端"
    read -p "请选择停止方式[1-2]: " stop_type
    
    case "$stop_type" in
        1)
            stop_all_clients_internal
            ;;
        2)
            stop_port_range_clients
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return
            ;;
    esac
}

stop_all_clients_internal() {
    echo -e "${YELLOW}正在停止所有客户端...${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    # 询问停止方式
    echo -e "${YELLOW}选择停止方式：${NC}"
    echo "1. 停止统一服务（如果使用统一服务管理）"
    echo "2. 停止systemd服务（如果使用多实例服务）"
    echo "3. 停止进程（如果直接启动进程）"
    echo "4. 自动检测并停止（推荐）"
    read -p "请选择 [1-4]: " stop_method
    
    shopt -s nullglob
    stopped_count=0
    
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        
        case "$stop_method" in
            1)
                # 停止统一服务
                if systemctl stop hysteria-client-manager.service &>/dev/null; then
                    echo -e "${GREEN}✓ 已停止统一服务，所有客户端已停止${NC}"
                    stopped_count=1
                    break
                else
                    echo -e "${RED}✗ 停止统一服务失败${NC}"
                fi
                ;;
            2)
                # 停止systemd服务
                if systemctl stop hysteriaclient@"$name" &>/dev/null; then
                    echo -e "${GREEN}✓ 已停止systemd服务 $name${NC}"
                    ((stopped_count++))
                else
                    echo -e "${RED}✗ 停止systemd服务 $name 失败${NC}"
                fi
                ;;
            3)
                # 停止进程
                if pkill -f "hysteria.*client.*-c.*$cfg" >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ 已停止进程 $name${NC}"
                    ((stopped_count++))
                else
                    echo -e "${RED}✗ 停止进程 $name 失败${NC}"
                fi
                ;;
            4)
                # 自动检测并停止
                if systemctl is-active --quiet hysteria-client-manager.service 2>/dev/null; then
                    # 是统一服务
                    if systemctl stop hysteria-client-manager.service &>/dev/null; then
                        echo -e "${GREEN}✓ 已停止统一服务，所有客户端已停止${NC}"
                        stopped_count=1
                        break
                    else
                        echo -e "${RED}✗ 停止统一服务失败${NC}"
                    fi
                elif systemctl is-active --quiet hysteriaclient@"$name" 2>/dev/null; then
                    # 是systemd服务
                    if systemctl stop hysteriaclient@"$name" &>/dev/null; then
                        echo -e "${GREEN}✓ 已停止systemd服务 $name${NC}"
                        ((stopped_count++))
                    else
                        echo -e "${RED}✗ 停止systemd服务 $name 失败${NC}"
                    fi
                elif pgrep -f "hysteria.*client.*-c.*$cfg" >/dev/null; then
                    # 是直接进程
                    if pkill -f "hysteria.*client.*-c.*$cfg" >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ 已停止进程 $name${NC}"
                        ((stopped_count++))
                    else
                        echo -e "${RED}✗ 停止进程 $name 失败${NC}"
                    fi
                else
                    echo -e "${YELLOW}客户端 $name 未运行${NC}"
                fi
                ;;
        esac
    done
    
    if [ $stopped_count -gt 0 ]; then
        echo -e "${GREEN}成功停止 $stopped_count 个客户端${NC}"
    fi
}

stop_port_range_clients() {
    echo -e "${GREEN}停止指定端口范围的客户端:${NC}"
    read -p "请输入端口范围 (格式: 20000-20005): " port_range
    
    # 验证端口范围格式
    if [[ ! "$port_range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        echo -e "${RED}端口范围格式错误，请使用 起始端口-结束端口 格式${NC}"
        return
    fi
    
    start_port=${BASH_REMATCH[1]}
    end_port=${BASH_REMATCH[2]}
    
    # 验证端口范围
    if [ "$start_port" -gt "$end_port" ]; then
        echo -e "${RED}端口范围错误：起始端口不能大于结束端口${NC}"
        return
    fi
    
    echo -e "${YELLOW}正在停止端口范围 $start_port-$end_port 的客户端...${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    stopped_count=0
    shopt -s nullglob
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        # 从配置名称中提取端口号
        port=$(echo "$name" | grep -oE '[0-9]+$' || echo "")
        if [[ -n "$port" && "$port" -ge "$start_port" && "$port" -le "$end_port" ]]; then
            if systemctl stop hysteriaclient@"$name" &>/dev/null; then
                echo -e "${GREEN}✓ 已停止 $name${NC}"
                ((stopped_count++))
            else
                echo -e "${RED}✗ 停止 $name 失败${NC}"
            fi
        fi
    done
    
    if [ $stopped_count -gt 0 ]; then
        echo -e "${GREEN}成功停止 $stopped_count 个客户端${NC}"
    else
        echo -e "${YELLOW}在指定端口范围内没有找到客户端${NC}"
    fi
}

# 重启全部客户端
restart_all() {
    echo -e "${GREEN}批量重启客户端:${NC}"
    echo "1. 重启所有客户端"
    echo "2. 重启指定端口范围的客户端"
    read -p "请选择重启方式[1-2]: " restart_type
    
    case "$restart_type" in
        1)
            restart_all_clients_internal
            ;;
        2)
            restart_port_range_clients
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return
            ;;
    esac
}

restart_all_clients_internal() {
    echo -e "${YELLOW}正在重启所有客户端...${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    # 询问重启方式
    echo -e "${YELLOW}选择重启方式：${NC}"
    echo "1. 重启统一服务（如果使用统一服务管理）"
    echo "2. 重启systemd服务（如果使用多实例服务）"
    echo "3. 重启进程（如果直接启动进程）"
    echo "4. 自动检测并重启（推荐）"
    read -p "请选择 [1-4]: " restart_method
    
    shopt -s nullglob
    restarted_count=0
    
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        
        case "$restart_method" in
            1)
                # 重启统一服务
                if systemctl restart hysteria-client-manager.service &>/dev/null; then
                    echo -e "${GREEN}✓ 已重启统一服务，所有客户端已重启${NC}"
                    restarted_count=1
                    break
                else
                    echo -e "${RED}✗ 重启统一服务失败${NC}"
                fi
                ;;
            2)
                # 重启systemd服务
                if systemctl restart hysteriaclient@"$name" &>/dev/null; then
                    echo -e "${GREEN}✓ 已重启systemd服务 $name${NC}"
                    ((restarted_count++))
                else
                    echo -e "${RED}✗ 重启systemd服务 $name 失败${NC}"
                fi
                ;;
            3)
                # 重启进程
                if pkill -f "hysteria.*client.*-c.*$cfg" >/dev/null 2>&1; then
                    sleep 0.2
                    nohup /usr/local/bin/hysteria client -c "$cfg" >/dev/null 2>&1 &
                    local pid=$!
                    sleep 0.1
                    if kill -0 "$pid" 2>/dev/null; then
                        echo -e "${GREEN}✓ 已重启进程 $name (PID: $pid)${NC}"
                        ((restarted_count++))
                    else
                        echo -e "${RED}✗ 重启进程 $name 失败${NC}"
                    fi
                else
                    echo -e "${RED}✗ 停止进程 $name 失败${NC}"
                fi
                ;;
            4)
                # 自动检测并重启
                if systemctl is-active --quiet hysteria-client-manager.service 2>/dev/null; then
                    # 是统一服务
                    if systemctl restart hysteria-client-manager.service &>/dev/null; then
                        echo -e "${GREEN}✓ 已重启统一服务，所有客户端已重启${NC}"
                        restarted_count=1
                        break
                    else
                        echo -e "${RED}✗ 重启统一服务失败${NC}"
                    fi
                elif systemctl is-active --quiet hysteriaclient@"$name" 2>/dev/null; then
                    # 是systemd服务
                    if systemctl restart hysteriaclient@"$name" &>/dev/null; then
                        echo -e "${GREEN}✓ 已重启systemd服务 $name${NC}"
                        ((restarted_count++))
                    else
                        echo -e "${RED}✗ 重启systemd服务 $name 失败${NC}"
                    fi
                elif pgrep -f "hysteria.*client.*-c.*$cfg" >/dev/null; then
                    # 是直接进程
                    if pkill -f "hysteria.*client.*-c.*$cfg" >/dev/null 2>&1; then
                        sleep 1
                        nohup /usr/local/bin/hysteria client -c "$cfg" >/dev/null 2>&1 &
                        local pid=$!
                        sleep 0.5
                        if kill -0 "$pid" 2>/dev/null; then
                            echo -e "${GREEN}✓ 已重启进程 $name (PID: $pid)${NC}"
                            ((restarted_count++))
                        else
                            echo -e "${RED}✗ 重启进程 $name 失败${NC}"
                        fi
                    else
                        echo -e "${RED}✗ 停止进程 $name 失败${NC}"
                    fi
                else
                    echo -e "${YELLOW}客户端 $name 未运行${NC}"
                fi
                ;;
        esac
    done
    
    if [ $restarted_count -gt 0 ]; then
        echo -e "${GREEN}成功重启 $restarted_count 个客户端${NC}"
    fi
}

restart_port_range_clients() {
    echo -e "${GREEN}重启指定端口范围的客户端:${NC}"
    read -p "请输入端口范围 (格式: 20000-20005): " port_range
    
    # 验证端口范围格式
    if [[ ! "$port_range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        echo -e "${RED}端口范围格式错误，请使用 起始端口-结束端口 格式${NC}"
        return
    fi
    
    start_port=${BASH_REMATCH[1]}
    end_port=${BASH_REMATCH[2]}
    
    # 验证端口范围
    if [ "$start_port" -gt "$end_port" ]; then
        echo -e "${RED}端口范围错误：起始端口不能大于结束端口${NC}"
        return
    fi
    
    echo -e "${YELLOW}正在重启端口范围 $start_port-$end_port 的客户端...${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    restarted_count=0
    shopt -s nullglob
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        # 从配置名称中提取端口号
        port=$(echo "$name" | grep -oE '[0-9]+$' || echo "")
        if [[ -n "$port" && "$port" -ge "$start_port" && "$port" -le "$end_port" ]]; then
            if systemctl restart hysteriaclient@"$name" &>/dev/null; then
                echo -e "${GREEN}✓ 已重启 $name${NC}"
                ((restarted_count++))
            else
                echo -e "${RED}✗ 重启 $name 失败${NC}"
            fi
        fi
    done
    
    if [ $restarted_count -gt 0 ]; then
        echo -e "${GREEN}成功重启 $restarted_count 个客户端${NC}"
    else
        echo -e "${YELLOW}在指定端口范围内没有找到客户端${NC}"
    fi
}

# 查看所有客户端 systemd 状态
status_all() {
    echo -e "${GREEN}查看客户端状态:${NC}"
    echo "1. 查看所有客户端状态"
    echo "2. 查看指定端口范围的客户端状态"
    echo "3. 查看统一服务状态"
    read -p "请选择查看方式[1-3]: " view_type
    
    case "$view_type" in
        1)
            status_all_clients_internal
            ;;
        2)
            status_port_range_clients
            ;;
        3)
            status_unified_service
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return
            ;;
    esac
}

# 查看统一服务状态
status_unified_service() {
    echo -e "${YELLOW}统一服务状态:${NC}"
    
    if systemctl is-active --quiet hysteria-client-manager.service 2>/dev/null; then
        echo -e "${GREEN}✓ 统一服务正在运行${NC}"
        echo "服务名称: hysteria-client-manager.service"
        echo "运行时间: $(systemctl show hysteria-client-manager.service --property=ActiveEnterTimestamp | cut -d= -f2)"
        
        echo -e "\n${YELLOW}正在管理的配置文件:${NC}"
        shopt -s nullglob
        for cfg in /root/*.json; do
            [ -f "$cfg" ] || continue
            name=$(basename "${cfg%.json}")
            
            # 检查该配置文件对应的进程是否在运行
            if pgrep -f "hysteria.*client.*-c.*$cfg" >/dev/null; then
                echo -e "${GREEN}  - $name (运行中)${NC}"
            else
                echo -e "${RED}  - $name (未运行)${NC}"
            fi
        done
        
        # 显示进程信息
        echo -e "\n${YELLOW}相关进程:${NC}"
        pids=$(pgrep -f "hysteria.*client.*-c.*/root/.*\.json")
        if [ -n "$pids" ]; then
            for pid in $pids; do
                echo -e "${GREEN}  - PID: $pid${NC}"
            done
        else
            echo -e "${YELLOW}  未找到相关进程${NC}"
        fi
        
        # 显示PID文件信息
        if [ -f "/var/run/hysteria-client-manager.pid" ]; then
            echo -e "\n${YELLOW}PID文件:${NC}"
            echo -e "${GREEN}  - /var/run/hysteria-client-manager.pid${NC}"
            echo "内容: $(cat /var/run/hysteria-client-manager.pid)"
        fi
    else
        echo -e "${RED}✗ 统一服务未运行${NC}"
    fi
}

status_all_clients_internal() {
    echo -e "${YELLOW}所有客户端 systemd 状态：${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    shopt -s nullglob
    found=0
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        found=1
        
        echo -e "${GREEN}[$name]${NC}"
        
        # 检查服务是否存在
        if systemctl list-unit-files | grep -q "hysteriaclient@$name.service"; then
            # 获取服务状态
            status=$(systemctl is-active hysteriaclient@"$name" 2>/dev/null || echo "inactive")
            loaded=$(systemctl is-enabled hysteriaclient@"$name" 2>/dev/null || echo "disabled")
            
            echo "  状态: $status"
            echo "  启用: $loaded"
            
            # 如果服务正在运行，显示更多信息
            if [ "$status" = "active" ]; then
                echo "  运行时间: $(systemctl show hysteriaclient@$name --property=ActiveEnterTimestamp | cut -d= -f2)"
            fi
        else
            echo "  服务未注册"
        fi
        
        echo "---------------------------------------"
    done
    
    if [ $found -eq 0 ]; then
        echo -e "${YELLOW}没有找到任何客户端配置文件${NC}"
    fi
}

status_port_range_clients() {
    echo -e "${GREEN}查看指定端口范围的客户端状态:${NC}"
    read -p "请输入端口范围 (格式: 20000-20005): " port_range
    
    # 验证端口范围格式
    if [[ ! "$port_range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        echo -e "${RED}端口范围格式错误，请使用 起始端口-结束端口 格式${NC}"
        return
    fi
    
    start_port=${BASH_REMATCH[1]}
    end_port=${BASH_REMATCH[2]}
    
    # 验证端口范围
    if [ "$start_port" -gt "$end_port" ]; then
        echo -e "${RED}端口范围错误：起始端口不能大于结束端口${NC}"
        return
    fi
    
    echo -e "${YELLOW}端口范围 $start_port-$end_port 的客户端状态：${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    found_count=0
    shopt -s nullglob
    for cfg in /root/*.json; do
        [ -f "$cfg" ] || continue
        name=$(basename "${cfg%.json}")
        # 从配置名称中提取端口号
        port=$(echo "$name" | grep -oE '[0-9]+$' || echo "")
        if [[ -n "$port" && "$port" -ge "$start_port" && "$port" -le "$end_port" ]]; then
            found_count=1
            
            echo -e "${GREEN}[$name]${NC}"
            
            # 检查服务是否存在
            if systemctl list-unit-files | grep -q "hysteriaclient@$name.service"; then
                # 获取服务状态
                status=$(systemctl is-active hysteriaclient@"$name" 2>/dev/null || echo "inactive")
                loaded=$(systemctl is-enabled hysteriaclient@"$name" 2>/dev/null || echo "disabled")
                
                echo "  状态: $status"
                echo "  启用: $loaded"
                
                # 如果服务正在运行，显示更多信息
                if [ "$status" = "active" ]; then
                    echo "  运行时间: $(systemctl show hysteriaclient@$name --property=ActiveEnterTimestamp | cut -d= -f2)"
                fi
            else
                echo "  服务未注册"
            fi
            
            echo "---------------------------------------"
        fi
    done
    
    if [ $found_count -eq 0 ]; then
        echo -e "${YELLOW}在指定端口范围内没有找到客户端${NC}"
    fi
}

# 删除客户端配置并禁用服务（支持单个、范围和全部）
delete_config() {
    echo -e "${YELLOW}可用的配置文件：${NC}"
    
    # 检查是否有配置文件
    if ! ls /root/*.json 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}当前没有客户端配置文件${NC}"
        return
    fi
    
    # 显示配置文件列表
    ls -l /root/*.json 2>/dev/null || echo "无配置文件"
    
    echo
    echo -e "${YELLOW}删除选项:${NC}"
    echo "1. 输入单个配置名称 (如: 47.251.58.77_20000)"
    echo "2. 输入端口范围 (如: 20000-20005)"
    echo "3. 输入 'all' 删除所有配置"
    echo "4. 直接回车仅查看"
    read -p "请选择删除方式: " name
    
    if [ "$name" == "all" ]; then
        echo -e "${YELLOW}确认删除所有客户端配置？(y/n): ${NC}"
        read -p "" confirm
        if [[ "$confirm" == [yY] ]]; then
            # 收集所有配置文件
            all_configs=()
            for cfg in /root/*.json; do
                [ -f "$cfg" ] || continue
                cname=$(basename "${cfg%.json}")
                all_configs+=("$cname")
            done
            
            if [ ${#all_configs[@]} -eq 0 ]; then
                echo -e "${YELLOW}没有找到任何配置文件${NC}"
            else
                echo -e "${YELLOW}正在批量删除 ${#all_configs[@]} 个配置...${NC}"
                
                # 批量停止服务
                echo -e "${YELLOW}正在批量停止服务...${NC}"
                for cname in "${all_configs[@]}"; do
                    systemctl disable --now hysteriaclient@"$cname" >/dev/null 2>&1 || true &
                done
                wait  # 等待所有后台任务完成
                
                # 批量删除配置文件
                echo -e "${YELLOW}正在批量删除配置文件...${NC}"
                for cname in "${all_configs[@]}"; do
                    rm -f "/root/$cname.json" 2>/dev/null || true &
                    rm -f "/var/log/hysteria-client-$cname.log" 2>/dev/null || true &
                done
                wait  # 等待所有删除操作完成
                
                echo -e "${GREEN}已删除 ${#all_configs[@]} 个客户端配置${NC}"
            fi
        else
            echo -e "${YELLOW}取消删除操作${NC}"
        fi
    elif [[ -n "$name" ]]; then
        # 检查是否为端口范围 (格式: start-end)
        if [[ "$name" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start_port=${BASH_REMATCH[1]}
            end_port=${BASH_REMATCH[2]}
            
            # 验证端口范围
            if [ "$start_port" -gt "$end_port" ]; then
                echo -e "${RED}端口范围错误：起始端口不能大于结束端口${NC}"
            else
                echo -e "${YELLOW}确认删除端口范围 $start_port-$end_port 的所有客户端配置？(y/n): ${NC}"
                read -p "" confirm
                if [[ "$confirm" == [yY] ]]; then
                    deleted_count=0
                    configs_to_delete=()
                    
                    # 先收集要删除的配置
                    for cfg in /root/*.json; do
                        [ -f "$cfg" ] || continue
                        cname=$(basename "${cfg%.json}")
                        # 从配置名称中提取端口号
                        port=$(echo "$cname" | grep -oE '[0-9]+$' || echo "")
                        if [[ -n "$port" && "$port" -ge "$start_port" && "$port" -le "$end_port" ]]; then
                            configs_to_delete+=("$cname")
                        fi
                    done
                    
                    echo -e "${YELLOW}找到 ${#configs_to_delete[@]} 个配置在指定端口范围内${NC}"
                    
                    # 批量删除操作（优化速度）
                    echo -e "${YELLOW}正在批量删除 ${#configs_to_delete[@]} 个配置...${NC}"
                    
                    # 批量停止服务
                    echo -e "${YELLOW}正在批量停止服务...${NC}"
                    for cname in "${configs_to_delete[@]}"; do
                        systemctl disable --now hysteriaclient@"$cname" >/dev/null 2>&1 || true &
                    done
                    wait  # 等待所有后台任务完成
                    
                    # 批量删除配置文件
                    echo -e "${YELLOW}正在批量删除配置文件...${NC}"
                    for cname in "${configs_to_delete[@]}"; do
                        rm -f "/root/$cname.json" 2>/dev/null || true &
                        rm -f "/var/log/hysteria-client-$cname.log" 2>/dev/null || true &
                    done
                    wait  # 等待所有删除操作完成
                    
                    deleted_count=${#configs_to_delete[@]}
                    
                    if [ $deleted_count -eq 0 ]; then
                        echo -e "${YELLOW}在指定端口范围内没有找到配置${NC}"
                    else
                        echo -e "${GREEN}已删除 $deleted_count 个客户端配置${NC}"
                    fi
                else
                    echo -e "${YELLOW}取消删除操作${NC}"
                fi
            fi
        else
            # 单个配置删除
            if [ -f "/root/$name.json" ]; then
                delete_client_config "$name"
            else
                echo -e "${RED}配置文件 $name 不存在${NC}"
            fi
        fi
    fi
    
    echo
    read -p "按回车键返回..."
}

# 删除单个客户端配置的辅助函数（优化版本）
delete_client_config() {
    local cname="$1"
    local config_file="/root/$cname.json"
    
    if [ -f "$config_file" ]; then
        # 停止并禁用服务（忽略错误）
        systemctl disable --now hysteriaclient@"$cname" >/dev/null 2>&1 || true
        # 删除配置文件（忽略错误）
        rm -f "$config_file" 2>/dev/null || true
        # 删除日志文件（忽略错误）
        rm -f "/var/log/hysteria-client-$cname.log" 2>/dev/null || true
        echo -e "${GREEN}配置文件 $cname 已删除并禁用服务${NC}"
        return 0
    else
        echo -e "${YELLOW}配置文件 $cname 不存在，跳过删除${NC}"
        return 1
    fi
}

# 批量删除客户端配置的辅助函数（新增）
batch_delete_client_configs() {
    local configs=("$@")
    local deleted_count=0
    
    if [ ${#configs[@]} -eq 0 ]; then
        echo -e "${YELLOW}没有配置需要删除${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}正在批量删除 ${#configs[@]} 个配置...${NC}"
    
    # 批量停止服务
    echo -e "${YELLOW}正在批量停止服务...${NC}"
    for cname in "${configs[@]}"; do
        systemctl disable --now hysteriaclient@"$cname" >/dev/null 2>&1 || true &
    done
    wait  # 等待所有后台任务完成
    
    # 批量删除配置文件
    echo -e "${YELLOW}正在批量删除配置文件...${NC}"
    for cname in "${configs[@]}"; do
        rm -f "/root/$cname.json" 2>/dev/null || true &
        rm -f "/var/log/hysteria-client-$cname.log" 2>/dev/null || true &
    done
    wait  # 等待所有删除操作完成
    
    deleted_count=${#configs[@]}
    echo -e "${GREEN}已删除 $deleted_count 个客户端配置${NC}"
    return 0
}

# 展示所有配置
list_configs() {
    echo -e "${YELLOW}可用的配置文件：${NC}"
    local config_count=0
    for cfg in /root/*.json; do
        if [ -f "$cfg" ]; then
            config_count=$((config_count + 1))
            echo -e "${GREEN}${config_count}.${NC} $(basename "$cfg")"
        fi
    done
    echo -e "${YELLOW}总共 ${config_count} 个配置文件${NC}"
}



while true; do
    clear
    echo -e "${GREEN}==== Hysteria Client Systemd 管理 ====${NC}"
    echo "1. 自动注册并启动所有配置到 systemd"
    echo "2. 停止全部客户端"
    echo "3. 重启全部客户端"
    echo "4. 查看所有客户端状态"
    echo "5. 删除单个/全部客户端配置和实例"
    echo "6. 展示所有配置"
    echo "7. 启动剩余未启动的实例"
    echo "0. 退出"
    read -t 60 -p "请选择 [0-7]: " choice || exit 0

    case $choice in
        1) auto_systemd_enable_all ;;
        2) stop_all ;;
        3) restart_all ;;
        4) status_all ;;
        5) delete_config ;;
        6) list_configs ;;
        7) start_remaining_instances ;;
        0) exit ;;
        *) echo -e "${RED}无效选择${NC}" ;;
    esac

    read -n 1 -s -r -p "按任意键继续..."
done
