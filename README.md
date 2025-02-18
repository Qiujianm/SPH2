# SPH2 - Hysteria Management Script

一个用于管理 Hysteria 代理服务的 Shell 脚本集合。

## 功能特点

- 一键安装 Hysteria
- 服务端与客户端管理
- 系统服务集成
- 配置文件管理
- 完整的状态监控

## 快速开始

### 安装

```bash
wget -N --no-check-certificate https://raw.githubusercontent.com/Qiujianm/SPH2/main/setup.sh
bash setup.sh
```

### 使用

安装完成后，使用以下命令启动管理面板：

```bash
h2
```

## 目录结构

```
/usr/local/SPH2/
├── main.sh           # 主程序入口
├── constants.sh      # 常量定义
├── server_manager.sh # 服务端管理
├── client_manager.sh # 客户端管理
└── start_clients.sh  # 客户端启动脚本
```

## 配置文件位置

- 服务端配置：`/etc/hysteria/config.yaml`
- 客户端配置：`/root/H2/*.json`

## 管理面板功能

1. 安装 Hysteria
2. 服务端管理
   - 启动/停止/重启服务
   - 查看状态和日志
   - 查看当前配置
3. 客户端管理
   - 启动/停止/重启客户端
   - 查看状态和日志
   - 管理客户端配置
4. 系统优化
5. 检查更新
6. 运行状态查看
7. 完全卸载

## 系统要求

- 操作系统：支持 systemd 的 Linux 系统
- 依赖：curl、wget
- 权限：需要 root 权限

## 服务管理

### 服务端

```bash
systemctl start hysteria-server   # 启动服务端
systemctl stop hysteria-server    # 停止服务端
systemctl restart hysteria-server # 重启服务端
systemctl status hysteria-server  # 查看状态
```

### 客户端

```bash
systemctl start clients   # 启动所有客户端
systemctl stop clients    # 停止所有客户端
systemctl restart clients # 重启所有客户端
systemctl status clients  # 查看状态
```

## 卸载

通过管理面板选择"完全卸载"选项，或直接运行：

```bash
h2
# 选择选项 7 进行卸载
```

## 注意事项

1. 首次安装后需要配置服务端和客户端的配置文件
2. 所有操作需要 root 权限
3. 确保系统支持 systemd
4. 配置文件修改后需要重启相应的服务

## 许可证

[MIT License](LICENSE)