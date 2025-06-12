# Docker Registry 代理快速开始指南

本指南将帮助您快速在Kubernetes集群中部署和配置Docker Registry代理。

## 🚀 快速部署

### 1. 前置条件检查

```bash
# 检查依赖项
./scripts/setup-registry-proxy.sh --check-deps

# 确保kubectl可以连接到集群
kubectl cluster-info
```

### 2. 基本部署

```bash
# 基本安装（使用默认配置）
./scripts/setup-registry-proxy.sh

# 或者指定命名空间
./scripts/setup-registry-proxy.sh --namespace registry-system
```

### 3. 验证部署

```bash
# 运行测试脚本
./scripts/test-registry-access.sh

# 检查Pod状态
kubectl get pods -l app=registry-proxy

# 检查服务状态
kubectl get services -l app=registry-proxy
```

## 🔧 配置代理环境

### 企业网络代理配置

```bash
# 设置代理环境变量
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
export NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16

# 部署带代理配置的Registry
./scripts/setup-registry-proxy.sh
```

### 私有Registry认证配置

```bash
# 设置私有Registry认证信息
export DOCKER_REGISTRY_SERVER=registry.company.com
export DOCKER_REGISTRY_USER=your-username
export DOCKER_REGISTRY_PASS=your-password
export DOCKER_REGISTRY_EMAIL=your-email@company.com

# 部署带认证的Registry代理
./scripts/setup-registry-proxy.sh
```

## 🏗️ Kind集群部署

### 创建支持Registry代理的Kind集群

```bash
# 使用预配置的Kind集群配置
kind create cluster --config=examples/kind-with-registry.yaml

# 部署Registry代理
./scripts/setup-registry-proxy.sh

# 测试配置
./scripts/test-registry-access.sh
```

### 本地Registry集成

```bash
# 1. 启动本地Registry
docker run -d --restart=always -p 5000:5000 --name registry registry:2

# 2. 连接Registry到Kind网络
docker network connect kind registry

# 3. 在集群中使用本地Registry
docker tag alpine:latest localhost:5000/alpine:latest
docker push localhost:5000/alpine:latest

# 4. 在Pod中使用本地镜像
kubectl run test-pod --image=localhost:5000/alpine:latest --rm -it --restart=Never
```

## 📊 监控和管理

### 查看Registry状态

```bash
# 查看Pod日志
kubectl logs -l app=registry-proxy -f

# 查看Registry metrics
kubectl port-forward service/registry-proxy 5001:5001
curl http://localhost:5001/metrics
```

### 管理Registry缓存

```bash
# 查看缓存大小
kubectl exec -it deployment/registry-proxy -- du -sh /var/lib/registry

# 清理缓存（会重启Pod）
kubectl rollout restart deployment/registry-proxy
```

## 🧪 测试场景

### 测试镜像拉取

```bash
# 运行测试Pod
kubectl apply -f examples/test-pod.yaml

# 查看测试结果
kubectl logs registry-test-pod

# 清理测试资源
kubectl delete -f examples/test-pod.yaml
```

### 测试外部访问

```bash
# 测试外部Registry访问
./scripts/test-registry-access.sh --external-test

# 快速测试（跳过镜像拉取）
./scripts/test-registry-access.sh --quick
```

## ⚙️ 高级配置

### 自定义镜像加速器

编辑 `configs/containerd-proxy.toml`：

```toml
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
  endpoint = [
    "https://your-custom-mirror.com",
    "https://dockerhub.azk8s.cn"
  ]
```

### 配置多个私有Registry

编辑 `configs/private-registry-secret.yaml`，添加多个Registry认证信息。

### 启用HTTPS和TLS

```bash
# 创建TLS证书Secret
kubectl create secret tls registry-tls-secret \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key

# 更新Ingress配置启用HTTPS
kubectl apply -f manifests/registry-proxy-deployment.yaml
```

## 🔍 故障排除

### 常见问题

1. **镜像拉取失败**
   ```bash
   # 检查Registry连接
   kubectl exec -it deployment/registry-proxy -- curl http://localhost:5000/v2/
   ```

2. **代理配置不生效**
   ```bash
   # 检查环境变量
   kubectl get configmap registry-proxy-config -o yaml
   ```

3. **认证失败**
   ```bash
   # 检查Secret配置
   kubectl get secret registry-secret -o yaml
   ```

### 调试命令

```bash
# 进入Registry Pod调试
kubectl exec -it deployment/registry-proxy -- /bin/sh

# 查看详细事件
kubectl get events --sort-by=.metadata.creationTimestamp

# 检查网络连接
kubectl run debug --image=nicolaka/netshoot --rm -it --restart=Never
```

## 🧹 清理

### 卸载Registry代理

```bash
# 完全卸载
./scripts/setup-registry-proxy.sh --uninstall

# 清理测试资源
./scripts/test-registry-access.sh --cleanup
```

### 删除Kind集群

```bash
kind delete cluster --name registry-proxy-cluster
```

## 📚 更多资源

- [完整文档](README.md)
- [配置参考](configs/)
- [部署清单](manifests/)
- [测试示例](examples/)

## ❓ 获取帮助

```bash
# 查看脚本帮助
./scripts/setup-registry-proxy.sh --help
./scripts/test-registry-access.sh --help

# 检查集群状态
kubectl get all -l app=registry-proxy
```

---

**注意**: 请根据您的具体网络环境和安全要求调整配置。在生产环境中使用前，请确保进行充分的测试。
