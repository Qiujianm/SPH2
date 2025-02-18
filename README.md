# SPH2

这是一个用于管理 Hysteria 服务的脚本集合。该集合包含了安装、配置、启动、停止和管理 Hysteria 服务的脚本。

## 目录结构

- `constants.sh` - 包含全局变量和颜色定义。
- `install.sh` - 用于安装 Hysteria 和相关依赖的脚本。
- `server_manager.sh` - 用于管理 Hysteria 服务端的脚本。
- `client_manager.sh` - 用于管理 Hysteria 客户端的脚本。
- `start_clients.sh` - 启动所有客户端配置的脚本。
- `main.sh` - 主管理面板脚本，提供用户交互界面。

## 安装

1. 克隆仓库到本地：

    ```bash
    git clone https://github.com/Qiujianm/SPH2.git
    cd SPH2
    ```

2. 运行安装脚本：

    ```bash
    chmod +x install.sh
    ./install.sh
    ```

## 使用说明

安装完成后，使用以下命令启动管理脚本：

```bash
h2
```

### 主菜单

- `1. 安装 Hysteria` - 安装 Hysteria 服务。
- `2. 服务端管理` - 进入服务端管理菜单。
- `3. 客户端配置管理` - 进入客户端配置管理菜单。
- `4. 系统优化` - 优化系统配置。
- `5. 检查更新` - 检查脚本和服务更新。
- `6. 运行状态` - 查看服务运行状态。
- `7. 完全卸载` - 卸载 Hysteria 服务和配置。
- `0. 退出` - 退出脚本。

### 服务端管理菜单

- `1. 启动服务端` - 启动 Hysteria 服务端。
- `2. 停止服务端` - 停止 Hysteria 服务端。
- `3. 重启服务端` - 重启 Hysteria 服务端。
- `4. 查看服务端状态` - 查看服务端运行状态。
- `5. 查看服务端日志` - 查看服务端日志。
- `6. 全自动生成配置` - 自动生成服务端配置。
- `7. 手动生成配置` - 手动生成服务端配置。
- `8. 查看当前配置` - 查看当前服务端配置。
- `0. 返回主菜单` - 返回主菜单。

### 客户端配置管理菜单

- `1. 启动客户端` - 启动 Hysteria 客户端。
- `2. 停止客户端` - 停止 Hysteria 客户端。
- `3. 重启客户端` - 重启 Hysteria 客户端。
- `4. 查看客户端状态` - 查看客户端运行状态。
- `5. 查看客户端日志` - 查看客户端日志。
- `6. 添加客户端配置` - 添加新的客户端配置。
- `0. 返回主菜单` - 返回主菜单。

## 注意

请确保在安装和运行脚本时使用 root 用户权限。

## 许可证

MIT License. 请参阅 LICENSE 文件以获取更多信息。
```` ▋