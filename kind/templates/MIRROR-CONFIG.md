# Kind 配置文件国内镜像源说明

## 概述

本目录下的所有 Kind 配置模板已经预配置了国内镜像源，以提高在中国大陆地区拉取容器镜像的速度和成功率。

## 配置的镜像源

所有配置文件中已添加了以下国内镜像源：

### Docker Hub 镜像
- `dockerhub.azk8s.cn` - Azure 中国镜像源
- `docker.mirrors.ustc.edu.cn` - 中科大镜像源
- `hub-mirror.c.163.com` - 网易镜像源
- `registry.docker-cn.com` - Docker 中国官方镜像源
- `registry-1.docker.io` - 官方源（备用）

### Kubernetes 相关镜像
- `k8s-gcr.azk8s.cn` - Azure 中国 K8s 镜像源
- `registry.aliyuncs.com/k8sxio` - 阿里云 K8s 镜像源

### Google Container Registry (GCR)
- `gcr.azk8s.cn` - Azure 中国 GCR 镜像源
- `registry.aliyuncs.com` - 阿里云镜像源

### Quay.io 镜像
- `quay.azk8s.cn` - Azure 中国 Quay 镜像源
- `quay-mirror.qiniu.com` - 七牛云 Quay 镜像源

## 配置文件列表

以下配置文件已添加镜像源配置：

1. **kind-config.yaml** - 完整的 Kind 配置模板
2. **kind-single-node.yaml** - 单节点集群配置
3. **kind-multi-master.yaml** - 多主节点高可用集群配置
4. **kind-ingress-ready.yaml** - Ingress 就绪集群配置

## 配置原理

配置通过 `containerdConfigPatches` 字段实现，该字段允许我们修改 containerd 运行时的配置。镜像源配置包含：

1. **镜像镜像映射** (`registry.mirrors`): 将官方镜像源映射到国内镜像源
2. **TLS 配置** (`registry.configs`): 确保与镜像源的安全连接

## 使用方法

### 创建集群
```bash
# 使用单节点配置
kind create cluster --config=kind-single-node.yaml

# 使用多主节点配置
kind create cluster --config=kind-multi-master.yaml

# 使用 Ingress 就绪配置
kind create cluster --config=kind-ingress-ready.yaml

# 使用完整配置模板
kind create cluster --config=kind-config.yaml
```

### 验证镜像源配置
```bash
# 进入节点查看 containerd 配置
docker exec -it <node-name> cat /etc/containerd/config.toml

# 测试镜像拉取
kubectl run test-pod --image=nginx:latest --rm -it -- /bin/bash
```

## 故障排除

### 镜像拉取失败
1. 检查网络连接是否正常
2. 尝试手动拉取镜像测试镜像源可用性：
   ```bash
   docker pull dockerhub.azk8s.cn/library/nginx:latest
   ```
3. 如果某个镜像源不可用，配置中的其他备用源会自动尝试

### 集群创建失败
1. 确保 Docker 正在运行
2. 检查 Kind 版本是否兼容
3. 查看详细错误信息：
   ```bash
   kind create cluster --config=<config-file> --verbosity=1
   ```

## 镜像源状态监控

建议定期检查镜像源的可用性，因为这些服务可能会有维护或变更：

```bash
# 测试 Docker Hub 镜像源
curl -I https://dockerhub.azk8s.cn/v2/

# 测试 K8s 镜像源
curl -I https://k8s-gcr.azk8s.cn/v2/
```

## 自定义镜像源

如果需要添加或修改镜像源，可以编辑配置文件中的 `containerdConfigPatches` 部分：

```yaml
containerdConfigPatches:
- |
  version = 2
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."your-registry.com"]
    endpoint = ["https://your-mirror.com"]
```

## 注意事项

1. 镜像源的可用性可能会发生变化，建议根据实际情况调整配置
2. 某些私有镜像仍需要配置认证信息
3. 如果遇到镜像拉取问题，可以临时禁用镜像源配置进行故障排除

## 更新日志

- 2024/06/12: 初始配置，添加主要国内镜像源支持
- 支持 Docker Hub, GCR, K8s.gcr.io, Quay.io 等主要镜像仓库的国内镜像源
