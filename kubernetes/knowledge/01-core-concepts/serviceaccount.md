# ServiceAccount 资源详解

## 概述

ServiceAccount 为运行在 Pod 中的进程提供身份标识。它是 Kubernetes 安全模型的重要组成部分，用于控制 Pod 对 API Server 的访问权限。

## 核心特性

### 1. 身份认证
- 为 Pod 提供身份标识
- 自动生成访问令牌
- 与 RBAC 集成

### 2. 权限控制
- 限制 API 访问权限
- 支持细粒度授权
- 最小权限原则

### 3. 自动挂载
- 令牌自动挂载到 Pod
- 透明的身份验证
- 可配置挂载行为

## ServiceAccount 配置详解

### 基础配置示例

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service-account
  namespace: default
  labels:
    app: myapp
    component: backend
  annotations:
    description: "Service account for backend pods"
automountServiceAccountToken: true    # 是否自动挂载令牌
secrets:                             # 关联的 Secret
- name: my-secret
imagePullSecrets:                    # 镜像拉取 Secret
- name: registry-secret
```

### 完整配置示例

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web-service-account
  namespace: production
  labels:
    app: web
    tier: frontend
    environment: production
  annotations:
    kubernetes.io/description: "Service account for web application"
    security.alpha.kubernetes.io/sysctls: kernel.shm_rmid_forced
automountServiceAccountToken: true
secrets:
- name: web-app-secret
imagePullSecrets:
- name: docker-registry-secret
- name: private-registry-secret
```

## 令牌管理

### 1. 自动令牌生成

```bash
# 查看 ServiceAccount
kubectl get serviceaccount my-service-account

# 查看自动生成的 Secret
kubectl get secrets | grep my-service-account

# 查看令牌内容
kubectl describe secret my-service-account-token-xxxxx
```

### 2. 手动管理令牌

```yaml
# 创建长期令牌 Secret
apiVersion: v1
kind: Secret
metadata:
  name: manual-token
  annotations:
    kubernetes.io/service-account.name: my-service-account
type: kubernetes.io/service-account-token

---
# 在 ServiceAccount 中引用
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service-account
secrets:
- name: manual-token
```

### 3. 投影令牌（推荐）

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: token-projected-pod
spec:
  serviceAccountName: my-service-account
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: token
      mountPath: /var/run/secrets/tokens
  volumes:
  - name: token
    projected:
      sources:
      - serviceAccountToken:
          path: token
          expirationSeconds: 3600    # 1 小时过期
          audience: api              # 目标受众
```

## RBAC 集成

### 1. 基本权限配置

```yaml
# 创建 Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]

---
# 绑定到 ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: ServiceAccount
  name: my-service-account
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### 2. 集群级权限

```yaml
# 集群角色
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]

---
# 集群角色绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node-reader-binding
subjects:
- kind: ServiceAccount
  name: monitoring-sa
  namespace: monitoring
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

## 典型使用场景

### 1. 应用程序访问 API

```yaml
# ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-client-sa
  namespace: default

---
# 权限配置
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: api-client-role
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "update"]

---
# 权限绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: api-client-binding
subjects:
- kind: ServiceAccount
  name: api-client-sa
roleRef:
  kind: Role
  name: api-client-role
  apiGroup: rbac.authorization.k8s.io

---
# Pod 使用
apiVersion: v1
kind: Pod
metadata:
  name: api-client-pod
spec:
  serviceAccountName: api-client-sa
  containers:
  - name: client
    image: kubectl:latest
```

### 2. 监控服务权限

```yaml
# 监控 ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus-sa
  namespace: monitoring

---
# 监控权限
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-role
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-binding
subjects:
- kind: ServiceAccount
  name: prometheus-sa
  namespace: monitoring
roleRef:
  kind: ClusterRole
  name: prometheus-role
  apiGroup: rbac.authorization.k8s.io
```

### 3. CI/CD 部署权限

```yaml
# CI/CD ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployer-sa
  namespace: ci-cd

---
# 部署权限
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: deployer-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["*"]
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["*"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: deployer-binding
subjects:
- kind: ServiceAccount
  name: deployer-sa
  namespace: ci-cd
roleRef:
  kind: ClusterRole
  name: deployer-role
  apiGroup: rbac.authorization.k8s.io
```

## 安全配置

### 1. 禁用自动挂载

```yaml
# 全局禁用
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secure-sa
automountServiceAccountToken: false

---
# Pod 级别禁用
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  serviceAccountName: secure-sa
  automountServiceAccountToken: false  # 覆盖 SA 设置
  containers:
  - name: app
    image: nginx
```

### 2. 最小权限原则

```yaml
# 只读权限示例
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: readonly-role
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]      # 只有读权限
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]                       # 只能读日志
```

### 3. 网络策略配合

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sa-network-policy
spec:
  podSelector:
    matchLabels:
      sa: restricted-sa
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
  egress:
  - to:
    - podSelector:
        matchLabels:
          role: database
```

## 管理和监控

### 1. 查看 ServiceAccount

```bash
# 列出 ServiceAccount
kubectl get serviceaccounts
kubectl get sa                    # 简写

# 查看详细信息
kubectl describe serviceaccount my-service-account

# 查看关联的 Secret
kubectl get secret -o jsonpath='{.items[?(@.type=="kubernetes.io/service-account-token")].metadata.name}'
```

### 2. 测试权限

```bash
# 检查权限
kubectl auth can-i get pods --as=system:serviceaccount:default:my-service-account

# 检查特定资源权限
kubectl auth can-i create deployments --as=system:serviceaccount:default:my-service-account

# 列出所有权限
kubectl auth can-i --list --as=system:serviceaccount:default:my-service-account
```

### 3. 故障排除

```bash
# 检查 Pod 中的令牌
kubectl exec pod-name -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

# 验证令牌
kubectl exec pod-name -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/

# 检查 RBAC 绑定
kubectl get rolebindings,clusterrolebindings --all-namespaces -o wide | grep my-service-account
```

## 最佳实践

### 1. 命名规范

```yaml
metadata:
  name: app-component-sa          # 应用-组件-sa
  # 例如：web-frontend-sa, api-backend-sa
```

### 2. 按用途分离

```yaml
# 应用运行时 SA
metadata:
  name: app-runtime-sa
  labels:
    purpose: runtime

# 初始化 SA
metadata:
  name: app-init-sa
  labels:
    purpose: initialization

# 监控 SA
metadata:
  name: app-monitoring-sa
  labels:
    purpose: monitoring
```

### 3. 环境隔离

```yaml
# 生产环境 SA
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prod-app-sa
  namespace: production
  labels:
    environment: production
automountServiceAccountToken: true

# 开发环境 SA（更宽松）
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dev-app-sa
  namespace: development
  labels:
    environment: development
automountServiceAccountToken: true
```

### 4. 安全加固

```yaml
# 1. 使用投影令牌
volumes:
- name: kube-api-access
  projected:
    sources:
    - serviceAccountToken:
        expirationSeconds: 3600
        path: token
    - configMap:
        name: kube-root-ca.crt
        items:
        - key: ca.crt
          path: ca.crt
    - downwardAPI:
        items:
        - path: namespace
          fieldRef:
            fieldPath: metadata.namespace

# 2. 定期轮换密钥
# 3. 监控访问日志
# 4. 使用网络策略限制
```