# Istio 可观测性

## 可观测性工作原理

### 1. 指标收集详细机制
```
指标收集流程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Envoy     │ -> │ Prometheus  │ -> │   Grafana   │ -> │    用户     │
│   生成指标   │    │   收集存储   │    │   可视化    │    │   查看监控   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**Envoy 指标生成**：
```
Envoy 指标分类：
┌─────────────────────────────────────┐
│            Envoy 指标               │
├─────────────────────────────────────┤
│ 1. 请求指标                         │
│    - istio_requests_total           │
│    - istio_request_duration_ms      │
│    - istio_request_bytes           │
│    - istio_response_bytes          │
├─────────────────────────────────────┤
│ 2. TCP 指标                        │
│    - istio_tcp_opened_total        │
│    - istio_tcp_closed_total        │
│    - istio_tcp_sent_bytes_total    │
│    - istio_tcp_received_bytes_total│
├─────────────────────────────────────┤
│ 3. 上游服务指标                     │
│    - envoy_cluster_upstream_rq_*   │
│    - envoy_cluster_health_check_*  │
│    - envoy_cluster_outlier_*       │
└─────────────────────────────────────┘
```

**指标标签和维度**：
```yaml
# 典型的 Istio 指标标签
labels:
  source_workload: "productpage-v1"
  source_app: "productpage"
  source_version: "v1"
  destination_service_name: "reviews"
  destination_service_namespace: "default"
  destination_workload: "reviews-v1"
  request_protocol: "http"
  response_code: "200"
  connection_security_policy: "mutual_tls"
```

**Prometheus 抓取配置**：
```yaml
# Prometheus 抓取 Envoy 指标
- job_name: 'istio-mesh'
  kubernetes_sd_configs:
  - role: endpoints
    namespaces:
      names:
      - istio-system
  relabel_configs:
  - source_labels: [__meta_kubernetes_service_name]
    action: keep
    regex: istio-proxy
  - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
    action: replace
    regex: ([^:]+)(?::\d+)?;(\d+)
    replacement: $1:$2
    target_label: __address__
  - action: labelmap
    regex: __meta_kubernetes_service_label_(.+)
```

### 2. 分布式追踪详细机制
```
追踪数据流：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Request   │ -> │   Span A    │ -> │   Span B    │ -> │   Span C    │
│   入口      │    │   服务 A     │    │   服务 B     │    │   服务 C     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                           │                  │                  │
                           v                  v                  v
                    ┌─────────────────────────────────────────────────┐
                    │                 Jaeger                          │
                    │           追踪数据收集和展示                      │
                    └─────────────────────────────────────────────────┘
```

**Trace 和 Span 结构**：
```
Trace 层次结构：
┌─────────────────────────────────────┐
│              Trace                  │
│  TraceID: 1234567890abcdef          │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │          Root Span              │ │
│ │  SpanID: abc123                 │ │
│ │  Operation: GET /productpage    │ │
│ │ ┌─────────────────────────────┐ │ │
│ │ │        Child Span           │ │ │
│ │ │  SpanID: def456             │ │ │
│ │ │  Parent: abc123             │ │ │
│ │ │  Operation: GET /reviews    │ │ │
│ │ │ ┌─────────────────────────┐ │ │ │
│ │ │ │     Child Span          │ │ │ │
│ │ │ │  SpanID: ghi789         │ │ │ │
│ │ │ │  Parent: def456         │ │ │ │
│ │ │ │  Operation: GET /ratings│ │ │ │
│ │ │ └─────────────────────────┘ │ │ │
│ │ └─────────────────────────────┘ │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**追踪头传播**：
```yaml
# OpenTracing Headers
x-request-id: "1234567890abcdef"
x-b3-traceid: "1234567890abcdef"
x-b3-spanid: "abc123"
x-b3-parentspanid: "def456"
x-b3-sampled: "1"
x-b3-flags: "0"

# Jaeger Headers
uber-trace-id: "1234567890abcdef:abc123:def456:1"

# W3C Trace Context
traceparent: "00-1234567890abcdef-abc123-01"
tracestate: "jaeger=abc123"
```

**采样策略**：
```yaml
# Telemetry v2 采样配置
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: tracing-default
spec:
  tracing:
  - providers:
    - name: jaeger
      jaeger:
        service: jaeger.istio-system.svc.cluster.local
        port: 14268
  - randomSamplingPercentage: 1.0  # 1% 采样率
```

### 3. 访问日志详细配置
**Envoy 访问日志格式**：
```json
{
  "start_time": "2023-06-13T14:20:30.123Z",
  "method": "GET",
  "path": "/productpage",
  "protocol": "HTTP/1.1",
  "response_code": 200,
  "response_flags": "-",
  "bytes_received": 0,
  "bytes_sent": 4415,
  "duration": 147,
  "x_forwarded_for": "-",
  "user_agent": "Mozilla/5.0...",
  "request_id": "1234567890abcdef",
  "authority": "productpage:9080",
  "upstream_host": "10.244.0.5:9080",
  "upstream_cluster": "outbound|9080||productpage.default.svc.cluster.local",
  "upstream_local_address": "10.244.0.4:45678",
  "downstream_local_address": "10.244.0.4:15006",
  "downstream_remote_address": "10.244.0.3:54321",
  "requested_server_name": "-",
  "route_name": "default"
}
```

**自定义日志配置**：
```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: access-logging
spec:
  accessLogging:
  - providers:
    - name: otel
      envoyOtelAls:
        service: opentelemetry-collector.istio-system.svc.cluster.local
        port: 4317
  - format:
      text: |
        [%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%"
        %RESPONSE_CODE% %RESPONSE_FLAGS% %BYTES_RECEIVED% %BYTES_SENT%
        %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% "%REQ(X-FORWARDED-FOR)%"
        "%REQ(USER-AGENT)%" "%REQ(X-REQUEST-ID)%" "%REQ(:AUTHORITY)%" "%UPSTREAM_HOST%"
```

### 4. 遥测数据处理管道
**数据收集流程**：
```
遥测数据处理管道：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Envoy     │ -> │ Telemetry   │ -> │ Collector   │ -> │  Backend    │
│   Sidecar   │    │ Extension   │    │ (OTEL/etc)  │    │ (各种存储)   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                          │                  │                  │
                          v                  v                  v
                   ┌─────────────────────────────────────────────────┐
                   │               数据转换和路由                     │
                   │  - 格式转换 (JSON, Protobuf, etc)              │
                   │  - 标签增强 (添加元数据)                       │
                   │  - 采样和过滤                                 │
                   │  - 批处理和缓冲                               │
                   └─────────────────────────────────────────────────┘
```

### 5. Kiali 服务拓扑可视化
**拓扑数据构建**：
```
服务拓扑构建流程：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Prometheus  │ -> │ 指标查询    │ -> │ 关系分析    │ -> │ 拓扑图生成  │
│ 指标数据    │    │ 服务关系    │    │ 流量统计    │    │ 节点和边    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                          │                  │                  │
                          v                  v                  v
                   ┌─────────────────────────────────────────────────┐
                   │              服务网格拓扑                        │
                   │  - 服务节点 (工作负载、版本)                     │
                   │  - 流量边 (请求量、错误率、延迟)                 │
                   │  - 安全状态 (mTLS、策略)                       │
                   │  - 健康状态 (可用性、性能)                     │
                   └─────────────────────────────────────────────────┘
```

**实时流量监控**：
```yaml
# Kiali 查询 Prometheus 的典型指标
queries:
  - name: "Request Volume"
    query: 'sum(rate(istio_requests_total[1m])) by (source_workload, destination_service_name)'
  
  - name: "Error Rate"
    query: 'sum(rate(istio_requests_total{response_code!~"2.."}[1m])) / sum(rate(istio_requests_total[1m]))'
  
  - name: "Response Time P99"
    query: 'histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket[1m])) by (le))'
  
  - name: "TCP Traffic"
    query: 'sum(rate(istio_tcp_sent_bytes_total[1m])) by (source_workload, destination_service_name)'
```

## 监控和告警配置

### 1. 关键指标监控
**服务级别指标**：
```yaml
# SLI 指标定义
- name: availability
  query: |
    sum(rate(istio_requests_total{response_code!~"5.."}[5m])) /
    sum(rate(istio_requests_total[5m]))

- name: latency_p99
  query: |
    histogram_quantile(0.99,
      sum(rate(istio_request_duration_milliseconds_bucket[5m]))
      by (destination_service_name, le)
    )

- name: error_rate
  query: |
    sum(rate(istio_requests_total{response_code=~"5.."}[5m])) /
    sum(rate(istio_requests_total[5m]))
```

**基础设施指标**：
```yaml
# 网格健康指标
- name: proxy_ready
  query: |
    sum(up{job="istio-proxy"}) /
    count(up{job="istio-proxy"})

- name: control_plane_ready
  query: |
    sum(up{job="istiod"}) /
    count(up{job="istiod"})

- name: config_sync_errors
  query: |
    sum(rate(pilot_xds_pushes_total{type="nack"}[5m]))
```

### 2. 告警规则设置
**服务级别告警**：
```yaml
groups:
- name: istio-service-alerts
  rules:
  - alert: HighErrorRate
    expr: |
      sum(rate(istio_requests_total{response_code=~"5.."}[5m])) /
      sum(rate(istio_requests_total[5m])) > 0.05
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value | humanizePercentage }}"

  - alert: HighLatency
    expr: |
      histogram_quantile(0.99,
        sum(rate(istio_request_duration_milliseconds_bucket[5m]))
        by (destination_service_name, le)
      ) > 1000
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High latency detected"
      description: "P99 latency is {{ $value }}ms"
```

**基础设施告警**：
```yaml
- name: istio-infrastructure-alerts
  rules:
  - alert: IstiodDown
    expr: up{job="istiod"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Istiod is down"
      description: "Istiod instance {{ $labels.instance }} is down"

  - alert: ConfigSyncErrors
    expr: rate(pilot_xds_pushes_total{type="nack"}[5m]) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High config sync errors"
      description: "Config sync error rate is {{ $value }}"
```

### 3. 仪表板配置
**Grafana 仪表板模板**：
```json
{
  "dashboard": {
    "title": "Istio Service Mesh",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(istio_requests_total[1m])) by (destination_service_name)",
            "legendFormat": "{{ destination_service_name }}"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(istio_requests_total{response_code=~\"5..\"}[5m])) / sum(rate(istio_requests_total[5m]))",
            "legendFormat": "Error Rate"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.50, sum(rate(istio_request_duration_milliseconds_bucket[1m])) by (le))",
            "legendFormat": "P50"
          },
          {
            "expr": "histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket[1m])) by (le))",
            "legendFormat": "P99"
          }
        ]
      }
    ]
  }
}
```

## 故障排查和诊断

### 1. 日志分析
**Envoy 访问日志分析**：
```bash
# 查看错误请求
kubectl logs -f deployment/productpage-v1 -c istio-proxy | grep "5[0-9][0-9]"

# 查看慢请求
kubectl logs -f deployment/productpage-v1 -c istio-proxy | awk '$9 > 1000'

# 统计请求状态码
kubectl logs deployment/productpage-v1 -c istio-proxy | awk '{print $9}' | sort | uniq -c
```

**Istiod 日志分析**：
```bash
# 查看配置推送错误
kubectl logs -f deployment/istiod -n istio-system | grep "error"

# 查看证书相关问题
kubectl logs -f deployment/istiod -n istio-system | grep -i "cert\|tls"

# 查看服务发现问题
kubectl logs -f deployment/istiod -n istio-system | grep -i "discovery\|endpoint"
```

### 2. 配置诊断
**使用 istioctl 诊断**：
```bash
# 检查代理配置
istioctl proxy-config cluster productpage-v1-xxx

# 检查路由配置
istioctl proxy-config routes productpage-v1-xxx

# 检查监听器配置
istioctl proxy-config listeners productpage-v1-xxx

# 检查端点配置
istioctl proxy-config endpoints productpage-v1-xxx
```

### 3. 流量分析
**使用 Kiali 分析**：
- 查看服务拓扑图
- 分析流量流向
- 检查错误率和延迟
- 验证安全策略

**使用 Jaeger 追踪**：
- 查看请求调用链
- 分析性能瓶颈
- 定位错误根因
- 跟踪跨服务依赖

---

*最后更新时间: 2025-06-13*
