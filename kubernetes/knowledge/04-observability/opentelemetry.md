# OpenTelemetry 统一可观测性框架

## 概述

OpenTelemetry (OTel) 是云原生计算基金会 (CNCF) 的开源可观测性框架，为云原生软件提供统一的指标、日志和分布式追踪标准，实现供应商中立的可观测性数据收集、处理和导出。

### OpenTelemetry 架构

```mermaid
graph TB
    subgraph "应用程序层"
        APP1[Web 应用]
        APP2[微服务]
        APP3[数据库]
        APP4[消息队列]
    end
    
    subgraph "OpenTelemetry SDK"
        AUTO_INSTR[自动化仪表]
        MANUAL_INSTR[手动仪表]
        TRACER[Tracer]
        METER[Meter]
        LOGGER[Logger]
    end
    
    subgraph "OpenTelemetry API"
        TRACE_API[Trace API]
        METRICS_API[Metrics API]
        LOGS_API[Logs API]
        BAGGAGE_API[Baggage API]
        CONTEXT_API[Context API]
    end
    
    subgraph "数据处理"
        PROCESSOR[Processor]
        SAMPLER[Sampler]
        RESOURCE[Resource Detector]
        EXPORTER[Exporter]
    end
    
    subgraph "OpenTelemetry Collector"
        RECEIVERS[Receivers]
        PROCESSORS[Processors]
        EXPORTERS[Exporters]
        CONNECTORS[Connectors]
    end
    
    subgraph "后端系统"
        JAEGER[Jaeger]
        PROMETHEUS[Prometheus]
        LOKI[Loki]
        ELASTIC[Elasticsearch]
        VENDOR[商业 APM]
    end
    
    APP1 --> AUTO_INSTR
    APP2 --> MANUAL_INSTR
    APP3 --> TRACER
    APP4 --> METER
    
    AUTO_INSTR --> TRACE_API
    MANUAL_INSTR --> METRICS_API
    TRACER --> LOGS_API
    METER --> BAGGAGE_API
    LOGGER --> CONTEXT_API
    
    TRACE_API --> PROCESSOR
    METRICS_API --> SAMPLER
    LOGS_API --> RESOURCE
    BAGGAGE_API --> EXPORTER
    CONTEXT_API --> EXPORTER
    
    PROCESSOR --> RECEIVERS
    SAMPLER --> PROCESSORS
    RESOURCE --> EXPORTERS
    EXPORTER --> CONNECTORS
    
    RECEIVERS --> JAEGER
    PROCESSORS --> PROMETHEUS
    EXPORTERS --> LOKI
    CONNECTORS --> ELASTIC
    EXPORTERS --> VENDOR
```

## OpenTelemetry 核心概念

### 信号类型 (Signals)

```yaml
# opentelemetry-signals.yaml
opentelemetry_signals:
  traces:
    description: "分布式追踪数据"
    components:
      span:
        definition: "单个操作的执行记录"
        attributes:
          - "操作名称 (Operation Name)"
          - "开始和结束时间"
          - "父子关系"
          - "状态码和错误信息"
          - "自定义属性 (Tags)"
        
      trace:
        definition: "一组相关 Span 的集合"
        properties:
          - "唯一的 Trace ID"
          - "跨服务的请求路径"
          - "端到端的调用链"
          
      context:
        definition: "追踪上下文传播"
        mechanisms:
          - "HTTP Headers"
          - "gRPC Metadata"
          - "Message Queue Headers"
          - "Database Connection Context"
    
    use_cases:
      - "分布式系统性能分析"
      - "服务依赖关系映射"
      - "请求流程可视化"
      - "性能瓶颈识别"
  
  metrics:
    description: "数值测量数据"
    instrument_types:
      counter:
        definition: "单调递增的累积值"
        examples: ["请求总数", "错误计数", "字节传输量"]
        
      updown_counter:
        definition: "可增可减的累积值"
        examples: ["活跃连接数", "队列大小", "内存使用量"]
        
      histogram:
        definition: "数值分布统计"
        examples: ["请求延迟分布", "响应大小分布"]
        
      gauge:
        definition: "瞬时测量值"
        examples: ["CPU 使用率", "温度读数", "当前用户数"]
    
    aggregation:
      temporal: "时间维度聚合"
      spatial: "空间维度聚合"
      exemplars: "示例数据关联"
  
  logs:
    description: "结构化日志数据"
    log_record:
      timestamp: "时间戳"
      severity: "严重程度"
      body: "日志内容"
      attributes: "上下文属性"
      trace_context: "追踪上下文"
      resource: "资源信息"
    
    correlation:
      trace_log: "追踪与日志关联"
      metric_log: "指标与日志关联"
      span_events: "Span 事件记录"

semantic_conventions:
  purpose: "标准化属性和命名规范"
  categories:
    resource:
      - "service.name"
      - "service.version"
      - "deployment.environment"
      - "k8s.cluster.name"
      - "k8s.namespace.name"
      - "k8s.pod.name"
      
    http:
      - "http.method"
      - "http.url"
      - "http.status_code"
      - "http.user_agent"
      
    database:
      - "db.system"
      - "db.name"
      - "db.statement"
      - "db.operation"
      
    messaging:
      - "messaging.system"
      - "messaging.destination"
      - "messaging.operation"
```

## OpenTelemetry Collector

### Collector 架构

```mermaid
graph LR
    subgraph "数据源"
        APP_TRACES[应用追踪]
        APP_METRICS[应用指标]
        APP_LOGS[应用日志]
        INFRA_METRICS[基础设施指标]
        THIRD_PARTY[第三方系统]
    end
    
    subgraph "OpenTelemetry Collector"
        subgraph "Receivers"
            OTLP_RECEIVER[OTLP Receiver]
            JAEGER_RECEIVER[Jaeger Receiver]
            PROMETHEUS_RECEIVER[Prometheus Receiver]
            FLUENTD_RECEIVER[Fluentd Receiver]
            ZIPKIN_RECEIVER[Zipkin Receiver]
        end
        
        subgraph "Processors"
            BATCH_PROCESSOR[Batch Processor]
            RESOURCE_PROCESSOR[Resource Processor]
            ATTRIBUTES_PROCESSOR[Attributes Processor]
            SAMPLING_PROCESSOR[Sampling Processor]
            FILTER_PROCESSOR[Filter Processor]
            SPAN_PROCESSOR[Span Processor]
            MEMORY_LIMITER[Memory Limiter]
        end
        
        subgraph "Exporters"
            OTLP_EXPORTER[OTLP Exporter]
            JAEGER_EXPORTER[Jaeger Exporter]
            PROMETHEUS_EXPORTER[Prometheus Exporter]
            LOGGING_EXPORTER[Logging Exporter]
            KAFKA_EXPORTER[Kafka Exporter]
        end
    end
    
    subgraph "后端存储"
        JAEGER_BACKEND[Jaeger]
        PROMETHEUS_BACKEND[Prometheus]
        ELASTIC_BACKEND[Elasticsearch]
        GRAFANA_BACKEND[Grafana]
        VENDOR_BACKEND[商业 APM]
    end
    
    APP_TRACES --> OTLP_RECEIVER
    APP_METRICS --> PROMETHEUS_RECEIVER
    APP_LOGS --> FLUENTD_RECEIVER
    INFRA_METRICS --> PROMETHEUS_RECEIVER
    THIRD_PARTY --> JAEGER_RECEIVER
    
    OTLP_RECEIVER --> BATCH_PROCESSOR
    JAEGER_RECEIVER --> RESOURCE_PROCESSOR
    PROMETHEUS_RECEIVER --> ATTRIBUTES_PROCESSOR
    FLUENTD_RECEIVER --> SAMPLING_PROCESSOR
    ZIPKIN_RECEIVER --> FILTER_PROCESSOR
    
    BATCH_PROCESSOR --> SPAN_PROCESSOR
    RESOURCE_PROCESSOR --> MEMORY_LIMITER
    ATTRIBUTES_PROCESSOR --> OTLP_EXPORTER
    SAMPLING_PROCESSOR --> JAEGER_EXPORTER
    FILTER_PROCESSOR --> PROMETHEUS_EXPORTER
    
    OTLP_EXPORTER --> JAEGER_BACKEND
    JAEGER_EXPORTER --> JAEGER_BACKEND
    PROMETHEUS_EXPORTER --> PROMETHEUS_BACKEND
    LOGGING_EXPORTER --> ELASTIC_BACKEND
    KAFKA_EXPORTER --> VENDOR_BACKEND
```

### Collector 配置

```yaml
# otel-collector-config.yaml
receivers:
  # OTLP receiver for receiving telemetry data
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
        cors:
          allowed_origins:
            - "http://*"
            - "https://*"
  
  # Jaeger receiver for legacy Jaeger clients
  jaeger:
    protocols:
      grpc:
        endpoint: 0.0.0.0:14250
      thrift_http:
        endpoint: 0.0.0.0:14268
      thrift_compact:
        endpoint: 0.0.0.0:6831
      thrift_binary:
        endpoint: 0.0.0.0:6832
  
  # Zipkin receiver for Zipkin format traces
  zipkin:
    endpoint: 0.0.0.0:9411
  
  # Prometheus receiver for scraping metrics
  prometheus:
    config:
      scrape_configs:
        - job_name: 'kubernetes-apiservers'
          kubernetes_sd_configs:
            - role: endpoints
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          relabel_configs:
            - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
              action: keep
              regex: default;kubernetes;https
        
        - job_name: 'kubernetes-nodes'
          kubernetes_sd_configs:
            - role: node
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          relabel_configs:
            - action: labelmap
              regex: __meta_kubernetes_node_label_(.+)
        
        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
  
  # Filelog receiver for collecting log files
  filelog:
    include: 
      - /var/log/pods/*/*/*.log
    exclude:
      - /var/log/pods/*/otc-container/*.log
    start_at: end
    include_file_path: true
    include_file_name: false
    operators:
      - type: router
        id: get-format
        routes:
          - output: parser-docker
            expr: 'body matches "^\\{"'
          - output: parser-crio
            expr: 'body matches "^[^ Z]+ "'
          - output: parser-containerd
            expr: true
      
      # Docker CRI parser
      - type: json_parser
        id: parser-docker
        output: extract_metadata_from_filepath
        timestamp:
          parse_from: attributes.time
          layout: '%Y-%m-%dT%H:%M:%S.%LZ'
      
      # CRI-O parser  
      - type: regex_parser
        id: parser-crio
        output: extract_metadata_from_filepath
        regex: '^(?P<time>[^ Z]+) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) (?P<log>.*)$'
        timestamp:
          parse_from: attributes.time
          layout: '%Y-%m-%dT%H:%M:%S.%L%z'
      
      # Containerd parser
      - type: regex_parser
        id: parser-containerd
        output: extract_metadata_from_filepath
        regex: '^(?P<time>[^ Z]+) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) (?P<log>.*)$'
        timestamp:
          parse_from: attributes.time
          layout: '%Y-%m-%dT%H:%M:%S.%LZ'
      
      # Extract metadata from file path
      - type: regex_parser
        id: extract_metadata_from_filepath
        regex: '^.*\/(?P<namespace>[^_]+)_(?P<pod_name>[^_]+)_(?P<uid>[a-f0-9\-]{36})\/(?P<container_name>[^\._]+)\/(?P<restart_count>\d+)\.log$'
        parse_from: attributes["log.file.path"]
        cache:
          size: 128
      
      # Move attributes to resource
      - type: move
        from: attributes.namespace
        to: resource["k8s.namespace.name"]
      - type: move
        from: attributes.pod_name
        to: resource["k8s.pod.name"]
      - type: move
        from: attributes.container_name
        to: resource["k8s.container.name"]
      - type: move
        from: attributes.restart_count
        to: resource["k8s.container.restart_count"]
      - type: move
        from: attributes.uid
        to: resource["k8s.pod.uid"]

processors:
  # Batch processor for batching telemetry data
  batch:
    timeout: 1s
    send_batch_size: 1024
    send_batch_max_size: 2048
  
  # Resource processor for adding resource attributes
  resource:
    attributes:
      - key: deployment.environment
        value: "production"
        action: upsert
      - key: service.version
        from_attribute: "app.version"
        action: insert
      - key: k8s.cluster.name
        value: "my-cluster"
        action: upsert
  
  # Attributes processor for modifying span/log attributes
  attributes:
    actions:
      - key: db.statement
        action: delete
      - key: http.request.header.authorization
        action: delete
      - key: environment
        value: "prod"
        action: insert
  
  # Memory limiter to prevent OOM
  memory_limiter:
    limit_mib: 512
    spike_limit_mib: 128
    check_interval: 5s
  
  # Span processor for span modifications
  span:
    name:
      to_attributes:
        rules:
          - "^/api/v1/users/(?P<user_id>\\d+)$"
      from_attributes: ["http.method", "http.route"]
      separator: " "
  
  # Probabilistic sampler
  probabilistic_sampler:
    sampling_percentage: 15.3
  
  # Tail sampling processor
  tail_sampling:
    decision_wait: 10s
    num_traces: 100
    expected_new_traces_per_sec: 10
    policies:
      - name: errors-policy
        type: status_code
        status_code:
          status_codes: [ERROR]
      - name: latency-policy
        type: latency
        latency:
          threshold_ms: 5000
      - name: probabilistic-policy
        type: probabilistic
        probabilistic:
          sampling_percentage: 25
      - name: rate-limiting-policy
        type: rate_limiting
        rate_limiting:
          spans_per_second: 35

exporters:
  # OTLP exporter for sending to OTLP compatible backends
  otlp/jaeger:
    endpoint: http://jaeger-collector:14250
    tls:
      insecure: true
  
  # Jaeger exporter
  jaeger:
    endpoint: jaeger-collector:14250
    tls:
      insecure: true
  
  # Prometheus exporter
  prometheus:
    endpoint: "0.0.0.0:8889"
    const_labels:
      cluster: "my-cluster"
    send_timestamps: true
    metric_expiration: 180m
  
  # Logging exporter for debugging
  logging:
    loglevel: debug
    sampling_initial: 5
    sampling_thereafter: 200
  
  # Elasticsearch exporter for logs
  elasticsearch:
    endpoints: ["http://elasticsearch:9200"]
    index: "otel-logs"
    mapping:
      mode: "none"
    logs_index: "otel-logs"
  
  # Kafka exporter for streaming
  kafka:
    brokers: ["kafka:9092"]
    topic: "otel-traces"
    encoding: "otlp_proto"
    partition_traces_by_id: true
    partition_metrics_by_resource_attributes: ["service.name"]

extensions:
  # Health check extension
  health_check:
    endpoint: 0.0.0.0:13133
  
  # pprof extension for profiling
  pprof:
    endpoint: 0.0.0.0:1777
  
  # zpages extension for debugging
  zpages:
    endpoint: 0.0.0.0:55679

service:
  extensions: [health_check, pprof, zpages]
  pipelines:
    # Traces pipeline
    traces:
      receivers: [otlp, jaeger, zipkin]
      processors: [memory_limiter, resource, batch]
      exporters: [otlp/jaeger, jaeger, logging]
    
    # Metrics pipeline  
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, resource, batch]
      exporters: [prometheus, logging]
    
    # Logs pipeline
    logs:
      receivers: [otlp, filelog]
      processors: [memory_limiter, resource, attributes, batch]
      exporters: [elasticsearch, logging]

  telemetry:
    logs:
      level: "info"
    metrics:
      address: 0.0.0.0:8888
```

### Collector 部署

```yaml
# otel-collector-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: observability
  labels:
    app: otel-collector
spec:
  replicas: 3
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      serviceAccountName: otel-collector
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector-contrib:latest
        args:
          - "--config=/etc/otelcol-contrib/otel-collector-config.yaml"
        ports:
        - containerPort: 4317   # OTLP gRPC receiver
          name: otlp-grpc
        - containerPort: 4318   # OTLP HTTP receiver
          name: otlp-http
        - containerPort: 14250  # Jaeger gRPC receiver
          name: jaeger-grpc
        - containerPort: 14268  # Jaeger HTTP receiver
          name: jaeger-http
        - containerPort: 9411   # Zipkin receiver
          name: zipkin
        - containerPort: 8889   # Prometheus metrics exporter
          name: prometheus
        - containerPort: 13133  # Health check
          name: health-check
        - containerPort: 8888   # Internal metrics
          name: metrics
        env:
        - name: K8S_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: K8S_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: K8S_POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: K8S_POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        resources:
          limits:
            cpu: 1
            memory: 2Gi
          requests:
            cpu: 500m
            memory: 512Mi
        volumeMounts:
        - name: otel-collector-config
          mountPath: /etc/otelcol-contrib
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        livenessProbe:
          httpGet:
            path: /
            port: 13133
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 13133
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
      - name: otel-collector-config
        configMap:
          name: otel-collector-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
  namespace: observability
  labels:
    app: otel-collector
spec:
  selector:
    app: otel-collector
  ports:
  - name: otlp-grpc
    port: 4317
    targetPort: 4317
    protocol: TCP
  - name: otlp-http
    port: 4318
    targetPort: 4318
    protocol: TCP
  - name: jaeger-grpc
    port: 14250
    targetPort: 14250
    protocol: TCP
  - name: jaeger-http
    port: 14268
    targetPort: 14268
    protocol: TCP
  - name: zipkin
    port: 9411
    targetPort: 9411
    protocol: TCP
  - name: prometheus
    port: 8889
    targetPort: 8889
    protocol: TCP
  - name: metrics
    port: 8888
    targetPort: 8888
    protocol: TCP
  type: ClusterIP
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-collector
  namespace: observability
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: otel-collector
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: otel-collector
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: otel-collector
subjects:
- kind: ServiceAccount
  name: otel-collector
  namespace: observability
```

## 应用程序集成

### Go 应用集成

```go
// main.go - Go 应用 OpenTelemetry 集成
package main

import (
    "context"
    "fmt"
    "log"
    "net/http"
    "os"
    "time"

    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
    "go.opentelemetry.io/otel/metric"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/sdk/instrumentation"
    sdkmetric "go.opentelemetry.io/otel/sdk/metric"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
    "go.opentelemetry.io/otel/trace"
    "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
    "go.opentelemetry.io/contrib/instrumentation/database/sql/otelsql"
    _ "github.com/lib/pq"
    "database/sql"
)

// 初始化 OpenTelemetry
func initOpenTelemetry() func() {
    ctx := context.Background()
    
    // 创建资源
    res, err := resource.New(ctx,
        resource.WithAttributes(
            semconv.ServiceName("my-go-service"),
            semconv.ServiceVersion("1.0.0"),
            semconv.DeploymentEnvironment("production"),
            attribute.String("service.instance.id", os.Getenv("POD_NAME")),
        ),
    )
    if err != nil {
        log.Fatalf("Failed to create resource: %v", err)
    }

    // 设置追踪
    traceExporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint("http://otel-collector:4317"),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        log.Fatalf("Failed to create trace exporter: %v", err)
    }

    tracerProvider := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(traceExporter),
        sdktrace.WithResource(res),
        sdktrace.WithSampler(sdktrace.TraceIDRatioBased(0.1)), // 10% 采样
    )
    otel.SetTracerProvider(tracerProvider)

    // 设置指标
    metricExporter, err := otlpmetricgrpc.New(ctx,
        otlpmetricgrpc.WithEndpoint("http://otel-collector:4317"),
        otlpmetricgrpc.WithInsecure(),
    )
    if err != nil {
        log.Fatalf("Failed to create metric exporter: %v", err)
    }

    meterProvider := sdkmetric.NewMeterProvider(
        sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExporter,
            sdkmetric.WithInterval(30*time.Second))),
        sdkmetric.WithResource(res),
    )
    otel.SetMeterProvider(meterProvider)

    // 设置传播器
    otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
        propagation.TraceContext{},
        propagation.Baggage{},
    ))

    // 返回清理函数
    return func() {
        ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
        defer cancel()
        
        if err := tracerProvider.Shutdown(ctx); err != nil {
            log.Printf("Error shutting down tracer provider: %v", err)
        }
        
        if err := meterProvider.Shutdown(ctx); err != nil {
            log.Printf("Error shutting down meter provider: %v", err)
        }
    }
}

// 自定义指标
var (
    tracer = otel.Tracer("my-go-service")
    meter  = otel.Meter("my-go-service")
    
    // 业务指标
    requestCounter, _ = meter.Int64Counter(
        "http_requests_total",
        metric.WithDescription("Total number of HTTP requests"),
    )
    
    requestDuration, _ = meter.Float64Histogram(
        "http_request_duration_seconds",
        metric.WithDescription("HTTP request duration in seconds"),
        metric.WithUnit("s"),
    )
    
    activeConnections, _ = meter.Int64UpDownCounter(
        "http_active_connections",
        metric.WithDescription("Number of active HTTP connections"),
    )
    
    databaseConnections, _ = meter.Int64Gauge(
        "database_connections",
        metric.WithDescription("Number of database connections"),
    )
)

// HTTP 处理器示例
func homeHandler(w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    ctx := r.Context()
    
    // 创建 span
    span := trace.SpanFromContext(ctx)
    span.SetAttributes(
        attribute.String("http.method", r.Method),
        attribute.String("http.url", r.URL.String()),
        attribute.String("user.id", r.Header.Get("X-User-ID")),
    )
    
    // 记录指标
    requestCounter.Add(ctx, 1, 
        metric.WithAttributes(
            attribute.String("method", r.Method),
            attribute.String("endpoint", "/"),
        ),
    )
    
    activeConnections.Add(ctx, 1)
    defer activeConnections.Add(ctx, -1)
    
    // 业务逻辑
    result, err := processRequest(ctx, r)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(trace.StatusCodeError, err.Error())
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    
    // 记录响应时间
    duration := time.Since(start).Seconds()
    requestDuration.Record(ctx, duration,
        metric.WithAttributes(
            attribute.String("method", r.Method),
            attribute.String("endpoint", "/"),
            attribute.String("status", "200"),
        ),
    )
    
    span.SetAttributes(attribute.String("response.status", "success"))
    
    w.Header().Set("Content-Type", "application/json")
    fmt.Fprintf(w, `{"message": "%s"}`, result)
}

// 业务逻辑处理
func processRequest(ctx context.Context, r *http.Request) (string, error) {
    // 创建子 span
    ctx, span := tracer.Start(ctx, "process_request",
        trace.WithAttributes(
            attribute.String("operation", "business_logic"),
        ),
    )
    defer span.End()
    
    // 模拟数据库查询
    result, err := queryDatabase(ctx)
    if err != nil {
        return "", fmt.Errorf("database query failed: %w", err)
    }
    
    // 模拟外部 API 调用
    if err := callExternalAPI(ctx); err != nil {
        span.AddEvent("external_api_warning", 
            trace.WithAttributes(attribute.String("warning", err.Error())),
        )
    }
    
    return result, nil
}

// 数据库查询示例
func queryDatabase(ctx context.Context) (string, error) {
    ctx, span := tracer.Start(ctx, "query_database",
        trace.WithAttributes(
            attribute.String("db.system", "postgresql"),
            attribute.String("db.name", "myapp"),
            attribute.String("db.operation", "SELECT"),
        ),
    )
    defer span.End()
    
    // 数据库连接（使用 otelsql 包装）
    db, err := otelsql.Open("postgres", "postgres://user:password@localhost/myapp?sslmode=disable")
    if err != nil {
        return "", err
    }
    defer db.Close()
    
    // 记录连接数指标
    stats := db.Stats()
    databaseConnections.Record(ctx, int64(stats.OpenConnections),
        metric.WithAttributes(
            attribute.String("db.name", "myapp"),
            attribute.String("state", "open"),
        ),
    )
    
    // 执行查询
    var result string
    query := "SELECT message FROM greetings WHERE id = $1"
    span.SetAttributes(attribute.String("db.statement", query))
    
    err = db.QueryRowContext(ctx, query, 1).Scan(&result)
    if err != nil {
        return "", err
    }
    
    span.SetAttributes(attribute.String("db.result.count", "1"))
    return result, nil
}

// 外部 API 调用示例
func callExternalAPI(ctx context.Context) error {
    ctx, span := tracer.Start(ctx, "call_external_api",
        trace.WithAttributes(
            attribute.String("http.method", "GET"),
            attribute.String("http.url", "https://api.example.com/data"),
        ),
    )
    defer span.End()
    
    // 创建 HTTP 客户端（自动集成 OpenTelemetry）
    client := http.Client{
        Transport: otelhttp.NewTransport(http.DefaultTransport),
        Timeout:   10 * time.Second,
    }
    
    req, err := http.NewRequestWithContext(ctx, "GET", "https://api.example.com/data", nil)
    if err != nil {
        return err
    }
    
    resp, err := client.Do(req)
    if err != nil {
        return err
    }
    defer resp.Body.Close()
    
    span.SetAttributes(
        attribute.Int("http.status_code", resp.StatusCode),
        attribute.String("http.status_text", resp.Status),
    )
    
    if resp.StatusCode >= 400 {
        span.SetStatus(trace.StatusCodeError, "HTTP error")
        return fmt.Errorf("HTTP %d: %s", resp.StatusCode, resp.Status)
    }
    
    return nil
}

func main() {
    // 初始化 OpenTelemetry
    cleanup := initOpenTelemetry()
    defer cleanup()
    
    // 设置 HTTP 路由（使用 otelhttp 中间件）
    mux := http.NewServeMux()
    mux.HandleFunc("/", homeHandler)
    mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        fmt.Fprintln(w, "OK")
    })
    
    // 应用 OpenTelemetry HTTP 中间件
    handler := otelhttp.NewHandler(mux, "my-go-service")
    
    // 启动服务器
    log.Println("Starting server on :8080")
    if err := http.ListenAndServe(":8080", handler); err != nil {
        log.Fatalf("Server failed to start: %v", err)
    }
}
```

### Java 应用集成

```java
// Application.java - Spring Boot 应用 OpenTelemetry 集成
package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.DoubleHistogram;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.context.Scope;

import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.sdk.metrics.SdkMeterProvider;
import io.opentelemetry.sdk.metrics.export.PeriodicMetricReader;

import io.opentelemetry.exporter.otlp.trace.OtlpGrpcSpanExporter;
import io.opentelemetry.exporter.otlp.metrics.OtlpGrpcMetricExporter;

import io.opentelemetry.semconv.resource.attributes.ResourceAttributes;
import io.opentelemetry.instrumentation.annotations.WithSpan;

import javax.annotation.PostConstruct;
import java.time.Duration;
import java.util.concurrent.TimeUnit;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}

// OpenTelemetry 配置
@Service
public class OpenTelemetryConfig {
    
    private OpenTelemetry openTelemetry;
    private Tracer tracer;
    private Meter meter;
    
    // 业务指标
    private LongCounter requestCounter;
    private DoubleHistogram requestDuration;
    private LongCounter errorCounter;
    
    @PostConstruct
    public void init() {
        setupOpenTelemetry();
        setupMetrics();
    }
    
    private void setupOpenTelemetry() {
        // 创建资源
        Resource resource = Resource.getDefault()
            .merge(Resource.builder()
                .put(ResourceAttributes.SERVICE_NAME, "java-spring-service")
                .put(ResourceAttributes.SERVICE_VERSION, "1.0.0")
                .put(ResourceAttributes.DEPLOYMENT_ENVIRONMENT, "production")
                .build());
        
        // 配置追踪导出器
        OtlpGrpcSpanExporter spanExporter = OtlpGrpcSpanExporter.builder()
            .setEndpoint("http://otel-collector:4317")
            .build();
        
        // 创建追踪提供者
        SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
            .addSpanProcessor(BatchSpanProcessor.builder(spanExporter)
                .setMaxExportBatchSize(512)
                .setExportTimeout(Duration.ofSeconds(30))
                .setScheduleDelay(Duration.ofSeconds(5))
                .build())
            .setResource(resource)
            .build();
        
        // 配置指标导出器
        OtlpGrpcMetricExporter metricExporter = OtlpGrpcMetricExporter.builder()
            .setEndpoint("http://otel-collector:4317")
            .build();
        
        // 创建指标提供者
        SdkMeterProvider meterProvider = SdkMeterProvider.builder()
            .registerMetricReader(PeriodicMetricReader.builder(metricExporter)
                .setInterval(Duration.ofSeconds(30))
                .build())
            .setResource(resource)
            .build();
        
        // 创建 OpenTelemetry 实例
        this.openTelemetry = OpenTelemetrySdk.builder()
            .setTracerProvider(tracerProvider)
            .setMeterProvider(meterProvider)
            .build();
        
        this.tracer = openTelemetry.getTracer("java-spring-service");
        this.meter = openTelemetry.getMeter("java-spring-service");
    }
    
    private void setupMetrics() {
        // 创建业务指标
        this.requestCounter = meter
            .counterBuilder("http_requests_total")
            .setDescription("Total number of HTTP requests")
            .build();
        
        this.requestDuration = meter
            .histogramBuilder("http_request_duration_seconds")
            .setDescription("HTTP request duration in seconds")
            .setUnit("s")
            .build();
        
        this.errorCounter = meter
            .counterBuilder("application_errors_total")
            .setDescription("Total number of application errors")
            .build();
    }
    
    // Getters
    public Tracer getTracer() { return tracer; }
    public Meter getMeter() { return meter; }
    public LongCounter getRequestCounter() { return requestCounter; }
    public DoubleHistogram getRequestDuration() { return requestDuration; }
    public LongCounter getErrorCounter() { return errorCounter; }
}

// REST 控制器
@RestController
public class UserController {
    
    @Autowired
    private OpenTelemetryConfig otelConfig;
    
    @Autowired
    private UserService userService;
    
    @GetMapping("/users/{id}")
    public ResponseEntity<User> getUser(@PathVariable String id) {
        long startTime = System.currentTimeMillis();
        
        // 获取当前 span（由自动化仪表创建）
        Span span = Span.current();
        span.setAttributes(Attributes.of(
            AttributeKey.stringKey("user.id"), id,
            AttributeKey.stringKey("operation"), "get_user"
        ));
        
        try {
            // 记录请求指标
            otelConfig.getRequestCounter().add(1, 
                Attributes.of(
                    AttributeKey.stringKey("method"), "GET",
                    AttributeKey.stringKey("endpoint"), "/users/{id}"
                ));
            
            // 业务逻辑
            User user = userService.findById(id);
            if (user == null) {
                span.setStatus(StatusCode.ERROR, "User not found");
                return ResponseEntity.notFound().build();
            }
            
            span.setAttributes(Attributes.of(
                AttributeKey.stringKey("user.name"), user.getName(),
                AttributeKey.stringKey("user.status"), user.getStatus()
            ));
            
            return ResponseEntity.ok(user);
            
        } catch (Exception e) {
            // 记录错误
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, e.getMessage());
            
            otelConfig.getErrorCounter().add(1,
                Attributes.of(
                    AttributeKey.stringKey("error.type"), e.getClass().getSimpleName(),
                    AttributeKey.stringKey("endpoint"), "/users/{id}"
                ));
            
            return ResponseEntity.status(500).build();
            
        } finally {
            // 记录请求持续时间
            double duration = (System.currentTimeMillis() - startTime) / 1000.0;
            otelConfig.getRequestDuration().record(duration,
                Attributes.of(
                    AttributeKey.stringKey("method"), "GET",
                    AttributeKey.stringKey("endpoint"), "/users/{id}",
                    AttributeKey.stringKey("status"), "200"
                ));
        }
    }
}

// 业务服务
@Service
public class UserService {
    
    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private OpenTelemetryConfig otelConfig;
    
    @WithSpan("user_service.find_by_id")
    public User findById(String id) {
        Span span = Span.current();
        span.setAttributes(Attributes.of(
            AttributeKey.stringKey("db.operation"), "SELECT",
            AttributeKey.stringKey("db.table"), "users"
        ));
        
        // 数据库查询
        User user = userRepository.findById(id);
        
        if (user != null) {
            span.setAttributes(Attributes.of(
                AttributeKey.booleanKey("cache.hit"), false,
                AttributeKey.longKey("db.rows_affected"), 1L
            ));
        }
        
        return user;
    }
    
    @WithSpan("user_service.create_user")
    public User createUser(User user) {
        Span span = Span.current();
        span.setAttributes(Attributes.of(
            AttributeKey.stringKey("operation"), "create_user",
            AttributeKey.stringKey("user.type"), user.getType()
        ));
        
        try {
            // 验证用户数据
            validateUser(user);
            
            // 保存到数据库
            User savedUser = userRepository.save(user);
            
            // 发送欢迎邮件
            sendWelcomeEmail(savedUser);
            
            span.addEvent("user_created", 
                Attributes.of(AttributeKey.stringKey("user.id"), savedUser.getId()));
            
            return savedUser;
            
        } catch (ValidationException e) {
            span.setStatus(StatusCode.ERROR, "Validation failed");
            span.recordException(e);
            throw e;
        }
    }
    
    private void validateUser(User user) {
        Span span = otelConfig.getTracer().spanBuilder("validate_user")
            .setParent(Context.current())
            .startSpan();
        
        try (Scope scope = span.makeCurrent()) {
            // 验证逻辑
            if (user.getEmail() == null || !user.getEmail().contains("@")) {
                throw new ValidationException("Invalid email");
            }
            
            span.addEvent("validation_passed");
            
        } finally {
            span.end();
        }
    }
    
    private void sendWelcomeEmail(User user) {
        Span span = otelConfig.getTracer().spanBuilder("send_welcome_email")
            .setParent(Context.current())
            .startSpan();
        
        try (Scope scope = span.makeCurrent()) {
            // 模拟邮件发送
            Thread.sleep(100);
            
            span.setAttributes(Attributes.of(
                AttributeKey.stringKey("email.to"), user.getEmail(),
                AttributeKey.stringKey("email.template"), "welcome"
            ));
            
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, "Failed to send email");
        } finally {
            span.end();
        }
    }
}
```

## 最佳实践

### OpenTelemetry 实施最佳实践

```yaml
# opentelemetry-best-practices.yaml
opentelemetry_best_practices:
  instrumentation:
    auto_vs_manual:
      automatic_instrumentation:
        advantages:
          - "快速部署，无需代码修改"
          - "覆盖常见框架和库"
          - "标准化的追踪数据"
        limitations:
          - "缺乏业务上下文"
          - "无法自定义业务指标"
          - "可能产生过多数据"
        use_cases:
          - "快速原型验证"
          - "标准 Web 应用"
          - "第三方库监控"
      
      manual_instrumentation:
        advantages:
          - "完全控制追踪数据"
          - "丰富的业务上下文"
          - "自定义指标和事件"
        challenges:
          - "需要代码修改"
          - "开发工作量大"
          - "维护成本高"
        use_cases:
          - "关键业务逻辑"
          - "自定义指标需求"
          - "细粒度性能分析"
      
      hybrid_approach:
        strategy: "自动化仪表 + 关键路径手动增强"
        implementation:
          - "使用自动化仪表作为基础"
          - "在关键业务逻辑添加手动仪表"
          - "为重要操作添加自定义属性"
          - "补充业务指标和事件"
  
  performance_optimization:
    sampling_strategies:
      head_sampling:
        description: "在追踪开始时决定是否采样"
        pros: ["低延迟", "资源消耗少"]
        cons: ["可能丢失重要追踪", "无法基于追踪特征采样"]
        configuration:
          probability: "根据流量设置采样率 (1-10%)"
          rate_limiting: "设置每秒最大追踪数"
      
      tail_sampling:
        description: "在追踪完成后基于特征决定是否保留"
        pros: ["智能采样", "保留重要追踪", "减少存储成本"]
        cons: ["内存开销大", "处理延迟高"]
        policies:
          - "错误追踪 100% 保留"
          - "高延迟追踪优先保留"
          - "正常追踪按概率采样"
    
    resource_management:
      memory_limits:
        - "设置 Collector 内存限制"
        - "配置批处理大小"
        - "启用内存限制器处理器"
      
      batch_processing:
        - "批量发送减少网络开销"
        - "设置合适的批大小和超时"
        - "平衡延迟和吞吐量"
      
      attribute_limits:
        - "限制属性数量和大小"
        - "删除敏感信息属性"
        - "使用属性处理器标准化"
  
  data_quality:
    semantic_conventions:
      importance: "确保数据一致性和可查询性"
      implementation:
        - "使用标准属性名称"
        - "遵循命名约定"
        - "保持版本一致性"
        - "定期更新到最新规范"
    
    attribute_design:
      cardinality_control:
        - "避免高基数属性 (如用户ID)"
        - "使用固定值集合"
        - "合并相似属性值"
      
      meaningful_attributes:
        - "添加业务上下文属性"
        - "包含错误诊断信息"
        - "记录重要的环境信息"
    
    span_design:
      granularity:
        - "平衡细节和性能"
        - "重要操作创建 Span"
        - "避免过于细粒度的 Span"
      
      naming:
        - "使用描述性的操作名称"
        - "保持命名一致性"
        - "避免包含变量值"
  
  security_considerations:
    sensitive_data:
      - "识别和标记敏感属性"
      - "使用属性处理器删除敏感信息"
      - "实施数据脱敏策略"
      - "定期审计数据内容"
    
    access_control:
      - "限制可观测性数据访问"
      - "实施基于角色的访问控制"
      - "加密传输中的数据"
      - "安全存储认证信息"
    
    compliance:
      - "确保符合数据保护法规"
      - "实施数据保留策略"
      - "提供数据删除机制"
      - "记录数据处理活动"
```

## 总结

OpenTelemetry 为 Kubernetes 环境提供了统一的可观测性标准，通过标准化的 API、SDK 和工具，实现了供应商中立的可观测性数据收集和处理。关键要点包括：

1. **统一标准**：提供指标、日志、追踪的统一 API 和数据模型
2. **供应商中立**：避免厂商锁定，支持多种后端系统
3. **自动化仪表**：减少手动集成工作，提供开箱即用的监控
4. **灵活配置**：通过 Collector 实现灵活的数据处理和路由
5. **生态丰富**：广泛的语言支持和第三方集成

通过合理的 OpenTelemetry 实施策略，可以构建出高效、标准化的可观测性基础设施，为 Kubernetes 应用提供全面的监控和追踪能力。
