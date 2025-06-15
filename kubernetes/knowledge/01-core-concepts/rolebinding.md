# RoleBinding 和 ClusterRoleBinding 资源详解

## 概述

RoleBinding 和 ClusterRoleBinding 用于将 Role 或 ClusterRole 中定义的权限绑定到用户、组或 ServiceAccount。它们是 RBAC 权限系统中的绑定层。

## 核心特性

### 1. 权限绑定
- 将角色权限授予主体
- 支持多种主体类型
- 灵活的权限分配

### 2. 作用范围
- RoleBinding: 命名空间级别绑定
- ClusterRoleBinding: 集群级别绑定
- 跨命名空间权限管理

### 3. 主体类型
- User: 用户账户
- Group: 用户组
- ServiceAccount: 服务账户

## RoleBinding 配置详解

### 基础 RoleBinding 配置

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:                        # 绑定的主体
- kind: User
  name: jane                     # 用户名
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: default                  # ServiceAccount 名称
  namespace: default             # ServiceAccount 所在命名空间
roleRef:                         # 引用的角色
  kind: Role
  name: pod-reader               # 角色名称
  apiGroup: rbac.authorization.k8s.io
```

### 完整 RoleBinding 配置

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: production
  labels:
    team: backend
    environment: production
  annotations:
    description: "将开发者权限绑定到后端团队成员"
    created-by: "platform-team"
subjects:
# 用户绑定
- kind: User
  name: alice@example.com
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: bob@example.com
  apiGroup: rbac.authorization.k8s.io

# 组绑定
- kind: Group
  name: backend-developers
  apiGroup: rbac.authorization.k8s.io

# ServiceAccount 绑定
- kind: ServiceAccount
  name: app-service-account
  namespace: production

roleRef:
  kind: Role                     # 可以是 Role 或 ClusterRole
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
```

## ClusterRoleBinding 配置详解

### 基础 ClusterRoleBinding 配置

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-binding
  labels:
    purpose: administration
subjects:
- kind: User
  name: admin@example.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

### 完整 ClusterRoleBinding 配置

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: monitoring-cluster-binding
  labels:
    purpose: monitoring
    team: platform
  annotations:
    description: "监控服务的集群级权限绑定"
    last-updated: "2023-12-01"
subjects:
# 监控服务账户
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
- kind: ServiceAccount
  name: grafana
  namespace: monitoring

# 监控团队用户
- kind: User
  name: monitoring-admin@example.com
  apiGroup: rbac.authorization.k8s.io

# 监控团队组
- kind: Group
  name: monitoring-team
  apiGroup: rbac.authorization.k8s.io

roleRef:
  kind: ClusterRole
  name: monitoring-reader
  apiGroup: rbac.authorization.k8s.io
```

## 主体类型详解

### 1. 用户 (User) 绑定

```yaml
subjects:
# 单个用户
- kind: User
  name: alice@example.com
  apiGroup: rbac.authorization.k8s.io

# 多个用户
- kind: User
  name: bob@example.com
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: charlie@example.com
  apiGroup: rbac.authorization.k8s.io
```

### 2. 用户组 (Group) 绑定

```yaml
subjects:
# 开发团队组
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io

# 管理员组
- kind: Group
  name: cluster-admins
  apiGroup: rbac.authorization.k8s.io

# OIDC 组
- kind: Group
  name: github:myorg:backend-team
  apiGroup: rbac.authorization.k8s.io
```

### 3. ServiceAccount 绑定

```yaml
subjects:
# 同命名空间 ServiceAccount
- kind: ServiceAccount
  name: my-service-account
  namespace: default

# 跨命名空间 ServiceAccount
- kind: ServiceAccount
  name: monitoring-sa
  namespace: monitoring

# 系统 ServiceAccount
- kind: ServiceAccount
  name: system:kube-proxy
  namespace: kube-system
```

## 典型绑定场景

### 1. 开发环境权限

```yaml
# 开发者角色
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

---
# 开发者绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: development
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

### 2. 生产环境只读权限

```yaml
# 只读角色
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: readonly
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]

---
# 只读绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: readonly-binding
  namespace: production
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: auditor@example.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: readonly
  apiGroup: rbac.authorization.k8s.io
```

### 3. 服务账户权限

```yaml
# 应用服务账户
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web-app-sa
  namespace: production

---
# 应用权限绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: web-app-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: web-app-sa
  namespace: production
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
```

### 4. 跨命名空间权限

```yaml
# 使用 ClusterRole 在特定命名空间生效
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cross-namespace-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: monitoring-sa
  namespace: monitoring          # 不同命名空间的 SA
roleRef:
  kind: ClusterRole              # 引用 ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

## CI/CD 权限配置

### 1. GitLab CI 权限

```yaml
# GitLab Runner ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-runner
  namespace: gitlab-system

---
# CI/CD 权限角色
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gitlab-runner
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]

---
# 权限绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gitlab-runner-binding
subjects:
- kind: ServiceAccount
  name: gitlab-runner
  namespace: gitlab-system
roleRef:
  kind: ClusterRole
  name: gitlab-runner
  apiGroup: rbac.authorization.k8s.io
```

### 2. GitHub Actions 权限

```yaml
# GitHub Actions ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: github-actions
  namespace: ci-cd

---
# 部署权限
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: deployer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "statefulsets"]
  verbs: ["*"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["*"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: github-actions-binding
subjects:
- kind: ServiceAccount
  name: github-actions
  namespace: ci-cd
roleRef:
  kind: ClusterRole
  name: deployer
  apiGroup: rbac.authorization.k8s.io
```

## 监控和审计

### 1. 查看绑定关系

```bash
# 查看 RoleBinding
kubectl get rolebindings
kubectl get rolebindings -A

# 查看 ClusterRoleBinding
kubectl get clusterrolebindings

# 查看详细信息
kubectl describe rolebinding developer-binding -n production
kubectl describe clusterrolebinding cluster-admin-binding
```

### 2. 权限验证

```bash
# 检查用户权限
kubectl auth can-i get pods --as=alice@example.com
kubectl auth can-i create deployments --as=alice@example.com -n production

# 检查 ServiceAccount 权限
kubectl auth can-i get pods --as=system:serviceaccount:default:my-sa
kubectl auth can-i --list --as=system:serviceaccount:default:my-sa

# 检查组权限
kubectl auth can-i get pods --as=alice@example.com --as-group=developers
```

### 3. 权限审计

```bash
# 查找特定用户的所有绑定
kubectl get rolebindings,clusterrolebindings --all-namespaces -o json | \
  jq '.items[] | select(.subjects[]? | select(.name=="alice@example.com"))'

# 查找特定角色的所有绑定
kubectl get rolebindings,clusterrolebindings --all-namespaces -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin")'

# 列出所有 ServiceAccount 的权限
kubectl get serviceaccounts --all-namespaces
```

## 安全最佳实践

### 1. 最小权限原则

```yaml
# 好的实践：精确权限
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: specific-access
  namespace: production
subjects:
- kind: User
  name: developer@example.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader              # 只给需要的权限
  apiGroup: rbac.authorization.k8s.io

# 避免：过度权限
# roleRef:
#   kind: ClusterRole
#   name: cluster-admin         # 避免给予过多权限
```

### 2. 定期权限审查

```yaml
metadata:
  annotations:
    last-reviewed: "2023-12-01"
    reviewer: "security-team@example.com"
    expiry-date: "2024-06-01"   # 权限过期时间
```

### 3. 权限分离

```yaml
# 按环境分离权限
# 开发环境：完整权限
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-full-access
  namespace: development
subjects:
- kind: Group
  name: developers
roleRef:
  kind: Role
  name: developer-full

---
# 生产环境：只读权限
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: prod-readonly
  namespace: production
subjects:
- kind: Group
  name: developers
roleRef:
  kind: Role
  name: readonly
```

### 4. 临时权限管理

```yaml
# 临时权限绑定（通过外部工具管理）
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: emergency-access
  namespace: production
  annotations:
    temp-access: "true"
    expires-at: "2023-12-31T23:59:59Z"
    reason: "Production incident response"
subjects:
- kind: User
  name: oncall-engineer@example.com
roleRef:
  kind: Role
  name: incident-responder
```

## 故障排除

### 1. 权限问题诊断

```bash
# 检查绑定是否存在
kubectl get rolebindings,clusterrolebindings | grep my-binding

# 检查角色是否存在
kubectl get roles,clusterroles | grep my-role

# 检查主体格式
kubectl describe rolebinding my-binding

# 验证 API 组
kubectl api-resources | grep rbac
```

### 2. 常见错误修复

```bash
# 错误：权限不足
# 检查用户是否在正确的组中
kubectl auth can-i --list --as=user@example.com

# 错误：找不到角色
# 检查角色是否在正确的命名空间
kubectl get role my-role -n my-namespace

# 错误：ServiceAccount 权限问题
# 检查 ServiceAccount 是否存在
kubectl get serviceaccount my-sa -n my-namespace
```