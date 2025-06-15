# NetworkPolicy 资源详解

## 概述

NetworkPolicy 是 Kubernetes 中用于控制 Pod 间网络流量的资源。它提供了在应用层面实现网络隔离和安全策略的能力，类似于网络防火墙规则。

## 核心特性

### 1. 网络隔离
- 控制 Pod 间的入站和出站流量
- 基于标签选择器的策略
- 支持命名空间级别隔离

### 2. 安全策略
- 默认拒绝策略
- 白名单访问控制
- 多层安全防护

### 3. 灵活配置
- 支持 IP 块、端口、协议配置
- 可组合多种选择器
- 策略优先级控制

## NetworkPolicy 配置详解

### 基础配置示例

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:                    # 策略应用的 Pod 选择器
    matchLabels:
      role: db
  policyTypes:                   # 策略类型
  - Ingress                      # 入站流量
  - Egress                       # 出站流量
  ingress:                       # 入站规则
  - from:
    - ipBlock:
        cidr: 172.17.0.0/16      # IP 块
        except:
        - 172.17.1.0/24          # 排除的 IP 范围
    - namespaceSelector:
        matchLabels:
          name: myproject        # 命名空间选择器
    - podSelector:
        matchLabels:
          role: frontend         # Pod 选择器
    ports:
    - protocol: TCP
      port: 6379
  egress:                        # 出站规则
  - to:
    - ipBlock:
        cidr: 10.0.0.0/24
    ports:
    - protocol: TCP
      port: 5978
```

## 策略类型详解

### 1. 默认拒绝所有入站流量

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}               # 空选择器，匹配所有 Pod
  policyTypes:
  - Ingress
  # 没有 ingress 规则，拒绝所有入站
```

### 2. 默认拒绝所有出站流量

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  # 没有 egress 规则，拒绝所有出站
```

### 3. 默认拒绝所有流量

```yaml
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
  # 拒绝所有入站和出站流量
```

## 选择器类型详解

### 1. Pod 选择器

```yaml
spec:
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend           # 匹配标签的 Pod
          tier: web
    - podSelector:
        matchExpressions:         # 表达式匹配
        - key: environment
          operator: In
          values: ["production", "staging"]
```

### 2. 命名空间选择器

```yaml
spec:
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend          # 指定命名空间
    - namespaceSelector:
        matchLabels:
          environment: production # 生产环境命名空间
```

### 3. IP 块选择器

```yaml
spec:
  ingress:
  - from:
    - ipBlock:
        cidr: 172.17.0.0/16      # 允许的 IP 范围
        except:                   # 排除的 IP 范围
        - 172.17.1.0/24
        - 172.17.2.0/24
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0          # 允许所有外部访问
        except:
        - 169.254.169.254/32     # 排除元数据服务
```

## 典型应用场景

### 1. 三层应用隔离

```yaml
# 前端层策略
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-netpol
  namespace: default
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from: []                     # 允许所有入站（通过 Ingress）
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: backend          # 只能访问后端
    ports:
    - protocol: TCP
      port: 8080

---
# 后端层策略
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-netpol
  namespace: default
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend         # 只允许前端访问
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database         # 只能访问数据库
    ports:
    - protocol: TCP
      port: 5432

---
# 数据库层策略
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-netpol
  namespace: default
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend          # 只允许后端访问
    ports:
    - protocol: TCP
      port: 5432
  egress: []                     # 禁止所有出站流量
```

### 2. 命名空间隔离

```yaml
# 生产环境隔离
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: production-isolation
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
    - namespaceSelector:
        matchLabels:
          name: monitoring       # 允许监控命名空间
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: production
  - to: {}                       # 允许出站到集群外
    ports:
    - protocol: UDP
      port: 53                   # DNS
    - protocol: TCP
      port: 443                  # HTTPS
```

### 3. 微服务通信控制

```yaml
# 用户服务策略
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: user-service-netpol
  namespace: microservices
spec:
  podSelector:
    matchLabels:
      app: user-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-gateway       # API 网关
    - podSelector:
        matchLabels:
          app: auth-service      # 认证服务
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database          # 数据库
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: cache             # 缓存
    ports:
    - protocol: TCP
      port: 6379
```

### 4. 开发测试环境策略

```yaml
# 开发环境宽松策略
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: development-policy
  namespace: development
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: {}                       # 允许所有出站流量
  # 不限制入站流量

---
# 测试环境中等策略
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: testing-policy
  namespace: testing
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: testing
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          environment: testing
  - to: {}                       # 允许外部访问
    ports:
    - protocol: TCP
      port: 443
    - protocol: UDP
      port: 53
```

## 高级配置

### 1. 端口范围和协议

```yaml
spec:
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: client
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 8443
    - protocol: UDP
      port: 53
  - from:
    - ipBlock:
        cidr: 10.0.0.0/8
    ports:
    - protocol: TCP
      port: 22                   # SSH
    - protocol: SCTP
      port: 9999                 # SCTP 协议
```

### 2. 命名端口支持

```yaml
# Pod 定义命名端口
apiVersion: v1
kind: Pod
metadata:
  name: web-server
  labels:
    app: web
spec:
  containers:
  - name: web
    image: nginx
    ports:
    - containerPort: 80
      name: http               # 命名端口
    - containerPort: 443
      name: https

---
# 在 NetworkPolicy 中使用命名端口
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-netpol
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: client
    ports:
    - protocol: TCP
      port: http               # 使用命名端口
    - protocol: TCP
      port: https
```

### 3. 多规则组合

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: complex-policy
spec:
  podSelector:
    matchLabels:
      app: complex-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # 规则 1：允许同命名空间特定 Pod
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 8080
  # 规则 2：允许监控命名空间
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
  # 规则 3：允许特定 IP 范围的管理访问
  - from:
    - ipBlock:
        cidr: 192.168.1.0/24
    ports:
    - protocol: TCP
      port: 22
  egress:
  # 允许访问数据库
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  # 允许 DNS 查询
  - to: {}
    ports:
    - protocol: UDP
      port: 53
  # 允许外部 API 调用
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 10.0.0.0/8
        - 172.16.0.0/12
        - 192.168.0.0/16
    ports:
    - protocol: TCP
      port: 443
```

## 监控和故障排除

### 1. 查看 NetworkPolicy

```bash
# 查看 NetworkPolicy
kubectl get networkpolicies
kubectl get netpol             # 简写

# 查看详细信息
kubectl describe networkpolicy my-netpol

# 查看特定命名空间的策略
kubectl get netpol -n production
```

### 2. 测试网络连接

```bash
# 创建测试 Pod
kubectl run test-pod --image=busybox --rm -it -- /bin/sh

# 在测试 Pod 中测试连接
# wget -qO- --timeout=2 http://service-name:port
# nc -zv service-name port

# 测试 DNS 解析
# nslookup service-name
```

### 3. 调试网络策略

```bash
# 检查 Pod 标签
kubectl get pods --show-labels

# 检查命名空间标签
kubectl get namespaces --show-labels

# 查看网络策略事件
kubectl get events --field-selector involvedObject.kind=NetworkPolicy

# 检查 CNI 插件日志
kubectl logs -n kube-system -l k8s-app=calico-node
```

## 最佳实践

### 1. 默认拒绝策略

```yaml
# 在每个命名空间中实施默认拒绝
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
```

### 2. 渐进式策略实施

```yaml
# 1. 先实施监控和日志记录
# 2. 实施宽松策略
# 3. 逐步收紧策略
# 4. 监控应用健康状况
```

### 3. 标签标准化

```yaml
# 使用一致的标签策略
metadata:
  labels:
    app: frontend              # 应用名称
    tier: web                  # 层级
    environment: production    # 环境
    version: v1.0             # 版本
    security-zone: dmz        # 安全区域
```

### 4. 文档化策略

```yaml
metadata:
  annotations:
    description: "前端应用网络策略"
    owner: "frontend-team@example.com"
    security-review: "2023-12-01"
    policy-version: "v1.2"
```

### 5. 测试和验证

```bash
# 自动化测试脚本
#!/bin/bash
# test-network-policy.sh

# 测试允许的连接
kubectl run test-frontend --image=busybox --labels="app=frontend" --rm -it -- \
  wget -qO- --timeout=2 http://backend-service:8080

# 测试被拒绝的连接
kubectl run test-external --image=busybox --rm -it -- \
  wget -qO- --timeout=2 http://backend-service:8080
```

## 与服务网格集成

### 1. Istio 集成

```yaml
# NetworkPolicy + Istio AuthorizationPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: istio-netpol
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: istio-proxy     # 允许 Istio sidecar
    ports:
    - protocol: TCP
      port: 15001            # Istio 代理端口
```

### 2. Linkerd 集成

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: linkerd-netpol
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          linkerd.io/proxy-deployment: my-app
```