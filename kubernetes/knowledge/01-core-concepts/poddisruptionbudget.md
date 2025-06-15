# PodDisruptionBudget 资源详解

## 概述

PodDisruptionBudget (PDB) 是 Kubernetes 中用于限制同时被干扰的 Pod 数量的资源。它确保在执行维护操作（如节点升级、Pod 驱逐等）时，应用程序能够维持最低的可用性水平。

## 核心特性

### 1. 可用性保障
- 确保应用程序的最小可用副本数
- 防止过多 Pod 同时被删除
- 维护服务的连续性

### 2. 自愿中断控制
- 控制计划内的维护操作
- 限制同时驱逐的 Pod 数量
- 配合集群升级和节点维护

### 3. 灵活配置
- 支持绝对数量和百分比
- 基于标签选择器匹配 Pod
- 命名空间级别作用域

## PodDisruptionBudget 配置详解

### 基础配置示例

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
  namespace: production
spec:
  minAvailable: 2             # 最小可用 Pod 数量
  selector:                   # Pod 选择器
    matchLabels:
      app: web-app
```

### 完整配置示例

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: comprehensive-pdb
  namespace: production
  labels:
    app: web-service
    tier: frontend
    environment: production
  annotations:
    description: "Web 服务的 Pod 中断预算"
    owner: "frontend-team@example.com"
    last-updated: "2023-12-01"
spec:
  minAvailable: 3             # 最小可用数量
  # maxUnavailable: 1         # 最大不可用数量（与 minAvailable 二选一）
  selector:
    matchLabels:
      app: web-service
      tier: frontend
    matchExpressions:
    - key: environment
      operator: In
      values: ["production"]
```

## 配置选项详解

### 1. minAvailable（最小可用）

```yaml
# 绝对数量
spec:
  minAvailable: 3             # 至少保持 3 个 Pod 可用
  selector:
    matchLabels:
      app: database

---
# 百分比
spec:
  minAvailable: 50%           # 至少保持 50% 的 Pod 可用
  selector:
    matchLabels:
      app: web-frontend
```

### 2. maxUnavailable（最大不可用）

```yaml
# 绝对数量
spec:
  maxUnavailable: 1           # 最多允许 1 个 Pod 不可用
  selector:
    matchLabels:
      app: api-server

---
# 百分比
spec:
  maxUnavailable: 25%         # 最多允许 25% 的 Pod 不可用
  selector:
    matchLabels:
      app: worker-nodes
```

### 3. 选择器配置

```yaml
spec:
  minAvailable: 2
  selector:
    # 标签匹配
    matchLabels:
      app: my-app
      version: v1.0
    
    # 表达式匹配
    matchExpressions:
    - key: tier
      operator: In
      values: ["frontend", "backend"]
    - key: environment
      operator: NotIn
      values: ["development"]
```

## 不同应用场景配置

### 1. Web 前端服务

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: frontend-pdb
  namespace: production
spec:
  minAvailable: 2             # 至少保持 2 个前端 Pod
  selector:
    matchLabels:
      app: frontend
      tier: web
```

### 2. 数据库服务

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: database-pdb
  namespace: production
spec:
  maxUnavailable: 1           # 数据库集群最多允许 1 个节点不可用
  selector:
    matchLabels:
      app: postgres
      role: database
```

### 3. 微服务应用

```yaml
# API 网关服务
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-gateway-pdb
  namespace: production
spec:
  minAvailable: 80%           # 保持 80% 可用性
  selector:
    matchLabels:
      app: api-gateway

---
# 用户服务
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: user-service-pdb
  namespace: production
spec:
  maxUnavailable: 25%         # 最多 25% 不可用
  selector:
    matchLabels:
      app: user-service

---
# 订单服务
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: order-service-pdb
  namespace: production
spec:
  minAvailable: 3             # 至少 3 个实例
  selector:
    matchLabels:
      app: order-service
```

### 4. 批处理任务

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: batch-job-pdb
  namespace: data-processing
spec:
  minAvailable: 1             # 至少保持 1 个任务运行
  selector:
    matchLabels:
      app: data-processor
      type: batch
```

## 与工作负载资源配合

### 1. 与 Deployment 配合

```yaml
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production
spec:
  replicas: 5                 # 5 个副本
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
        version: v1.0
    spec:
      containers:
      - name: web
        image: nginx:latest

---
# 对应的 PDB
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
  namespace: production
spec:
  minAvailable: 3             # 5 个副本中至少保持 3 个可用
  selector:
    matchLabels:
      app: web-app
```

### 2. 与 StatefulSet 配合

```yaml
# StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  namespace: production
spec:
  serviceName: database
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
        role: primary
    spec:
      containers:
      - name: postgres
        image: postgres:13

---
# 对应的 PDB
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: database-pdb
  namespace: production
spec:
  maxUnavailable: 1           # 3 个数据库节点最多 1 个不可用
  selector:
    matchLabels:
      app: database
```

### 3. 与 DaemonSet 配合

```yaml
# DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
  namespace: logging
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
        component: logging
    spec:
      containers:
      - name: fluentd
        image: fluentd:latest

---
# 对应的 PDB
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: log-collector-pdb
  namespace: logging
spec:
  maxUnavailable: 10%         # 最多 10% 的日志收集器不可用
  selector:
    matchLabels:
      app: log-collector
```

## 高可用配置策略

### 1. 关键服务高可用

```yaml
# 支付服务 - 零停机
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: payment-service-pdb
  namespace: production
spec:
  minAvailable: 100%          # 支付服务不允许中断
  selector:
    matchLabels:
      app: payment-service

---
# 认证服务 - 高可用
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: auth-service-pdb
  namespace: production
spec:
  minAvailable: 90%           # 认证服务保持 90% 可用
  selector:
    matchLabels:
      app: auth-service
```

### 2. 分层可用性策略

```yaml
# 核心层 - 最高可用性
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: core-services-pdb
  namespace: production
spec:
  minAvailable: 90%
  selector:
    matchLabels:
      tier: core

---
# 业务层 - 高可用性
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: business-services-pdb
  namespace: production
spec:
  minAvailable: 75%
  selector:
    matchLabels:
      tier: business

---
# 支撑层 - 标准可用性
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: support-services-pdb
  namespace: production
spec:
  maxUnavailable: 50%
  selector:
    matchLabels:
      tier: support
```

## 维护窗口配置

### 1. 滚动维护策略

```yaml
# 分批维护的 PDB
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: rolling-maintenance-pdb
  namespace: production
  annotations:
    maintenance-strategy: "rolling"
    batch-size: "25%"
spec:
  maxUnavailable: 25%         # 每次最多维护 25% 的 Pod
  selector:
    matchLabels:
      app: web-cluster
```

### 2. 维护窗口时间配置

```yaml
# 结合 CronJob 的维护策略
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: scheduled-maintenance-pdb
  namespace: production
  annotations:
    maintenance-window: "02:00-04:00 UTC"
    maintenance-day: "Sunday"
spec:
  # 在维护窗口外保持高可用
  minAvailable: 80%
  selector:
    matchLabels:
      maintenance-group: standard
```

## 监控和管理

### 1. 查看 PDB 状态

```bash
# 查看 PodDisruptionBudget
kubectl get poddisruptionbudget
kubectl get pdb               # 简写

# 查看详细信息
kubectl describe pdb web-app-pdb

# 查看特定命名空间
kubectl get pdb -n production
```

### 2. PDB 状态监控

```bash
# 查看 PDB 状态详情
kubectl describe pdb web-app-pdb -n production

# 输出示例：
# Name:           web-app-pdb
# Namespace:      production
# Min available:  3
# Selector:       app=web-app
# Status:
#     Allowed disruptions:  2
#     Current:             5
#     Desired:             5
#     Total:               5
```

### 3. 驱逐操作验证

```bash
# 测试驱逐操作
kubectl drain node-1 --dry-run

# 实际驱逐（会遵守 PDB）
kubectl drain node-1 --ignore-daemonsets --delete-emptydir-data

# 查看驱逐相关事件
kubectl get events --field-selector reason=EvictionThresholdMet
```

## 故障排除

### 1. 常见问题

```bash
# 1. PDB 阻止了驱逐操作
# 检查 PDB 配置是否合理
kubectl describe pdb web-app-pdb

# 2. 选择器不匹配
# 验证 Pod 标签和 PDB 选择器
kubectl get pods --show-labels
kubectl describe pdb web-app-pdb

# 3. 副本数不足
# 检查 Deployment 副本数是否满足 PDB 要求
kubectl get deployment web-app
```

### 2. 调试命令

```bash
# 查看哪些 Pod 被 PDB 保护
kubectl get pods -l app=web-app -o wide

# 检查节点驱逐状态
kubectl get nodes
kubectl describe node node-1

# 查看 PDB 相关事件
kubectl get events --field-selector involvedObject.kind=PodDisruptionBudget
```

## 最佳实践

### 1. 合理设置可用性水平

```yaml
# 根据服务重要性设置不同的可用性要求
critical-services:
  minAvailable: 90-100%       # 关键服务

important-services:
  minAvailable: 75-80%        # 重要服务

standard-services:
  maxUnavailable: 25-50%      # 标准服务

background-jobs:
  maxUnavailable: 75%         # 后台任务
```

### 2. 避免过于严格的配置

```yaml
# 避免：过于严格的 PDB
spec:
  minAvailable: 100%          # 可能导致无法维护

# 推荐：合理的 PDB
spec:
  minAvailable: 80%           # 允许部分 Pod 不可用进行维护
```

### 3. 与副本数匹配

```yaml
# 确保副本数足够支持 PDB 要求
deployment-replicas: 5
pdb-min-available: 3          # 5-3=2，允许最多 2 个 Pod 同时维护

# 避免：副本数不足
deployment-replicas: 2
pdb-min-available: 2          # 无法进行任何维护操作
```

### 4. 分环境配置

```yaml
# 生产环境：严格的 PDB
production:
  minAvailable: 80%

# 测试环境：宽松的 PDB
testing:
  maxUnavailable: 50%

# 开发环境：无 PDB 或极宽松
development:
  maxUnavailable: 100%        # 允许完全停机
```

### 5. 监控和告警

```yaml
# Prometheus 监控规则
groups:
- name: pod-disruption-budget
  rules:
  - alert: PDBViolation
    expr: |
      kube_poddisruptionbudget_status_current_healthy{} 
      < 
      kube_poddisruptionbudget_status_desired_healthy{}
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "PDB 违规：{{ $labels.poddisruptionbudget }}"
      description: "命名空间 {{ $labels.namespace }} 中的 PDB {{ $labels.poddisruptionbudget }} 当前健康 Pod 数低于期望值"

  - alert: PDBBlockingMaintenance
    expr: |
      kube_poddisruptionbudget_status_disruptions_allowed{} == 0
    for: 10m
    labels:
      severity: info
    annotations:
      summary: "PDB 阻止维护操作"
      description: "PDB {{ $labels.poddisruptionbudget }} 当前不允许任何中断，可能阻止维护操作"
```

### 6. 文档化和标准化

```yaml
metadata:
  annotations:
    description: "服务的 Pod 中断预算配置"
    business-impact: "high"
    maintenance-contact: "platform-team@example.com"
    review-schedule: "quarterly"
    compliance-requirement: "99.9% uptime SLA"
```

### 7. 自动化验证

```bash
#!/bin/bash
# PDB 配置验证脚本

# 检查是否有足够的副本支持 PDB
check_pdb_feasibility() {
    local namespace=$1
    local app=$2
    
    replicas=$(kubectl get deployment $app -n $namespace -o jsonpath='{.spec.replicas}')
    min_available=$(kubectl get pdb -n $namespace -l app=$app -o jsonpath='{.items[0].spec.minAvailable}')
    
    if [[ $min_available =~ % ]]; then
        # 处理百分比情况
        percentage=${min_available%\%}
        required=$((replicas * percentage / 100))
    else
        required=$min_available
    fi
    
    if [ $required -ge $replicas ]; then
        echo "WARNING: PDB 配置可能过于严格"
        echo "副本数: $replicas, 最小可用: $min_available (需要: $required)"
    fi
}
```