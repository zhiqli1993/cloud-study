# Kubernetes 性能基准测试

## 基准测试概述

性能基准测试是衡量 Kubernetes 集群和应用性能的重要手段，通过标准化测试方法建立性能基线，识别性能瓶颈，验证优化效果。

## 测试维度和指标

### 集群性能指标

**控制平面性能**：
- API Server 响应延迟
- etcd 读写性能
- 调度器调度延迟
- 控制器循环周期

**数据平面性能**：
- 网络吞吐量和延迟
- 存储 IOPS 和带宽
- 容器启动时间
- 资源利用率

**应用性能指标**：
- 请求响应时间
- 吞吐量（QPS/TPS）
- 错误率
- 可用性

### 基准测试工具

**集群基准测试**：
```bash
# Kubestr - 存储性能测试
kubectl apply -f https://raw.githubusercontent.com/kastenhq/kubestr/main/kubestr-install.yaml
kubestr fio -s fast-ssd -z 10Gi

# Sonobuoy - 集群一致性测试
sonobuoy run --mode=certified-conformance
sonobuoy status
sonobuoy results

# K-Bench - 综合性能测试
git clone https://github.com/vmware-tanzu/k-bench.git
kubectl apply -f k-bench/config/
kubectl create -f k-bench/config/rbac/
```

**网络性能测试**：
```yaml
# iperf3 网络测试 Pod
apiVersion: v1
kind: Pod
metadata:
  name: iperf3-server
  labels:
    app: iperf3-server
spec:
  containers:
  - name: iperf3-server
    image: networkstatic/iperf3
    args: ['-s']
    ports:
    - containerPort: 5201

---
apiVersion: v1
kind: Service
metadata:
  name: iperf3-server
spec:
  selector:
    app: iperf3-server
  ports:
  - port: 5201
    targetPort: 5201

---
# 客户端测试 Pod
apiVersion: v1
kind: Pod
metadata:
  name: iperf3-client
spec:
  containers:
  - name: iperf3-client
    image: networkstatic/iperf3
    command: ['sleep', '3600']
```

**存储性能测试**：
```yaml
# FIO 存储测试作业
apiVersion: batch/v1
kind: Job
metadata:
  name: fio-test
spec:
  template:
    spec:
      containers:
      - name: fio
        image: ljishen/fio
        command: 
        - fio
        - --name=test
        - --ioengine=libaio
        - --iodepth=64
        - --rw=randwrite
        - --bs=4k
        - --direct=1
        - --size=1G
        - --numjobs=4
        - --runtime=60
        - --group_reporting
        - --filename=/data/testfile
        volumeMounts:
        - name: test-volume
          mountPath: /data
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1000m
            memory: 2Gi
      volumes:
      - name: test-volume
        persistentVolumeClaim:
          claimName: fio-test-pvc
      restartPolicy: Never

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fio-test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 10Gi
```

## 应用性能测试

### 负载测试工具

**Vegeta 负载测试**：
```yaml
# Vegeta 负载测试配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: vegeta-config
data:
  targets.txt: |
    GET http://my-service:8080/api/health
    GET http://my-service:8080/api/users
    POST http://my-service:8080/api/data
    @body.json
  body.json: |
    {"name": "test", "value": "benchmark"}

---
apiVersion: batch/v1
kind: Job
metadata:
  name: vegeta-test
spec:
  template:
    spec:
      containers:
      - name: vegeta
        image: peterevans/vegeta
        command:
        - sh
        - -c
        - |
          vegeta attack -targets=/config/targets.txt -rate=100 -duration=60s | \
          vegeta report -type=text > /results/report.txt &&
          vegeta attack -targets=/config/targets.txt -rate=100 -duration=60s | \
          vegeta report -type=json > /results/report.json
        volumeMounts:
        - name: config
          mountPath: /config
        - name: results
          mountPath: /results
      volumes:
      - name: config
        configMap:
          name: vegeta-config
      - name: results
        emptyDir: {}
      restartPolicy: Never
```

**K6 性能测试**：
```yaml
# K6 性能测试配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: k6-script
data:
  script.js: |
    import http from 'k6/http';
    import { check, sleep } from 'k6';
    import { Counter, Rate, Trend } from 'k6/metrics';

    const errorRate = new Rate('errors');
    const responseTime = new Trend('response_time');

    export let options = {
      stages: [
        { duration: '2m', target: 100 },
        { duration: '5m', target: 100 },
        { duration: '2m', target: 200 },
        { duration: '5m', target: 200 },
        { duration: '2m', target: 0 },
      ],
      thresholds: {
        'http_req_duration': ['p(99)<1500'],
        'http_req_failed': ['rate<0.1'],
      },
    };

    export default function() {
      const response = http.get('http://my-service:8080/api/endpoint');
      
      check(response, {
        'status is 200': (r) => r.status === 200,
        'response time < 500ms': (r) => r.timings.duration < 500,
      });

      errorRate.add(response.status !== 200);
      responseTime.add(response.timings.duration);
      
      sleep(1);
    }

---
apiVersion: batch/v1
kind: Job
metadata:
  name: k6-test
spec:
  template:
    spec:
      containers:
      - name: k6
        image: grafana/k6:latest
        command: ['k6', 'run', '/scripts/script.js']
        volumeMounts:
        - name: script
          mountPath: /scripts
      volumes:
      - name: script
        configMap:
          name: k6-script
      restartPolicy: Never
```

## 基准测试场景

### 典型测试场景

**Web 应用基准测试**：
```yaml
# 基准测试部署
apiVersion: apps/v1
kind: Deployment
metadata:
  name: benchmark-app
spec:
  replicas: 5
  selector:
    matchLabels:
      app: benchmark-app
  template:
    metadata:
      labels:
        app: benchmark-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10

---
apiVersion: v1
kind: Service
metadata:
  name: benchmark-app
spec:
  selector:
    app: benchmark-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

**数据库基准测试**：
```yaml
# Sysbench MySQL 测试
apiVersion: batch/v1
kind: Job
metadata:
  name: mysql-benchmark
spec:
  template:
    spec:
      containers:
      - name: sysbench
        image: severalnines/sysbench
        command:
        - sh
        - -c
        - |
          sysbench oltp_read_write \
            --mysql-host=mysql-service \
            --mysql-port=3306 \
            --mysql-user=root \
            --mysql-password=password \
            --mysql-db=testdb \
            --table-size=100000 \
            --tables=10 \
            --threads=16 \
            --time=300 \
            --report-interval=10 \
            prepare &&
          sysbench oltp_read_write \
            --mysql-host=mysql-service \
            --mysql-port=3306 \
            --mysql-user=root \
            --mysql-password=password \
            --mysql-db=testdb \
            --table-size=100000 \
            --tables=10 \
            --threads=16 \
            --time=300 \
            --report-interval=10 \
            run
      restartPolicy: Never
```

## 性能监控和数据收集

### Prometheus 监控配置

**基准测试监控指标**：
```yaml
# 自定义监控指标
apiVersion: v1
kind: ConfigMap
metadata:
  name: benchmark-monitoring
data:
  prometheus-rules.yml: |
    groups:
    - name: benchmark-metrics
      rules:
      # 应用响应时间
      - record: app:http_request_duration_seconds:mean5m
        expr: |
          rate(http_request_duration_seconds_sum[5m]) /
          rate(http_request_duration_seconds_count[5m])
      
      # 应用错误率
      - record: app:http_request_error_rate:rate5m
        expr: |
          rate(http_requests_total{status=~"5.."}[5m]) /
          rate(http_requests_total[5m])
      
      # CPU 使用率
      - record: node:cpu_utilization:rate5m
        expr: |
          1 - (
            avg by (instance) (
              rate(node_cpu_seconds_total{mode="idle"}[5m])
            )
          )
      
      # 内存使用率
      - record: node:memory_utilization:ratio
        expr: |
          1 - (
            node_memory_MemAvailable_bytes /
            node_memory_MemTotal_bytes
          )
```

### 性能数据分析

**基准测试报告生成**：
```bash
#!/bin/bash
# 性能测试报告生成脚本

NAMESPACE="benchmark"
TEST_DURATION="300"
OUTPUT_DIR="./benchmark-results"

mkdir -p $OUTPUT_DIR

# 收集测试期间的监控数据
kubectl exec -n monitoring prometheus-0 -- \
  promtool query range \
    --start=$(date -d '5 minutes ago' --iso-8601) \
    --end=$(date --iso-8601) \
    --step=30s \
    'app:http_request_duration_seconds:mean5m' \
  > $OUTPUT_DIR/response_time.txt

# 生成性能报告
cat > $OUTPUT_DIR/benchmark-report.md << EOF
# 性能基准测试报告

## 测试环境
- 集群节点数: $(kubectl get nodes --no-headers | wc -l)
- 测试时间: $(date)
- 测试持续时间: ${TEST_DURATION}秒

## 性能指标

### 应用性能
- 平均响应时间: $(cat $OUTPUT_DIR/response_time.txt | tail -1)
- 峰值 QPS: $(kubectl top pods -n $NAMESPACE --no-headers | head -1)

### 资源使用
- CPU 使用率: $(kubectl top nodes --no-headers | awk '{sum+=$3} END {print sum/NR}')%
- 内存使用率: $(kubectl top nodes --no-headers | awk '{sum+=$5} END {print sum/NR}')%

## 建议优化方向
EOF

echo "基准测试报告已生成: $OUTPUT_DIR/benchmark-report.md"
```

## 持续性能测试

### 自动化测试流水线

**GitLab CI 性能测试**：
```yaml
# .gitlab-ci.yml
stages:
  - deploy
  - benchmark
  - report

deploy-app:
  stage: deploy
  script:
    - kubectl apply -f k8s-manifests/
    - kubectl rollout status deployment/test-app

performance-test:
  stage: benchmark
  script:
    - kubectl apply -f benchmark/k6-test.yaml
    - kubectl wait --for=condition=complete job/k6-test --timeout=600s
    - kubectl logs job/k6-test > performance-results.txt
  artifacts:
    paths:
      - performance-results.txt
    expire_in: 1 week

generate-report:
  stage: report
  script:
    - python scripts/generate-performance-report.py
  artifacts:
    reports:
      performance: performance-report.json
```

### 性能回归检测

**性能阈值监控**：
```yaml
# 性能回归告警规则
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: performance-regression
spec:
  groups:
  - name: performance-regression
    rules:
    - alert: ResponseTimeRegression
      expr: |
        app:http_request_duration_seconds:mean5m > 
        (app:http_request_duration_seconds:mean5m offset 24h) * 1.2
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "应用响应时间较昨日同期增长超过20%"
        description: "当前响应时间: {{ $value }}s，24小时前: {{ query \"app:http_request_duration_seconds:mean5m offset 24h\" }}s"

    - alert: ThroughputRegression
      expr: |
        rate(http_requests_total[5m]) < 
        (rate(http_requests_total[5m] offset 24h)) * 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "应用吞吐量较昨日同期下降超过20%"
```

## 最佳实践

### 测试环境准备
1. **隔离测试环境**：使用专用命名空间和资源配额
2. **一致性环境**：确保测试环境与生产环境一致
3. **基线建立**：建立性能基线和阈值标准
4. **数据预热**：在正式测试前进行系统预热

### 测试执行原则
1. **渐进式加压**：逐步增加负载，观察系统响应
2. **多维度测试**：同时测试不同场景和负载模式
3. **重复验证**：多次执行测试确保结果可靠性
4. **监控全面**：收集完整的性能和资源监控数据

### 结果分析和报告
1. **趋势分析**：对比历史数据识别性能趋势
2. **瓶颈定位**：结合监控数据定位性能瓶颈
3. **优化建议**：基于测试结果提供具体优化建议
4. **持续改进**：建立性能测试的持续改进机制

通过系统性的性能基准测试，可以建立完整的性能评估体系，为系统优化提供数据支撑，确保应用在生产环境中的稳定高效运行。
