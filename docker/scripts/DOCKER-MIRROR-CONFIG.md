# Docker 国内镜像源配置指南

## 概述

本指南提供了在中国大陆环境下配置Docker国内镜像源的详细步骤，以提高镜像拉取速度和稳定性。

## 配置方法

### 方法一：修改 Docker daemon 配置文件 (推荐)

#### Linux 系统

1. **创建或编辑 Docker daemon 配置文件**
   ```bash
   sudo mkdir -p /etc/docker
   sudo nano /etc/docker/daemon.json
   ```

2. **添加镜像源配置**
   ```json
   {
     "registry-mirrors": [
       "https://dockerhub.azk8s.cn",
       "https://docker.mirrors.ustc.edu.cn",
       "https://hub-mirror.c.163.com",
       "https://mirror.baidubce.com",
       "https://registry.docker-cn.com"
     ],
     "insecure-registries": [
       "localhost:5000",
       "registry.local:5000"
     ],
     "log-driver": "json-file",
     "log-opts": {
       "max-size": "10m",
       "max-file": "3"
     },
     "storage-driver": "overlay2",
     "exec-opts": ["native.cgroupdriver=systemd"],
     "dns": ["8.8.8.8", "114.114.114.114"],
     "max-concurrent-downloads": 10,
     "max-concurrent-uploads": 5
   }
   ```

3. **重启 Docker 服务**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart docker
   ```

#### Windows 系统

1. **打开 Docker Desktop**
2. **进入设置 (Settings)**
3. **选择 Docker Engine**
4. **编辑配置 JSON**
   ```json
   {
     "registry-mirrors": [
       "https://dockerhub.azk8s.cn",
       "https://docker.mirrors.ustc.edu.cn",
       "https://hub-mirror.c.163.com",
       "https://mirror.baidubce.com"
     ],
     "insecure-registries": [],
     "debug": false,
     "experimental": false
   }
   ```
5. **点击 Apply & Restart**

#### macOS 系统

1. **打开 Docker Desktop**
2. **点击 Docker 图标 → Preferences**
3. **选择 Docker Engine**
4. **编辑配置 JSON** (同 Windows 配置)
5. **点击 Apply & Restart**

### 方法二：使用环境变量 (临时)

```bash
# 设置镜像源环境变量
export DOCKER_REGISTRY_MIRROR=https://dockerhub.azk8s.cn

# 拉取镜像时指定镜像源
docker pull dockerhub.azk8s.cn/library/nginx:latest
```

## 推荐的国内镜像源

### 可用的镜像源列表

| 镜像源 | URL | 提供商 | 说明 |
|--------|-----|--------|------|
| 1ms镜像源 | `https://docker.1ms.run` | 1ms | 新兴镜像源，速度较快 |
| Azure 中国 | `https://dockerhub.azk8s.cn` | Microsoft | 稳定可靠 |
| AnyHub | `https://docker.anyhub.us.kg` | AnyHub | 备用镜像源 |
| Jobcher | `https://dockerhub.jobcher.com` | Jobcher | 备用镜像源 |
| ICU镜像源 | `https://dockerhub.icu` | ICU | 备用镜像源 |
| 阿里云 | `https://registry.aliyuncs.com` | Alibaba | 需要登录获取专属加速地址 |
| 腾讯云 | `https://mirror.ccs.tencentyun.com` | Tencent | 需要登录获取专属加速地址 |

### 阿里云镜像加速器配置

1. **登录阿里云控制台**
2. **搜索 "容器镜像服务"**
3. **获取专属加速地址**
4. **配置示例**
   ```json
   {
     "registry-mirrors": [
       "https://your-id.mirror.aliyuncs.com",
       "https://dockerhub.azk8s.cn"
     ]
   }
   ```

## 验证配置

### 检查配置是否生效

```bash
# 查看 Docker 信息
docker info

# 在输出中查找 Registry Mirrors 部分
# Registry Mirrors:
#  https://dockerhub.azk8s.cn/
#  https://docker.mirrors.ustc.edu.cn/
```

### 测试镜像拉取速度

```bash
# 清除本地镜像缓存
docker image prune -a

# 测试拉取常用镜像
time docker pull nginx:latest
time docker pull redis:latest
time docker pull mysql:latest
```

### 测试特定镜像源

```bash
# 直接从指定镜像源拉取
docker pull dockerhub.azk8s.cn/library/nginx:latest
docker pull docker.mirrors.ustc.edu.cn/library/redis:latest
```

## 针对不同场景的配置

### Kubernetes 环境配置

对于 Kubernetes 集群，需要配置 containerd 的镜像源：

```toml
# /etc/containerd/config.toml
version = 2

[plugins."io.containerd.grpc.v1.cri".registry.mirrors]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = [
      "https://dockerhub.azk8s.cn",
      "https://docker.mirrors.ustc.edu.cn"
    ]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
    endpoint = [
      "https://k8s-gcr.azk8s.cn",
      "https://registry.aliyuncs.com/k8sxio"
    ]
```

### CI/CD 环境配置

在 CI/CD 流水线中配置镜像源：

#### GitHub Actions
```yaml
- name: Set up Docker
  uses: docker/setup-docker@v2
  with:
    config: |
      {
        "registry-mirrors": [
          "https://dockerhub.azk8s.cn"
        ]
      }
```

#### GitLab CI
```yaml
before_script:
  - echo '{"registry-mirrors":["https://dockerhub.azk8s.cn"]}' | sudo tee /etc/docker/daemon.json
  - sudo systemctl restart docker
```

## 故障排除

### 常见问题及解决方案

#### 1. 镜像源连接失败
```bash
# 测试镜像源连通性
curl -I https://dockerhub.azk8s.cn/v2/

# 如果失败，尝试其他镜像源
curl -I https://docker.mirrors.ustc.edu.cn/v2/
```

#### 2. 配置不生效
```bash
# 检查配置文件语法
sudo docker info

# 查看 Docker 日志
sudo journalctl -u docker.service -f
```

#### 3. 权限问题
```bash
# 确保配置文件权限正确
sudo chown root:root /etc/docker/daemon.json
sudo chmod 644 /etc/docker/daemon.json
```

#### 4. 网络代理环境
如果在代理环境下，需要额外配置：

```json
{
  "registry-mirrors": [
    "https://dockerhub.azk8s.cn"
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

## 安全注意事项

1. **使用 HTTPS 镜像源**：确保所有镜像源都使用 HTTPS 协议
2. **验证镜像完整性**：定期检查拉取镜像的校验和
3. **避免使用不可信镜像源**：只使用知名和可信的镜像源
4. **定期更新配置**：镜像源可能会变更，需要定期检查和更新

## 性能优化建议

1. **多镜像源配置**：配置多个镜像源作为备选
2. **并发下载设置**：合理设置 `max-concurrent-downloads`
3. **存储驱动优化**：使用 `overlay2` 存储驱动
4. **日志管理**：配置日志轮转避免磁盘空间不足

## 镜像源状态监控

可以使用以下脚本监控镜像源状态：

```bash
#!/bin/bash
# check-mirror-status.sh

MIRRORS=(
  "https://dockerhub.azk8s.cn"
  "https://docker.mirrors.ustc.edu.cn"
  "https://hub-mirror.c.163.com"
  "https://mirror.baidubce.com"
)

for mirror in "${MIRRORS[@]}"; do
  echo "检查镜像源: $mirror"
  if curl -s -I "$mirror/v2/" | grep -q "200 OK"; then
    echo "✅ $mirror - 可用"
  else
    echo "❌ $mirror - 不可用"
  fi
done
```

## 参考资源

- [Docker 官方文档](https://docs.docker.com/engine/reference/commandline/dockerd/)
- [containerd 配置文档](https://github.com/containerd/containerd/blob/main/docs/cri/config.md)
- [Kubernetes 镜像源配置](https://kubernetes.io/docs/concepts/containers/images/)

---

**更新日期**: 2024年12月
**维护者**: Cloud Study Team
