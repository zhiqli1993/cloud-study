# Scheduler 架构详解

## 概述

Kubernetes Scheduler 是集群的调度器，负责将新创建的 Pod 调度到合适的节点上。它通过一系列算法和策略来确保 Pod 能够在满足资源需求和约束条件的节点上运行。

## 核心架构

```mermaid
graph TB
    subgraph "Scheduler 架构"
        subgraph "输入层"
            API_WATCH[API Server Watch]
            POD_QUEUE[Pod 队列]
            NODE_INFO[节点信息缓存]
        end
        
        subgraph "调度核心"
            SCHEDULER_CACHE[调度缓存]
            ALGORITHM[调度算法]
            subgraph "调度流程"
                FILTER[过滤阶段]
                SCORE[评分阶段]
                SELECT[选择阶段]
            end
        end
        
        subgraph "输出层"
            BIND[绑定操作]
            API_UPDATE[API Server 更新]
            EVENT[事件记录]
        end
        
        subgraph "扩展点"
            PLUGINS[调度插件]
            EXTENDERS[调度扩展器]
            CUSTOM[自定义调度器]
        end
    end
    
    subgraph "外部组件"
        API_SERVER[API Server]
        KUBELET[kubelet]
        NODES[集群节点]
    end
    
    API_SERVER --> API_WATCH
    API_WATCH --> POD_QUEUE
    API_SERVER --> NODE_INFO
    
    POD_QUEUE --> SCHEDULER_CACHE
    NODE_INFO --> SCHEDULER_CACHE
    SCHEDULER_CACHE --> ALGORITHM
    
    ALGORITHM --> FILTER
    FILTER --> SCORE
    SCORE --> SELECT
    
    SELECT --> BIND
    BIND --> API_UPDATE
    API_UPDATE --> API_SERVER
    
    ALGORITHM --> PLUGINS
    ALGORITHM --> EXTENDERS
    
    EVENT --> API_SERVER
    API_SERVER --> KUBELET
    KUBELET --> NODES
```

## 调度流程详解

### 1. 完整调度流程

```mermaid
sequenceDiagram
    participant API as API Server
    participant SCH as Scheduler
    participant CACHE as 调度缓存
    participant FILTER as 过滤器
    participant SCORE as 评分器
    participant BIND as 绑定器

    API->>SCH: 新 Pod 创建事件
    SCH->>CACHE: 获取节点信息
    CACHE->>SCH: 返回可用节点列表
    
    SCH->>FILTER: 执行过滤阶段
    FILTER->>FILTER: 应用过滤插件
    FILTER->>SCH: 返回候选节点
    
    alt 有候选节点
        SCH->>SCORE: 执行评分阶段
        SCORE->>SCORE: 应用评分插件
        SCORE->>SCH: 返回节点评分
        
        SCH->>SCH: 选择最佳节点
        SCH->>BIND: 绑定 Pod 到节点
        BIND->>API: 更新 Pod 绑定信息
        API->>SCH: 确认绑定成功
    else 无候选节点
        SCH->>API: 记录调度失败事件
        SCH->>SCH: 将 Pod 放回队列
    end
```

### 2. 调度队列机制

```mermaid
graph TB
    subgraph "调度队列架构"
        subgraph "输入"
            NEW_PODS[新建 Pod]
            RETRY_PODS[重试 Pod]
            UPDATE_PODS[更新 Pod]
        end
        
        subgraph "队列层"
            ACTIVE_QUEUE[活跃队列]
            BACKOFF_QUEUE[退避队列]
            UNSCHEDULABLE_QUEUE[不可调度队列]
        end
        
        subgraph "处理层"
            SCHEDULER_CYCLE[调度周期]
            BACKOFF_TIMER[退避定时器]
            FLUSH_TIMER[刷新定时器]
        end
    end
    
    NEW_PODS --> ACTIVE_QUEUE
    RETRY_PODS --> BACKOFF_QUEUE
    UPDATE_PODS --> ACTIVE_QUEUE
    
    ACTIVE_QUEUE --> SCHEDULER_CYCLE
    BACKOFF_QUEUE --> BACKOFF_TIMER
    UNSCHEDULABLE_QUEUE --> FLUSH_TIMER
    
    SCHEDULER_CYCLE --> ACTIVE_QUEUE
    SCHEDULER_CYCLE --> BACKOFF_QUEUE
    SCHEDULER_CYCLE --> UNSCHEDULABLE_QUEUE
    
    BACKOFF_TIMER --> ACTIVE_QUEUE
    FLUSH_TIMER --> ACTIVE_QUEUE
```

## 调度算法详解

### 1. 过滤阶段 (Filtering)

#### 内置过滤插件
```yaml
# 节点亲和性过滤
NodeAffinity:
  # 检查 Pod 的节点亲和性规则
  - requiredDuringSchedulingIgnoredDuringExecution
  - preferredDuringSchedulingIgnoredDuringExecution

# 资源过滤
NodeResourcesFit:
  # 检查节点资源是否满足 Pod 需求
  - CPU 资源
  - 内存资源
  - 存储资源
  - 扩展资源

# 污点容忍过滤
TaintToleration:
  # 检查 Pod 是否容忍节点污点
  - NoSchedule 污点
  - PreferNoSchedule 污点
  - NoExecute 污点
```

#### 过滤算法实现
```go
// 过滤插件接口
type FilterPlugin interface {
    Name() string
    Filter(ctx context.Context, state *CycleState, pod *v1.Pod, nodeInfo *NodeInfo) *Status
}

// 资源过滤示例
func (f *NodeResourcesFit) Filter(ctx context.Context, cycleState *framework.CycleState, pod *v1.Pod, nodeInfo *framework.NodeInfo) *Status {
    node := nodeInfo.Node()
    
    // 计算 Pod 资源需求
    podRequest := computePodResourceRequest(pod)
    
    // 获取节点可用资源
    allocatable := node.Status.Allocatable
    
    // 检查资源是否足够
    if !fitsRequest(podRequest, allocatable) {
        return framework.NewStatus(framework.Unschedulable, "Insufficient resources")
    }
    
    return framework.NewStatus(framework.Success, "")
}
```

### 2. 评分阶段 (Scoring)

#### 内置评分插件
```yaml
# 节点资源评分
NodeResourcesFit:
  # 根据资源利用率评分
  strategy: LeastAllocated  # 最少分配策略
  # strategy: MostAllocated   # 最多分配策略
  # strategy: RequestedToCapacityRatio  # 请求容量比策略

# 节点亲和性评分
NodeAffinity:
  # 根据亲和性偏好评分
  weight: 100

# Pod 间亲和性评分
InterPodAffinity:
  # 根据 Pod 间亲和性评分
  weight: 100

# 负载分散评分
PodTopologySpread:
  # 根据拓扑分散约束评分
  weight: 100
```

#### 评分算法实现
```go
// 评分插件接口
type ScorePlugin interface {
    Name() string
    Score(ctx context.Context, state *CycleState, pod *v1.Pod, nodeName string) (int64, *Status)
    ScoreExtensions() ScoreExtensions
}

// 资源评分示例
func (f *NodeResourcesFit) Score(ctx context.Context, cycleState *framework.CycleState, pod *v1.Pod, nodeName string) (int64, *Status) {
    nodeInfo, err := f.handle.SnapshotSharedLister().NodeInfos().Get(nodeName)
    if err != nil {
        return 0, framework.NewStatus(framework.Error, fmt.Sprintf("getting node %q from Snapshot: %v", nodeName, err))
    }
    
    // 计算资源利用率
    requested := nodeInfo.Requested
    allocatable := nodeInfo.Allocatable
    
    // 根据策略计算评分
    score := calculateScore(requested, allocatable, f.strategy)
    
    return score, framework.NewStatus(framework.Success, "")
}
```

## 调度策略详解

### 1. 节点选择策略

#### 资源分配策略
```yaml
# 最少分配策略 (LeastAllocated)
# 优先选择资源使用率低的节点
score = ((allocatable - requested) / allocatable) * 100

# 最多分配策略 (MostAllocated)  
# 优先选择资源使用率高的节点
score = (requested / allocatable) * 100

# 请求容量比策略 (RequestedToCapacityRatio)
# 根据配置的目标利用率评分
score = requestedToCapacity * 100
```

#### 亲和性和反亲和性
```yaml
# Pod 亲和性示例
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - database
        topologyKey: kubernetes.io/hostname
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - web
          topologyKey: kubernetes.io/hostname
```

### 2. 高级调度特性

#### 拓扑分散约束
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
  labels:
    app: myapp
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: myapp
  - maxSkew: 1
    topologyKey: node
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: myapp
```

#### 污点和容忍
```yaml
# 节点污点
kubectl taint nodes node1 key1=value1:NoSchedule

# Pod 容忍
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  tolerations:
  - key: "key1"
    operator: "Equal"
    value: "value1"
    effect: "NoSchedule"
  - key: "key2"
    operator: "Exists"
    effect: "NoExecute"
    tolerationSeconds: 3600
```

## 调度框架详解

### 1. 调度框架扩展点

```mermaid
graph TB
    subgraph "调度框架扩展点"
        subgraph "调度周期"
            SORT[Sort]
            PREFILTER[PreFilter]
            FILTER[Filter]
            POSFILTER[PostFilter]
            PRESCORE[PreScore]
            SCORE[Score]
            RESERVE[Reserve]
            PERMIT[Permit]
        end
        
        subgraph "绑定周期"
            PREBIND[PreBind]
            BIND[Bind]
            POSTBIND[PostBind]
        end
        
        subgraph "异步扩展点"
            UNRESERVE[Unreserve]
        end
    end
    
    SORT --> PREFILTER
    PREFILTER --> FILTER
    FILTER --> POSFILTER
    POSFILTER --> PRESCORE
    PRESCORE --> SCORE
    SCORE --> RESERVE
    RESERVE --> PERMIT
    
    PERMIT --> PREBIND
    PREBIND --> BIND
    BIND --> POSTBIND
    
    RESERVE -.-> UNRESERVE
    PERMIT -.-> UNRESERVE
```

### 2. 自定义调度插件

#### 插件实现示例
```go
// 自定义调度插件
type CustomPlugin struct {
    handle framework.Handle
}

// 实现 FilterPlugin 接口
func (cp *CustomPlugin) Name() string {
    return "CustomPlugin"
}

func (cp *CustomPlugin) Filter(ctx context.Context, state *framework.CycleState, pod *v1.Pod, nodeInfo *framework.NodeInfo) *framework.Status {
    // 自定义过滤逻辑
    node := nodeInfo.Node()
    
    // 检查自定义标签
    if node.Labels["custom-label"] != "allowed" {
        return framework.NewStatus(framework.Unschedulable, "Node does not have required custom label")
    }
    
    return framework.NewStatus(framework.Success, "")
}

// 实现 ScorePlugin 接口
func (cp *CustomPlugin) Score(ctx context.Context, state *framework.CycleState, pod *v1.Pod, nodeName string) (int64, *framework.Status) {
    // 自定义评分逻辑
    nodeInfo, err := cp.handle.SnapshotSharedLister().NodeInfos().Get(nodeName)
    if err != nil {
        return 0, framework.NewStatus(framework.Error, err.Error())
    }
    
    // 根据自定义指标计算评分
    score := calculateCustomScore(nodeInfo.Node())
    
    return score, framework.NewStatus(framework.Success, "")
}
```

#### 插件配置
```yaml
apiVersion: kubescheduler.config.k8s.io/v1beta3
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: custom-scheduler
  plugins:
    filter:
      enabled:
      - name: CustomPlugin
    score:
      enabled:
      - name: CustomPlugin
  pluginConfig:
  - name: CustomPlugin
    args:
      customParam: "value"
```

## 多调度器架构

### 1. 多调度器部署

```mermaid
graph TB
    subgraph "多调度器架构"
        subgraph "默认调度器"
            DEFAULT_SCH[default-scheduler]
            DEFAULT_QUEUE[默认队列]
        end
        
        subgraph "自定义调度器 1"
            CUSTOM_SCH1[gpu-scheduler]
            GPU_QUEUE[GPU 队列]
        end
        
        subgraph "自定义调度器 2"
            CUSTOM_SCH2[batch-scheduler]
            BATCH_QUEUE[批处理队列]
        end
        
        subgraph "Pod 分发"
            POD_ROUTER[Pod 路由器]
            DEFAULT_PODS[默认 Pods]
            GPU_PODS[GPU Pods]
            BATCH_PODS[批处理 Pods]
        end
    end
    
    POD_ROUTER --> DEFAULT_PODS
    POD_ROUTER --> GPU_PODS
    POD_ROUTER --> BATCH_PODS
    
    DEFAULT_PODS --> DEFAULT_QUEUE
    GPU_PODS --> GPU_QUEUE
    BATCH_PODS --> BATCH_QUEUE
    
    DEFAULT_QUEUE --> DEFAULT_SCH
    GPU_QUEUE --> CUSTOM_SCH1
    BATCH_QUEUE --> CUSTOM_SCH2
```

### 2. 调度器选择

```yaml
# 指定调度器的 Pod
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  schedulerName: gpu-scheduler  # 指定使用 GPU 调度器
  containers:
  - name: gpu-container
    image: tensorflow/tensorflow:latest-gpu
    resources:
      limits:
        nvidia.com/gpu: 1
```

## 性能优化

### 1. 调度性能指标

```yaml
# 关键性能指标
scheduler_scheduling_duration_seconds: 调度延迟
scheduler_pending_pods: 待调度 Pod 数量
scheduler_queue_incoming_pods_total: 队列接收 Pod 总数
scheduler_framework_extension_point_duration_seconds: 扩展点执行时间
scheduler_plugin_execution_duration_seconds: 插件执行时间
```

### 2. 性能调优策略

#### 批量调度
```yaml
# 批量调度配置
apiVersion: kubescheduler.config.k8s.io/v1beta3
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: batch-scheduler
  plugins:
    queueSort:
      enabled:
      - name: PrioritySort
  pluginConfig:
  - name: PrioritySort
    args:
      batchSize: 100  # 批量处理大小
```

#### 缓存优化
```go
// 节点信息缓存
type NodeInfoCache struct {
    mu          sync.RWMutex
    nodes       map[string]*NodeInfo
    generation  int64
    lastUpdate  time.Time
}

// 增量更新缓存
func (cache *NodeInfoCache) UpdateNode(node *v1.Node) {
    cache.mu.Lock()
    defer cache.mu.Unlock()
    
    nodeInfo := cache.nodes[node.Name]
    if nodeInfo == nil {
        nodeInfo = NewNodeInfo()
        cache.nodes[node.Name] = nodeInfo
    }
    
    nodeInfo.SetNode(node)
    cache.generation++
    cache.lastUpdate = time.Now()
}
```

## 故障排除

### 1. 调度失败诊断

#### 常见调度失败原因
```bash
# 查看调度失败事件
kubectl describe pod unscheduled-pod

# 常见失败原因
# 1. 资源不足
# 2. 节点亲和性不匹配
# 3. 污点不被容忍
# 4. Pod 间亲和性约束
# 5. 拓扑分散约束
```

#### 调度器日志分析
```bash
# 查看调度器日志
kubectl logs -n kube-system deployment/kube-scheduler

# 启用详细日志
--v=2  # 基本调度信息
--v=4  # 详细调度决策
--v=6  # 更详细的调试信息
```

### 2. 性能问题排查

#### 调度延迟分析
```bash
# 监控调度延迟
kubectl top pods --sort-by=.metadata.creationTimestamp

# 查看调度器性能指标
curl http://scheduler:10251/metrics | grep scheduler_scheduling_duration
```

#### 队列积压分析
```bash
# 查看待调度 Pod
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# 分析队列状态
curl http://scheduler:10251/metrics | grep scheduler_pending_pods
```

## 最佳实践

### 1. 调度策略设计

#### 资源管理
```yaml
# 合理设置资源请求和限制
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

#### 亲和性配置
```yaml
# 合理使用亲和性
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:  # 使用偏好而非强制
    - weight: 1
      preference:
        matchExpressions:
        - key: node-type
          operator: In
          values:
          - compute-optimized
```

### 2. 调度器运维

#### 监控告警
```yaml
# 调度器监控规则
groups:
- name: scheduler
  rules:
  - alert: SchedulerDown
    expr: up{job="kube-scheduler"} == 0
    for: 5m
    
  - alert: HighSchedulingLatency
    expr: histogram_quantile(0.99, scheduler_scheduling_duration_seconds_bucket) > 1
    for: 10m
    
  - alert: TooManyPendingPods
    expr: scheduler_pending_pods > 100
    for: 5m
```

#### 高可用部署
```yaml
# 多副本调度器部署
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  replicas: 3
  selector:
    matchLabels:
      component: kube-scheduler
  template:
    spec:
      containers:
      - name: kube-scheduler
        image: k8s.gcr.io/kube-scheduler:v1.21.0
        command:
        - kube-scheduler
        - --leader-elect=true
        - --lock-object-name=kube-scheduler
        - --lock-object-namespace=kube-system
