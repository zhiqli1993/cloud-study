# Istio 服务网格学习和实践资源

[![Istio Version](https://img.shields.io/badge/Istio-1.19+-blue.svg)](https://istio.io)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.20+-green.svg)](https://kubernetes.io)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

这是一个完整的 Istio 服务网格学习和实践资源库，包含知识文档、演示应用、配置模板和自动化脚本。

## 📁 目录结构

```
istio/
├── 📚 knowledge/          # Istio 知识库
├── 🎯 demo/              # 官方演示应用
├── 📜 templates/         # 配置模板库
├── 🔧 scripts/           # 安装管理脚本
└── 📖 README.md          # 本文档
```

## 🚀 快速开始

### 1. 安装 Istio
```bash
# Linux/macOS
chmod +x scripts/install-istio.sh
./scripts/install-istio.sh

# Windows
scripts/install-istio.bat
```

### 2. 部署演示应用
```bash
# 启用自动注入
kubectl label namespace default istio-injection=enabled

# 部署 Bookinfo 应用
kubectl apply -f demo/bookinfo/bookinfo.yaml
kubectl apply -f demo/bookinfo/bookinfo-gateway.yaml
```

### 3. 查看服务网格
```bash
# 查看服务状态
kubectl get pods,svc

# 查看 Istio 配置
kubectl get gateway,virtualservice,destinationrule
```

## 📚 知识库 (knowledge/)

完整的 Istio 学习资料，从基础概念到高级实践。

### 📖 学习路径

#### 🎯 初学者路径
1. **[组件概览](knowledge/01-components.md)** - 了解 Istio 核心组件
2. **[架构设计](knowledge/02-architecture.md)** - 理解整体架构
3. **[工作原理](knowledge/03-working-principles.md)** - 深入理解工作机制

#### 🛠️ 运维路径
1. **[可观测性](knowledge/04-observability.md)** - 监控、日志、追踪配置
2. **[配置分析](knowledge/06-config-dump.md)** - 配置调试和分析
3. **[故障排查](knowledge/07-troubleshooting.md)** - 问题诊断和解决

#### ⚡ 优化路径
1. **[性能优化](knowledge/05-optimization.md)** - 全面的性能调优指南
2. **[最佳实践](knowledge/08-best-practices.md)** - 生产环境建议

### 🔍 快速索引

| 主题 | 文档 | 说明 |
|-----|------|------|
| **基础概念** | [01-components.md](knowledge/01-components.md) | 数据平面、控制平面、核心组件 |
| **架构设计** | [02-architecture.md](knowledge/02-architecture.md) | 单集群、多集群、多网格部署 |
| **工作原理** | [03-working-principles.md](knowledge/03-working-principles.md) | Sidecar 模式、xDS 协议、流量管理 |
| **监控告警** | [04-observability.md](knowledge/04-observability.md) | Prometheus、Grafana、Jaeger、Kiali |
| **性能调优** | [05-optimization.md](knowledge/05-optimization.md) | 资源优化、网络性能、扩展性 |
| **配置调试** | [06-config-dump.md](knowledge/06-config-dump.md) | Envoy 配置分析、故障排查 |
| **问题解决** | [07-troubleshooting.md](knowledge/07-troubleshooting.md) | 常见问题、诊断工具、恢复策略 |
| **生产实践** | [08-best-practices.md](knowledge/08-best-practices.md) | 部署策略、安全配置、升级方案 |

## 🎯 演示应用 (demo/)

官方示例应用，用于学习和测试 Istio 功能。

### 📱 应用列表

| 应用 | 描述 | 用途 |
|-----|------|------|
| **[Bookinfo](demo/bookinfo/)** 📚 | 四个微服务组成的图书信息应用 | 流量管理、金丝雀发布、安全策略 |
| **[Httpbin](demo/httpbin/)** 🌐 | HTTP 请求测试服务 | API 测试、策略验证 |
| **[Sleep](demo/sleep/)** 😴 | 客户端测试工具 | 服务连通性测试 |
| **[HelloWorld](demo/helloworld/)** 👋 | 简单的多版本服务 | 版本管理、流量分割 |

### 🔄 常用场景

```bash
# 金丝雀发布 - 10% 流量到新版本
kubectl apply -f templates/virtual-service.yaml

# 基于用户路由 - 特定用户访问新功能
kubectl apply -f templates/virtual-service.yaml

# 故障注入 - 测试服务容错能力
kubectl apply -f templates/virtual-service.yaml

# 安全策略 - 启用 mTLS 认证
kubectl apply -f templates/policy.yaml
```

## 📜 配置模板 (templates/)

生产级别的 Istio 配置模板，覆盖各种使用场景。

### 🏗️ 模板分类

#### 🚦 流量管理
- **[VirtualService](templates/virtual-service.yaml)** - HTTP/TCP 流量路由
- **[DestinationRule](templates/destination-rule.yaml)** - 负载均衡、熔断器
- **[Gateway](templates/gateway.yaml)** - 入口网关配置
- **[ServiceEntry](templates/service-entry.yaml)** - 外部服务集成

#### 🔒 安全策略
- **[Security Policies](templates/policy.yaml)** - mTLS、JWT、RBAC

#### 🔧 高级配置
- **[EnvoyFilter](templates/envoyfilter.yaml)** - 自定义 Envoy 配置
- **[WorkloadEntry](templates/workloadentry.yaml)** - VM 工作负载管理

#### 📊 可观测性
- **[Telemetry](templates/telemetry.yaml)** - 自定义指标和追踪

### 💡 使用示例

```bash
# 应用流量管理配置
kubectl apply -f templates/virtual-service.yaml
kubectl apply -f templates/destination-rule.yaml

# 配置入口网关
kubectl apply -f templates/gateway.yaml

# 启用安全策略
kubectl apply -f templates/policy.yaml

# 配置可观测性
kubectl apply -f templates/telemetry.yaml
```

## 🔧 自动化脚本 (scripts/)

跨平台的 Istio 安装、配置和管理脚本。

### 📦 脚本列表

| 脚本 | 平台 | 功能 |
|-----|------|------|
| `install-istio.sh` | Unix/Linux/macOS | 自动安装 Istio |
| `install-istio.bat` | Windows | 自动安装 Istio |
| `uninstall-istio.sh` | Unix/Linux/macOS | 完全卸载 Istio |
| `uninstall-istio.bat` | Windows | 完全卸载 Istio |

### ⚙️ 特性

- ✅ **多平台支持** - Linux、macOS、Windows
- ✅ **版本管理** - 支持指定版本安装
- ✅ **自动检测** - 操作系统和架构自动识别
- ✅ **集群集成** - 可选择直接安装到 K8s 集群
- ✅ **验证功能** - 安装后自动验证
- ✅ **错误处理** - 完善的错误检查和报告

### 🚀 使用方法

```bash
# 安装最新版本
./scripts/install-istio.sh

# 安装指定版本
./scripts/install-istio.sh v1.20.0

# 使用 demo 配置文件安装
./scripts/install-istio.sh latest demo

# 完全卸载
./scripts/uninstall-istio.sh --purge
```

## 🛠️ 实践场景

### 🎯 流量管理场景

#### 金丝雀发布
```bash
# 1. 部署应用的两个版本
kubectl apply -f demo/bookinfo/bookinfo.yaml

# 2. 配置流量分割 (90% v1, 10% v2)
kubectl apply -f templates/virtual-service.yaml

# 3. 监控指标和错误率
kubectl port-forward -n istio-system svc/grafana 3000:3000
```

#### 基于用户的路由
```bash
# 特定用户访问新功能
kubectl apply -f templates/virtual-service.yaml
```

#### 故障注入测试
```bash
# 注入延迟和错误，测试容错能力
kubectl apply -f templates/virtual-service.yaml
```

### 🔒 安全场景

#### mTLS 双向认证
```bash
# 启用严格 mTLS
kubectl apply -f templates/policy.yaml
```

#### JWT 认证
```bash
# 配置 JWT 令牌验证
kubectl apply -f templates/policy.yaml
```

#### RBAC 授权
```bash
# 基于角色的访问控制
kubectl apply -f templates/policy.yaml
```

### 📊 可观测性场景

#### 监控配置
```bash
# 部署监控组件
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/grafana.yaml

# 访问 Grafana
kubectl port-forward -n istio-system svc/grafana 3000:3000
```

#### 分布式追踪
```bash
# 部署 Jaeger
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/jaeger.yaml

# 访问 Jaeger UI
kubectl port-forward -n istio-system svc/tracing 16686:80
```

#### 服务拓扑
```bash
# 部署 Kiali
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/kiali.yaml

# 访问 Kiali
kubectl port-forward -n istio-system svc/kiali 20001:20001
```

## 📋 前置条件

### 🖥️ 系统要求
- **操作系统**: Linux, macOS, Windows
- **Kubernetes**: 1.20+
- **内存**: 最少 4GB，推荐 8GB+
- **CPU**: 最少 2 核，推荐 4 核+

### 🔧 工具依赖
- `kubectl` - Kubernetes 命令行工具
- `curl` 或 `wget` - 下载工具
- `tar` - 解压工具
- Docker（用于本地开发）

### 🌐 网络要求
- 互联网连接（下载 Istio 和镜像）
- Kubernetes 集群访问权限
- 防火墙配置允许 Istio 端口

## 🚨 故障排查

### 常见问题

#### 安装问题
```bash
# 检查 Istio 状态
istioctl version
kubectl get pods -n istio-system

# 验证安装
istioctl verify-install
```

#### Sidecar 注入问题
```bash
# 检查注入标签
kubectl get ns default --show-labels

# 手动注入
istioctl kube-inject -f app.yaml | kubectl apply -f -
```

#### 服务连通性问题
```bash
# 检查代理状态
istioctl proxy-status

# 分析配置
istioctl analyze

# 查看代理配置
istioctl proxy-config cluster <pod-name>
```

### 诊断工具

```bash
# 配置转储
kubectl exec <pod-name> -c istio-proxy -- curl localhost:15000/config_dump

# 代理日志
kubectl logs <pod-name> -c istio-proxy

# 流量分析
kubectl exec -it deploy/sleep -- curl -v httpbin:8000/get
```

## 📈 性能优化

### 资源配置
```yaml
# Sidecar 资源限制
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

### 网络优化
```yaml
# 连接池配置
connectionPool:
  tcp:
    maxConnections: 100
  http:
    http1MaxPendingRequests: 10
    maxRequestsPerConnection: 2
```

### 监控优化
```yaml
# 采样率配置
sampling: 1.0  # 100% 采样（开发环境）
sampling: 0.1  # 10% 采样（生产环境）
```

## 🏷️ 版本支持

| Istio 版本 | Kubernetes 版本 | 支持状态 |
|-----------|----------------|----------|
| 1.20.x    | 1.25-1.28     | ✅ 当前 |
| 1.19.x    | 1.24-1.28     | ✅ 支持 |
| 1.18.x    | 1.23-1.27     | ⚠️ 维护 |
| 1.17.x    | 1.22-1.26     | ❌ 已停止 |

---

📅 **创建时间**: 2025-06-13  
🔄 **最后更新**: 2025-06-13  
