# Cloud Study 云原生学习项目

本项目是一个全面的云原生技术学习和实践资源库，包含 Kubernetes、服务网格、容器镜像代理等核心组件的配置、安装脚本和最佳实践。

## 📁 项目结构

```
cloud-study/
├── README.md                          # 项目主文档
├── containerd-config-patch.toml       # Containerd 配置补丁
├── kind/                              # Kind (Kubernetes in Docker) 相关配置
│   ├── install/                       # Kind 安装脚本
│   └── templates/                     # Kind 集群配置模板
├── istio/                             # Istio 服务网格相关配置
│   └── install/                       # Istio 安装脚本
└── docker-registry-proxy/             # Docker 镜像仓库代理配置
    ├── configs/                       # 代理配置文件
    ├── manifests/                     # Kubernetes 清单文件
    ├── scripts/                       # 部署脚本
    └── examples/                      # 使用示例
```

## 🚀 快速开始

### 前置条件

- Docker Desktop 或 Docker Engine
- Git（用于克隆项目）
- 基本的命令行操作知识

### 基本工作流程

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd cloud-study
   ```

2. **安装 Kind（推荐首选）**
   ```bash
   # Linux/macOS
   cd kind/install && chmod +x install-kind.sh && ./install-kind.sh
   
   # Windows
   cd kind/install && install-kind.bat
   ```

3. **创建 Kubernetes 集群**
   ```bash
   # 使用单节点模板（推荐学习使用）
   kind create cluster --config=kind/templates/kind-single-node.yaml
   
   # 或使用完整功能模板
   kind create cluster --config=kind/templates/kind-config.yaml
   ```

4. **验证集群**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

## 📦 组件详解

### 1. Kind (Kubernetes in Docker)

**目的**: 在本地快速创建 Kubernetes 集群用于学习和开发

**主要特性**:
- 🌍 **预配置国内镜像源** - 解决国内网络访问问题
- 🏗️ **多种集群模板** - 适用不同学习场景
- ⚡ **快速部署** - 几分钟内创建完整集群
- 🔧 **跨平台支持** - Linux、macOS、Windows

**可用模板**:
- `kind-single-node.yaml` - 单节点集群（学习推荐）
- `kind-config.yaml` - 完整功能集群
- `kind-multi-master.yaml` - 高可用集群
- `kind-ingress-ready.yaml` - Ingress 就绪集群

**详细文档**: [kind/templates/README.md](kind/templates/README.md)

### 2. Istio 服务网格

**目的**: 提供微服务间的流量管理、安全、可观测性

**主要特性**:
- 📊 **流量管理** - 路由、负载均衡、熔断
- 🔒 **安全策略** - mTLS、访问控制
- 📈 **可观测性** - 指标、日志、链路追踪
- 🌐 **跨平台安装** - 自动化安装脚本

**快速安装**:
```bash
# Linux/macOS
cd istio/install && chmod +x install-istio.sh && ./install-istio.sh

# Windows  
cd istio/install && install-istio.bat
```

**详细文档**: [istio/install/README.md](istio/install/README.md)

### 3. Docker Registry 代理

**目的**: 解决容器镜像拉取的网络和权限问题

**主要特性**:
- 🚀 **镜像加速** - 配置国内镜像加速器
- 🏢 **企业代理** - 支持企业网络代理
- 🔐 **私有仓库** - 私有镜像仓库访问配置
- 🔄 **本地缓存** - 本地镜像仓库集成

**支持场景**:
- HTTP/HTTPS 代理访问外部仓库
- 私有 Registry 认证配置
- 镜像加速器配置
- Kind 集群本地 Registry 集成

**详细文档**: [docker-registry-proxy/README.md](docker-registry-proxy/README.md)

## 🎯 学习路径推荐

### 初学者路径

1. **容器基础** ➜ 理解 Docker 容器概念
2. **Kind 集群** ➜ 创建第一个 Kubernetes 集群
3. **基础操作** ➜ 学习 kubectl 基本命令
4. **应用部署** ➜ 部署第一个应用到集群

### 进阶路径

1. **网络配置** ➜ 配置 Ingress 和服务发现
2. **存储管理** ➜ 持久化存储和 ConfigMap
3. **服务网格** ➜ 安装配置 Istio
4. **可观测性** ➜ 监控、日志、链路追踪

### 实战路径

1. **多集群管理** ➜ 高可用集群配置
2. **CI/CD 集成** ➜ 持续集成和部署
3. **安全最佳实践** ➜ RBAC、网络策略、镜像安全
4. **生产就绪** ➜ 监控告警、备份恢复

## 🛠️ 常用命令

### Kind 集群管理
```bash
# 列出集群
kind get clusters

# 删除集群
kind delete cluster --name=<集群名称>

# 加载镜像到集群
kind load docker-image <镜像名称>

# 导出集群配置
kind get kubeconfig --name=<集群名称>
```

### Kubernetes 基础操作
```bash
# 查看集群信息
kubectl cluster-info
kubectl get nodes

# 查看 Pod 状态
kubectl get pods --all-namespaces

# 查看服务
kubectl get services

# 查看详细信息
kubectl describe pod <pod-name>
```

### Istio 管理
```bash
# 检查 Istio 版本
istioctl version

# 验证安装
istioctl verify-install

# 分析配置
istioctl analyze

# 查看代理状态
istioctl proxy-status
```

## 🔧 故障排除

### 常见问题

1. **镜像拉取失败**
   - 检查网络连接
   - 使用配置的镜像加速器
   - 参考 [docker-registry-proxy](docker-registry-proxy/) 配置

2. **集群创建失败**
   - 确保 Docker 正在运行
   - 检查端口占用情况
   - 查看 Kind 日志：`kind export logs`

3. **kubectl 连接失败**
   - 检查 kubeconfig 配置
   - 验证集群状态：`kind get clusters`

### 获取帮助

- **Kubernetes 官方文档**: https://kubernetes.io/docs/
- **Kind 文档**: https://kind.sigs.k8s.io/
- **Istio 文档**: https://istio.io/latest/docs/
- **Docker 文档**: https://docs.docker.com/

## 🌟 最佳实践

### 开发环境配置
- 使用单节点 Kind 集群节省资源
- 配置本地镜像仓库加速开发
- 启用 Ingress 支持本地访问

### 学习建议
- 从基础概念开始，逐步深入
- 动手实践每个配置选项
- 阅读官方文档理解原理
- 参与社区讨论交流经验

### 安全考虑
- 定期更新组件版本
- 不在生产环境使用测试配置
- 正确配置网络策略和访问控制
- 监控集群安全状态

## 📊 项目状态

- ✅ Kind 集群模板（包含国内镜像源配置）
- ✅ Istio 跨平台安装脚本
- ✅ Docker Registry 代理配置
- ✅ 完整的文档和使用示例
- 🚧 持续更新和优化中

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. **Fork 项目**
2. **创建特性分支**: `git checkout -b feature/your-feature`
3. **提交更改**: `git commit -am 'Add some feature'`
4. **推送分支**: `git push origin feature/your-feature`
5. **创建 Pull Request**

### 贡献类型
- 🐛 Bug 修复
- ✨ 新功能添加
- 📚 文档改进
- 🎨 代码优化
- 🧪 测试用例

## 📝 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 📞 联系方式

如有问题或建议，请通过以下方式联系：

- 📧 提交 Issue
- 💬 参与 Discussions
- 🔀 提交 Pull Request

---

**祝您云原生学习之旅愉快！** 🎉

> 💡 **提示**: 建议从 Kind 单节点集群开始，逐步探索更复杂的配置和场景。
