# Service 资源详解

## 概述

Service 是 Kubernetes 中的抽象，定义了一组 Pod 的逻辑集合和访问策略。Service 为动态的 Pod 集合提供稳定的网络端点，实现服务发现和负载均衡。

## 核心特性

### 1. 服务发现
- 提供稳定的 ClusterIP，不会因 Pod 重建而改变
- 自动 DNS 记录：`<service-name>.<namespace>.svc.cluster.local`
- 环境变量注入到同命名空间的 Pod

### 2. 负载均衡
- 自动将流量分发到健康的 Pod
- 支持多种负载均衡算法
- 会话亲和性支持

## Service 类型

### 1. ClusterIP (默认)
集群内部访问，仅在集群内可达

### 2. NodePort
通过每个节点的端口暴露服务

### 3. LoadBalancer
使用云提供商的负载均衡器暴露服务

### 4. ExternalName
将服务映射到外部域名

## Service 配置详解

### ClusterIP Service 配置

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service                # Service 名称
  namespace: default              # 命名空间
  labels:                         # 标签
    app: my-app
    tier: backend
  annotations:                    # 注解
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: ClusterIP               # 服务类型（默认）
  clusterIP: 10.96.0.100        # 指定 ClusterIP（可选）
  # clusterIP: None             # Headless Service
  selector:                     # Pod 选择器
    app: my-app
    tier: backend
  ports:                        # 端口配置
  - name: http                  # 端口名称
    protocol: TCP               # 协议：TCP、UDP、SCTP
    port: 80                    # Service 端口
    targetPort: 8080            # Pod 端口（可以是端口号或端口名）
  - name: https
    protocol: TCP
    port: 443
    targetPort: https-port      # 使用容器端口名
  sessionAffinity: None         # 会话亲和性：None、ClientIP
  sessionAffinityConfig:        # 会话亲和性配置
    clientIP:
      timeoutSeconds: 10800     # 超时时间（3小时）
```

### NodePort Service 配置

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nodeport-service
spec:
  type: NodePort                # NodePort 类型
  selector:
    app: my-app
  ports:
  - name: http
    protocol: TCP
    port: 80                    # Service 端口
    targetPort: 8080            # Pod 端口
    nodePort: 30080             # 节点端口（30000-32767，可选）
  externalTrafficPolicy: Cluster  # 外部流量策略
  # Cluster: 流量可以转发到任何节点的 Pod（默认）
  # Local: 流量只转发到本地节点的 Pod
```

### LoadBalancer Service 配置

```yaml
apiVersion: v1
kind: Service
metadata:
  name: loadbalancer-service
  annotations:                  # 云提供商特定注解
    # AWS
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:..."
    # GCP
    cloud.google.com/load-balancer-type: "Internal"
    # Azure
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
spec:
  type: LoadBalancer            # LoadBalancer 类型
  selector:
    app: my-app
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
  externalTrafficPolicy: Local  # 推荐设置为 Local
  loadBalancerIP: 192.168.1.100 # 指定外部 IP（可选）
  loadBalancerSourceRanges:     # 限制访问源 IP
  - 10.0.0.0/8
  - 192.168.0.0/16
```

### ExternalName Service 配置

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  type: ExternalName            # ExternalName 类型
  externalName: example.com     # 外部域名
  ports:                        # 可选：端口配置
  - name: http
    port: 80
```

### Headless Service 配置

```yaml
apiVersion: v1
kind: Service
metadata:
  name: headless-service
spec:
  clusterIP: None               # 设置为 None 创建 Headless Service
  selector:
    app: my-app
  ports:
  - name: http
    port: 80
    targetPort: 8080
```

## 高级配置

### 1. 多端口 Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: multi-port-service
spec:
  selector:
    app: my-app
  ports:
  - name: http                  # 多端口时必须指定名称
    protocol: TCP
    port: 80
    targetPort: 8080
  - name: https
    protocol: TCP
    port: 443
    targetPort: 8443
  - name: grpc
    protocol: TCP
    port: 9090
    targetPort: 9090
  - name: metrics
    protocol: TCP
    port: 9100
    targetPort: metrics-port   # 使用容器端口名
```

### 2. Service 与 Endpoints

```yaml
# Service 不使用选择器
apiVersion: v1
kind: Service
metadata:
  name: external-db-service
spec:
  ports:
  - name: mysql
    protocol: TCP
    port: 3306
    targetPort: 3306
  # 不定义 selector
---
# 手动创建 Endpoints
apiVersion: v1
kind: Endpoints
metadata:
  name: external-db-service     # 必须与 Service 名称相同
subsets:
- addresses:                    # 外部服务地址
  - ip: 192.168.1.100
  - ip: 192.168.1.101
  ports:
  - name: mysql
    port: 3306
    protocol: TCP
```

### 3. Service 拓扑感知

```yaml
apiVersion: v1
kind: Service
metadata:
  name: topology-aware-service
  annotations:
    service.kubernetes.io/topology-aware-hints: auto
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
  internalTrafficPolicy: Local  # 内部流量策略
  # Local: 优先路由到本地 Pod
  # Cluster: 路由到所有可用 Pod（默认）
```

### 4. 自定义 EndpointSlices

```yaml
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: my-service-abc123
  labels:
    kubernetes.io/service-name: my-service
addressType: IPv4
endpoints:
- addresses:
  - "10.1.2.3"
  conditions:
    ready: true
    serving: true
    terminating: false
  hostname: pod-1
  nodeName: node-1
  zone: us-west-1a
ports:
- name: http
  port: 8080
  protocol: TCP
```

## 会话亲和性配置

### ClientIP 亲和性

```yaml
apiVersion: v1
kind: Service
metadata:
  name: sticky-service
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
  sessionAffinity: ClientIP     # 基于客户端 IP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800     # 会话超时：3小时
```

## 服务发现详解

### 1. DNS 记录

```yaml
# Service 会创建以下 DNS 记录：
# A 记录
my-service.default.svc.cluster.local -> 10.96.0.100

# SRV 记录
_http._tcp.my-service.default.svc.cluster.local -> 0 100 80 my-service.default.svc.cluster.local

# 对于 Headless Service
my-service.default.svc.cluster.local -> Pod IPs
pod-name.my-service.default.svc.cluster.local -> Pod IP
```

### 2. 环境变量

```bash
# Kubernetes 自动注入的环境变量
MY_SERVICE_SERVICE_HOST=10.96.0.100
MY_SERVICE_SERVICE_PORT=80
MY_SERVICE_PORT=tcp://10.96.0.100:80
MY_SERVICE_PORT_80_TCP=tcp://10.96.0.100:80
MY_SERVICE_PORT_80_TCP_PROTO=tcp
MY_SERVICE_PORT_80_TCP_PORT=80
MY_SERVICE_PORT_80_TCP_ADDR=10.96.0.100
```

## 负载均衡配置

### 1. 负载均衡算法

```yaml
# kube-proxy 支持的负载均衡算法
# iptables 模式：随机选择（基于统计模块）
# IPVS 模式：支持多种算法

apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-proxy-config
  namespace: kube-system
data:
  config.conf: |
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    kind: KubeProxyConfiguration
    mode: "ipvs"
    ipvs:
      scheduler: "rr"           # 轮询
      # scheduler: "lc"         # 最少连接
      # scheduler: "dh"         # 目标哈希
      # scheduler: "sh"         # 源哈希
      # scheduler: "sed"        # 最短期望延迟
      # scheduler: "nq"         # 永不排队
```

### 2. 外部流量策略

```yaml
apiVersion: v1
kind: Service
metadata:
  name: traffic-policy-service
spec:
  type: NodePort
  externalTrafficPolicy: Local  # 外部流量策略
  # Cluster（默认）: 流量可以路由到任何节点的 Pod
  #   - 优点：负载分布均匀
  #   - 缺点：可能有额外的网络跳转，源 IP 会被 SNAT
  # Local: 流量只路由到接收流量节点上的 Pod
  #   - 优点：保留源 IP，无额外网络跳转
  #   - 缺点：负载可能不均匀
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
```

## 服务网格集成

### 1. Istio 集成

```yaml
apiVersion: v1
kind: Service
metadata:
  name: istio-enabled-service
  labels:
    app: my-app
    version: v1
spec:
  selector:
    app: my-app
  ports:
  - name: http                  # Istio 要求端口必须命名
    port: 80
    targetPort: 8080
  - name: grpc                  # 命名约定：http、http2、grpc、mongo、redis 等
    port: 9090
    targetPort: 9090
```

### 2. 流量分割

```yaml
# 使用 Istio VirtualService 进行流量分割
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-service-vs
spec:
  hosts:
  - my-service
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: my-service
        subset: v2
  - route:
    - destination:
        host: my-service
        subset: v1
      weight: 90
    - destination:
        host: my-service
        subset: v2
      weight: 10
```

## 监控和可观测性

### 1. Service 监控指标

```yaml
# 关键监控指标
- kube_service_info: Service 基本信息
- kube_service_spec_type: Service 类型
- kube_service_status_load_balancer_ingress: LoadBalancer 状态
- kube_endpoint_info: Endpoint 信息
- kube_endpoint_address_available: 可用 Endpoint 数量
- kube_endpoint_address_not_ready: 不可用 Endpoint 数量
```

### 2. 健康检查

```bash
# 检查 Service 状态
kubectl get svc my-service -o wide

# 检查 Endpoints
kubectl get endpoints my-service

# 检查 EndpointSlices
kubectl get endpointslices -l kubernetes.io/service-name=my-service

# 测试服务连通性
kubectl run test-pod --image=busybox --rm -it -- wget -O- http://my-service
```

## 故障排除

### 1. 常见问题

```bash
# 1. Service 无法访问
# 检查 Service 配置
kubectl describe svc my-service

# 检查 Pod 标签是否匹配
kubectl get pods --show-labels
kubectl get svc my-service -o yaml | grep selector

# 2. Endpoints 为空
# 检查 Pod 是否就绪
kubectl get pods -o wide
kubectl describe pod my-pod

# 检查端口是否正确
kubectl get svc my-service -o yaml | grep targetPort

# 3. DNS 解析失败
# 测试 DNS 解析
kubectl run test-dns --image=busybox --rm -it -- nslookup my-service

# 检查 CoreDNS 状态
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

### 2. 调试工具

```bash
# 使用 kubectl port-forward 测试
kubectl port-forward svc/my-service 8080:80

# 使用临时 Pod 测试网络连通性
kubectl run debug-pod --image=nicolaka/netshoot --rm -it -- bash

# 在 debug Pod 中测试
curl http://my-service
dig my-service.default.svc.cluster.local
telnet my-service 80
```

## 最佳实践

### 1. 命名规范

```yaml
metadata:
  name: my-app-service          # 使用描述性名称
  labels:
    app: my-app                 # 应用标识
    component: backend          # 组件标识
    tier: data                  # 层级标识
    version: v1.0               # 版本标识
```

### 2. 端口命名

```yaml
ports:
- name: http                    # 使用协议名称
  port: 80
  targetPort: 8080
- name: https
  port: 443
  targetPort: 8443
- name: grpc
  port: 9090
  targetPort: 9090
- name: metrics                 # 或功能名称
  port: 9100
  targetPort: 9100
```

### 3. 安全配置

```yaml
# 使用网络策略限制访问
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    - podSelector:
        matchLabels:
          role: client
    ports:
    - protocol: TCP
      port: 8080
```

### 4. 高可用配置

```yaml
# 确保多个 Pod 副本
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3                   # 多副本
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: my-app
  template:
    spec:
      affinity:
        podAntiAffinity:        # Pod 反亲和性
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - my-app
              topologyKey: kubernetes.io/hostname
```

## 性能优化

### 1. 拓扑感知路由

```yaml
apiVersion: v1
kind: Service
metadata:
  name: optimized-service
  annotations:
    service.kubernetes.io/topology-aware-hints: auto
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
  internalTrafficPolicy: Local  # 优先本地路由
```

### 2. 会话亲和性优化

```yaml
# 对于有状态应用，使用会话亲和性
sessionAffinity: ClientIP
sessionAffinityConfig:
  clientIP:
    timeoutSeconds: 3600        # 1小时，根据应用需求调整
```