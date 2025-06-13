# Istio 工作原理

## Sidecar 模式工作原理

### 1. 代理注入详细流程
```
应用 Pod 部署过程：
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   原始 Pod      │ -> │  Sidecar 注入     │ -> │  最终 Pod       │
│ ┌─────────────┐ │    │ ┌─────────────┐  │    │ ┌─────────────┐ │
│ │ Application │ │    │ │ Application │  │    │ │ Application │ │
│ └─────────────┘ │    │ └─────────────┘  │    │ └─────────────┘ │
└─────────────────┘    │ ┌─────────────┐  │    │ ┌─────────────┐ │
                       │ │ Envoy Proxy │  │    │ │ Envoy Proxy │ │
                       │ └─────────────┘  │    │ └─────────────┘ │
                       └──────────────────┘    └─────────────────┘
```

**注入机制**：
- **Admission Controller**：Kubernetes 准入控制器拦截 Pod 创建请求
- **Webhook 调用**：调用 Istiod 的 sidecar-injector webhook
- **注入决策**：基于命名空间标签、Pod 注解、全局策略决定是否注入
- **配置生成**：动态生成 Envoy 容器和 init 容器配置
- **Pod 修改**：修改 Pod 规范，添加 sidecar 容器

**注入条件判断**：
```yaml
# 命名空间级别启用
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled

# Pod 级别控制
apiVersion: v1
kind: Pod
metadata:
  annotations:
    sidecar.istio.io/inject: "true"  # 强制注入
    sidecar.istio.io/inject: "false" # 禁用注入
```

### 2. 流量拦截详细机制
**Init 容器工作流程**：
```
Init 容器执行过程：
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Pod 启动       │ -> │ Init 容器执行    │ -> │ 应用容器启动     │
│                │    │ iptables 规则    │    │ 流量已被拦截     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

**iptables 规则详解**：
```bash
# 出站流量重定向规则
iptables -t nat -A OUTPUT -p tcp --dport $port -j REDIRECT --to-port 15001

# 入站流量重定向规则  
iptables -t nat -A PREROUTING -p tcp --dport $port -j REDIRECT --to-port 15006

# 排除特定端口和地址
iptables -t nat -I OUTPUT -s 127.0.0.6/32 -j RETURN
iptables -t nat -I OUTPUT -d 127.0.0.1/32 -j RETURN
```

**端口映射详情**：
- **15001**：Envoy 出站代理端口
- **15006**：Envoy 入站代理端口  
- **15000**：Envoy 管理端口
- **15020**：Envoy 健康检查端口
- **15021**：Envoy 就绪检查端口
- **15090**：Envoy 指标端口

**流量处理流程**：
```
请求流量处理：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Application │ -> │  iptables   │ -> │    Envoy    │ -> │   Target    │
│   发起请求   │    │   重定向    │    │   代理处理   │    │   目标服务   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                           │                  │
                           v                  v
                   ┌─────────────────────────────┐
                   │       监听器链               │
                   │  - HTTP Connection Manager  │
                   │  - TLS Inspector            │
                   │  - HTTP Filters             │
                   └─────────────────────────────┘
```

## 服务发现工作流程

### 1. 服务注册详细流程
```
Kubernetes 服务注册流程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Service   │ -> │  Endpoints  │ -> │    Pilot    │ -> │   Envoy     │
│  创建/更新   │    │   发现      │    │   处理      │    │   配置更新   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**详细步骤**：
1. **Kubernetes 资源监听**：
   - Pilot 监听 Kubernetes API Server
   - 关注 Service、Endpoints、Pod 等资源变化
   - 使用 Informer 机制高效监听资源变更

2. **服务抽象模型构建**：
   ```go
   type Service struct {
       Hostname    string
       Ports       []Port
       Address     string
       Resolution  Resolution  // DNS, ClientSideLB, Passthrough
       Attributes  ServiceAttributes
   }
   ```

3. **服务实例发现**：
   ```go
   type ServiceInstance struct {
       Service     *Service
       Endpoint    NetworkEndpoint
       Labels      Labels
       TLSMode     TLSMode
   }
   ```

### 2. xDS 配置分发详细机制
**xDS 协议栈**：
```
xDS 协议层次：
┌─────────────────────────────────────┐
│           Management Server         │  <- Istiod/Pilot
│         (Pilot Discovery)           │
└─────────────────────────────────────┘
                    │
                    │ gRPC Stream
                    │
┌─────────────────────────────────────┐
│              xDS APIs               │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐    │
│  │ LDS │ │ RDS │ │ CDS │ │ EDS │    │
│  └─────┘ └─────┘ └─────┘ └─────┘    │ 
└─────────────────────────────────────┘
                    │
                    │ Configuration
                    │
┌─────────────────────────────────────┐
│            Envoy Proxy              │
└─────────────────────────────────────┘
```

**xDS 配置类型详解**：

1. **LDS (Listener Discovery Service)**：
   ```json
   {
     "name": "0.0.0.0_8080",
     "address": {
       "socket_address": {
         "address": "0.0.0.0",
         "port_value": 8080
       }
     },
     "filter_chains": [{
       "filters": [{
         "name": "envoy.filters.network.http_connection_manager",
         "typed_config": {
           "route_config_name": "8080"
         }
       }]
     }]
   }
   ```

2. **RDS (Route Discovery Service)**：
   ```json
   {
     "name": "8080",
     "virtual_hosts": [{
       "name": "productpage:8080",
       "domains": ["productpage:8080"],
       "routes": [{
         "match": {"prefix": "/"},
         "route": {"cluster": "outbound|8080||productpage"}
       }]
     }]
   }
   ```

3. **CDS (Cluster Discovery Service)**：
   ```json
   {
     "name": "outbound|8080||productpage",
     "type": "EDS",
     "eds_cluster_config": {
       "eds_config": {
         "ads": {}
       }
     },
     "lb_policy": "ROUND_ROBIN"
   }
   ```

4. **EDS (Endpoint Discovery Service)**：
   ```json
   {
     "cluster_name": "outbound|8080||productpage",
     "endpoints": [{
       "lb_endpoints": [{
         "endpoint": {
           "address": {
             "socket_address": {
               "address": "10.244.0.5",
               "port_value": 8080
             }
           }
         }
       }]
     }]
   }
   ```

**配置推送策略**：
- **增量更新**：只推送变更的配置，减少网络开销
- **版本控制**：每个配置都有版本号，支持回滚
- **ACK/NACK 机制**：Envoy 确认配置接收和应用状态
- **错误处理**：配置应用失败时的降级策略

**配置同步流程**：
```
配置同步详细流程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ K8s 资源    │ -> │   Pilot     │ -> │   Envoy     │ -> │  ACK/NACK   │
│ 变更事件    │    │ 配置计算    │    │ 配置应用    │    │   响应      │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                          │                  │                  │
                          v                  v                  v
                   ┌─────────────────────────────────────────────────┐
                   │              配置存储和缓存                      │
                   │  - 内存缓存 (最近使用的配置)                    │
                   │  - 持久化存储 (配置快照)                       │
                   │  - 增量计算 (差异检测)                         │
                   └─────────────────────────────────────────────────┘
```

### 3. 服务网格内部通信机制
**服务间调用流程**：
```
服务调用详细流程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Service A   │ -> │ Envoy A     │ -> │ Envoy B     │ -> │ Service B   │
│ 发起调用    │    │ 出站处理    │    │ 入站处理    │    │ 接收请求    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                          │                  │
                          v                  v
                   ┌─────────────────────────────┐
                   │       服务注册表             │
                   │  - 服务发现                 │
                   │  - 负载均衡                 │
                   │  - 健康检查                 │
                   │  - 故障转移                 │
                   └─────────────────────────────┘
```

**DNS 解析和服务发现**：
- **内部 DNS**：Kubernetes DNS 提供服务名解析
- **FQDN 格式**：`service.namespace.svc.cluster.local`
- **短名称**：在同一命名空间内可使用短服务名
- **外部服务**：通过 ServiceEntry 注册外部依赖

## 流量管理工作原理

### 1. 请求路由详细流程
```
客户端请求处理流程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │ -> │   Gateway   │ -> │ VirtualSvc  │ -> │   Service   │
│   请求      │    │   入口网关   │    │   路由规则   │    │   目标服务   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                              │
                                              v
                                    ┌─────────────┐
                                    │DestinRule   │
                                    │ 目标规则    │
                                    └─────────────┘
```

**路由匹配逻辑**：
```
请求路由匹配过程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ HTTP Request│ -> │ Header Match│ -> │  URI Match  │ -> │Route Action │
│   到达      │    │   检查      │    │   检查      │    │   执行      │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                          │                  │                  │
                          v                  v                  v
                   ┌─────────────────────────────────────────────────┐
                   │              路由规则优先级                      │
                   │  1. 精确匹配 (exact)                           │
                   │  2. 前缀匹配 (prefix)                          │
                   │  3. 正则匹配 (regex)                           │
                   │  4. 默认路由 (catch-all)                       │
                   └─────────────────────────────────────────────────┘
```

**流量分割实现**：
```yaml
# 金丝雀发布示例
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: productpage
        subset: v2
  - route:
    - destination:
        host: productpage
        subset: v1
      weight: 90
    - destination:
        host: productpage
        subset: v2
      weight: 10
```

### 2. 负载均衡详细机制
**负载均衡算法实现**：

1. **Round Robin（轮询）**：
   ```
   请求分发轮询：
   Request 1 -> Endpoint A
   Request 2 -> Endpoint B  
   Request 3 -> Endpoint C
   Request 4 -> Endpoint A (循环)
   ```

2. **Least Request（最少请求）**：
   ```
   活跃请求统计：
   Endpoint A: 5 requests
   Endpoint B: 3 requests ← 选择
   Endpoint C: 7 requests
   ```

3. **Random（随机）**：
   ```
   随机选择：
   随机数 % 端点数量 = 选中的端点
   ```

4. **Hash（哈希）**：
   ```
   一致性哈希：
   Hash(源IP/Header) % 端点数量 = 选中的端点
   ```

**健康检查机制**：
```
健康检查流程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 主动检查    │ -> │ 被动检查    │ -> │ 状态评估    │ -> │ 流量调整    │
│ HTTP/TCP    │    │ 错误率统计  │    │ 健康度计算  │    │ 权重更新    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**主动健康检查配置**：
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
spec:
  trafficPolicy:
    healthCheck:
      interval: 30s           # 检查间隔
      timeout: 5s            # 超时时间
      unhealthyThreshold: 3  # 不健康阈值
      healthyThreshold: 2    # 健康阈值
      path: "/health"        # 检查路径
```

**被动健康检查（异常检测）**：
```yaml
trafficPolicy:
  outlierDetection:
    consecutiveErrors: 5        # 连续错误次数
    interval: 30s              # 检测间隔
    baseEjectionTime: 30s      # 基本驱逐时间
    maxEjectionPercent: 50     # 最大驱逐百分比
    splitExternalLocalOriginErrors: true
```

### 3. 连接池和断路器
**连接池配置**：
```yaml
trafficPolicy:
  connectionPool:
    tcp:
      maxConnections: 100      # 最大连接数
      connectTimeout: 30s      # 连接超时
      keepAlive:
        time: 7200s           # TCP Keep-Alive 时间
        interval: 75s         # Keep-Alive 探测间隔
    http:
      http1MaxPendingRequests: 10   # HTTP/1.1 等待请求数
      http2MaxRequests: 100         # HTTP/2 最大请求数
      maxRequestsPerConnection: 2   # 每连接最大请求数
      maxRetries: 3                 # 最大重试次数
```

**断路器状态管理**：
```
断路器详细状态转换：
┌─────────────┐  错误率超阈值  ┌─────────────┐  超时后试探  ┌─────────────┐
│   Closed    │ ────────── > │    Open     │ ────────── > │ Half-Open   │
│    关闭     │              │    开启     │              │   半开启    │
│  正常通行    │              │   快速失败   │              │   试探性通行  │
└─────────────┘              └─────────────┘              └─────────────┘
       ^                                                         │
       │ 试探成功                                                │ 试探失败
       └─────────────────────────────────────────────────────────┘
```

## 安全工作原理

### 1. 身份验证详细流程
```
mTLS 身份验证流程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Service A  │ -> │  Envoy A    │ -> │  Envoy B    │ -> │  Service B  │
│   发起请求   │    │  客户端证书  │    │  服务端证书  │    │   处理请求   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                           │                  │
                           v                  v
                    ┌─────────────────────────────┐
                    │        Citadel CA           │
                    │    证书签发和验证            │
                    └─────────────────────────────┘
```

**证书生命周期管理**：
```
证书管理流程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 证书请求    │ -> │ CA 签发     │ -> │ 证书分发    │ -> │ 定期轮换    │
│ CSR 生成    │    │ 数字签名    │    │ Secret 存储 │    │ 自动更新    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**mTLS 握手详细过程**：
```
TLS 握手步骤：
1. Client Hello    -> 发送支持的加密套件
2. Server Hello    -> 选择加密套件，发送服务端证书
3. Client Cert     -> 发送客户端证书
4. Certificate Verify -> 证书验证
5. Finished        -> 握手完成，开始加密通信
```

**身份验证模式**：
```yaml
# STRICT 模式 - 强制 mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT

# PERMISSIVE 模式 - 兼容明文和加密
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: PERMISSIVE
```

**JWT 验证流程**：
```
JWT 验证详细流程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Client      │ -> │ JWT Token   │ -> │ Envoy       │ -> │ Service     │
│ 携带 Token  │    │ Header中    │    │ 验证签名    │    │ 授权访问    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                             │
                                             v
                                    ┌─────────────┐
                                    │ JWKS Endpoint│
                                    │ 获取公钥验证  │
                                    └─────────────┘
```

### 2. 授权决策详细机制
**授权策略评估流程**：
```
授权决策过程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 请求到达    │ -> │ 策略匹配    │ -> │ 规则评估    │ -> │ 访问决策    │
│ 提取属性    │    │ 选择适用规则 │    │ 条件检查    │    │ ALLOW/DENY  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**授权策略结构**：
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin-viewer
spec:
  selector:
    matchLabels:
      app: httpbin
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/sleep"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/headers"]
  - when:
    - key: request.headers[version]
      values: ["v1"]
```

**RBAC 决策树**：
```
授权规则匹配：
┌─────────────┐
│   Request   │
└─────┬───────┘
      │
      v
┌─────────────┐  No Match
│ Rule 1      │ ────────────┐
│ ALLOW       │             │
└─────┬───────┘             │
      │ Match               │
      v                     │
┌─────────────┐             │
│   ALLOW     │             │
└─────────────┘             │
                            │
┌─────────────┐  No Match   │
│ Rule 2      │ ────────────┤
│ DENY        │             │
└─────┬───────┘             │
      │ Match               │
      v                     │
┌─────────────┐             │
│    DENY     │             │
└─────────────┘             │
                            │
                            v
                   ┌─────────────┐
                   │   Default   │
                   │    DENY     │
                   └─────────────┘
```

**策略优先级**：
1. **CUSTOM 操作**：自定义外部授权
2. **DENY 操作**：拒绝访问
3. **ALLOW 操作**：允许访问
4. **默认策略**：如无匹配规则，默认拒绝

### 3. 安全策略实施点
**Envoy 安全过滤器链**：
```
安全过滤器处理流程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ TLS 终止    │ -> │ JWT 验证    │ -> │ RBAC 检查   │ -> │ 业务逻辑    │
│ 证书验证    │    │ Token 解析  │    │ 授权决策    │    │ 请求处理    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

---

*最后更新时间: 2025-06-13*
