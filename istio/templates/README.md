# Istio 流量治理模板

本目录包含了完整的 Istio 流量治理资源模板，涵盖流量管理、安全策略、可观测性等各个方面。

## 📁 模板文件说明

### 🚦 流量管理 (Traffic Management)

#### `virtual-service.yaml`
**VirtualService** - HTTP/TCP 流量路由配置
- HTTP 流量路由（基于 Header、URI 等条件）
- 权重分流 (A/B Testing, 金丝雀发布)
- 故障注入 (延迟、错误)
- 超时和重试配置
- TCP 流量路由

#### `destination-rule.yaml`
**DestinationRule** - 目标服务策略配置
- 负载均衡策略 (ROUND_ROBIN, LEAST_CONN, RANDOM, PASSTHROUGH)
- 连接池管理 (TCP/HTTP 连接限制)
- 熔断器配置 (Circuit Breaker)
- 服务子集定义 (Subsets)
- mTLS 配置

#### `gateway.yaml`
**Gateway** - 入口网关配置
- HTTP/HTTPS 网关配置
- TLS 终止和证书管理
- TCP/TLS 网关
- mTLS 双向认证
- 多协议网关 (HTTP, HTTPS, GRPC, MONGO)

#### `service-entry.yaml`
**ServiceEntry** - 外部服务注册
- 外部 HTTP/HTTPS 服务
- 外部 TCP 服务
- 静态 IP 地址配置
- VM 工作负载注册
- gRPC 外部服务

### 🔒 安全策略 (Security)

#### `policy.yaml`
安全相关的策略配置
- **RequestAuthentication** - JWT 认证配置
- **AuthorizationPolicy** - RBAC 授权策略
- **PeerAuthentication** - mTLS 对等认证

### 🔧 高级配置 (Advanced Configuration)

#### `envoyfilter.yaml`
**EnvoyFilter** - Envoy 代理自定义配置
- 限流 (Rate Limiting)
- WebAssembly 插件
- Lua 脚本
- 熔断器
- 自定义访问日志

#### `workloadentry.yaml`
工作负载和边车配置
- **WorkloadEntry** - VM 工作负载注册
- **WorkloadGroup** - VM 集群管理
- **Sidecar** - 边车代理配置

### 📊 可观测性 (Observability)

#### `telemetry.yaml`
**Telemetry** - 遥测数据配置
- 自定义指标收集
- 分布式链路追踪
- 访问日志配置
- 命名空间级别遥测
- 工作负载特定遥测

## 🚀 使用方法

### 1. 基础流量路由
```bash
# 应用 VirtualService 和 DestinationRule
kubectl apply -f virtual-service.yaml
kubectl apply -f destination-rule.yaml
```

### 2. 配置入口网关
```bash
# 应用 Gateway 配置
kubectl apply -f gateway.yaml
```

### 3. 安全策略配置
```bash
# 应用安全策略
kubectl apply -f policy.yaml
```

### 4. 外部服务集成
```bash
# 注册外部服务
kubectl apply -f service-entry.yaml
```

### 5. 高级功能配置
```bash
# 应用 EnvoyFilter
kubectl apply -f envoyfilter.yaml

# 配置工作负载
kubectl apply -f workloadentry.yaml
```

### 6. 可观测性配置
```bash
# 配置遥测
kubectl apply -f telemetry.yaml
```

## 📋 常见使用场景

### 🔄 金丝雀发布 (Canary Deployment)
```yaml
# 在 virtual-service.yaml 中配置权重分流
route:
- destination:
    host: my-service
    subset: v1
  weight: 90
- destination:
    host: my-service
    subset: v2
  weight: 10
```

### 🛡️ 基于用户的路由
```yaml
# 在 virtual-service.yaml 中配置基于 Header 的路由
match:
- headers:
    end-user:
      exact: jason
route:
- destination:
    host: my-service
    subset: v2
```

### 🔐 mTLS 安全策略
```yaml
# 在 policy.yaml 中配置 mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT
```

### 📈 自定义指标收集
```yaml
# 在 telemetry.yaml 中配置自定义指标
dimensions:
  source_service: source.workload.name | "unknown"
  destination_service: destination.service.name | "unknown"
  request_protocol: request.protocol | "unknown"
```

## ⚠️ 注意事项

1. **命名空间**: 所有模板默认使用 `default` 命名空间，请根据实际情况修改
2. **服务名称**: 请将模板中的示例服务名称替换为实际的服务名称
3. **证书配置**: Gateway 中的 TLS 证书需要预先创建并上传到集群
4. **资源依赖**: 某些资源有依赖关系，请按照正确顺序应用
5. **版本兼容**: 请确保模板版本与 Istio 版本兼容

## 🔧 自定义配置

每个模板文件都包含多个示例配置，您可以：

1. **选择性应用**: 根据需要选择特定的资源配置
2. **参数替换**: 将示例值替换为实际的服务和配置参数
3. **组合使用**: 结合多个模板实现复杂的流量治理策略
4. **扩展配置**: 基于模板添加更多自定义配置

## 📚 相关文档

- [Istio 官方文档](https://istio.io/latest/docs/)
- [流量管理概念](https://istio.io/latest/docs/concepts/traffic-management/)
- [安全策略指南](https://istio.io/latest/docs/concepts/security/)
- [可观测性配置](https://istio.io/latest/docs/concepts/observability/)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这些模板！
