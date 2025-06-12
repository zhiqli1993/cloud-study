# Istio 安装脚本

本目录包含跨平台的 Istio 服务网格安装和卸载脚本。

## 文件列表

- `install-istio.sh` - Unix/Linux/macOS 安装脚本
- `install-istio.bat` - Windows 安装脚本  
- `uninstall-istio.sh` - Unix/Linux/macOS 卸载脚本
- `uninstall-istio.bat` - Windows 卸载脚本
- `README.md` - 本文档文件

## 特性

- **多平台支持**: 支持 Linux、macOS 和 Windows
- **自动平台检测**: 自动检测操作系统和架构
- **版本管理**: 安装最新版本或指定特定版本
- **集群集成**: 可选择直接安装 Istio 到 Kubernetes 集群
- **验证功能**: 自动验证安装结果
- **交互式提示**: 用户友好的安装过程
- **错误处理**: 全面的错误检查和报告

## 前置条件

### 所有平台
- 互联网连接（用于下载 Istio）
- `curl` 或 `wget`（用于下载）
- `tar`（用于解压缩归档文件）

### Kubernetes 集群安装
- 已安装并配置 `kubectl`
- 可访问 Kubernetes 集群
- 具有安装集群级资源的适当权限

## 安装

### Unix/Linux/macOS

```bash
# 使脚本可执行
chmod +x install-istio.sh

# 安装最新版本
./install-istio.sh

# 安装指定版本
./install-istio.sh v1.20.0

# 使用指定配置文件安装
./install-istio.sh latest demo
```

### Windows

```cmd
# 运行批处理脚本
install-istio.bat

# 安装指定版本
install-istio.bat v1.20.0

# 使用指定配置文件安装
install-istio.bat latest demo
```

### 安装脚本功能

1. **平台检测**: 自动检测操作系统和架构
2. **版本管理**: 获取最新版本或使用指定版本
3. **下载**: 下载适合您平台的 Istio 发行版
4. **安装**: 解压并安装 `istioctl` 到 PATH 中的合适目录
5. **验证**: 验证安装是否成功
6. **集群安装**（可选）: 提供安装 Istio 到 Kubernetes 集群的选项
7. **配置**: 为默认命名空间设置自动边车注入
8. **使用示例**: 提供有用的使用示例

## 卸载

### Unix/Linux/macOS

```bash
# 使脚本可执行
chmod +x uninstall-istio.sh

# 标准卸载
./uninstall-istio.sh

# 完全移除（清除模式）
./uninstall-istio.sh --purge
```

### Windows

```cmd
# 标准卸载
uninstall-istio.bat

# 完全移除（清除模式）
uninstall-istio.bat --purge
```

### 卸载脚本功能

1. **集群清理**: 从 Kubernetes 集群中移除 Istio
2. **标签移除**: 移除命名空间的 istio-injection 标签
3. **二进制文件移除**: 从系统中移除 istioctl 二进制文件
4. **配置清理**: 移除 Istio 配置目录（清除模式下）
5. **CRD 清理**: 移除 Istio 自定义资源定义（清除模式下）

## 安装目录

脚本将按以下顺序查找第一个可写目录来安装 `istioctl`：

### Unix/Linux/macOS
1. `/usr/local/bin`（如果可写）
2. `$HOME/.local/bin`
3. `$HOME/bin`

### Windows
1. `%ProgramFiles%\Git\usr\local\bin`（如果安装了 Git Bash）
2. `%USERPROFILE%\.local\bin`
3. `%USERPROFILE%\bin`

如果选择的目录不在您的 PATH 中，脚本会发出警告并提供说明。

## 支持的平台

### 操作系统
- Linux（x86_64、ARM64、ARMv7）
- macOS（x86_64、ARM64）
- Windows（x86_64、ARM64）

### 架构
- `amd64`（x86_64）
- `arm64`（ARM64/AArch64）
- `armv7`（ARMv7 - 仅限 Linux）

## 使用示例

安装后，您可以使用 `istioctl` 执行各种任务：

### 基本命令
```bash
# 显示版本信息
istioctl version

# 安装 Istio 到集群
istioctl install --set values.defaultRevision=default -y

# 从集群卸载 Istio
istioctl uninstall --purge -y

# 验证 Istio 安装
istioctl verify-install
```

### 配置管理
```bash
# 显示集群配置
istioctl proxy-config cluster <pod-name>

# 显示代理状态
istioctl proxy-status

# 分析配置问题
istioctl analyze
```

### 流量管理
```bash
# 启用自动边车注入
kubectl label namespace default istio-injection=enabled

# 部署带边车的应用程序
kubectl apply -f your-app.yaml
```

## 故障排除

### 常见问题

1. **权限被拒绝**: 在 Unix/Linux 系统上使用 `sudo` 运行脚本，或在 Windows 上以管理员身份运行
2. **找不到命令**: 确保安装目录在您的 PATH 中
3. **下载失败**: 检查您的互联网连接和防火墙设置
4. **集群连接失败**: 验证您的 `kubectl` 配置

### 手动安装

如果自动脚本失败，您可以手动安装：

1. 从 [Istio 发行版](https://github.com/istio/istio/releases) 下载适当的发行版
2. 解压缩归档文件
3. 将 `istioctl` 复制到 PATH 中的目录
4. 使其可执行（仅限 Unix/Linux/macOS）：`chmod +x istioctl`

### 获取帮助

- **Istio 文档**: https://istio.io/latest/docs/
- **Istio GitHub**: https://github.com/istio/istio
- **Istio 社区**: https://istio.io/latest/about/community/

## 脚本选项

### 安装脚本

| 选项 | 描述 |
|------|------|
| `[version]` | 指定 Istio 版本（默认：latest） |
| `[profile]` | 指定安装配置文件（默认：default） |

### 卸载脚本

| 选项 | 描述 |
|------|------|
| `--purge` | 完全移除，包括 CRD 和配置 |

## 安全注意事项

- 脚本从官方 Istio GitHub 发行版下载
- 不会自动验证校验和（生产环境建议手动验证）
- 脚本可能需要提升权限才能安装
- 在生产环境中运行前请检查脚本

## 贡献

改进这些脚本：

1. 在您的平台上测试
2. 报告问题或建议改进
3. 遵循现有代码风格和模式
4. 确保在所有支持的平台上兼容

## 版本兼容性

这些脚本设计用于：
- Istio 1.10+
- Kubernetes 1.20+
- curl、wget 和 tar 的最新版本

## 许可证

这些脚本按原样提供，用于教育和运营目的。有关 Istio 特定条款，请参考 Istio 项目许可证。
