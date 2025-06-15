# Endpoints 资源详解

## 概述

Endpoints 是 Kubernetes 中表示 Service 后端端点的资源。它包含了可以处理请求的 Pod 的 IP 地址和端口信息。通常由 Kubernetes 自动管理，但也可以手动配置。

## 核心特性

### 1. 服务端点管理
- 维护 Service 的后端 Pod 列表
- 自动更新 Pod IP 和端口
- 支持手动配置外部端点

### 2. 负载均衡基础
- 为 kube-proxy 提供转发目标
- 支持健康检查集成
- 动态端点更新

### 3. 服务发现
- DNS 解析的基础数据
- 服务网格集成点
- 监控和观测的数据源

## Endpoints 配置详解

### 自动生成的 Endpoints

```yaml
# Service 配置
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web                      # 选择器匹配的 Pod
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP

---
# Kubernetes 自动生成的 Endpoints
apiVersion: v1
kind: Endpoints
metadata:
  name: web-service              # 与 Service 同名
subsets:
- addresses:                     # 就绪的端点
  - ip: 10.244.1.10
    targetRef:
      kind: Pod
      name: web-pod-1
      namespace: default
  - ip: 10.244.2.15
    targetRef:
      kind: Pod
      name: web-pod-2
      namespace: default
  notReadyAddresses:             # 未就绪的端点
  - ip: 10.244.1.20
    targetRef:
      kind: Pod
      name: web-pod-3
      namespace: default
  ports:
  - port: 8080
    protocol: TCP
```

### 手动配置的 Endpoints

```yaml
# 无选择器的 Service
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  # 注意：没有 selector

---
# 手动配置的 Endpoints
apiVersion: v1
kind: Endpoints
metadata:
  name: external-service          # 必须与 Service 同名
subsets:
- addresses:
  - ip: 192.168.1.100            # 外部服务 IP
  - ip: 192.168.1.101
  ports:
  - port: 80
    protocol: TCP
```

## EndpointSlices 详解

### EndpointSlices 概述
EndpointSlices 是 Kubernetes 1.17+ 引入的新资源，用于替代 Endpoints，提供更好的可扩展性。

```yaml
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: web-service-abc123
  labels:
    kubernetes.io/service-name: web-service
addressType: IPv4
endpoints:
- addresses:
  - "10.244.1.10"
  conditions:
    ready: true                   # 端点就绪状态
    serving: true                 # 端点服务状态
    terminating: false            # 端点终止状态
  targetRef:
    kind: Pod
    name: web-pod-1
    namespace: default
  topology:                       # 拓扑信息
    kubernetes.io/hostname: node-1
    topology.kubernetes.io/zone: us-west-2a
- addresses:
  - "10.244.2.15"
  conditions:
    ready: true
    serving: true
    terminating: false
  targetRef:
    kind: Pod
    name: web-pod-2
    namespace: default
  topology:
    kubernetes.io/hostname: node-2
    topology.kubernetes.io/zone: us-west-2b
ports:
- port: 8080
  protocol: TCP
  name: http
```

## 典型使用场景

### 1. 外部数据库服务

```yaml
# 数据库 Service
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
spec:
  ports:
  - port: 3306
    protocol: TCP

---
# 外部数据库 Endpoints
apiVersion: v1
kind: Endpoints
metadata:
  name: mysql-service
subsets:
- addresses:
  - ip: 10.0.1.100              # 主数据库
    targetRef:
      kind: Pod
      name: mysql-primary
  - ip: 10.0.1.101              # 从数据库
    targetRef:
      kind: Pod
      name: mysql-replica
  ports:
  - port: 3306
    protocol: TCP
```

### 2. 混合云服务

```yaml
# 混合云 Service
apiVersion: v1
kind: Service
metadata:
  name: hybrid-api
spec:
  ports:
  - port: 443
    protocol: TCP

---
# 混合云 Endpoints
apiVersion: v1
kind: Endpoints
metadata:
  name: hybrid-api
subsets:
- addresses:
  - ip: 10.244.1.50            # 集群内 Pod
  - ip: 203.0.113.10           # 公有云实例
  - ip: 192.168.1.20           # 私有云实例
  ports:
  - port: 443
    protocol: TCP
```

### 3. 服务迁移场景

```yaml
# 迁移期间的双重端点
apiVersion: v1
kind: Endpoints
metadata:
  name: migrating-service
subsets:
- addresses:
  - ip: 10.244.1.30            # 新版本 Pod
    targetRef:
      kind: Pod
      name: new-app-pod
  - ip: 192.168.1.100          # 旧版本外部服务
  ports:
  - port: 8080
    protocol: TCP
```

## 健康检查集成

### 1. 就绪状态管理

```yaml
# Pod 就绪状态影响 Endpoints
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
  labels:
    app: web
spec:
  containers:
  - name: web
    image: nginx
    ports:
    - containerPort: 80
    readinessProbe:              # 就绪检查
      httpGet:
        path: /ready
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
    livenessProbe:               # 存活检查
      httpGet:
        path: /health
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 10
```

### 2. 自定义健康检查

```yaml
# 使用 EndpointSlices 的高级健康检查
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: advanced-health-check
  labels:
    kubernetes.io/service-name: web-service
addressType: IPv4
endpoints:
- addresses:
  - "10.244.1.10"
  conditions:
    ready: true                 # 基础就绪
    serving: true               # 服务就绪
    terminating: false          # 非终止状态
  hints:                        # 流量提示
    forZones:
    - name: "us-west-2a"
  nodeName: node-1
  zone: us-west-2a
ports:
- port: 8080
  protocol: TCP
```

## 网络拓扑感知

### 1. 区域感知路由

```yaml
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: zone-aware-service
  labels:
    kubernetes.io/service-name: zone-aware
addressType: IPv4
endpoints:
- addresses:
  - "10.244.1.10"
  conditions:
    ready: true
  topology:
    topology.kubernetes.io/zone: us-west-2a
    topology.kubernetes.io/region: us-west-2
  hints:
    forZones:
    - name: "us-west-2a"        # 流量提示
- addresses:
  - "10.244.2.20"
  conditions:
    ready: true
  topology:
    topology.kubernetes.io/zone: us-west-2b
    topology.kubernetes.io/region: us-west-2
  hints:
    forZones:
    - name: "us-west-2b"
ports:
- port: 8080
  protocol: TCP
```

### 2. 节点本地流量

```yaml
# 节点本地 Service
apiVersion: v1
kind: Service
metadata:
  name: node-local-service
spec:
  selector:
    app: node-local
  ports:
  - port: 80
  internalTrafficPolicy: Local   # 节点本地流量策略
  externalTrafficPolicy: Local   # 外部流量策略
```

## 监控和管理

### 1. 查看 Endpoints

```bash
# 查看 Endpoints
kubectl get endpoints

# 查看特定 Endpoints
kubectl describe endpoints web-service

# 查看 EndpointSlices
kubectl get endpointslices

# 查看详细信息
kubectl describe endpointslice web-service-abc123
```

### 2. 故障排除

```bash
# 检查 Service 和 Endpoints 关联
kubectl get service,endpoints web-service

# 检查 Pod 标签和选择器
kubectl get pods --show-labels
kubectl get service web-service -o yaml | grep selector

# 检查 Pod 就绪状态
kubectl get pods -o wide
kubectl describe pod web-pod
```

### 3. 调试网络连接

```bash
# 测试端点连接
kubectl run debug-pod --image=busybox --rm -it -- /bin/sh
# 在 debug pod 中：
# nslookup web-service
# wget -qO- http://10.244.1.10:8080

# 检查 kube-proxy 规则
kubectl get service web-service
iptables -t nat -L | grep web-service  # 在节点上运行
```

## 最佳实践

### 1. 标签和选择器

```yaml
# 一致的标签策略
metadata:
  labels:
    app: web                    # 应用名称
    version: v1.0              # 版本
    component: frontend        # 组件
    tier: web                  # 层级

# Service 选择器
spec:
  selector:
    app: web                   # 匹配核心标签
    component: frontend        # 精确匹配
```

### 2. 健康检查配置

```yaml
# 合理的健康检查
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5        # 给应用启动时间
  periodSeconds: 5              # 频繁检查
  failureThreshold: 3           # 容忍短暂失败

livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30       # 给更多启动时间
  periodSeconds: 10             # 较长间隔
  failureThreshold: 3
```

### 3. 外部服务管理

```yaml
# 外部服务使用 ExternalName
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com
  ports:
  - port: 5432

# 或使用手动 Endpoints
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  ports:
  - port: 443
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-api
subsets:
- addresses:
  - ip: 203.0.113.10
  ports:
  - port: 443
```

### 4. 性能优化

```yaml
# 使用 EndpointSlices 获得更好性能
# 启用拓扑感知路由
apiVersion: v1
kind: Service
metadata:
  name: topology-aware
  annotations:
    service.kubernetes.io/topology-aware-hints: auto
spec:
  selector:
    app: web
  ports:
  - port: 80
```