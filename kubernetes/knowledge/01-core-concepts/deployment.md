# Deployment 资源详解

## 概述

Deployment 是 Kubernetes 中用于管理无状态应用的高级控制器，提供声明式的更新方式来管理 Pod 和 ReplicaSet。它是最常用的工作负载资源之一。

## 核心特性

### 1. 声明式更新
- 声明期望状态，Kubernetes 自动协调实际状态
- 支持滚动更新和回滚操作
- 版本历史管理

### 2. 自动扩缩容
- 手动扩缩容：调整副本数量
- 自动扩缩容：配合 HPA 使用
- 支持暂停和恢复

### 3. 高可用保障
- 多副本部署
- 滚动更新策略
- 失败自动处理

## Deployment 配置详解

### 基础配置示例

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment             # Deployment 名称
  namespace: default              # 命名空间
  labels:                         # 标签
    app: my-app
    version: v1.0
  annotations:                    # 注解
    deployment.kubernetes.io/revision: "1"
spec:
  replicas: 3                     # 副本数量
  selector:                       # 选择器（必须匹配 template.metadata.labels）
    matchLabels:
      app: my-app
  template:                       # Pod 模板
    metadata:
      labels:                     # Pod 标签（必须包含 selector 中的标签）
        app: my-app
        version: v1.0
    spec:                         # Pod 规格
      containers:
      - name: app-container
        image: nginx:1.20
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
  strategy:                       # 更新策略
    type: RollingUpdate           # 滚动更新（默认）
    rollingUpdate:
      maxUnavailable: 25%         # 最大不可用 Pod 数量
      maxSurge: 25%               # 最大额外 Pod 数量
  revisionHistoryLimit: 10        # 保留的历史版本数量
  progressDeadlineSeconds: 600    # 进度截止时间
  paused: false                   # 是否暂停部署
```

### 配置项详解

#### metadata 字段

```yaml
metadata:
  name: my-app-deployment         # 必需：Deployment 名称
  namespace: production           # 可选：命名空间
  labels:                         # 可选：Deployment 标签
    app: my-app
    tier: frontend
    environment: production
    version: v1.0
  annotations:                    # 可选：注解
    description: "前端应用部署"
    contact: "team@example.com"
    deployment.kubernetes.io/revision: "3"
```

#### spec.selector 字段

```yaml
selector:                         # 必需：选择器
  matchLabels:                    # 标签匹配（AND 关系）
    app: my-app
    tier: frontend
  # matchExpressions:             # 表达式匹配（更灵活）
  # - key: environment
  #   operator: In                # In、NotIn、Exists、DoesNotExist
  #   values: ["production", "staging"]
  # - key: tier
  #   operator: Exists
```

#### spec.template 字段

```yaml
template:                         # Pod 模板
  metadata:
    labels:                       # 必需：Pod 标签（必须匹配 selector）
      app: my-app
      tier: frontend
      version: v1.0
    annotations:                  # 可选：Pod 注解
      prometheus.io/scrape: "true"
      prometheus.io/port: "9090"
  spec:                          # Pod 规格（与 Pod spec 相同）
    containers:
    - name: app
      image: nginx:1.20
      # ... 其他容器配置
```

#### spec.strategy 字段

```yaml
strategy:
  type: RollingUpdate             # 更新策略类型
  # type: Recreate              # 重建策略（所有 Pod 先删除再创建）
  
  rollingUpdate:                  # 滚动更新配置（仅在 RollingUpdate 时有效）
    maxUnavailable: 1             # 最大不可用 Pod 数量（数量或百分比）
    # maxUnavailable: 25%         # 25% 的 Pod 可以不可用
    maxSurge: 1                   # 最大额外 Pod 数量（数量或百分比）
    # maxSurge: 25%               # 最多额外创建 25% 的 Pod
```

### 高级配置

#### 资源管理

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        image: nginx:1.20
        resources:
          requests:               # 资源请求（用于调度）
            cpu: "100m"           # 100 毫核
            memory: "128Mi"       # 128 MiB
            ephemeral-storage: "1Gi"  # 临时存储
          limits:                 # 资源限制（硬限制）
            cpu: "500m"           # 500 毫核
            memory: "512Mi"       # 512 MiB
            ephemeral-storage: "2Gi"  # 临时存储
```

#### 健康检查

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        image: nginx:1.20
        livenessProbe:            # 存活探针
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:           # 就绪探针
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        startupProbe:             # 启动探针
          httpGet:
            path: /startup
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 30
```

#### 调度策略

```yaml
spec:
  template:
    spec:
      affinity:                   # 亲和性配置
        nodeAffinity:             # 节点亲和性
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values: ["amd64"]
        podAntiAffinity:          # Pod 反亲和性
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["my-app"]
              topologyKey: kubernetes.io/hostname
      
      tolerations:                # 污点容忍
      - key: "dedicated"
        operator: "Equal"
        value: "frontend"
        effect: "NoSchedule"
      
      nodeSelector:               # 节点选择器
        environment: production
        instance-type: m5.large
```

#### 安全配置

```yaml
spec:
  template:
    spec:
      securityContext:            # Pod 安全上下文
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 2000
        fsGroup: 2000
      
      containers:
      - name: app
        image: nginx:1.20
        securityContext:          # 容器安全上下文
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        
        volumeMounts:             # 只读根文件系统需要挂载可写目录
        - name: tmp-volume
          mountPath: /tmp
        - name: var-cache-nginx
          mountPath: /var/cache/nginx
        - name: var-run
          mountPath: /var/run
      
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: var-cache-nginx
        emptyDir: {}
      - name: var-run
        emptyDir: {}
```

## 更新策略详解

### 1. 滚动更新 (RollingUpdate)

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%         # 允许 25% 的 Pod 不可用
      maxSurge: 25%               # 允许额外创建 25% 的 Pod
```

**滚动更新流程：**
1. 创建新版本的 ReplicaSet
2. 逐步扩容新 ReplicaSet，缩容旧 ReplicaSet
3. 确保在任何时刻不可用的 Pod 数量不超过 maxUnavailable
4. 确保总的 Pod 数量不超过 replicas + maxSurge

### 2. 重建策略 (Recreate)

```yaml
spec:
  strategy:
    type: Recreate              # 先删除所有旧 Pod，再创建新 Pod
```

**重建流程：**
1. 删除所有旧版本的 Pod
2. 等待所有 Pod 完全终止
3. 创建所有新版本的 Pod

**适用场景：**
- 应用不能同时运行多个版本
- 需要独占资源的应用
- 数据库等有状态应用（通常使用 StatefulSet）

### 3. 更新触发条件

```yaml
# 更新会在以下情况触发：
# 1. 镜像变更
spec:
  template:
    spec:
      containers:
      - name: app
        image: nginx:1.21        # 从 nginx:1.20 更新到 nginx:1.21

# 2. 环境变量变更
        env:
        - name: APP_VERSION
          value: "v2.0"          # 从 v1.0 更新到 v2.0

# 3. 配置变更
        volumeMounts:
        - name: config
          mountPath: /etc/config
      volumes:
      - name: config
        configMap:
          name: app-config-v2    # 从 app-config-v1 更新到 app-config-v2

# 4. 资源限制变更
        resources:
          limits:
            cpu: "1000m"         # 从 500m 更新到 1000m
```

## 扩缩容操作

### 1. 手动扩缩容

```bash
# 命令行扩缩容
kubectl scale deployment my-deployment --replicas=5

# 或修改 YAML 文件
kubectl edit deployment my-deployment

# 或使用 patch
kubectl patch deployment my-deployment -p '{"spec":{"replicas":5}}'
```

### 2. 声明式扩缩容

```yaml
# 修改 replicas 字段
spec:
  replicas: 5                   # 从 3 扩容到 5
```

### 3. 自动扩缩容 (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-deployment-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-deployment
  minReplicas: 2                # 最小副本数
  maxReplicas: 10               # 最大副本数
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # CPU 使用率目标 70%
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80  # 内存使用率目标 80%
  behavior:                     # 扩缩容行为
    scaleDown:
      stabilizationWindowSeconds: 300  # 缩容稳定窗口
      policies:
      - type: Percent
        value: 10               # 每次最多缩容 10%
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0    # 扩容稳定窗口
      policies:
      - type: Percent
        value: 100              # 每次最多扩容 100%
        periodSeconds: 15
```

## 版本管理和回滚

### 1. 查看历史版本

```bash
# 查看部署历史
kubectl rollout history deployment my-deployment

# 查看特定版本详情
kubectl rollout history deployment my-deployment --revision=2
```

### 2. 回滚操作

```bash
# 回滚到上一个版本
kubectl rollout undo deployment my-deployment

# 回滚到特定版本
kubectl rollout undo deployment my-deployment --to-revision=2

# 查看回滚状态
kubectl rollout status deployment my-deployment
```

### 3. 暂停和恢复

```bash
# 暂停部署（用于分批更新）
kubectl rollout pause deployment my-deployment

# 恢复部署
kubectl rollout resume deployment my-deployment
```

### 4. 重启部署

```bash
# 重启部署（所有 Pod 会重新创建）
kubectl rollout restart deployment my-deployment
```

## 状态监控

### 1. Deployment 状态

```yaml
status:
  observedGeneration: 2         # 观察到的代次
  replicas: 3                   # 总副本数
  updatedReplicas: 3            # 已更新的副本数
  readyReplicas: 3              # 就绪的副本数
  availableReplicas: 3          # 可用的副本数
  conditions:                   # 状态条件
  - type: Progressing           # 进行中
    status: "True"
    reason: NewReplicaSetAvailable
    message: "ReplicaSet has successfully progressed."
  - type: Available             # 可用
    status: "True"
    reason: MinimumReplicasAvailable
    message: "Deployment has minimum availability."
```

### 2. 监控命令

```bash
# 查看 Deployment 状态
kubectl get deployments
kubectl describe deployment my-deployment

# 查看关联的 ReplicaSet
kubectl get replicasets -l app=my-app

# 查看 Pod 状态
kubectl get pods -l app=my-app

# 实时监控更新过程
kubectl rollout status deployment my-deployment -w
```

## 故障排除

### 1. 常见问题

```bash
# 1. Pod 无法启动
# 查看 Pod 详情
kubectl describe pod <pod-name>

# 查看 Pod 日志
kubectl logs <pod-name>

# 2. 更新卡住
# 检查 Deployment 状态
kubectl describe deployment my-deployment

# 检查事件
kubectl get events --sort-by=.metadata.creationTimestamp

# 3. 镜像拉取失败
# 检查镜像是否存在
docker pull nginx:1.20

# 检查镜像拉取密钥
kubectl get secrets
kubectl describe secret regcred
```

### 2. 调试技巧

```bash
# 进入 Pod 调试
kubectl exec -it <pod-name> -- /bin/bash

# 端口转发测试
kubectl port-forward deployment/my-deployment 8080:80

# 创建调试 Pod
kubectl run debug --image=busybox --rm -it -- sh

# 查看资源使用情况
kubectl top pods -l app=my-app
```

## 最佳实践

### 1. 标签管理

```yaml
metadata:
  labels:
    app: my-app                 # 应用名称
    component: frontend         # 组件
    tier: web                   # 层级
    environment: production     # 环境
    version: v1.0               # 版本
spec:
  selector:
    matchLabels:
      app: my-app               # 选择器必须稳定，不要包含版本号
  template:
    metadata:
      labels:
        app: my-app             # 必须匹配选择器
        version: v1.0           # 可以包含版本信息
```

### 2. 资源配置

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        resources:
          requests:               # 始终设置 requests
            cpu: 100m
            memory: 128Mi
          limits:                 # 设置合理的 limits
            cpu: 500m
            memory: 512Mi
```

### 3. 健康检查

```yaml
# 配置合适的健康检查
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30       # 给应用足够的启动时间
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5        # 就绪检查可以更早开始
  periodSeconds: 5
```

### 4. 更新策略

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 25%         # 保证服务可用性
    maxSurge: 25%               # 控制资源使用
```

### 5. 版本管理

```yaml
spec:
  revisionHistoryLimit: 5       # 保留合适数量的历史版本
  progressDeadlineSeconds: 300  # 设置合理的超时时间
```

### 6. 高可用部署

```yaml
spec:
  replicas: 3                   # 至少 3 个副本
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
                  values: ["my-app"]
              topologyKey: kubernetes.io/hostname
```

## 监控指标

### 1. 关键指标

```yaml
# Deployment 监控指标
- kube_deployment_status_replicas: 期望副本数
- kube_deployment_status_replicas_available: 可用副本数
- kube_deployment_status_replicas_unavailable: 不可用副本数
- kube_deployment_status_replicas_updated: 已更新副本数
- kube_deployment_metadata_generation: 配置代次
- kube_deployment_status_observed_generation: 观察到的代次
```

### 2. 告警规则

```yaml
# Prometheus 告警规则示例
groups:
- name: deployment
  rules:
  - alert: DeploymentReplicasMismatch
    expr: kube_deployment_spec_replicas != kube_deployment_status_replicas_available
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Deployment replica mismatch"
      
  - alert: DeploymentGenerationMismatch
    expr: kube_deployment_status_observed_generation != kube_deployment_metadata_generation
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Deployment generation mismatch"
```