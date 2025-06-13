# Istio 性能优化

## 性能优化原理

### 1. 配置优化
- **配置作用域**：使用 Sidecar 资源限制配置范围
- **选择性推送**：只向需要的 Envoy 推送相关配置
- **配置缓存**：避免重复的配置计算和传输

#### Sidecar 资源优化
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: productpage
  namespace: default
spec:
  workloadSelector:
    labels:
      app: productpage
  egress:
  - hosts:
    - "./reviews.default.svc.cluster.local"
    - "./ratings.default.svc.cluster.local"
    - "istio-system/*"
  ingress:
  - port:
      number: 9080
      name: http
      protocol: HTTP
    defaultEndpoint: 127.0.0.1:9080
```

#### 配置推送优化
```yaml
# 使用命名空间隔离减少配置范围
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    istio-injection: enabled
    name: production
---
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: production
spec:
  egress:
  - hosts:
    - "./*"  # 只允许同命名空间服务
    - "istio-system/*"  # 系统组件
```

### 2. 流量优化
- **连接复用**：HTTP/2 连接复用减少连接开销
- **请求合并**：批量处理小请求
- **缓存机制**：智能缓存热点数据

#### 连接池优化
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews-dr
spec:
  host: reviews.default.svc.cluster.local
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
        connectTimeout: 30s
        keepAlive:
          time: 7200s
          interval: 75s
          probes: 9
      http:
        http1MaxPendingRequests: 10
        http2MaxRequests: 1000
        maxRequestsPerConnection: 10
        maxRetries: 3
        consecutiveGatewayErrors: 5
        h2UpgradePolicy: UPGRADE  # 启用 HTTP/2
```

#### 负载均衡优化
```yaml
trafficPolicy:
  loadBalancer:
    simple: LEAST_CONN  # 最少连接数算法
    consistentHash:     # 一致性哈希
      httpHeaderName: "x-user-id"
      minimumRingSize: 1024
  outlierDetection:
    consecutiveErrors: 3
    interval: 30s
    baseEjectionTime: 30s
    maxEjectionPercent: 50
    minHealthPercent: 30
```

## 资源管理优化

### 1. Sidecar 资源限制
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-sidecar-injector
  namespace: istio-system
data:
  config: |
    policy: enabled
    alwaysInjectSelector:
      []
    neverInjectSelector:
      []
    template: |
      spec:
        containers:
        - name: istio-proxy
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
```

### 2. 控制平面资源优化
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istiod
  namespace: istio-system
spec:
  template:
    spec:
      containers:
      - name: discovery
        resources:
          limits:
            cpu: 500m
            memory: 2048Mi
          requests:
            cpu: 500m
            memory: 2048Mi
        env:
        - name: PILOT_PUSH_THROTTLE
          value: "100"  # 限制配置推送频率
        - name: PILOT_DEBOUNCE_AFTER
          value: "100ms"  # 配置变更防抖
        - name: PILOT_DEBOUNCE_MAX
          value: "10s"    # 最大防抖时间
```

### 3. 内存和 CPU 调优
```yaml
# Envoy 内存优化
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio
  namespace: istio-system
data:
  mesh: |
    proxyStatsMatcher:
      inclusionRegexps:
      - ".*circuit_breakers.*"
      - ".*upstream_rq_retry.*"
      - ".*_cx_.*"
      - ".*_rq_.*"
      exclusionRegexps:
      - ".*osconfig.*"
    # 默认并发连接数
    concurrency: 2
    # 统计信息保留时间
    statsConfig:
      proxyStatsMatcher:
        inclusionRegexps:
        - ".*outlier_detection.*"
        - ".*circuit_breakers.*"
```

## 网络性能优化

### 1. TCP 优化
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: tcp-optimization
spec:
  host: "*.local"
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
        connectTimeout: 10s
        tcpKeepalive:
          time: 7200s
          interval: 75s
          probes: 9
        # TCP_NODELAY 选项
        tcpNoDelay: true
```

### 2. HTTP/2 优化
```yaml
trafficPolicy:
  connectionPool:
    http:
      http2MaxRequests: 1000
      maxRequestsPerConnection: 10
      # 启用 HTTP/2
      h2UpgradePolicy: UPGRADE
      # HTTP/2 窗口大小
      http2Settings:
        maxConcurrentStreams: 1000
        initialStreamWindowSize: 65536
        initialConnectionWindowSize: 1048576
```

### 3. TLS 性能优化
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: tls-optimization
spec:
  host: productpage.default.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
      # TLS 版本优化
      minProtocolVersion: TLSV1_2
      maxProtocolVersion: TLSV1_3
      # 加密套件优化
      cipherSuites:
      - ECDHE-RSA-AES128-GCM-SHA256
      - ECDHE-RSA-AES256-GCM-SHA384
```

## 监控和指标优化

### 1. 指标收集优化
```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: metrics-optimization
spec:
  metrics:
  - providers:
    - name: prometheus
  - overrides:
    - match:
        metric: ALL_METRICS
      operation: UPSERT
      tags:
        request_protocol:
          operation: REMOVE  # 移除不必要的标签
    - match:
        metric: ALL_METRICS
        mode: CLIENT
      disabled: true  # 禁用客户端指标
```

### 2. 访问日志优化
```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: access-log-optimization
spec:
  accessLogging:
  - providers:
    - name: otel
  - filter:
      expression: 'response.code >= 400'  # 只记录错误日志
  - format:
      text: |
        [%START_TIME%] %RESPONSE_CODE% %DURATION%
        "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%"
```

### 3. 追踪采样优化
```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: tracing-optimization
spec:
  tracing:
  - providers:
    - name: jaeger
  - randomSamplingPercentage: 0.1  # 0.1% 采样率
  - customTags:
      user_id:
        header:
          name: x-user-id
          defaultValue: "unknown"
```

## 扩展性优化

### 1. 水平扩展配置
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istiod
  namespace: istio-system
spec:
  replicas: 3  # 多副本部署
  template:
    spec:
      containers:
      - name: discovery
        env:
        - name: EXTERNAL_ISTIOD
          value: "true"
        - name: PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION
          value: "true"
---
apiVersion: v1
kind: Service
metadata:
  name: istiod-remote
  namespace: istio-system
spec:
  type: LoadBalancer  # 负载均衡
  ports:
  - port: 15010
    name: grpc-xds
  - port: 15011
    name: grpc-xds-tls
  selector:
    app: istiod
```

### 2. 多集群优化
```yaml
# 跨集群流量策略
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: cross-cluster-dr
spec:
  host: reviews.default.svc.cluster.local
  trafficPolicy:
    outlierDetection:
      consecutiveErrors: 3
      interval: 30s
      baseEjectionTime: 30s
    loadBalancer:
      localityLbSetting:
        enabled: true
        distribute:
        - from: "region1/zone1/*"
          to:
            "region1/zone1/*": 80
            "region1/zone2/*": 20
        failover:
        - from: region1
          to: region2
```

## 缓存和预取优化

### 1. DNS 缓存优化
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30  # DNS 缓存 TTL
        }
        cache 300  # 缓存 300 秒
        loop
        reload
        loadbalance
    }
```

### 2. 连接预热
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: connection-warming
spec:
  host: reviews.default.svc.cluster.local
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 50
        # 连接预热
        connectTimeout: 5s
      http:
        # 预建立连接
        http1MaxPendingRequests: 20
        http2MaxRequests: 100
```

## 故障恢复优化

### 1. 重试策略优化
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: retry-optimization
spec:
  http:
  - match:
    - uri:
        prefix: /api
    route:
    - destination:
        host: api-service
    retryPolicy:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx,reset,connect-failure,refused-stream
      retryRemoteLocalities: true
```

### 2. 断路器优化
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: circuit-breaker-optimization
spec:
  host: reviews.default.svc.cluster.local
  trafficPolicy:
    outlierDetection:
      consecutiveErrors: 3
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 50
      # 快速恢复
      splitExternalLocalOriginErrors: true
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 10
        maxRequestsPerConnection: 2
```

## 最佳实践

### 1. 渐进式采用
- 从单个服务或命名空间开始
- 逐步扩展到更多服务
- 使用标签选择器精确控制 sidecar 注入

### 2. 资源管理
- 为 Envoy sidecar 设置适当的资源限制
- 监控和调优控制平面资源使用
- 使用 Sidecar 资源优化配置分发

### 3. 网络优化
- 启用 HTTP/2 提高连接复用
- 合理配置连接池大小
- 使用本地性感知负载均衡

### 4. 监控优化
- 只收集必要的指标和日志
- 使用适当的采样率
- 配置告警阈值避免噪音

### 5. 安全与性能平衡
- 合理使用 mTLS，考虑性能影响
- 优化 TLS 握手开销
- 使用会话复用减少加密开销

## 性能测试和基准

### 1. 压力测试配置
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: load-test-config
data:
  test-config.yaml: |
    scenarios:
    - name: baseline
      duration: 300s
      target: 1000  # RPS
      gracefulRampTime: 30s
    - name: peak-load
      duration: 600s
      target: 5000  # RPS
      gracefulRampTime: 60s
```

### 2. 性能监控指标
```yaml
# 关键性能指标
performance_metrics:
- name: latency_p99
  query: histogram_quantile(0.99, istio_request_duration_milliseconds_bucket)
- name: throughput
  query: sum(rate(istio_requests_total[1m]))
- name: error_rate
  query: sum(rate(istio_requests_total{response_code=~"5.."}[1m])) / sum(rate(istio_requests_total[1m]))
- name: cpu_usage
  query: rate(container_cpu_usage_seconds_total{container="istio-proxy"}[1m])
- name: memory_usage
  query: container_memory_working_set_bytes{container="istio-proxy"}
```

---

*最后更新时间: 2025-06-13*
