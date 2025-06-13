# Istio 故障排查

## 故障处理机制

### 1. 熔断器
```
熔断器状态转换：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Closed    │ -> │    Open     │ -> │ Half-Open   │
│    关闭     │    │    开启     │    │   半开启    │ 
│  正常通行    │    │   快速失败   │    │   试探性通行  │
└─────────────┘    └─────────────┘    └─────────────┘
       ^                                      │
       │                                      │
       └──────────────────────────────────────┘
```

### 2. 重试和超时
- **指数退避**：重试间隔逐渐增加
- **超时控制**：防止长时间等待
- **最大重试次数**：避免无限重试

## 常见问题排查

### 1. 网络连接问题

#### Sidecar 注入失败
**问题现象**：
- Pod 中没有 istio-proxy 容器
- 服务无法被网格管理

**排查步骤**：
```bash
# 检查命名空间标签
kubectl get namespace default --show-labels

# 检查 sidecar 注入器状态
kubectl get mutatingwebhookconfigurations istio-sidecar-injector -o yaml

# 检查 Pod 注解
kubectl describe pod <pod-name>

# 手动注入测试
istioctl kube-inject -f deployment.yaml | kubectl apply -f -
```

**常见原因和解决方案**：
```yaml
# 1. 命名空间未启用注入
apiVersion: v1
kind: Namespace
metadata:
  name: default
  labels:
    istio-injection: enabled

# 2. Pod 显式禁用注入
apiVersion: v1
kind: Pod
metadata:
  annotations:
    sidecar.istio.io/inject: "false"  # 移除此注解

# 3. Webhook 配置问题
kubectl get pods -n istio-system
kubectl logs deployment/istiod -n istio-system
```

#### 服务发现问题
**问题现象**：
- 服务间无法通信
- DNS 解析失败
- Envoy 无法获取端点信息

**排查命令**：
```bash
# 检查服务和端点
kubectl get svc,endpoints

# 检查 Envoy 配置
istioctl proxy-config cluster <pod-name> -n <namespace>
istioctl proxy-config endpoints <pod-name> -n <namespace>

# 检查 DNS 解析
kubectl exec -it <pod-name> -c istio-proxy -- nslookup <service-name>

# 检查服务注册
istioctl proxy-status
```

**解决方案**：
```bash
# 重启相关服务
kubectl rollout restart deployment/<deployment-name>

# 强制配置同步
istioctl proxy-config cluster <pod-name> --fqdn <service-fqdn>

# 检查网络策略
kubectl get networkpolicies
```

#### mTLS 认证问题
**问题现象**：
- 连接被拒绝 (connection refused)
- TLS 握手失败
- 证书验证错误

**排查步骤**：
```bash
# 检查 mTLS 状态
istioctl authn tls-check <pod-name>.<namespace>

# 检查证书
istioctl proxy-config secret <pod-name> -n <namespace>

# 检查 PeerAuthentication 策略
kubectl get peerauthentication -A

# 查看 TLS 配置
istioctl proxy-config listener <pod-name> -n <namespace> --port 15006 -o json
```

**常见解决方案**：
```yaml
# 1. 设置 PERMISSIVE 模式
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: PERMISSIVE

# 2. 检查目标规则
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: default
spec:
  host: "*.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```

### 2. 路由和流量管理问题

#### 路由规则不生效
**问题现象**：
- 流量没有按预期路由
- 金丝雀发布失败
- 负载均衡不正常

**排查命令**：
```bash
# 检查虚拟服务配置
kubectl get virtualservices -A
kubectl describe virtualservice <vs-name>

# 检查目标规则
kubectl get destinationrules -A
kubectl describe destinationrule <dr-name>

# 检查 Envoy 路由配置
istioctl proxy-config routes <pod-name> -n <namespace>
istioctl proxy-config listeners <pod-name> -n <namespace>

# 检查配置状态
istioctl analyze
```

**调试技巧**：
```bash
# 启用访问日志
kubectl patch configmap istio -n istio-system --type merge -p='{"data":{"mesh":"accessLogFile: /dev/stdout"}}'

# 查看实时日志
kubectl logs -f <pod-name> -c istio-proxy

# 使用 Envoy admin 接口
kubectl port-forward <pod-name> 15000:15000
curl http://localhost:15000/config_dump
```

#### Gateway 配置问题
**问题现象**：
- 外部流量无法访问
- 证书配置错误
- 端口不通

**排查步骤**：
```bash
# 检查 Gateway 状态
kubectl get gateway -A
kubectl describe gateway <gateway-name>

# 检查 Ingress Gateway Pod
kubectl get pods -n istio-system -l app=istio-ingressgateway
kubectl logs -n istio-system -l app=istio-ingressgateway

# 检查监听器配置
istioctl proxy-config listeners deploy/istio-ingressgateway -n istio-system

# 测试端口连通性
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
```

### 3. 性能问题

#### 高延迟问题
**排查工具**：
```bash
# 查看延迟指标
curl "http://prometheus:9090/api/v1/query?query=histogram_quantile(0.99,sum(rate(istio_request_duration_milliseconds_bucket[5m]))by(le))"

# 分析调用链
# 在 Jaeger UI 中查看 trace

# 检查 Envoy 统计信息
kubectl exec <pod-name> -c istio-proxy -- curl localhost:15000/stats | grep -E "(upstream_rq_time|downstream_rq_time)"
```

**常见原因**：
- 连接池配置不当
- 重试策略过于激进
- 上游服务性能问题
- 网络配置问题

#### 内存泄漏问题
**监控命令**：
```bash
# 查看内存使用
kubectl top pods
kubectl exec <pod-name> -c istio-proxy -- curl localhost:15000/memory

# 检查连接数
kubectl exec <pod-name> -c istio-proxy -- curl localhost:15000/stats | grep cx_

# 查看配置大小
istioctl proxy-config cluster <pod-name> | wc -l
```

### 4. 安全策略问题

#### 授权策略配置错误
**问题现象**：
- 403 Forbidden 错误
- 正常请求被拒绝
- 策略不生效

**排查方法**：
```bash
# 检查授权策略
kubectl get authorizationpolicy -A
kubectl describe authorizationpolicy <policy-name>

# 查看 RBAC 配置
istioctl proxy-config listener <pod-name> -n <namespace> --port 15006 -o json | jq '.[] | select(.filterChains[].filters[].typedConfig.httpFilters[]?.name == "envoy.filters.http.rbac")'

# 启用授权调试日志
kubectl annotate pod <pod-name> sidecar.istio.io/logLevel=rbac:debug

# 查看授权日志
kubectl logs <pod-name> -c istio-proxy | grep rbac
```

#### JWT 验证问题
**排查步骤**：
```bash
# 检查 RequestAuthentication
kubectl get requestauthentication -A

# 验证 JWT Token
istioctl authn tls-check <service>.<namespace>

# 检查 JWKS 端点
curl <jwks-uri>

# 查看认证日志
kubectl logs <pod-name> -c istio-proxy | grep jwt
```

## 诊断工具使用

### 1. istioctl 诊断命令

#### 配置分析
```bash
# 全面配置分析
istioctl analyze

# 分析特定命名空间
istioctl analyze -n production

# 检查特定资源
istioctl analyze -f virtualservice.yaml

# 详细分析报告
istioctl analyze --verbose
```

#### 代理配置检查
```bash
# 查看代理状态
istioctl proxy-status

# 配置导出
istioctl proxy-config all <pod-name> -n <namespace> -o json > config-dump.json

# 特定配置检查
istioctl proxy-config cluster <pod-name>
istioctl proxy-config listener <pod-name>
istioctl proxy-config route <pod-name>
istioctl proxy-config endpoint <pod-name>
istioctl proxy-config bootstrap <pod-name>
istioctl proxy-config log <pod-name>
istioctl proxy-config secret <pod-name>
```

#### 流量分析
```bash
# 查看流量
istioctl experimental authz check <pod-name>

# 检查 TLS 配置
istioctl authn tls-check <service>.<namespace>

# 验证配置
istioctl validate -f config.yaml
```

### 2. 日志分析

#### Envoy 访问日志
```bash
# 基本访问日志查看
kubectl logs <pod-name> -c istio-proxy

# 过滤错误请求
kubectl logs <pod-name> -c istio-proxy | grep -E "40[0-9]|50[0-9]"

# 统计状态码
kubectl logs <pod-name> -c istio-proxy | awk '{print $9}' | sort | uniq -c

# 查看慢请求
kubectl logs <pod-name> -c istio-proxy | awk '$NF > 1000'
```

#### Istiod 组件日志
```bash
# 查看控制平面日志
kubectl logs -n istio-system deployment/istiod

# 过滤特定类型日志
kubectl logs -n istio-system deployment/istiod | grep -i error
kubectl logs -n istio-system deployment/istiod | grep -i "config\|push"

# 实时监控日志
kubectl logs -f -n istio-system deployment/istiod
```

### 3. 网络诊断

#### 连通性测试
```bash
# 创建测试 Pod
kubectl run debug --image=nicolaka/netshoot -it --rm

# 在测试 Pod 中执行
# DNS 测试
nslookup productpage.default.svc.cluster.local

# 端口测试
nc -zv productpage.default.svc.cluster.local 9080

# HTTP 测试
curl -v http://productpage.default.svc.cluster.local:9080/
```

#### 证书检查
```bash
# 检查服务端证书
openssl s_client -connect productpage:9080 -servername productpage

# 检查证书链
istioctl proxy-config secret <pod-name> -o json | jq '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' | base64 -d | openssl x509 -text

# 验证证书有效期
kubectl get secret -n istio-system istio-ca-secret -o jsonpath='{.data.cert-chain\.pem}' | base64 -d | openssl x509 -text | grep -A2 "Validity"
```

## 故障恢复策略

### 1. 自动恢复机制
```yaml
# 健康检查配置
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: circuit-breaker
spec:
  host: productpage
  trafficPolicy:
    outlierDetection:
      consecutiveErrors: 3
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 10
        maxRequestsPerConnection: 2
```

### 2. 重试机制
```yaml
# 智能重试配置
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: productpage
spec:
  http:
  - route:
    - destination:
        host: productpage
    retryPolicy:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx,reset,connect-failure,refused-stream
      retryRemoteLocalities: true
```

### 3. 超时控制
```yaml
# 超时配置
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  http:
  - route:
    - destination:
        host: reviews
    timeout: 10s
```

## 性能调优建议

### 1. 监控关键指标
```yaml
# 关键指标告警
groups:
- name: istio-performance
  rules:
  - alert: HighLatency
    expr: histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le)) > 1000
    for: 2m

  - alert: HighErrorRate
    expr: sum(rate(istio_requests_total{response_code=~"5.."}[5m])) / sum(rate(istio_requests_total[5m])) > 0.01
    for: 2m

  - alert: ConfigSyncErrors
    expr: sum(rate(pilot_xds_pushes_total{type="nack"}[5m])) > 0
    for: 1m
```

### 2. 资源优化
```yaml
# Envoy 资源限制
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

# 控制平面优化
env:
- name: PILOT_PUSH_THROTTLE
  value: "100"
- name: PILOT_DEBOUNCE_AFTER
  value: "100ms"
```

## 应急处理流程

### 1. 紧急故障处理
```bash
# 1. 快速禁用特定服务的 sidecar
kubectl patch deployment <deployment-name> -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"false"}}}}}'

# 2. 回滚到上一个版本
kubectl rollout undo deployment/<deployment-name>

# 3. 暂时禁用 mTLS
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: disable-mtls
  namespace: <namespace>
spec:
  mtls:
    mode: DISABLE
EOF

# 4. 移除问题配置
kubectl delete virtualservice <problematic-vs>
kubectl delete destinationrule <problematic-dr>
```

### 2. 分步排查流程
```
故障排查流程：
1. 确认问题范围 → 影响的服务和用户
2. 检查基础设施 → 网络、DNS、证书
3. 分析配置 → VirtualService、DestinationRule
4. 查看日志 → Envoy、Istiod 日志
5. 验证修复 → 测试和监控确认
```

### 3. 预防措施
- 配置变更前使用 `istioctl analyze` 验证
- 实施渐进式部署
- 设置适当的监控和告警
- 定期备份关键配置
- 建立故障响应手册

---

*最后更新时间: 2025-06-13*
