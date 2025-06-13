# Istio 最佳实践

## 最佳实践

### 1. 渐进式采用
- 从单个服务或命名空间开始
- 逐步扩展到更多服务
- 使用标签选择器精确控制 sidecar 注入

#### 渐进式注入策略
```yaml
# 阶段 1: 试点命名空间
apiVersion: v1
kind: Namespace
metadata:
  name: pilot
  labels:
    istio-injection: enabled
---
# 阶段 2: 选择性注入
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    istio-injection: disabled  # 默认禁用
---
apiVersion: v1
kind: Deployment
metadata:
  name: critical-service
  namespace: production
spec:
  template:
    metadata:
      annotations:
        sidecar.istio.io/inject: "true"  # 选择性启用
```

#### 金丝雀部署策略
```yaml
# 先部署到测试环境
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary-rollout
spec:
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: service
        subset: v2
      weight: 100
  - route:
    - destination:
        host: service
        subset: v1
      weight: 90
    - destination:
        host: service
        subset: v2
      weight: 10
```

### 2. 资源管理
- 为 Envoy sidecar 设置适当的资源限制
- 监控和调优控制平面资源使用
- 使用 Sidecar 资源优化配置分发

#### 资源配置建议
```yaml
# 生产环境 Sidecar 资源配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-sidecar-injector
  namespace: istio-system
data:
  config: |
    template: |
      spec:
        containers:
        - name: istio-proxy
          resources:
            limits:
              cpu: 1000m      # 生产环境增加 CPU 限制
              memory: 512Mi   # 根据实际使用调整
            requests:
              cpu: 100m       # 保守的请求值
              memory: 128Mi
```

#### 控制平面资源优化
```yaml
# Istiod 生产配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istiod
  namespace: istio-system
spec:
  replicas: 3  # 高可用配置
  template:
    spec:
      containers:
      - name: discovery
        resources:
          limits:
            cpu: 1000m
            memory: 2Gi
          requests:
            cpu: 500m
            memory: 2Gi
        env:
        - name: PILOT_PUSH_THROTTLE
          value: "100"
        - name: PILOT_DEBOUNCE_AFTER
          value: "100ms"
        - name: PILOT_DEBOUNCE_MAX
          value: "10s"
```

### 3. 安全配置
- 启用 mTLS 进行服务间通信加密
- 实施最小权限原则的授权策略
- 定期轮换证书和密钥

#### 安全策略配置
```yaml
# 全局 mTLS 策略
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT

# 最小权限授权策略
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec: {}  # 默认拒绝所有

# 具体服务授权
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: productpage-policy
  namespace: production
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/frontend"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
```

### 4. 可观测性
- 配置适当的指标收集
- 设置告警和监控
- 使用分布式追踪调试复杂的服务交互

#### 监控配置最佳实践
```yaml
# 选择性指标收集
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: production-metrics
spec:
  metrics:
  - providers:
    - name: prometheus
  - overrides:
    - match:
        metric: ALL_METRICS
      operation: UPSERT
      tags:
        # 移除高基数标签
        request_id:
          operation: REMOVE
        user_agent:
          operation: REMOVE
    - match:
        metric: istio_requests_total
        mode: CLIENT
      disabled: true  # 只保留服务端指标
```

#### 合理的采样率配置
```yaml
# 分层采样策略
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: tracing-sampling
spec:
  tracing:
  - providers:
    - name: jaeger
  - randomSamplingPercentage: 0.1  # 0.1% 基础采样
  - customTags:
      environment:
        literal:
          value: "production"
---
# 错误请求 100% 采样
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: error-tracing
spec:
  tracing:
  - providers:
    - name: jaeger
  - randomSamplingPercentage: 100
  - filter:
      expression: 'response.code >= 400'
```

### 5. 性能优化
- 调优 Envoy 配置以减少延迟
- 使用连接池和断路器提高弹性
- 监控和优化资源使用

#### 连接池最佳实践
```yaml
# 优化的连接池配置
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: production-defaults
spec:
  host: "*.production.svc.cluster.local"
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
        connectTimeout: 10s
        keepAlive:
          time: 7200s
          interval: 75s
      http:
        http1MaxPendingRequests: 64
        http2MaxRequests: 1000
        maxRequestsPerConnection: 10
        maxRetries: 3
        h2UpgradePolicy: UPGRADE
        useClientProtocol: true
    outlierDetection:
      consecutiveErrors: 3
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 50
```

## 生产环境建议

### 1. 高可用配置
```yaml
# 多副本 Istiod
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istiod
  namespace: istio-system
spec:
  replicas: 3
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: istiod
            topologyKey: kubernetes.io/hostname
```

### 2. 多集群配置
```yaml
# 主集群配置
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: primary
spec:
  values:
    pilot:
      env:
        EXTERNAL_ISTIOD: true
        DISCOVERY_ADDRESS: istiod.istio-system.svc.cluster.local:15012
---
# 远程集群配置
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: remote
spec:
  values:
    istiodRemote:
      enabled: true
    pilot:
      env:
        DISCOVERY_ADDRESS: <DISCOVERY_ADDRESS>
        PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION: true
```

### 3. 备份和恢复
```bash
# 备份 Istio 配置
kubectl get all,gateway,virtualservice,destinationrule,serviceentry,sidecar,authorizationpolicy,peerauthentication,requestauthentication,telemetry -n istio-system -o yaml > istio-backup.yaml

# 备份自定义资源
kubectl get crd | grep istio.io | awk '{print $1}' | xargs -I {} kubectl get {} -A -o yaml > istio-crds-backup.yaml

# 恢复配置
kubectl apply -f istio-backup.yaml
kubectl apply -f istio-crds-backup.yaml
```

## 开发环境实践

### 1. 快速开发配置
```yaml
# 开发环境宽松策略
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: development
spec:
  mtls:
    mode: PERMISSIVE  # 允许明文通信

# 开发环境全量日志
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: dev-logging
  namespace: development
spec:
  accessLogging:
  - providers:
    - name: otel
  - format:
      text: |
        [%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%"
        %RESPONSE_CODE% %RESPONSE_FLAGS% %BYTES_RECEIVED% %BYTES_SENT%
        %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% "%REQ(X-FORWARDED-FOR)%"
        "%REQ(USER-AGENT)%" "%REQ(X-REQUEST-ID)%" "%REQ(:AUTHORITY)%" "%UPSTREAM_HOST%"
```

### 2. 调试配置
```yaml
# 启用详细日志
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio
  namespace: istio-system
data:
  mesh: |
    defaultConfig:
      proxyLogLevel: debug
      componentLogLevel: "misc:error"
    accessLogFile: /dev/stdout
```

## 升级策略

### 1. 金丝雀升级
```bash
# 1. 安装新版本 Istiod
istioctl install --set revision=1-20-0 --set values.pilot.env.PILOT_ENABLE_CROSS_CLUSTER_WORKLOAD_ENTRY=true

# 2. 逐步迁移工作负载
kubectl label namespace production istio.io/rev=1-20-0 --overwrite
kubectl label namespace production istio-injection-

# 3. 重启 Pod 以使用新版本
kubectl rollout restart deployment -n production

# 4. 验证后移除旧版本
istioctl uninstall --revision=1-19-0
```

### 2. 回滚策略
```bash
# 快速回滚
kubectl label namespace production istio.io/rev=1-19-0 --overwrite
kubectl label namespace production istio.io/rev-
kubectl rollout restart deployment -n production
```

## 监控和告警

### 1. 关键指标监控
```yaml
# SLI/SLO 定义
apiVersion: v1
kind: ConfigMap
metadata:
  name: slo-config
data:
  config.yaml: |
    slos:
    - name: api-availability
      target: 99.9
      query: |
        sum(rate(istio_requests_total{response_code!~"5.."}[5m])) /
        sum(rate(istio_requests_total[5m]))
    
    - name: api-latency
      target: 500  # ms
      query: |
        histogram_quantile(0.99,
          sum(rate(istio_request_duration_milliseconds_bucket[5m]))
          by (destination_service_name, le)
        )
```

### 2. 告警规则
```yaml
# 生产环境告警
groups:
- name: istio-production
  rules:
  - alert: IstioHighErrorRate
    expr: |
      (
        sum(rate(istio_requests_total{response_code=~"5.."}[5m])) /
        sum(rate(istio_requests_total[5m]))
      ) * 100 > 1
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Istio error rate is above 1%"
      description: "Error rate is {{ $value }}%"

  - alert: IstioHighLatency
    expr: |
      histogram_quantile(0.99,
        sum(rate(istio_request_duration_milliseconds_bucket[5m]))
        by (destination_service_name, le)
      ) > 1000
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Istio P99 latency is above 1000ms"

  - alert: IstiodDown
    expr: up{job="istiod"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Istiod is down"
```

## 安全最佳实践

### 1. 网络策略
```yaml
# 结合 Kubernetes NetworkPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-istio
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
          name: istio-system
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: istio-system
```

### 2. 证书管理
```yaml
# 自定义 CA 配置
apiVersion: v1
kind: Secret
metadata:
  name: cacerts
  namespace: istio-system
type: Opaque
data:
  root-cert.pem: <base64-encoded-root-cert>
  cert-chain.pem: <base64-encoded-cert-chain>
  ca-cert.pem: <base64-encoded-ca-cert>
  ca-key.pem: <base64-encoded-ca-key>
```

### 3. 最小权限原则
```yaml
# 细粒度 RBAC
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: productpage-policy
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/frontend"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/productpage"]
  - when:
    - key: source.ip
      values: ["10.0.0.0/8"]  # 内网访问
```

## 故障预防

### 1. 配置验证
```bash
# 部署前验证
istioctl analyze

# 持续集成中的验证
istioctl validate -f manifests/

# 配置 admission controller
kubectl apply -f - <<EOF
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: istio-config-validator
webhooks:
- name: config.validation.istio.io
  clientConfig:
    service:
      name: istiod
      namespace: istio-system
      path: "/validate"
EOF
```

### 2. 渐进式部署
```yaml
# 使用 ArgoCD 渐进式部署
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: productpage
spec:
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 10m}
      - setWeight: 50
      - pause: {duration: 10m}
      canaryService: productpage-canary
      stableService: productpage-stable
      trafficRouting:
        istio:
          virtualService:
            name: productpage-vs
            routes:
            - primary
```

---

*最后更新时间: 2025-06-13*
