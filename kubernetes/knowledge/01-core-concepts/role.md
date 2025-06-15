# Role 和 ClusterRole 资源详解

## 概述

Role 和 ClusterRole 是 Kubernetes RBAC (Role-Based Access Control) 系统中定义权限的资源。Role 作用于命名空间级别，ClusterRole 作用于集群级别。

## 核心特性

### 1. 权限定义
- 定义可访问的资源和操作
- 支持细粒度权限控制
- 基于动词的权限模型

### 2. 作用范围
- Role: 命名空间级别权限
- ClusterRole: 集群级别权限
- 支持权限聚合

### 3. 可重用性
- 权限模板化
- 继承和组合
- 标准化权限管理

## Role 配置详解

### 基础 Role 配置

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default           # 作用的命名空间
  name: pod-reader
  labels:
    purpose: basic-access
rules:
- apiGroups: [""]             # 核心 API 组
  resources: ["pods"]         # 资源类型
  verbs: ["get", "list", "watch"]  # 允许的操作
- apiGroups: [""]
  resources: ["pods/log"]     # 子资源
  verbs: ["get"]
```

### 完整 Role 配置

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: developer-role
  labels:
    team: backend
    environment: production
  annotations:
    description: "开发者权限，包含 Pod、Service、ConfigMap 的读写权限"
rules:
# 核心资源权限
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# 应用相关权限
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# 扩展资源权限
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# 子资源权限
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "create"]

# 特定资源名称权限
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-secret", "db-secret"]  # 只能访问特定 Secret
  verbs: ["get"]
```

## ClusterRole 配置详解

### 基础 ClusterRole 配置

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
  labels:
    purpose: monitoring
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["nodes/status"]
  verbs: ["get"]
```

### 完整 ClusterRole 配置

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-admin-custom
  labels:
    purpose: administration
    tier: admin
  annotations:
    description: "自定义集群管理员权限"
rules:
# 所有核心资源的完整权限
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]

# 非资源 URL 权限
- nonResourceURLs: ["*"]
  verbs: ["*"]
```

### 监控专用 ClusterRole

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-reader
  labels:
    purpose: monitoring
rules:
# 节点信息权限
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "nodes/stats", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]

# 扩展资源权限
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch"]

# 网络资源权限
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]

# 指标权限
- nonResourceURLs: ["/metrics", "/metrics/*"]
  verbs: ["get"]
```

## 权限规则详解

### API 组配置

```yaml
rules:
# 核心 API 组（空字符串）
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list"]

# 应用 API 组
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "create", "update"]

# 扩展 API 组
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list"]

# 网络 API 组
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list", "create"]

# 批处理 API 组
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "create"]

# 所有 API 组
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

### 动词权限详解

```yaml
rules:
# 只读权限
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

# 创建权限
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create"]

# 更新权限
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["update", "patch"]

# 删除权限
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["delete", "deletecollection"]

# 完整权限
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["*"]

# 特殊动词
- apiGroups: [""]
  resources: ["pods/exec"]        # exec 子资源
  verbs: ["create"]
- apiGroups: [""]
  resources: ["pods/log"]         # log 子资源
  verbs: ["get"]
```

### 资源名称限制

```yaml
rules:
# 限制特定资源名称
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-config", "db-credentials"]
  verbs: ["get", "list"]

# 限制特定 ConfigMap
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["app-config", "feature-flags"]
  verbs: ["get", "update"]
```

## 角色聚合

### 聚合 ClusterRole

```yaml
# 基础角色
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: base-reader
  labels:
    rbac.example.com/aggregate-to-custom: "true"
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]

---
# 扩展角色
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: app-manager
  labels:
    rbac.example.com/aggregate-to-custom: "true"
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "delete"]

---
# 聚合角色
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: custom-admin
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.example.com/aggregate-to-custom: "true"
rules: []  # 规则由聚合自动填充
```

## 典型权限模板

### 1. 只读用户

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: readonly-user
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "endpoints"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
```

### 2. 开发者权限

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "create"]
```

### 3. CI/CD 权限

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cicd-deployer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets", "namespaces"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
```

### 4. 监控服务权限

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-service
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets"]
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
```

## 最佳实践

### 1. 最小权限原则

```yaml
# 好的实践：只给必要权限
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: specific-access
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]        # 只要读权限

# 避免的实践：过度权限
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: excessive-access
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]                  # 避免通配符权限
```

### 2. 角色命名规范

```yaml
metadata:
  name: namespace-role-purpose  # 命名空间-角色-用途
  # 例如：prod-developer, test-readonly, monitoring-reader
```

### 3. 标签和注解

```yaml
metadata:
  labels:
    team: backend               # 团队
    environment: production     # 环境
    purpose: development        # 用途
  annotations:
    description: "开发团队在生产环境的权限"
    contact: "backend-team@example.com"
    last-updated: "2023-12-01"
```

### 4. 定期审计

```bash
# 查看角色权限
kubectl describe role developer -n production
kubectl describe clusterrole monitoring-reader

# 审计权限绑定
kubectl get rolebindings,clusterrolebindings --all-namespaces
kubectl auth can-i --list --as=system:serviceaccount:default:developer
```