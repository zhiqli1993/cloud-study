# Docker 配置和安装指南

本目录包含Docker安装、配置和镜像源设置的相关文档和脚本。

## 📁 目录结构

```
docker/
├── README.md                          # 本文档
└── scripts/                          # Docker脚本目录
    ├── README.md                     # 安装脚本详细说明
    ├── install-docker.sh            # Linux Docker安装脚本
    ├── install-docker.bat           # Windows Docker安装脚本
    ├── uninstall-docker.sh          # Linux Docker卸载脚本
    ├── uninstall-docker.bat         # Windows Docker卸载脚本
    ├── configure-docker-mirrors.sh   # Linux自动配置脚本
    ├── configure-docker-mirrors.bat  # Windows自动配置脚本
    └── DOCKER-MIRROR-CONFIG.md       # Docker国内镜像源详细配置指南
```

## 🚀 快速开始

### 1. 安装 Docker

#### Linux/macOS 系统
```bash
# 进入脚本目录
cd docker/scripts

# 使脚本可执行并运行安装
chmod +x install-docker.sh
./install-docker.sh
```

#### Windows 系统
```cmd
# 进入脚本目录
cd docker\scripts

# 运行安装脚本（以管理员身份）
install-docker.bat
```

### 2. 配置国内镜像源

#### Linux 系统
```bash
# 进入脚本目录
cd docker/scripts

# 使用自动配置脚本
chmod +x configure-docker-mirrors.sh
./configure-docker-mirrors.sh

# 配置并测试
./configure-docker-mirrors.sh -t

# 仅验证当前配置
./configure-docker-mirrors.sh -v
```

#### Windows 系统
```cmd
# 进入脚本目录
cd docker\scripts

# 以管理员身份运行
configure-docker-mirrors.bat
```

### 3. 手动配置镜像源

详细的手动配置步骤请参考 [scripts/DOCKER-MIRROR-CONFIG.md](scripts/DOCKER-MIRROR-CONFIG.md)

## 📋 推荐的国内镜像源

| 镜像源 | URL | 提供商 | 特点 |
|--------|-----|--------|------|
| Azure中国 | `https://dockerhub.azk8s.cn` | Microsoft | 🔸 稳定可靠 |
| 中科大 | `https://docker.mirrors.ustc.edu.cn` | USTC | 🔸 教育网优化 |
| 网易 | `https://hub-mirror.c.163.com` | NetEase | 🔸 速度较快 |
| 百度云 | `https://mirror.baidubce.com` | Baidu | 🔸 国内优化 |

## 🔧 Docker 安装/卸载脚本

### 支持的平台

#### 操作系统
- **Linux**: Ubuntu, Debian, CentOS, RHEL, Fedora 等主要发行版
- **macOS**: Intel 和 Apple Silicon (M1/M2)
- **Windows**: Windows 10/11 (支持 Docker Desktop)

#### 架构
- **AMD64** (x86_64) - 所有平台
- **ARM64** (aarch64) - Linux 和 macOS
- **ARM** (armv7l) - 仅限 Linux

### Docker 版本说明

#### Linux
- 安装 **Docker Engine** (Community Edition)
- 包含 Docker CLI、Docker Daemon、containerd
- 支持 Docker Compose Plugin 和 Docker Buildx Plugin

#### macOS
- 安装 **Docker Desktop for Mac**
- 通过 Homebrew 进行安装和管理
- 包含完整的 Docker 开发环境

#### Windows
- 安装 **Docker Desktop for Windows**
- 支持 WSL2 和 Hyper-V 后端
- 包含完整的 Docker 开发环境

### 卸载 Docker

#### Linux/macOS

```bash
# 进入脚本目录
cd docker/scripts

# 使脚本可执行
chmod +x uninstall-docker.sh

# 运行卸载脚本
./uninstall-docker.sh
```

#### Windows

```cmd
# 进入脚本目录
cd docker\scripts

# 运行卸载脚本
uninstall-docker.bat
```

## ⚡ 快速验证

安装和配置完成后，使用以下命令验证：

```bash
# 查看Docker版本
docker --version

# 查看镜像源配置
docker info | grep -A 5 "Registry Mirrors"

# 测试镜像拉取速度
time docker pull hello-world

# 测试Docker运行
docker run hello-world

# 清理并重新测试
docker image prune -a
docker pull nginx:latest
```

## 🔧 配置示例

### 基本配置 (`/etc/docker/daemon.json`)
```json
{
  "registry-mirrors": [
    "https://dockerhub.azk8s.cn",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
```

### 完整配置
```json
{
  "registry-mirrors": [
    "https://dockerhub.azk8s.cn",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ],
  "insecure-registries": [
    "localhost:5000"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "max-concurrent-downloads": 10
}
```

## 🐛 故障排除

### 常见问题

1. **镜像源不可用**
   ```bash
   # 测试镜像源连通性
   curl -I https://dockerhub.azk8s.cn/v2/
   ```

2. **配置不生效**
   ```bash
   # 重启Docker服务
   sudo systemctl restart docker
   
   # 检查配置语法
   python3 -m json.tool /etc/docker/daemon.json
   ```

3. **权限问题**
   ```bash
   # 修复配置文件权限
   sudo chown root:root /etc/docker/daemon.json
   sudo chmod 644 /etc/docker/daemon.json
   
   # 添加用户到docker组
   sudo usermod -aG docker $USER
   newgrp docker
   ```

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

### 日志检查
```bash
# 查看Docker服务日志
sudo journalctl -u docker.service -f

# 查看Docker信息
docker info
```

## 💡 使用示例

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

## 🛡️ 安全注意事项

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

## 🔗 相关链接

- [Docker 官方文档](https://docs.docker.com/)
- [Docker Hub](https://hub.docker.com/)
- [Docker Engine 安装](https://docs.docker.com/engine/install/)
- [Docker Desktop](https://docs.docker.com/desktop/)
- [Docker Compose](https://docs.docker.com/compose/)
- [containerd 配置](https://github.com/containerd/containerd/blob/main/docs/cri/config.md)

## 📖 详细文档

如需了解更详细的安装步骤、配置选项和故障排除方法，请查看：
- [scripts/README.md](scripts/README.md) - 详细的安装/卸载脚本说明
- [scripts/DOCKER-MIRROR-CONFIG.md](scripts/DOCKER-MIRROR-CONFIG.md) - 详细的镜像源配置指南

## 📄 许可证

本项目遵循 MIT 许可证。

---

**维护者**: Cloud Study Team  
**最后更新**: 2024年12月
