# Kind 配置模板

本目录包含多种 Kind（Kubernetes in Docker）配置模板，适用于不同的使用场景。

## 镜像源配置 🚀

**重要提示**: 所有模板都已预配置国内镜像源，以提高在中国大陆地区的镜像拉取速度！

所有配置文件都包含以下国内镜像源：
- **Docker Hub**: Azure 中国、中科大、网易、Docker 中国官方源
- **Kubernetes**: Azure 中国 K8s、阿里云 K8s 镜像源  
- **GCR**: Azure 中国 GCR、阿里云镜像源
- **Quay.io**: Azure 中国 Quay、七牛云 Quay 镜像源

详细配置说明请参考：[MIRROR-CONFIG.md](./MIRROR-CONFIG.md)

## 可用模板

### 1. `kind-config.yaml` - 综合配置模板
**使用场景**: 功能完整的集群，包含详细配置选项
- 多节点集群（1个控制平面 + 1个工作节点，可选第二个工作节点）
- 完整的网络配置
- 广泛的端口映射
- 功能开关和运行时配置
- 详细的文档和示例
- **✅ 已配置国内镜像源**

```bash
kind create cluster --config=kind-config.yaml
```

### 2. `kind-single-node.yaml` - 单节点集群
**使用场景**: 开发、测试和学习
- 单一控制平面节点（无工作节点）
- 最小资源使用
- 服务的基本端口映射
- 支持 Ingress 的配置
- **✅ 已配置国内镜像源**

```bash
kind create cluster --config=kind-single-node.yaml
```

### 3. `kind-multi-master.yaml` - 高可用集群
**使用场景**: 类生产环境测试和高可用场景
- 3个控制平面节点实现高可用
- 3个工作节点分布工作负载
- 面向生产的配置
- 增强的安全设置
- **✅ 已配置国内镜像源**

```bash
kind create cluster --config=kind-multi-master.yaml
```

### 4. `kind-ingress-ready.yaml` - Ingress 优化集群
**使用场景**: 需要 Ingress 控制器的应用
- 预配置的 HTTP/HTTPS 端口映射
- Ingress 就绪的标签和配置
- NGINX Ingress 详细安装说明
- 支持多种 Ingress 控制器
- **✅ 已配置国内镜像源**

```bash
kind create cluster --config=kind-ingress-ready.yaml
```

## 快速开始指南

### 前置条件
- 安装并运行 Docker
- 安装 Kind（[安装指南](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)）
- 安装 kubectl

### 基本使用
1. 根据使用场景选择合适的模板
2. 创建集群：
   ```bash
   kind create cluster --config=templates/<模板名称>.yaml
   ```
3. 验证集群：
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

### 常用命令

```bash
# 列出所有集群
kind get clusters

# 删除集群
kind delete cluster --name=<集群名称>

# 导出集群日志
kind export logs /tmp/kind-logs --name=<集群名称>

# 将 Docker 镜像加载到集群
kind load docker-image <镜像名称> --name=<集群名称>

# 获取 kubeconfig
kind get kubeconfig --name=<集群名称>
```

## 配置选项说明

### 网络配置
- **apiServerPort**: Kubernetes API 服务器端口（默认：随机）
- **serviceSubnet**: Kubernetes 服务的 IP 范围
- **podSubnet**: Pod 的 IP 范围
- **disableDefaultCNI**: 设置为 true 以使用自定义 CNI
- **kubeProxyMode**: iptables 或 ipvs 模式

### 节点配置
- **role**: control-plane 或 worker
- **image**: Kubernetes 节点镜像版本
- **extraPortMappings**: 将容器端口映射到主机端口
- **extraMounts**: 将主机目录挂载到容器
- **labels**: 节点的 Kubernetes 标签

### 高级功能
- **featureGates**: 启用/禁用 Kubernetes 功能
- **kubeadmConfigPatches**: 自定义 kubeadm 配置
- **runtimeConfig**: 配置 API 服务器运行时

## 故障排除

### 常见问题

1. **端口已被占用**
   ```bash
   # 检查端口是否被占用
   netstat -an | grep :80
   # 在配置中更改 hostPort
   ```

2. **Docker 未运行**
   ```bash
   # 检查 Docker 状态
   docker ps
   # 如需要，启动 Docker
   ```

3. **镜像拉取问题**
   ```bash
   # 预先拉取镜像
   docker pull kindest/node:v1.28.0
   ```

### 调试命令

```bash
# 检查集群状态
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# 查看集群事件
kubectl get events --sort-by=.metadata.creationTimestamp

# 检查 Docker 容器
docker ps | grep kind

# SSH 进入节点
docker exec -it <节点名称> bash
```

## 自定义指南

### 创建自定义模板

1. **从基础模板开始**: 复制 `kind-config.yaml` 作为起点
2. **根据使用场景修改**: 调整节点、网络和功能
3. **测试配置**: 创建并验证集群
4. **记录更改**: 添加注释说明自定义内容

### 最佳实践

- 使用特定的镜像版本以保证可重现性
- 为应用程序包含必要的端口映射
- 为节点选择添加适当的标签
- 为系统组件配置资源预留
- 在生产使用前测试配置

## 集成示例

### 与 Ingress 控制器集成
```bash
# 创建支持 ingress 的集群
kind create cluster --config=kind-ingress-ready.yaml

# 安装 NGINX ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

### 与本地镜像仓库集成
```bash
# 创建仓库
docker run -d --restart=always -p 5000:5000 --name registry registry:2

# 连接到 Kind
docker network connect kind registry

# 在集群中使用
docker tag myapp:latest localhost:5000/myapp:latest
docker push localhost:5000/myapp:latest
kind load docker-image localhost:5000/myapp:latest
```

### 与 Helm 集成
```bash
# 安装 Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 添加仓库
helm repo add stable https://charts.helm.sh/stable
helm repo update

# 安装应用
helm install my-app stable/nginx-ingress
```

## 版本兼容性

| Kind 版本 | Kubernetes 版本 | 模板兼容性 |
|-----------|----------------|-----------|
| v0.20.x   | v1.28.x        | 所有模板   |
| v0.19.x   | v1.27.x        | 所有模板   |
| v0.18.x   | v1.26.x        | 仅基本功能 |

## 贡献指南

添加新模板时：
1. 遵循现有命名约定
2. 包含全面的文档
3. 在多种场景下测试
4. 更新此 README
5. 添加使用示例

## 参考资料

- [Kind 官方文档](https://kind.sigs.k8s.io/)
- [Kubernetes 官方文档](https://kubernetes.io/docs/)
- [Kind 配置参考](https://kind.sigs.k8s.io/docs/user/configuration/)

## 使用建议

### 选择合适的模板
- **学习和开发**: 使用 `kind-single-node.yaml`
- **测试应用程序**: 使用 `kind-config.yaml`
- **测试高可用性**: 使用 `kind-multi-master.yaml`
- **测试 Ingress**: 使用 `kind-ingress-ready.yaml`

### 性能优化
- 单节点集群适合资源有限的环境
- 多节点集群更接近真实的生产环境
- 根据需要调整资源预留设置

### 安全考虑
- 生产测试时启用审计日志
- 配置适当的准入控制器
- 使用网络策略限制 Pod 间通信

### 监控和日志
- 使用 `kind export logs` 收集日志
- 集成监控工具如 Prometheus
- 考虑使用 ELK 堆栈进行日志聚合
