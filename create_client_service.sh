#!/bin/bash
source /usr/local/SPH2/constants.sh

# 创建客户端服务文件
cat > "$CLIENT_SERVICE_FILE" << EOF
[Unit]
Description=Hysteria Clients Service
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/SPH2/start_clients.sh
ExecStop=/usr/local/SPH2/start_clients.sh stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.default
EOF

# 重载服务
systemctl daemon-reload