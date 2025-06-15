# ResourceQuota 资源详解

## 概述

ResourceQuota 是 Kubernetes 中用于限制命名空间资源总使用量的对象。它可以限制命名空间内可以创建的对象数量，以及这些对象可以消耗的计算资源总量。

## 核心特性

### 1. 资源总量控制
- 限制命名空间内的总资源使用量
- 控制对象数量上限
- 防止资源过度消耗

### 2. 多种资源类型
- 计算资源（CPU、内存）
- 存储资源（存储卷、存储容量）
- 对象数量（Pod、Service、Secret 等）

### 3. 命名空间级别
- 作用于特定命名空间
- 支持多个 ResourceQuota 对象
- 与 LimitRange 配合使用

## ResourceQuota 配置详解

### 基础配置示例

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: basic-quota
  namespace: development
spec:
  hard:
    # 计算资源配额
    requests.cpu: 4000m         # CPU 请求总量
    requests.memory: 8Gi        # 内存请求总量
    limits.cpu: 8000m           # CPU 限制总量
    limits.memory: 16Gi         # 内存限制总量
    
    # 对象数量配额
    pods: 20                    # Pod 数量限制
    services: 10                # Service 数量限制
    secrets: 20                 # Secret 数量限制
    configmaps: 20              # ConfigMap 数量限制
    
    # 存储配额
    persistentvolumeclaims: 10  # PVC 数量限制
    requests.storage: 100Gi     # 存储容量总量
```

### 完整配置示例

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: comprehensive-quota
  namespace: production
  labels:
    environment: production
    team: platform
  annotations:
    description: "生产环境完整资源配额"
    owner: "platform-team@example.com"
spec:
  hard:
    # 计算资源配额
    requests.cpu: 20000m        # 20 CPU 请求
    requests.memory: 40Gi       # 40Gi 内存请求
    limits.cpu: 40000m          # 40 CPU 限制
    limits.memory: 80Gi         # 80Gi 内存限制
    requests.ephemeral-storage: 200Gi  # 临时存储请求
    limits.ephemeral-storage: 400Gi    # 临时存储限制
    
    # Pod 相关配额
    pods: 100                   # 最大 Pod 数量
    
    # 工作负载配额
    deployments.apps: 20        # Deployment 数量
    replicasets.apps: 50        # ReplicaSet 数量
    statefulsets.apps: 10       # StatefulSet 数量
    daemonsets.apps: 5          # DaemonSet 数量
    jobs.batch: 20              # Job 数量
    cronjobs.batch: 10          # CronJob 数量
    
    # 服务发现配额
    services: 20                # Service 数量
    services.nodeports: 5       # NodePort Service 数量
    services.loadbalancers: 3   # LoadBalancer Service 数量
    ingresses.networking.k8s.io: 10  # Ingress 数量
    
    # 配置和存储配额
    configmaps: 50              # ConfigMap 数量
    secrets: 50                 # Secret 数量
    persistentvolumeclaims: 30  # PVC 数量
    requests.storage: 1000Gi    # 存储容量总量
    
    # 网络配额
    networkpolicies.networking.k8s.io: 20  # NetworkPolicy 数量
    
    # RBAC 配额
    roles.rbac.authorization.k8s.io: 10           # Role 数量
    rolebindings.rbac.authorization.k8s.io: 20   # RoleBinding 数量
    serviceaccounts: 30         # ServiceAccount 数量
  
  # 可选：作用域限制
  scopes:
  - NotTerminating             # 只应用于非终止状态的 Pod
  
  # 可选：作用域选择器
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["high"]
```

## 资源类型详解

### 1. 计算资源配额

```yaml
spec:
  hard:
    # CPU 配额
    requests.cpu: 10000m        # 所有容器 CPU 请求总和
    limits.cpu: 20000m          # 所有容器 CPU 限制总和
    
    # 内存配额
    requests.memory: 20Gi       # 所有容器内存请求总和
    limits.memory: 40Gi         # 所有容器内存限制总和
    
    # 临时存储配额
    requests.ephemeral-storage: 100Gi  # 临时存储请求总和
    limits.ephemeral-storage: 200Gi    # 临时存储限制总和
    
    # GPU 配额（如果支持）
    requests.nvidia.com/gpu: 4  # GPU 请求总量
    limits.nvidia.com/gpu: 4    # GPU 限制总量
```

### 2. 存储资源配额

```yaml
spec:
  hard:
    # 存储卷配额
    persistentvolumeclaims: 20      # PVC 数量限制
    requests.storage: 500Gi         # 存储容量总量
    
    # 按存储类限制
    fast-ssd.storageclass.storage.k8s.io/requests.storage: 100Gi
    fast-ssd.storageclass.storage.k8s.io/persistentvolumeclaims: 5
    
    standard.storageclass.storage.k8s.io/requests.storage: 400Gi
    standard.storageclass.storage.k8s.io/persistentvolumeclaims: 15
```

### 3. 对象数量配额

```yaml
spec:
  hard:
    # 核心对象
    pods: 50                    # Pod 数量
    services: 20                # Service 数量
    secrets: 30                 # Secret 数量
    configmaps: 30              # ConfigMap 数量
    
    # 工作负载对象
    deployments.apps: 15        # Deployment 数量
    statefulsets.apps: 5        # StatefulSet 数量
    daemonsets.apps: 3          # DaemonSet 数量
    
    # 批处理对象
    jobs.batch: 10              # Job 数量
    cronjobs.batch: 5           # CronJob 数量
    
    # 网络对象
    ingresses.networking.k8s.io: 10         # Ingress 数量
    networkpolicies.networking.k8s.io: 15  # NetworkPolicy 数量
```

## 作用域配置

### 1. 基本作用域

```yaml
spec:
  scopes:
  - Terminating               # 终止状态的 Pod
  - NotTerminating           # 非终止状态的 Pod
  - BestEffort               # BestEffort QoS 的 Pod
  - NotBestEffort            # 非 BestEffort QoS 的 Pod
```

### 2. 作用域选择器

```yaml
spec:
  scopeSelector:
    matchExpressions:
    # 按优先级类选择
    - operator: In
      scopeName: PriorityClass
      values: ["high", "medium"]
    
    # 按 QoS 类选择
    - operator: Exists
      scopeName: BestEffort
```

### 3. 组合作用域示例

```yaml
# 高优先级 Pod 的资源配额
apiVersion: v1
kind: ResourceQuota
metadata:
  name: high-priority-quota
  namespace: production
spec:
  hard:
    requests.cpu: 10000m
    requests.memory: 20Gi
    pods: 30
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["high"]

---
# 普通优先级 Pod 的资源配额
apiVersion: v1
kind: ResourceQuota
metadata:
  name: normal-priority-quota
  namespace: production
spec:
  hard:
    requests.cpu: 5000m
    requests.memory: 10Gi
    pods: 50
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["normal", "low"]
```

## 环境配置示例

### 1. 开发环境配额

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: development-quota
  namespace: development
spec:
  hard:
    # 适中的计算资源
    requests.cpu: 8000m
    requests.memory: 16Gi
    limits.cpu: 16000m
    limits.memory: 32Gi
    
    # 较多的对象数量（便于开发调试）
    pods: 50
    services: 30
    configmaps: 50
    secrets: 50
    
    # 较小的存储配额
    persistentvolumeclaims: 20
    requests.storage: 200Gi
    
    # 工作负载限制
    deployments.apps: 30
    jobs.batch: 20
    cronjobs.batch: 15
```

### 2. 测试环境配额

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: testing-quota
  namespace: testing
spec:
  hard:
    # 模拟生产的计算资源
    requests.cpu: 12000m
    requests.memory: 24Gi
    limits.cpu: 24000m
    limits.memory: 48Gi
    
    # 适中的对象数量
    pods: 40
    services: 20
    configmaps: 40
    secrets: 40
    
    # 中等存储配额
    persistentvolumeclaims: 25
    requests.storage: 400Gi
    
    # 工作负载限制
    deployments.apps: 20
    statefulsets.apps: 8
    jobs.batch: 15
```

### 3. 生产环境配额

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    # 大量计算资源
    requests.cpu: 50000m
    requests.memory: 100Gi
    limits.cpu: 100000m
    limits.memory: 200Gi
    
    # 严格控制的对象数量
    pods: 80
    services: 30
    configmaps: 60
    secrets: 60
    
    # 大存储配额
    persistentvolumeclaims: 40
    requests.storage: 2000Gi
    
    # 严格的工作负载限制
    deployments.apps: 25
    statefulsets.apps: 15
    daemonsets.apps: 10
    
    # 网络资源限制
    ingresses.networking.k8s.io: 15
    networkpolicies.networking.k8s.io: 30
```

## 监控和管理

### 1. 查看 ResourceQuota 状态

```bash
# 查看 ResourceQuota
kubectl get resourcequota
kubectl get quota              # 简写

# 查看详细信息
kubectl describe resourcequota production-quota

# 查看特定命名空间
kubectl get quota -n production

# 查看使用情况
kubectl describe quota -n production
```

### 2. 资源使用情况监控

```bash
# 查看资源使用详情
kubectl describe quota production-quota -n production

# 输出示例：
# Name:                    production-quota
# Namespace:               production
# Resource                 Used   Hard
# --------                 ----   ----
# configmaps               5      60
# persistentvolumeclaims   8      40
# pods                     15     80
# requests.cpu             5500m  50000m
# requests.memory          11Gi   100Gi
# requests.storage         150Gi  2000Gi
# secrets                  10     60
# services                 8      30
```

### 3. 配额告警监控

```yaml
# Prometheus 监控规则示例
groups:
- name: resourcequota
  rules:
  - alert: ResourceQuotaCPUUsageHigh
    expr: |
      (
        kube_resourcequota{resource="requests.cpu", type="used"}
        /
        kube_resourcequota{resource="requests.cpu", type="hard"}
      ) > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "命名空间 {{ $labels.namespace }} CPU 配额使用率过高"
      description: "CPU 使用率已达到 {{ $value | humanizePercentage }}"

  - alert: ResourceQuotaMemoryUsageHigh
    expr: |
      (
        kube_resourcequota{resource="requests.memory", type="used"}
        /
        kube_resourcequota{resource="requests.memory", type="hard"}
      ) > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "命名空间 {{ $labels.namespace }} 内存配额使用率过高"
```

## 与其他资源配合

### 1. 与 LimitRange 配合

```yaml
# ResourceQuota - 控制总量
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: production
spec:
  hard:
    requests.cpu: 20000m
    requests.memory: 40Gi
    pods: 100

---
# LimitRange - 控制单个资源
apiVersion: v1
kind: LimitRange
metadata:
  name: individual-limits
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
    min:
      cpu: 100m
      memory: 128Mi
```

### 2. 与 PriorityClass 配合

```yaml
# 高优先级类
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000
globalDefault: false
description: "高优先级工作负载"

---
# 高优先级配额
apiVersion: v1
kind: ResourceQuota
metadata:
  name: high-priority-quota
  namespace: production
spec:
  hard:
    requests.cpu: 15000m
    requests.memory: 30Gi
    pods: 50
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["high-priority"]
```

## 最佳实践

### 1. 分层配额策略

```yaml
# 按环境分层
environments:
  development:
    cpu: 8000m
    memory: 16Gi
    storage: 200Gi
  
  testing:
    cpu: 12000m
    memory: 24Gi
    storage: 400Gi
  
  production:
    cpu: 50000m
    memory: 100Gi
    storage: 2000Gi
```

### 2. 按团队分配

```yaml
# 团队 A - 后端服务
apiVersion: v1
kind: ResourceQuota
metadata:
  name: backend-team-quota
  namespace: backend-services
spec:
  hard:
    requests.cpu: 20000m
    requests.memory: 40Gi
    pods: 60

---
# 团队 B - 前端服务
apiVersion: v1
kind: ResourceQuota
metadata:
  name: frontend-team-quota
  namespace: frontend-services
spec:
  hard:
    requests.cpu: 10000m
    requests.memory: 20Gi
    pods: 40
```

### 3. 监控和调优

```bash
# 定期检查配额使用情况
kubectl get quota --all-namespaces

# 分析资源使用趋势
kubectl describe quota -n production

# 根据使用情况调整配额
kubectl edit resourcequota production-quota -n production
```

### 4. 自动化管理

```yaml
# 使用 Helm Chart 管理配额
# values.yaml
resourceQuota:
  enabled: true
  hard:
    requests.cpu: "{{ .Values.quota.cpu }}"
    requests.memory: "{{ .Values.quota.memory }}"
    pods: "{{ .Values.quota.pods }}"

# 不同环境的值
environments:
  dev:
    quota:
      cpu: 8000m
      memory: 16Gi
      pods: 50
  
  prod:
    quota:
      cpu: 50000m
      memory: 100Gi
      pods: 100
```

### 5. 故障预防

```yaml
# 预留紧急资源
apiVersion: v1
kind: ResourceQuota
metadata:
  name: emergency-quota
  namespace: production
spec:
  hard:
    requests.cpu: 5000m         # 预留 5 CPU
    requests.memory: 10Gi       # 预留 10Gi 内存
    pods: 20                    # 预留 20 个 Pod
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["emergency"]
```