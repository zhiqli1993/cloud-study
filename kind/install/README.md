# Kind 安装/升级脚本

这个目录包含了用于安装和升级 [Kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker) 的跨平台脚本。

## 文件说明

- `install-kind.sh` - Unix/Linux/macOS 通用安装脚本
- `install-kind.bat` - Windows 批处理安装脚本
- `uninstall-kind.sh` - Unix/Linux/macOS 通用卸载脚本
- `uninstall-kind.bat` - Windows 批处理卸载脚本
- `README.md` - 使用说明文档

## 支持的平台

### 操作系统
- Linux (所有主要发行版)
- macOS (Intel 和 Apple Silicon)
- Windows 10/11

### 架构
- AMD64 (x86_64)
- ARM64 (aarch64)
- ARM (armv7l，仅限 Linux)

## 使用方法

### 安装 Kind

#### Unix/Linux/macOS

```bash
# 使脚本可执行
chmod +x install-kind.sh

# 安装最新版本
./install-kind.sh

# 安装指定版本
./install-kind.sh v0.20.0
```

#### Windows

**方法 1: 使用批处理脚本 (推荐)**
```cmd
# 安装最新版本
install-kind.bat

# 安装指定版本
install-kind.bat v0.20.0
```

**方法 2: 使用 Git Bash**
```bash
# 在 Git Bash 中运行 Unix 脚本
chmod +x install-kind.sh
./install-kind.sh
```

### 卸载 Kind

#### Unix/Linux/macOS

```bash
# 使脚本可执行
chmod +x uninstall-kind.sh

# 运行卸载脚本
./uninstall-kind.sh
```

#### Windows

**方法 1: 使用批处理脚本 (推荐)**
```cmd
# 运行卸载脚本
uninstall-kind.bat
```

**方法 2: 使用 Git Bash**
```bash
# 在 Git Bash 中运行 Unix 脚本
chmod +x uninstall-kind.sh
./uninstall-kind.sh
```

### 卸载功能特性

- **交互式卸载**: 每个步骤都会询问用户确认
- **集群清理**: 自动检测并选择性删除现有的 kind 集群
- **Docker 清理**: 清理 kind 创建的 Docker 网络
- **二进制文件删除**: 从系统中移除 kind 可执行文件
- **配置清理**: 选择性删除 kind 配置目录 (`~/.kind`)
- **验证卸载**: 确认卸载是否完成，并提示手动清理剩余资源

## 功能特性

### 自动检测
- 自动检测操作系统和架构
- 自动选择合适的二进制文件

### 版本管理
- 支持安装最新版本或指定版本
- 检查当前已安装版本
- 智能升级（如果版本相同则跳过）

### 安装位置
脚本会按优先级尝试以下安装位置：

**Unix/Linux/macOS:**
1. `/usr/local/bin` (如果有写权限)
2. `$HOME/.local/bin`
3. `$HOME/bin` (如果需要会创建)

**Windows:**
1. `%ProgramFiles%\Git\usr\local\bin` (Git Bash 环境)
2. `%USERPROFILE%\.local\bin`
3. `%USERPROFILE%\bin` (如果需要会创建)

### 验证安装
- 安装后自动验证版本
- 提供 PATH 配置建议（如果需要）

## 依赖要求

### Unix/Linux/macOS
- `bash` shell
- `curl` 或 `wget`
- `uname`
- 基本 Unix 工具 (`grep`, `sed`, `awk`)

### Windows
- `curl` (Windows 10 1803+ 自带)
- 或者使用 Git Bash 环境

## 使用示例

### 安装完成后的基本用法

```bash
# 创建集群
kind create cluster

# 创建命名集群
kind create cluster --name my-cluster

# 列出集群
kind get clusters

# 删除集群
kind delete cluster

# 查看帮助
kind --help
```

### 高级配置

```bash
# 使用配置文件创建集群
kind create cluster --config=cluster-config.yaml

# 指定 Kubernetes 版本
kind create cluster --image kindest/node:v1.27.3

# 导出 kubeconfig
kind export kubeconfig --name my-cluster
```

## 故障排除

### 权限问题
如果遇到权限错误：

**Unix/Linux/macOS:**
```bash
# 使用 sudo 运行（仅当安装到 /usr/local/bin 时需要）
sudo ./install-kind.sh
```

**Windows:**
```cmd
# 以管理员身份运行命令提示符
# 然后运行安装脚本
```

### PATH 配置
如果安装后无法找到 `kind` 命令：

**Unix/Linux/macOS:**
```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Windows:**
1. 打开"系统属性" → "高级" → "环境变量"
2. 在用户变量中编辑 PATH
3. 添加安装目录路径

### 网络问题
如果下载失败：
1. 检查网络连接
2. 确认防火墙设置
3. 可以手动下载并放置到 PATH 中

## 手动安装

如果脚本无法正常工作，可以手动安装：

1. 访问 [Kind Releases](https://github.com/kubernetes-sigs/kind/releases)
2. 下载适合您平台的二进制文件
3. 重命名为 `kind` (Linux/macOS) 或 `kind.exe` (Windows)
4. 移动到 PATH 中的目录
5. 赋予执行权限 (Unix 系统)

## 更多信息

- [Kind 官方文档](https://kind.sigs.k8s.io/)
- [Kind GitHub 仓库](https://github.com/kubernetes-sigs/kind)
- [Kubernetes 官方文档](https://kubernetes.io/docs/)

## 许可证

这些脚本在 MIT 许可证下发布。Kind 本身遵循 Apache 2.0 许可证。
