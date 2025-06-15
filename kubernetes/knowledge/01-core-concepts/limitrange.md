# LimitRange 资源详解

## 概述

LimitRange 是 Kubernetes 中用于限制命名空间内资源使用的策略对象。它可以设置 Pod、Container、PersistentVolumeClaim 等资源的最小值、最大值和默认值，确保资源的合理分配和使用。

## 核心特性

### 1. 资源限制
- 设置资源的最小和最大限制
- 定义默认资源请求和限制
- 控制资源使用比例

### 2. 多种资源类型
- Container 级别限制
- Pod 级别限制
- PersistentVolumeClaim 限制

### 3. 命名空间级别
- 作用于特定命名空间
- 支持多个 LimitRange 对象
- 自动应用到新创建的资源

## LimitRange 配置详解

### 基础配置示例

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-limit-range
  namespace: development
spec:
  limits:
  - default:                    # 默认限制（limits）
      cpu: 200m
      memory: 256Mi
    defaultRequest:             # 默认请求（requests）
      cpu: 100m
      memory: 128Mi
    max:                        # 最大值
      cpu: 500m
      memory: 1Gi
    min:                        # 最小值
      cpu: 50m
      memory: 64Mi
    type: Container             # 限制类型
```

### Container 级别限制

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: container-limit-range
  namespace: production
spec:
  limits:
  - type: Container
    default:                    # 容器默认 limits
      cpu: 500m
      memory: 512Mi
      ephemeral-storage: 1Gi
    defaultRequest:             # 容器默认 requests
      cpu: 100m
      memory: 128Mi
      ephemeral-storage: 100Mi
    max:                        # 容器最大资源
      cpu: 2000m
      memory: 4Gi
      ephemeral-storage: 10Gi
    min:                        # 容器最小资源
      cpu: 50m
      memory: 64Mi
      ephemeral-storage: 50Mi
    maxLimitRequestRatio:       # limits/requests 最大比例
      cpu: 4                    # limits 不能超过 requests 的 4 倍
      memory: 2                 # limits 不能超过 requests 的 2 倍
```

### Pod 级别限制

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: pod-limit-range
  namespace: production
spec:
  limits:
  - type: Pod
    max:                        # Pod 总资源上限
      cpu: 4000m
      memory: 8Gi
      ephemeral-storage: 20Gi
    min:                        # Pod 总资源下限
      cpu: 100m
      memory: 128Mi
      ephemeral-storage: 100Mi
```

### PersistentVolumeClaim 限制

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: pvc-limit-range
  namespace: production
spec:
  limits:
  - type: PersistentVolumeClaim
    max:                        # PVC 最大存储
      storage: 100Gi
    min:                        # PVC 最小存储
      storage: 1Gi
```

## 完整示例配置

### 1. 开发环境限制

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: development-limits
  namespace: development
  labels:
    environment: development
  annotations:
    description: "开发环境资源限制策略"
spec:
  limits:
  # Container 限制
  - type: Container
    default:
      cpu: 200m
      memory: 256Mi
      ephemeral-storage: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
      ephemeral-storage: 100Mi
    max:
      cpu: 1000m
      memory: 2Gi
      ephemeral-storage: 5Gi
    min:
      cpu: 50m
      memory: 64Mi
      ephemeral-storage: 50Mi
    maxLimitRequestRatio:
      cpu: 4
      memory: 3

  # Pod 限制
  - type: Pod
    max:
      cpu: 2000m
      memory: 4Gi
      ephemeral-storage: 10Gi
    min:
      cpu: 100m
      memory: 128Mi
      ephemeral-storage: 100Mi

  # PVC 限制
  - type: PersistentVolumeClaim
    max:
      storage: 50Gi
    min:
      storage: 1Gi
```

### 2. 生产环境限制

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: production
  labels:
    environment: production
  annotations:
    description: "生产环境资源限制策略"
spec:
  limits:
  # Container 限制（更严格）
  - type: Container
    default:
      cpu: 500m
      memory: 512Mi
      ephemeral-storage: 1Gi
    defaultRequest:
      cpu: 200m
      memory: 256Mi
      ephemeral-storage: 200Mi
    max:
      cpu: 4000m
      memory: 8Gi
      ephemeral-storage: 20Gi
    min:
      cpu: 100m
      memory: 128Mi
      ephemeral-storage: 100Mi
    maxLimitRequestRatio:
      cpu: 2                    # 生产环境要求更小的比例
      memory: 2

  # Pod 限制
  - type: Pod
    max:
      cpu: 8000m
      memory: 16Gi
      ephemeral-storage: 50Gi
    min:
      cpu: 200m
      memory: 256Mi
      ephemeral-storage: 200Mi

  # PVC 限制
  - type: PersistentVolumeClaim
    max:
      storage: 500Gi
    min:
      storage: 5Gi
```

### 3. 测试环境限制

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: testing-limits
  namespace: testing
spec:
  limits:
  # Container 限制
  - type: Container
    default:
      cpu: 300m
      memory: 384Mi
    defaultRequest:
      cpu: 150m
      memory: 192Mi
    max:
      cpu: 1500m
      memory: 3Gi
    min:
      cpu: 75m
      memory: 96Mi
    maxLimitRequestRatio:
      cpu: 3
      memory: 2

  # Pod 限制
  - type: Pod
    max:
      cpu: 3000m
      memory: 6Gi
    min:
      cpu: 150m
      memory: 192Mi
```

## 资源类型详解

### 1. Container 类型

```yaml
limits:
- type: Container
  # 适用于容器级别的资源限制
  # 包括 CPU、内存、临时存储
  # 支持设置默认值和比例限制
```

### 2. Pod 类型

```yaml
limits:
- type: Pod
  # 适用于整个 Pod 的资源总和
  # 限制 Pod 内所有容器的资源总和
  # 只支持 max 和 min 设置
```

### 3. PersistentVolumeClaim 类型

```yaml
limits:
- type: PersistentVolumeClaim
  # 适用于存储卷申请
  # 限制 PVC 的存储大小
  # 只支持 storage 资源类型
```

## 应用效果

### 1. 自动应用默认值

```yaml
# 没有指定资源的 Pod
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: app
    image: nginx
    # 没有指定 resources

# LimitRange 会自动应用默认值：
# resources:
#   requests:
#     cpu: 100m
#     memory: 128Mi
#   limits:
#     cpu: 200m
#     memory: 256Mi
```

### 2. 验证资源限制

```yaml
# 超出限制的 Pod 会被拒绝
apiVersion: v1
kind: Pod
metadata:
  name: large-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        cpu: 2000m              # 超出 max 限制
        memory: 10Gi            # 超出 max 限制
      limits:
        cpu: 4000m
        memory: 20Gi

# 错误信息：
# Pod "large-pod" is forbidden: maximum cpu usage per Container is 500m, but limit is 4000m
```

## 监控和管理

### 1. 查看 LimitRange

```bash
# 查看 LimitRange
kubectl get limitrange
kubectl get limits              # 简写

# 查看详细信息
kubectl describe limitrange resource-limit-range

# 查看特定命名空间
kubectl get limitrange -n production
```

### 2. 验证应用效果

```bash
# 查看 Pod 的资源配置
kubectl get pod test-pod -o yaml

# 查看资源使用情况
kubectl top pod test-pod

# 检查资源配额使用
kubectl describe quota -n production
```

## 与 ResourceQuota 配合

### 1. 组合使用示例

```yaml
# LimitRange - 控制单个资源的大小
apiVersion: v1
kind: LimitRange
metadata:
  name: individual-limits
  namespace: production
spec:
  limits:
  - type: Container
    max:
      cpu: 1000m
      memory: 2Gi
    min:
      cpu: 100m
      memory: 128Mi

---
# ResourceQuota - 控制命名空间总资源
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: production
spec:
  hard:
    requests.cpu: 10000m
    requests.memory: 20Gi
    limits.cpu: 20000m
    limits.memory: 40Gi
    persistentvolumeclaims: 50
    requests.storage: 500Gi
```

### 2. 策略组合

```yaml
# 多层次资源控制策略
namespace-level:
  - ResourceQuota: 控制命名空间总量
  - LimitRange: 控制单个资源大小

container-level:
  - LimitRange: 设置容器默认值和限制
  - PodSecurityPolicy: 安全策略

pod-level:
  - LimitRange: 控制 Pod 总资源
  - PriorityClass: 调度优先级
```

## 典型使用场景

### 1. 多租户环境

```yaml
# 租户 A - 高资源配额
apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-a-limits
  namespace: tenant-a
spec:
  limits:
  - type: Container
    default:
      cpu: 1000m
      memory: 1Gi
    max:
      cpu: 4000m
      memory: 8Gi

---
# 租户 B - 标准资源配额
apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-b-limits
  namespace: tenant-b
spec:
  limits:
  - type: Container
    default:
      cpu: 500m
      memory: 512Mi
    max:
      cpu: 2000m
      memory: 4Gi
```

### 2. 环境隔离

```yaml
# 开发环境 - 宽松限制
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: development
spec:
  limits:
  - type: Container
    default:
      cpu: 100m
      memory: 128Mi
    max:
      cpu: 1000m
      memory: 2Gi

---
# 生产环境 - 严格限制
apiVersion: v1
kind: LimitRange
metadata:
  name: prod-limits
  namespace: production
spec:
  limits:
  - type: Container
    default:
      cpu: 500m
      memory: 512Mi
    max:
      cpu: 2000m
      memory: 4Gi
    maxLimitRequestRatio:
      cpu: 2
      memory: 2
```

## 最佳实践

### 1. 设置合理的默认值

```yaml
# 根据应用特点设置默认值
spec:
  limits:
  - type: Container
    default:
      cpu: 200m               # 适合大多数应用
      memory: 256Mi           # 给予足够的内存
    defaultRequest:
      cpu: 100m               # 保守的请求值
      memory: 128Mi           # 最小可用内存
```

### 2. 合理的比例限制

```yaml
# 防止资源浪费
maxLimitRequestRatio:
  cpu: 4                      # CPU 可以有较大弹性
  memory: 2                   # 内存比例要较小
```

### 3. 环境差异化配置

```yaml
# 开发环境：宽松、快速迭代
development:
  max-cpu: 1000m
  max-memory: 2Gi
  ratio: 4

# 测试环境：中等、模拟生产
testing:
  max-cpu: 2000m
  max-memory: 4Gi
  ratio: 3

# 生产环境：严格、稳定可靠
production:
  max-cpu: 4000m
  max-memory: 8Gi
  ratio: 2
```

### 4. 监控和调优

```bash
# 定期检查资源使用情况
kubectl top nodes
kubectl top pods --all-namespaces

# 分析资源利用率
kubectl describe node
kubectl get events --field-selector reason=FailedScheduling

# 调整 LimitRange 配置
kubectl edit limitrange production-limits -n production
```

### 5. 文档化策略

```yaml
metadata:
  annotations:
    description: "生产环境资源限制策略"
    owner: "platform-team@example.com"
    last-updated: "2023-12-01"
    policy-version: "v1.2"
    review-schedule: "quarterly"
```