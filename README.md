# Hysteria2 一键管理脚本

## 项目介绍
一个用于快速部署和管理 Hysteria2 的 Shell 脚本工具。支持全自动安装、多客户端配置管理、服务状态监控等功能。

## 系统要求
- 支持的系统：CentOS 7+、Ubuntu 16+、Debian 9+
- 需要 root 权限
- 需要 curl 或 wget

## 快速开始
### 一键安装
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Qiujianm/SPH2/main/setup.sh)
```
或
```bash
wget -O /root/setup.sh https://raw.githubusercontent.com/Qiujianm/SPH2/main/setup.sh && chmod +x /root/setup.sh && cd /root && bash setup.sh
```

### 使用方法
安装完成后，输入以下命令进入管理面板：
```bash
h2
```

## 功能特点
- [x] 全自动/手动配置生成
- [x] 服务端完整管理（启动/停止/重启/状态）
- [x] 多客户端配置管理
- [x] SOCKS5 代理支持（0.0.0.0 监听）
- [x] 自动优化系统参数
- [x] 多镜像源支持
- [x] 完整的服务状态监控
- [x] 安全的证书管理

## 配置说明
### 服务端配置
- 配置文件：`/etc/hysteria/config.yaml`
- 证书文件：
  - 私钥：`/etc/hysteria/server.key`
  - 证书：`/etc/hysteria/server.crt`

### 客户端配置
- 配置目录：`/root/H2/`
- 配置格式：`client_[端口]_[SOCKS5端口].json`

## 目录结构
```
/root/
├── setup.sh      # 安装脚本
├── main.sh       # 主菜单
├── server.sh     # 服务端管理
├── client.sh     # 客户端管理
└── config.sh     # 配置工具

/root/H2/         # 客户端配置目录
└── client_*.json # 客户端配置文件

/etc/hysteria/    # 服务端配置目录
├── config.yaml   # 服务端配置
├── server.key    # 服务器私钥
└── server.crt    # 服务器证书
```

## 常见问题
1. **安装失败？**
   - 检查系统是否支持
   - 确保有足够的权限
   - 尝试更换安装源

2. **无法启动服务？**
   - 检查端口是否被占用
   - 查看系统日志
   - 确认配置文件正确

3. **客户端连接失败？**
   - 确认服务端正常运行
   - 检查防火墙设置
   - 验证配置参数

## 更新记录
### 2025-02-19
- 优化 SOCKS5 配置
- 完善服务管理功能
- 增加多镜像源支持
- 改进系统清理功能
- 增强错误处理机制

## 关于作者
- 作者：@Qiujianm
- 项目地址：[SPH2](https://github.com/Qiujianm/SPH2)

## 许可证
MIT License

## 鸣谢
- [Hysteria](https://github.com/apernet/hysteria)
- 所有贡献者和用户

## 免责声明
本脚本仅供学习和研究使用，请遵守当地法律法规。使用本脚本所产生的任何后果由使用者自行承担。