# Docker 安装/卸载脚本

这个目录包含了用于安装和卸载 [Docker](https://www.docker.com/) 的跨平台脚本。

## 文件说明

- `install-docker.sh` - Unix/Linux/macOS 通用安装脚本
- `install-docker.bat` - Windows 批处理安装脚本
- `uninstall-docker.sh` - Unix/Linux/macOS 通用卸载脚本
- `uninstall-docker.bat` - Windows 批处理卸载脚本
- `README.md` - 使用说明文档

## 支持的平台

### 操作系统
- **Linux**: Ubuntu, Debian, CentOS, RHEL, Fedora 等主要发行版
- **macOS**: Intel 和 Apple Silicon (M1/M2)
- **Windows**: Windows 10/11 (支持 Docker Desktop)

### 架构
- **AMD64** (x86_64) - 所有平台
- **ARM64** (aarch64) - Linux 和 macOS
- **ARM** (armv7l) - 仅限 Linux

## Docker 版本说明

### Linux
- 安装 **Docker Engine** (Community Edition)
- 包含 Docker CLI、Docker Daemon、containerd
- 支持 Docker Compose Plugin 和 Docker Buildx Plugin

### macOS
- 安装 **Docker Desktop for Mac**
- 通过 Homebrew 进行安装和管理
- 包含完整的 Docker 开发环境

### Windows
- 安装 **Docker Desktop for Windows**
- 支持 WSL2 和 Hyper-V 后端
- 包含完整的 Docker 开发环境

## 使用方法

### 安装 Docker

#### Unix/Linux/macOS

```bash
# 使脚本可执行
chmod +x install-docker.sh

# 运行安装脚本
./install-docker.sh
```

#### Windows

**方法 1: 使用批处理脚本 (推荐)**
```cmd
# 运行安装脚本
install-docker.bat
```

**方法 2: 使用 Git Bash**
```bash
# 在 Git Bash 中运行 Unix 脚本
chmod +x install-docker.sh
./install-docker.sh
```

### 卸载 Docker

#### Unix/Linux/macOS

```bash
# 使脚本可执行
chmod +x uninstall-docker.sh

# 运行卸载脚本
./uninstall-docker.sh
```

#### Windows

**方法 1: 使用批处理脚本 (推荐)**
```cmd
# 运行卸载脚本
uninstall-docker.bat
```

**方法 2: 使用 Git Bash**
```bash
# 在 Git Bash 中运行 Unix 脚本
chmod +x uninstall-docker.sh
./uninstall-docker.sh
```

## 功能特性

### 安装功能

#### 自动检测
- 自动检测操作系统和架构
- 智能选择合适的安装方法
- 检查系统要求和依赖

#### 版本管理
- 安装最新稳定版本
- 检查当前已安装版本
- 智能跳过重复安装

#### 系统集成
- **Linux**: 自动配置 systemd 服务，添加用户到 docker 组
- **macOS**: 通过 Homebrew 管理，与系统集成
- **Windows**: 检查 WSL2/Hyper-V，完整的 Docker Desktop 安装

### 卸载功能

#### 交互式卸载
- 每个步骤都会询问用户确认
- 选择性删除不同类型的数据
- 详细的操作说明和警告

#### 完整清理
- **容器和镜像**: 停止并删除所有容器和镜像
- **数据卷**: 选择性删除数据卷（包含用户数据）
- **网络**: 清理自定义 Docker 网络
- **配置**: 删除 Docker 配置目录
- **系统集成**: 移除服务、用户组等系统集成

#### 验证卸载
- 确认卸载是否完成
- 检查残留进程和文件
- 提供手动清理建议

## 依赖要求

### Unix/Linux/macOS
- `bash` shell (版本 4.0+)
- `curl` 或 `wget` (用于下载)
- `sudo` 权限 (用于系统级安装)
- 基本 Unix 工具 (`grep`, `sed`, `awk`, `uname`)

### macOS 额外要求
- **Homebrew** (会自动提示安装)
- macOS 10.14+ (Mojave 或更高版本)

### Windows 要求
- **Windows 10** 版本 2004 或更高版本
- **Windows 11** (推荐)
- `curl` (Windows 10 1803+ 自带)
- **WSL2** 或 **Hyper-V** (Docker Desktop 要求)

## 系统要求详细说明

### Linux 系统要求
- **内核**: Linux 内核 3.10 或更高版本
- **存储驱动**: 支持 overlay2, aufs, btrfs, zfs, devicemapper
- **内存**: 最少 1GB RAM (推荐 2GB+)
- **磁盘**: 最少 1GB 可用空间

### macOS 系统要求
- **版本**: macOS 10.14 (Mojave) 或更高版本
- **内存**: 最少 4GB RAM (推荐 8GB+)
- **磁盘**: 最少 2GB 可用空间

### Windows 系统要求
- **版本**: Windows 10 版本 2004 (Build 19041) 或更高版本
- **功能**: WSL 2 或 Hyper-V 支持
- **内存**: 最少 4GB RAM (推荐 8GB+)
- **磁盘**: 最少 4GB 可用空间

## 使用示例

### 安装完成后的基本用法

```bash
# 检查 Docker 版本
docker --version

# 显示系统信息
docker info

# 测试 Docker 安装
docker run hello-world

# 运行交互式容器
docker run -it ubuntu bash

# 列出运行中的容器
docker ps

# 列出所有容器
docker ps -a

# 列出镜像
docker images
```

### 高级用法示例

```bash
# 构建自定义镜像
docker build -t myapp .

# 运行带端口映射的容器
docker run -d -p 8080:80 nginx

# 挂载数据卷
docker run -d -v /host/data:/container/data myapp

# 查看容器日志
docker logs container_name

# 进入运行中的容器
docker exec -it container_name bash
```

### Docker Compose 示例

```bash
# 启动多容器应用
docker compose up -d

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs

# 停止服务
docker compose down
```

## 故障排除

### 安装问题

#### Linux 权限问题
```bash
# 如果提示权限不足，使用 sudo
sudo ./install-docker.sh

# 或者添加用户到 docker 组后重新登录
sudo usermod -aG docker $USER
newgrp docker
```

#### macOS Homebrew 问题
```bash
# 如果 Homebrew 未安装，先安装 Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 更新 Homebrew
brew update
```

#### Windows WSL2 问题
```cmd
# 启用 WSL2
wsl --install

# 检查 WSL2 状态
wsl --status

# 更新 WSL2 内核
wsl --update
```

### 运行时问题

#### Docker 守护进程未运行
```bash
# Linux: 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker

# macOS/Windows: 启动 Docker Desktop 应用
```

#### 权限被拒绝错误
```bash
# Linux: 确保用户在 docker 组中
groups $USER | grep docker

# 如果不在，添加到组
sudo usermod -aG docker $USER
newgrp docker
```

#### 网络连接问题
```bash
# 检查网络连接
curl -I https://download.docker.com

# 配置代理（如果需要）
export http_proxy=http://proxy.example.com:8080
export https_proxy=http://proxy.example.com:8080
```

### 卸载问题

#### 残留文件清理
```bash
# 手动清理 Docker 目录 (Linux)
sudo rm -rf /var/lib/docker
sudo rm -rf /etc/docker

# 清理用户配置
rm -rf ~/.docker
```

#### 服务清理
```bash
# Linux: 完全停止和禁用 Docker 服务
sudo systemctl stop docker
sudo systemctl disable docker
sudo systemctl stop containerd
sudo systemctl disable containerd
```

## 安全注意事项

### 用户权限
- Docker 守护进程以 root 权限运行
- docker 组的用户等同于 root 权限
- 在生产环境中谨慎添加用户到 docker 组

### 网络安全
- Docker 默认创建 bridge 网络
- 容器间可以通过网络通信
- 根据需要配置防火墙规则

### 数据安全
- 容器数据默认存储在容器内，删除容器会丢失数据
- 使用数据卷 (volumes) 持久化重要数据
- 定期备份重要的数据卷

## 性能优化建议

### 存储驱动
- **Linux**: 推荐使用 overlay2 存储驱动
- 确保文件系统支持所选存储驱动

### 内存配置
- **Linux**: 根据工作负载调整内存限制
- **macOS/Windows**: 在 Docker Desktop 中配置内存分配

### 日志管理
```bash
# 配置日志驱动和大小限制
docker run --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 myapp
```

## 高级配置

### 自定义 Docker 守护进程配置
```json
// /etc/docker/daemon.json (Linux)
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "dns": ["8.8.8.8", "8.8.4.4"]
}
```

### 启用实验性功能
```json
// /etc/docker/daemon.json
{
  "experimental": true
}
```

### 配置镜像加速器（中国用户）
```json
// /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ]
}
```

## 更多资源

### 官方文档
- [Docker 官方文档](https://docs.docker.com/)
- [Docker Engine 安装](https://docs.docker.com/engine/install/)
- [Docker Desktop](https://docs.docker.com/desktop/)
- [Docker Compose](https://docs.docker.com/compose/)

### 学习资源
- [Docker 官方教程](https://docs.docker.com/get-started/)
- [Docker 实战](https://github.com/docker/labs)
- [最佳实践指南](https://docs.docker.com/develop/dev-best-practices/)

### 社区支持
- [Docker 官方论坛](https://forums.docker.com/)
- [Docker GitHub](https://github.com/docker/docker-ce)
- [Stack Overflow Docker 标签](https://stackoverflow.com/questions/tagged/docker)

## 许可证

这些脚本在 MIT 许可证下发布。Docker 本身遵循 Apache 2.0 许可证。

---

## 更新日志

### v1.0.0 (2024-12-12)
- 初始版本发布
- 支持 Linux、macOS、Windows 三大平台
- 完整的安装和卸载功能
- 交互式用户界面
- 详细的系统检查和验证
