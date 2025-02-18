# Hysteria 管理脚本

这是一个用于管理 Hysteria 服务端和客户端的 Shell 脚本工具。

## 功能特点

- 支持服务端/客户端一键部署
- 多客户端配置管理
- 服务和客户端状态监控
- 自动依赖检查和安装
- 系统性能优化
- 配置备份和恢复
- 完整的卸载功能

## 系统要求

- 支持 Debian/Ubuntu 或 CentOS/RHEL 系统
- 需要 root 权限
- 基本系统工具 (wget, curl, git)

## 快速开始

1. 下载脚本
```bash
git clone https://github.com/Qiujianm/SPH2.git
cd SPH2
chmod +x *.sh
```

2. 运行脚本
```bash
./main.sh
```

## 使用说明

### 主菜单功能

1. 安装模式：一键部署 Hysteria 服务
2. 服务端管理：管理服务端配置和运行状态
3. 客户端管理：管理多个客户端配置
4. 系统优化：优化系统性能参数
5. 检查更新：更新脚本到最新版本
6. 运行状态：检查服务运行状态
7. 完全卸载：清理所有组件和配置

### 服务端管理

- 启动/停止/重启服务
- 查看服务状态和日志
- 修改服务端配置
- 查看当前配置

### 客户端管理

- 添加新客户端配置
- 查看现有配置
- 删除配置
- 启动/停止/重启客户端
- 查看客户端状态和日志

## 目录结构

```
.
├── main.sh             # 主脚本
├── constants.sh        # 常量定义
├── server_manager.sh   # 服务端管理模块
├── client_manager.sh   # 客户端管理模块
└── start_clients.sh    # 客户端启动脚本
```

## 配置说明

### 服务端配置

位置：/etc/hysteria/config.yaml
```json
{
    "listen": ":443",
    "protocol": "udp",
    "up_mbps": 200,
    "down_mbps": 200
}
```

### 客户端配置

位置：/root/H2/*.json
```json
{
    "server": "server_address:443",
    "protocol": "udp",
    "up_mbps": 200,
    "down_mbps": 200,
    "http": {
        "listen": "127.0.0.1:8080"
    }
}
```

## 注意事项

1. 请确保防火墙放行相应端口
2. 配置文件修改后需要重启相应服务
3. 卸载前建议备份配置文件
4. 每个客户端配置使用独立的本地端口

## 更新日志

- 2024.02.18
  - 优化客户端进程管理
  - 改进配置文件处理
  - 添加状态监控功能

## License

本项目采用 MIT 许可证
