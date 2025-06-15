# Namespace 资源详解

## 概述

Namespace 是 Kubernetes 中用于资源隔离和组织的机制，提供了一种在同一集群中划分资源的方法。它为多租户环境提供了逻辑分区，使不同的团队或项目可以在同一个集群中安全地共存。

## 核心特性

### 1. 资源隔离
- 逻辑分组和隔离资源
- 避免资源名称冲突
- 提供安全边界

### 2. 访问控制
- RBAC 权限控制
- 网络策略隔离
- 资源配额限制

### 3. 多租户支持
- 团队或项目隔离
- 环境分离（开发、测试、生产）
- 成本分摊和资源管理

## Namespace 配置详解

### 基础配置示例

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production                # Namespace 名称
  labels:                         # 标签
    environment: production
    team: backend
    cost-center: engineering
  annotations:                    # 注解
    description: "生产环境命名空间"
    contact: "backend-team@example.com"
    created-by: "platform-team"
    budget: "10000"
spec:
  finalizers:                     # 终结器
  - kubernetes                    # 确保资源清理
status:
  phase: Active                   # 状态：Active、Terminating
```

### 创建 Namespace 的方式

#### 1. 使用 kubectl 命令

```bash
# 创建基本 Namespace
kubectl create namespace development

# 创建带标签的 Namespace
kubectl create namespace staging --labels environment=staging,team=frontend

# 从 YAML 文件创建
kubectl apply -f namespace.yaml
```

#### 2. 声明式创建

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: development
    team: frontend
    version: v1
```

## 系统默认 Namespace

### 1. default
```yaml
# 默认命名空间
apiVersion: v1
kind: Namespace
metadata:
  name: default
  labels:
    kubernetes.io/metadata.name: default
```

**特点：**
- 用户创建资源的默认位置
- 不指定 namespace 时的默认选择
- 通常不建议在生产环境中使用

### 2. kube-system

```yaml
# 系统组件命名空间
apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
  labels:
    kubernetes.io/metadata.name: kube-system
```

**特点：**
- 存放 Kubernetes 系统组件
- CoreDNS、kube-proxy、CNI 等
- 需要特殊权限访问

### 3. kube-public

```yaml
# 公共命名空间
apiVersion: v1
kind: Namespace
metadata:
  name: kube-public
  labels:
    kubernetes.io/metadata.name: kube-public
```

**特点：**
- 所有用户都可读（包括未认证用户）
- 通常用于存放集群信息
- cluster-info ConfigMap

### 4. kube-node-lease

```yaml
# 节点租约命名空间
apiVersion: v1
kind: Namespace
metadata:
  name: kube-node-lease
  labels:
    kubernetes.io/metadata.name: kube-node-lease
```

**特点：**
- 存储节点心跳信息
- 提高节点心跳性能
- Kubernetes 1.14+ 引入

## 资源配额管理

### 1. ResourceQuota 配置

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: development
spec:
  hard:
    # 计算资源配额
    requests.cpu: "10"           # CPU 请求总量：10 核
    requests.memory: 20Gi        # 内存请求总量：20GB
    limits.cpu: "20"             # CPU 限制总量：20 核
    limits.memory: 40Gi          # 内存限制总量：40GB
    
    # 存储资源配额
    requests.storage: 100Gi      # 存储请求总量：100GB
    persistentvolumeclaims: "10" # PVC 数量限制：10 个
    
    # 对象数量配额
    pods: "100"                  # Pod 数量限制：100 个
    services: "20"               # Service 数量限制：20 个
    secrets: "50"                # Secret 数量限制：50 个
    configmaps: "50"             # ConfigMap 数量限制：50 个
    replicationcontrollers: "10" # RC 数量限制：10 个
    
    # 扩展资源配额
    count/deployments.apps: "20" # Deployment 数量限制：20 个
    count/jobs.batch: "10"       # Job 数量限制：10 个
    
    # 特定存储类配额
    gold.storageclass.storage.k8s.io/requests.storage: 50Gi
```

### 2. 分类配额示例

```yaml
# 开发环境配额
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: development
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "20"

---
# 生产环境配额
apiVersion: v1
kind: ResourceQuota
metadata:
  name: prod-quota
  namespace: production
spec:
  hard:
    requests.cpu: "50"
    requests.memory: 100Gi
    limits.cpu: "100"
    limits.memory: 200Gi
    pods: "500"
    services: "100"
    persistentvolumeclaims: "50"
```

## 限制范围 (LimitRange)

### 1. 基本 LimitRange 配置

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: limit-range
  namespace: development
spec:
  limits:
  # Container 限制
  - type: Container
    default:                     # 默认限制
      cpu: 500m
      memory: 512Mi
    defaultRequest:              # 默认请求
      cpu: 100m
      memory: 128Mi
    max:                         # 最大限制
      cpu: 2000m
      memory: 2Gi
    min:                         # 最小限制
      cpu: 50m
      memory: 64Mi
    maxLimitRequestRatio:        # 最大比率
      cpu: 4                     # limit/request 不能超过 4
      memory: 3
  
  # Pod 限制
  - type: Pod
    max:
      cpu: 4000m                 # Pod 总 CPU 限制
      memory: 4Gi                # Pod 总内存限制
    min:
      cpu: 100m
      memory: 128Mi
  
  # PVC 限制
  - type: PersistentVolumeClaim
    max:
      storage: 10Gi              # 最大存储
    min:
      storage: 1Gi               # 最小存储
```

### 2. 存储类限制

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: storage-limit-range
  namespace: development
spec:
  limits:
  - type: PersistentVolumeClaim
    max:
      storage: 50Gi
    min:
      storage: 1Gi
  # 特定存储类限制
  - type: PersistentVolumeClaim
    max:
      storage: 100Gi
    min:
      storage: 10Gi
    selector:
      matchLabels:
        storageClassName: fast-ssd
```

## 网络策略隔离

### 1. 默认拒绝所有流量

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}                # 选择所有 Pod
  policyTypes:
  - Ingress
  - Egress
  # 没有规则 = 拒绝所有
```

### 2. 命名空间间隔离

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: namespace-isolation
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: production       # 只允许同命名空间流量
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: production
  - to: {}                       # 允许出站到集群外部
    ports:
    - protocol: TCP
      port: 53                   # DNS
    - protocol: UDP
      port: 53
```

### 3. 跨命名空间访问控制

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-access
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: api-server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend          # 允许 frontend 命名空间访问
    - podSelector:
        matchLabels:
          app: web-app
    ports:
    - protocol: TCP
      port: 8080
```

## RBAC 权限控制

### 1. 命名空间级别角色

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: developer-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "delete"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "create"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: development
subjects:
- kind: User
  name: developer@example.com
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
```

### 2. 只读访问权限

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: readonly-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: readonly-binding
  namespace: production
subjects:
- kind: User
  name: auditor@example.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: readonly-role
  apiGroup: rbac.authorization.k8s.io
```

## Namespace 生命周期管理

### 1. 创建和配置

```bash
# 创建命名空间
kubectl create namespace my-namespace

# 设置默认命名空间
kubectl config set-context --current --namespace=my-namespace

# 查看当前命名空间
kubectl config view --minify | grep namespace:
```

### 2. 资源管理

```bash
# 查看命名空间中的所有资源
kubectl get all -n my-namespace

# 查看特定资源
kubectl get pods,services -n my-namespace

# 跨命名空间操作
kubectl get pods --all-namespaces
kubectl get pods -A  # 简写
```

### 3. 删除和清理

```bash
# 删除命名空间（会删除其中所有资源）
kubectl delete namespace my-namespace

# 强制删除（如果卡在 Terminating 状态）
kubectl delete namespace my-namespace --force --grace-period=0
```

### 4. 终结器处理

```bash
# 查看命名空间状态
kubectl get namespace my-namespace -o yaml

# 移除终结器（紧急情况）
kubectl patch namespace my-namespace -p '{"metadata":{"finalizers":null}}' --type=merge
```

## 监控和可观测性

### 1. 命名空间状态监控

```bash
# 查看命名空间状态
kubectl get namespaces

# 查看详细信息
kubectl describe namespace production

# 查看资源使用情况
kubectl top pods -n production
kubectl top nodes
```

### 2. 监控指标

```yaml
# 关键监控指标
- kube_namespace_status_phase: 命名空间状态
- kube_resourcequota: 资源配额使用情况
- kube_limitrange: 限制范围配置
- namespace_memory_usage_bytes: 命名空间内存使用
- namespace_cpu_usage_seconds_total: 命名空间 CPU 使用
```

### 3. 告警规则

```yaml
# Prometheus 告警规则
groups:
- name: namespace
  rules:
  - alert: NamespaceResourceQuotaExceeded
    expr: kube_resourcequota{type="used"} / kube_resourcequota{type="hard"} > 0.9
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Namespace resource quota almost exceeded"
      
  - alert: NamespaceTerminating
    expr: kube_namespace_status_phase{phase="Terminating"} == 1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Namespace stuck in terminating state"
```

## 最佳实践

### 1. 命名规范

```yaml
metadata:
  name: team-environment-purpose  # 团队-环境-用途
  # 示例：
  # frontend-prod-web
  # backend-dev-api
  # data-staging-analytics
  labels:
    team: backend                 # 团队标识
    environment: production       # 环境标识
    purpose: api                  # 用途标识
    cost-center: engineering      # 成本中心
    version: v1                   # 版本
```

### 2. 环境隔离

```yaml
# 开发环境
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: development
    tier: dev
---
# 测试环境
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
    tier: staging
---
# 生产环境
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    tier: prod
```

### 3. 资源配置

```yaml
# 为每个命名空间设置适当的资源配额
development:
  cpu: 4 cores
  memory: 8Gi
  storage: 50Gi
  pods: 50

staging:
  cpu: 8 cores
  memory: 16Gi
  storage: 100Gi
  pods: 100

production:
  cpu: 50 cores
  memory: 100Gi
  storage: 1Ti
  pods: 500
```

### 4. 安全配置

```yaml
# 1. 启用网络策略
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

# 2. 配置 RBAC
# 最小权限原则
# 定期审核权限

# 3. 使用 Pod Security Standards
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 5. 故障排除

```bash
# 1. 命名空间卡在 Terminating 状态
kubectl get namespace stuck-namespace -o yaml
kubectl patch namespace stuck-namespace -p '{"metadata":{"finalizers":null}}' --type=merge

# 2. 资源配额问题
kubectl describe resourcequota -n my-namespace
kubectl get events -n my-namespace --sort-by=.metadata.creationTimestamp

# 3. 权限问题
kubectl auth can-i create pods --namespace=my-namespace
kubectl auth can-i create pods --namespace=my-namespace --as=user@example.com

# 4. 网络策略问题
kubectl get networkpolicies -n my-namespace
kubectl describe networkpolicy policy-name -n my-namespace
```

### 6. 成本优化

```yaml
# 设置合理的资源配额
spec:
  hard:
    requests.cpu: "10"          # 根据实际需求设置
    requests.memory: 20Gi
    limits.cpu: "20"            # 防止资源浪费
    limits.memory: 40Gi

# 使用标签进行成本分摊
metadata:
  labels:
    cost-center: engineering
    project: web-platform
    owner: backend-team
```

## 高级特性

### 1. 自动命名空间管理

```yaml
# 使用 Operator 自动管理命名空间
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace-template
data:
  template: |
    apiVersion: v1
    kind: Namespace
    metadata:
      name: "${TEAM}-${ENVIRONMENT}"
      labels:
        team: "${TEAM}"
        environment: "${ENVIRONMENT}"
        managed-by: namespace-operator
    ---
    apiVersion: v1
    kind: ResourceQuota
    metadata:
      name: default-quota
      namespace: "${TEAM}-${ENVIRONMENT}"
    spec:
      hard:
        requests.cpu: "${CPU_REQUEST}"
        requests.memory: "${MEMORY_REQUEST}"
```

### 2. 命名空间联邦

```yaml
# 多集群命名空间管理
apiVersion: types.kubefed.io/v1beta1
kind: FederatedNamespace
metadata:
  name: multi-cluster-namespace
  namespace: kubefed-system
spec:
  template:
    metadata:
      labels:
        environment: production
  placement:
    clusters:
    - name: cluster1
    - name: cluster2
  overrides:
  - clusterName: cluster1
    clusterOverrides:
    - path: "/metadata/labels/region"
      value: "us-west"
```

### 3. 命名空间准入控制

```yaml
# ValidatingAdmissionWebhook 示例
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: namespace-validator
webhooks:
- name: namespace.validator.example.com
  clientConfig:
    service:
      name: namespace-validator
      namespace: default
      path: "/validate"
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["namespaces"]
  admissionReviewVersions: ["v1", "v1beta1"]
```