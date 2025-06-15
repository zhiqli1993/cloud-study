# PriorityClass 资源详解

## 概述

PriorityClass 是 Kubernetes 中定义 Pod 调度优先级的全局资源。它允许集群管理员定义不同的优先级别，调度器会根据这些优先级来决定 Pod 的调度顺序和抢占行为。

## 核心特性

### 1. 调度优先级
- 定义 Pod 的相对重要性
- 影响调度器的决策
- 支持抢占式调度

### 2. 全局作用域
- 集群级别资源
- 可被任何命名空间的 Pod 使用
- 统一的优先级体系

### 3. 抢占机制
- 高优先级 Pod 可以抢占资源
- 自动驱逐低优先级 Pod
- 确保关键工作负载的资源

## PriorityClass 配置详解

### 基础配置示例

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
  labels:
    priority-tier: high
    purpose: critical-workloads
value: 1000                     # 优先级值（越高越优先）
globalDefault: false            # 是否为全局默认
description: "高优先级工作负载，用于关键业务服务"
preemptionPolicy: PreemptLowerPriority  # 抢占策略
```

### 完整配置示例

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: critical-priority
  labels:
    tier: critical
    environment: production
    team: platform
  annotations:
    description: "最高优先级，用于系统关键组件"
    usage-guidelines: "仅用于系统核心服务和紧急恢复"
    created-by: "platform-team"
value: 2000                     # 最高优先级
globalDefault: false
description: "系统关键组件的最高优先级"
preemptionPolicy: PreemptLowerPriority
```

## 优先级体系设计

### 1. 标准优先级层次

```yaml
# 系统关键组件 - 最高优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: system-critical
value: 2000
globalDefault: false
description: "系统关键组件：DNS、网络、存储等"

---
# 业务关键应用 - 高优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: business-critical
value: 1500
globalDefault: false
description: "业务关键应用：核心服务、支付系统等"

---
# 重要应用 - 中高优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000
globalDefault: false
description: "重要应用：主要业务功能"

---
# 标准应用 - 中等优先级（默认）
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: normal-priority
value: 500
globalDefault: true           # 设为默认优先级
description: "标准应用的默认优先级"

---
# 低优先级应用 - 低优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 200
globalDefault: false
description: "低优先级应用：批处理、测试任务等"

---
# 最佳努力服务 - 最低优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: best-effort
value: 100
globalDefault: false
description: "最佳努力服务：可被随时抢占的任务"
preemptionPolicy: Never       # 不抢占其他 Pod
```

### 2. 环境相关优先级

```yaml
# 生产环境优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: production-high
  labels:
    environment: production
value: 1200
description: "生产环境高优先级应用"

---
# 测试环境优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: testing-priority
  labels:
    environment: testing
value: 300
description: "测试环境应用"

---
# 开发环境优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: development-priority
  labels:
    environment: development
value: 100
description: "开发环境应用"
```

## 抢占策略配置

### 1. PreemptLowerPriority（默认）

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: preemptive-priority
value: 1000
preemptionPolicy: PreemptLowerPriority
description: "可以抢占低优先级 Pod 的资源"
```

### 2. Never（不抢占）

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: non-preemptive-priority
value: 800
preemptionPolicy: Never
description: "高优先级但不抢占其他 Pod"
```

## Pod 中使用 PriorityClass

### 1. 基本使用

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: high-priority-pod
spec:
  priorityClassName: high-priority    # 指定优先级类
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
```

### 2. Deployment 中使用

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: critical-app
  template:
    metadata:
      labels:
        app: critical-app
    spec:
      priorityClassName: business-critical  # 业务关键优先级
      containers:
      - name: app
        image: myapp:latest
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 1Gi
```

### 3. 不同工作负载的优先级

```yaml
# 关键数据库服务
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  serviceName: database
  replicas: 3
  template:
    metadata:
      labels:
        app: database
    spec:
      priorityClassName: system-critical
      containers:
      - name: postgres
        image: postgres:13

---
# Web 前端服务
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 5
  template:
    metadata:
      labels:
        app: frontend
    spec:
      priorityClassName: high-priority
      containers:
      - name: web
        image: nginx

---
# 批处理任务
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-job
spec:
  template:
    spec:
      priorityClassName: low-priority
      containers:
      - name: worker
        image: batch-processor
      restartPolicy: Never
```

## 典型使用场景

### 1. 微服务架构优先级

```yaml
# API 网关 - 最高优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: api-gateway-priority
value: 1800
description: "API 网关服务优先级"

---
# 核心服务 - 高优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: core-service-priority
value: 1500
description: "核心微服务优先级"

---
# 支撑服务 - 中等优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: support-service-priority
value: 1000
description: "支撑服务优先级"

---
# 辅助服务 - 低优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: auxiliary-service-priority
value: 500
description: "辅助服务优先级"
```

### 2. 数据处理管道优先级

```yaml
# 实时数据处理 - 高优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: realtime-processing
value: 1400
description: "实时数据处理任务"

---
# 近实时处理 - 中等优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: near-realtime-processing
value: 1000
description: "近实时数据处理任务"

---
# 批量处理 - 低优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: batch-processing
value: 300
description: "批量数据处理任务"
preemptionPolicy: Never       # 不抢占其他任务
```

### 3. 监控和运维优先级

```yaml
# 监控系统 - 高优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: monitoring-priority
value: 1600
description: "监控系统组件"

---
# 日志收集 - 中等优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: logging-priority
value: 1200
description: "日志收集系统"

---
# 运维工具 - 中低优先级
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: ops-tools-priority
value: 800
description: "运维和管理工具"
```

## 监控和管理

### 1. 查看 PriorityClass

```bash
# 查看所有 PriorityClass
kubectl get priorityclass
kubectl get pc                 # 简写

# 查看详细信息
kubectl describe priorityclass high-priority

# 按优先级排序
kubectl get pc --sort-by=.value
```

### 2. 查看 Pod 优先级

```bash
# 查看 Pod 的优先级
kubectl get pods -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priorityClassName,VALUE:.spec.priority

# 查看特定优先级的 Pod
kubectl get pods --field-selector spec.priorityClassName=high-priority

# 查看优先级相关事件
kubectl get events --field-selector reason=Preempted
```

### 3. 抢占监控

```yaml
# Prometheus 监控规则
groups:
- name: priority-scheduling
  rules:
  - alert: PodPreemptionHigh
    expr: |
      rate(kube_pod_container_status_restarts_total[5m]) > 0.1
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "Pod 抢占频率过高"
      description: "命名空间 {{ $labels.namespace }} 中的 Pod 抢占频率异常"

  - alert: HighPriorityPodPending
    expr: |
      kube_pod_status_phase{phase="Pending"} and on(pod, namespace) kube_pod_info{priority_class="high-priority"}
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "高优先级 Pod 调度失败"
      description: "高优先级 Pod {{ $labels.pod }} 在命名空间 {{ $labels.namespace }} 中调度失败"
```

## 最佳实践

### 1. 优先级设计原则

```yaml
# 优先级值设计建议
system-critical:    2000-2999  # 系统组件
business-critical:  1500-1999  # 业务关键
high-priority:      1000-1499  # 重要应用
normal-priority:    500-999    # 标准应用（默认）
low-priority:       200-499    # 低优先级应用
best-effort:        0-199      # 最佳努力
```

### 2. 抢占策略最佳实践

```yaml
# 关键服务：允许抢占
critical-services:
  preemptionPolicy: PreemptLowerPriority
  
# 批处理任务：不抢占其他任务
batch-jobs:
  preemptionPolicy: Never
  
# 测试任务：可被抢占但不抢占他人
test-workloads:
  value: 100
  preemptionPolicy: Never
```

### 3. 资源配合策略

```yaml
# 高优先级 + 资源保证
high-priority-guaranteed:
  priorityClassName: high-priority
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 500m        # 与 requests 相同，保证资源
      memory: 1Gi

# 低优先级 + 最佳努力
low-priority-besteffort:
  priorityClassName: low-priority
  # 不设置 resources，使用最佳努力 QoS
```

### 4. 环境隔离策略

```yaml
# 生产环境：高优先级，严格资源限制
production:
  priorityClassName: production-high
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi

# 开发环境：低优先级，宽松限制
development:
  priorityClassName: development-priority
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

### 5. 故障恢复优先级

```yaml
# 紧急恢复任务
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: emergency-recovery
value: 2500
globalDefault: false
description: "紧急故障恢复任务的最高优先级"
preemptionPolicy: PreemptLowerPriority

---
# 在紧急情况下使用
apiVersion: v1
kind: Pod
metadata:
  name: emergency-repair
  labels:
    purpose: emergency
spec:
  priorityClassName: emergency-recovery
  containers:
  - name: repair-tool
    image: emergency-toolkit
  restartPolicy: Never
```

### 6. 资源配额集成

```yaml
# 按优先级分配资源配额
apiVersion: v1
kind: ResourceQuota
metadata:
  name: high-priority-quota
  namespace: production
spec:
  hard:
    requests.cpu: 10000m
    requests.memory: 20Gi
    pods: 50
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["high-priority", "business-critical"]

---
# 低优先级资源配额
apiVersion: v1
kind: ResourceQuota
metadata:
  name: low-priority-quota
  namespace: production
spec:
  hard:
    requests.cpu: 5000m
    requests.memory: 10Gi
    pods: 100
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["low-priority", "best-effort"]
```

### 7. 文档化和标准化

```yaml
metadata:
  annotations:
    priority-guidelines: |
      使用指南：
      - system-critical: 仅用于 DNS、网络、存储等系统组件
      - business-critical: 用于核心业务服务，如支付、认证
      - high-priority: 用于重要但非关键的服务
      - normal-priority: 标准应用的默认选择
      - low-priority: 用于批处理、测试等可中断任务
    approval-required: "true"
    contact: "platform-team@example.com"
```