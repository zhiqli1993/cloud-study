# Kubernetes Docker Registry 代理配置

本目录包含在Kubernetes集群中配置Docker Registry代理的完整解决方案，支持多种代理场景和配置方式。

## 目录结构

```
docker-registry-proxy/
├── README.md                          # 本文档
├── configs/                           # 配置文件目录
│   ├── containerd-proxy.yaml         # Containerd代理配置
│   ├── docker-daemon-proxy.json      # Docker daemon代理配置
│   ├── registry-mirror-config.yaml   # 镜像加速器配置
│   └── private-registry-secret.yaml  # 私有仓库认证配置
├── manifests/                         # Kubernetes清单文件
│   ├── registry-proxy-deployment.yaml # Registry代理服务部署
│   ├── registry-configmap.yaml       # Registry配置映射
│   └── registry-service.yaml         # Registry服务配置
├── scripts/                          # 部署和配置脚本
│   ├── setup-registry-proxy.sh       # 主要安装脚本
│   ├── configure-nodes.sh            # 节点配置脚本
│   └── test-registry-access.sh       # 测试脚本
└── examples/                         # 使用示例
    ├── kind-with-registry.yaml       # Kind集群配置示例
    └── test-pod.yaml                 # 测试Pod示例
```

## 支持的代理场景

### 1. HTTP/HTTPS代理访问外部Registry
适用于需要通过企业代理访问Docker Hub、Quay.io等外部仓库的场景。

### 2. 私有Registry代理
适用于配置访问企业内部私有Docker Registry的场景。

### 3. 镜像加速代理
适用于配置国内镜像加速器（如阿里云、腾讯云等）的场景。

### 4. 本地Registry代理
适用于Kind集群连接本地Docker Registry的场景。

## 快速开始

### 前置条件
- 运行中的Kubernetes集群（Kind、Minikube或其他）
- kubectl命令行工具
- 具有集群管理员权限

### 基本用法

1. **克隆或下载配置文件**
   ```bash
   # 进入配置目录
   cd docker-registry-proxy
   ```

2. **配置代理设置**
   ```bash
   # 编辑代理配置（根据您的网络环境）
   vim configs/docker-daemon-proxy.json
   ```

3. **部署Registry代理**
   ```bash
   # 运行安装脚本
   ./scripts/setup-registry-proxy.sh
   ```

4. **验证配置**
   ```bash
   # 测试Registry访问
   ./scripts/test-registry-access.sh
   ```

## 详细配置说明

### Docker Daemon代理配置

配置Docker daemon通过HTTP/HTTPS代理访问外部Registry：

```json
{
  "registry-mirrors": [
    "https://mirror.gcr.io",
    "https://dockerhub.azk8s.cn"
  ],
  "insecure-registries": [
    "localhost:5000",
    "registry.local:5000"
  ],
  "proxies": {
    "default": {
      "httpProxy": "http://proxy.company.com:8080",
      "httpsProxy": "http://proxy.company.com:8080",
      "noProxy": "localhost,127.0.0.1,*.local"
    }
  }
}
```

### Containerd代理配置

为Containerd配置Registry代理和镜像：

```yaml
version = 2
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["https://dockerhub.azk8s.cn", "https://docker.mirrors.ustc.edu.cn"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
      endpoint = ["https://k8s-gcr.azk8s.cn"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs."registry.company.com".auth]
      username = "myuser"
      password = "mypass"
```

### 私有Registry认证

配置访问私有Registry的认证信息：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
  namespace: default
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
```

## 使用场景和示例

### 场景1: Kind集群配置本地Registry

1. **启动本地Registry**
   ```bash
   docker run -d --restart=always -p 5000:5000 --name registry registry:2
   ```

2. **配置Kind集群**
   ```bash
   kind create cluster --config=examples/kind-with-registry.yaml
   ```

3. **连接Registry到Kind网络**
   ```bash
   docker network connect kind registry
   ```

### 场景2: 配置企业代理访问

1. **更新代理配置**
   ```bash
   # 编辑configs/docker-daemon-proxy.json
   # 设置您的企业代理地址和端口
   ```

2. **应用配置到所有节点**
   ```bash
   ./scripts/configure-nodes.sh
   ```

3. **重启Docker服务**
   ```bash
   # 在每个节点上执行
   systemctl restart docker
   ```

### 场景3: 配置镜像加速器

使用国内镜像加速器提高拉取速度：

```bash
# 应用镜像加速器配置
kubectl apply -f configs/registry-mirror-config.yaml
```

## 常用命令

### 管理命令

```bash
# 查看Registry代理状态
kubectl get pods -l app=registry-proxy

# 查看Registry配置
kubectl get configmaps registry-config -o yaml

# 更新Registry配置
kubectl apply -f manifests/registry-configmap.yaml

# 删除Registry代理
kubectl delete -f manifests/
```

### 测试命令

```bash
# 测试镜像拉取
kubectl run test-pod --image=nginx:latest --rm -it --restart=Never

# 查看节点Registry配置
kubectl get nodes -o wide
kubectl describe node <node-name>

# 检查Pod镜像拉取状态
kubectl describe pod <pod-name>
```

## 故障排除

### 常见问题

1. **镜像拉取失败**
   ```bash
   # 检查代理配置
   kubectl logs -l app=registry-proxy
   
   # 检查网络连接
   kubectl exec -it <pod-name> -- wget -O- http://proxy.company.com:8080
   ```

2. **认证失败**
   ```bash
   # 检查Secret配置
   kubectl get secret registry-secret -o yaml
   
   # 验证认证信息
   kubectl describe secret registry-secret
   ```

3. **代理配置不生效**
   ```bash
   # 检查Docker daemon配置
   docker info | grep -i proxy
   
   # 重启Docker服务
   systemctl restart docker
   ```

### 调试技巧

```bash
# 查看详细的镜像拉取日志
kubectl describe pod <pod-name>

# 进入节点调试
kubectl debug node/<node-name> -it --image=busybox

# 查看containerd配置
cat /etc/containerd/config.toml

# 测试Registry连接
curl -v https://registry.company.com/v2/
```

## 安全考虑

### 网络安全
- 使用HTTPS代理避免中间人攻击
- 配置适当的防火墙规则
- 使用私有网络进行Registry通信

### 认证安全
- 定期轮换Registry访问凭据
- 使用最小权限原则
- 启用Registry访问审计日志

### 配置安全
- 避免在配置文件中硬编码敏感信息
- 使用Kubernetes Secrets管理认证信息
- 定期审查和更新代理配置

## 性能优化

### 缓存策略
- 配置本地Registry缓存
- 使用多层缓存架构
- 设置合适的缓存过期时间

### 网络优化
- 选择最近的镜像加速器
- 配置并发拉取限制
- 使用压缩传输

### 监控和度量
- 配置Registry访问监控
- 设置镜像拉取时间告警
- 监控代理服务健康状态

## 相关资源

- [Docker Registry官方文档](https://docs.docker.com/registry/)
- [Kubernetes镜像拉取策略](https://kubernetes.io/docs/concepts/containers/images/)
- [Containerd配置指南](https://github.com/containerd/containerd/blob/main/docs/cri/config.md)
- [Kind本地Registry集成](https://kind.sigs.k8s.io/docs/user/local-registry/)

## 贡献指南

欢迎提交Issue和Pull Request来改进这些配置：

1. Fork本项目
2. 创建特性分支
3. 提交更改
4. 创建Pull Request

## 许可证

本项目采用MIT许可证 - 详见LICENSE文件
