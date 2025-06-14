# Controller Manager 架构详解

## 概述

Controller Manager 是 Kubernetes 集群的控制器管理器，负责运行各种控制器来维护集群的期望状态。它采用控制器模式，持续监控集群状态并采取必要的操作来使实际状态与期望状态保持一致。

## 核心架构

```mermaid
graph TB
    subgraph "Controller Manager 架构"
        subgraph "控制器管理层"
            CM_MAIN[Controller Manager 主进程]
            LEADER_ELECTION[Leader 选举]
            CONTROLLER_REGISTRY[控制器注册表]
        end
        
        subgraph "内置控制器"
            NODE_CTRL[节点控制器]
            REPLICATION_CTRL[副本控制器]
            ENDPOINT_CTRL[端点控制器]
            SA_CTRL[服务账户控制器]
            NAMESPACE_CTRL[命名空间控制器]
            PV_CTRL[持久卷控制器]
            RC_CTRL[资源配额控制器]
            SERVICE_CTRL[服务控制器]
            DEPLOYMENT_CTRL[部署控制器]
            DAEMONSET_CTRL[守护进程集控制器]
            JOB_CTRL[任务控制器]
            CRONJOB_CTRL[定时任务控制器]
        end
        
        subgraph "共享组件"
            SHARED_INFORMER[共享 Informer]
            WORK_QUEUE[工作队列]
            EVENT_RECORDER[事件记录器]
            METRICS[指标收集器]
        end
        
        subgraph "客户端层"
            API_CLIENT[API Server 客户端]
            WATCH_CLIENT[Watch 客户端]
            UPDATE_CLIENT[更新客户端]
        end
    end
    
    subgraph "外部组件"
        API_SERVER[API Server]
        ETCD[etcd]
        CLOUD_API[云服务 API]
    end
    
    CM_MAIN --> LEADER_ELECTION
    CM_MAIN --> CONTROLLER_REGISTRY
    
    CONTROLLER_REGISTRY --> NODE_CTRL
    CONTROLLER_REGISTRY --> REPLICATION_CTRL
    CONTROLLER_REGISTRY --> ENDPOINT_CTRL
    CONTROLLER_REGISTRY --> SA_CTRL
    CONTROLLER_REGISTRY --> NAMESPACE_CTRL
    CONTROLLER_REGISTRY --> PV_CTRL
    CONTROLLER_REGISTRY --> RC_CTRL
    CONTROLLER_REGISTRY --> SERVICE_CTRL
    CONTROLLER_REGISTRY --> DEPLOYMENT_CTRL
    CONTROLLER_REGISTRY --> DAEMONSET_CTRL
    CONTROLLER_REGISTRY --> JOB_CTRL
    CONTROLLER_REGISTRY --> CRONJOB_CTRL
    
    NODE_CTRL --> SHARED_INFORMER
    REPLICATION_CTRL --> SHARED_INFORMER
    ENDPOINT_CTRL --> SHARED_INFORMER
    
    SHARED_INFORMER --> WORK_QUEUE
    WORK_QUEUE --> EVENT_RECORDER
    EVENT_RECORDER --> METRICS
    
    SHARED_INFORMER --> API_CLIENT
    API_CLIENT --> WATCH_CLIENT
    WATCH_CLIENT --> UPDATE_CLIENT
    
    API_CLIENT --> API_SERVER
    API_SERVER --> ETCD
    
    NODE_CTRL --> CLOUD_API
    SERVICE_CTRL --> CLOUD_API
```

## 控制器模式详解

### 1. 控制器工作原理

```mermaid
graph TB
    subgraph "控制器循环"
        subgraph "观察阶段"
            WATCH[监听 API 事件]
            CACHE[本地缓存更新]
            INFORMER[Informer 机制]
        end
        
        subgraph "分析阶段"
            CURRENT_STATE[获取当前状态]
            DESIRED_STATE[获取期望状态]
            DIFF[状态差异分析]
        end
        
        subgraph "执行阶段"
            RECONCILE[协调操作]
            API_CALL[API 调用]
            STATUS_UPDATE[状态更新]
        end
        
        subgraph "反馈阶段"
            EVENT[事件记录]
            METRICS_UPDATE[指标更新]
            ERROR_HANDLE[错误处理]
        end
    end
    
    WATCH --> CACHE
    CACHE --> INFORMER
    INFORMER --> CURRENT_STATE
    
    CURRENT_STATE --> DESIRED_STATE
    DESIRED_STATE --> DIFF
    
    DIFF --> RECONCILE
    RECONCILE --> API_CALL
    API_CALL --> STATUS_UPDATE
    
    STATUS_UPDATE --> EVENT
    EVENT --> METRICS_UPDATE
    METRICS_UPDATE --> ERROR_HANDLE
    
    ERROR_HANDLE --> WATCH
```

### 2. 控制器生命周期

```mermaid
sequenceDiagram
    participant CM as Controller Manager
    participant CTRL as Controller
    participant INFORMER as Informer
    participant QUEUE as Work Queue
    participant API as API Server

    CM->>CTRL: 启动控制器
    CTRL->>INFORMER: 创建 Informer
    INFORMER->>API: 建立 Watch 连接
    API->>INFORMER: 返回资源变更事件
    
    loop 控制循环
        INFORMER->>QUEUE: 添加工作项
        CTRL->>QUEUE: 获取工作项
        CTRL->>CTRL: 执行协调逻辑
        CTRL->>API: 更新资源状态
        API->>CTRL: 确认更新成功
        
        alt 协调成功
            CTRL->>CTRL: 记录成功事件
        else 协调失败
            CTRL->>QUEUE: 重新排队
        end
    end
```

## 核心控制器详解

### 1. 节点控制器 (Node Controller)

#### 功能职责
- 监控节点健康状态
- 处理节点故障
- 管理节点生命周期
- 更新节点状态

#### 工作机制
```mermaid
graph TB
    subgraph "节点控制器工作流程"
        subgraph "监控阶段"
            KUBELET_HEARTBEAT[kubelet 心跳监控]
            NODE_STATUS[节点状态检查]
            HEALTH_CHECK[健康检查]
        end
        
        subgraph "状态管理"
            READY_CONDITION[Ready 条件更新]
            TAINT_MANAGEMENT[污点管理]
            LEASE_UPDATE[租约更新]
        end
        
        subgraph "故障处理"
            NODE_EVICTION[节点驱逐]
            POD_EVICTION[Pod 驱逐]
            GRACE_PERIOD[宽限期处理]
        end
    end
    
    KUBELET_HEARTBEAT --> NODE_STATUS
    NODE_STATUS --> HEALTH_CHECK
    
    HEALTH_CHECK --> READY_CONDITION
    READY_CONDITION --> TAINT_MANAGEMENT
    TAINT_MANAGEMENT --> LEASE_UPDATE
    
    HEALTH_CHECK --> NODE_EVICTION
    NODE_EVICTION --> POD_EVICTION
    POD_EVICTION --> GRACE_PERIOD
```

#### 配置参数
```yaml
# 节点控制器关键配置
node-monitor-period: 5s          # 节点监控周期
node-monitor-grace-period: 40s   # 节点监控宽限期
pod-eviction-timeout: 5m         # Pod 驱逐超时
large-cluster-size-threshold: 50 # 大集群阈值
unhealthy-zone-threshold: 0.55   # 不健康区域阈值
```

### 2. 副本控制器 (ReplicaSet Controller)

#### 功能职责
- 维护指定数量的 Pod 副本
- 处理 Pod 创建和删除
- 监控 Pod 健康状态
- 执行滚动更新

#### 协调逻辑
```go
// 副本控制器协调逻辑
func (rsc *ReplicaSetController) syncReplicaSet(key string) error {
    // 1. 获取 ReplicaSet 对象
    rs, err := rsc.rsLister.ReplicaSets(namespace).Get(name)
    if err != nil {
        return err
    }
    
    // 2. 获取匹配的 Pod 列表
    pods, err := rsc.getPodsForReplicaSet(rs)
    if err != nil {
        return err
    }
    
    // 3. 计算需要的副本数量
    diff := int(*rs.Spec.Replicas) - len(pods)
    
    // 4. 执行协调操作
    if diff > 0 {
        // 创建新的 Pod
        return rsc.slowStartBatch(diff, controller.SlowStartInitialBatchSize, func() error {
            return rsc.createPod(rs)
        })
    } else if diff < 0 {
        // 删除多余的 Pod
        return rsc.deletePods(-diff, pods)
    }
    
    return nil
}
```

### 3. 端点控制器 (Endpoints Controller)

#### 功能职责
- 维护 Service 和 Pod 之间的映射
- 更新 Endpoints 对象
- 处理 Pod 就绪状态变更
- 管理服务发现信息

#### 工作流程
```mermaid
sequenceDiagram
    participant SVC as Service
    participant EP_CTRL as Endpoints Controller
    participant POD as Pod
    participant EP as Endpoints

    Note over EP_CTRL: 监听 Service 和 Pod 变更
    
    SVC->>EP_CTRL: Service 创建/更新事件
    EP_CTRL->>EP_CTRL: 查找匹配的 Pod
    
    POD->>EP_CTRL: Pod 状态变更事件
    EP_CTRL->>EP_CTRL: 检查 Pod 就绪状态
    
    EP_CTRL->>EP: 更新 Endpoints 对象
    EP->>EP_CTRL: 确认更新完成
    
    Note over EP_CTRL: 持续监控并维护 Endpoints
```

### 4. 部署控制器 (Deployment Controller)

#### 功能职责
- 管理 ReplicaSet 生命周期
- 执行滚动更新策略
- 处理部署回滚
- 维护版本历史

#### 滚动更新机制
```mermaid
graph TB
    subgraph "滚动更新流程"
        subgraph "准备阶段"
            CREATE_NEW_RS[创建新 ReplicaSet]
            SCALE_UP_NEW[扩容新版本]
            WAIT_READY[等待就绪]
        end
        
        subgraph "更新阶段"
            SCALE_DOWN_OLD[缩容旧版本]
            SCALE_UP_MORE[继续扩容新版本]
            PROGRESS_CHECK[进度检查]
        end
        
        subgraph "完成阶段"
            CLEANUP_OLD[清理旧版本]
            UPDATE_STATUS[更新状态]
            RECORD_HISTORY[记录历史]
        end
    end
    
    CREATE_NEW_RS --> SCALE_UP_NEW
    SCALE_UP_NEW --> WAIT_READY
    WAIT_READY --> SCALE_DOWN_OLD
    
    SCALE_DOWN_OLD --> SCALE_UP_MORE
    SCALE_UP_MORE --> PROGRESS_CHECK
    PROGRESS_CHECK --> SCALE_DOWN_OLD
    
    PROGRESS_CHECK --> CLEANUP_OLD
    CLEANUP_OLD --> UPDATE_STATUS
    UPDATE_STATUS --> RECORD_HISTORY
```

### 5. 任务控制器 (Job Controller)

#### 功能职责
- 管理批处理任务
- 处理 Pod 失败重试
- 维护任务完成状态
- 执行清理策略

#### 任务状态管理
```yaml
# Job 状态转换
apiVersion: batch/v1
kind: Job
status:
  conditions:
  - type: Suspended    # 暂停状态
    status: "True"
  - type: Complete     # 完成状态
    status: "True"
  - type: Failed       # 失败状态
    status: "False"
  active: 0           # 活跃 Pod 数量
  succeeded: 3        # 成功 Pod 数量
  failed: 1           # 失败 Pod 数量
  completionTime: "2023-01-01T12:00:00Z"
  startTime: "2023-01-01T11:00:00Z"
```

## 共享组件详解

### 1. Shared Informer 机制

#### 架构设计
```mermaid
graph TB
    subgraph "Shared Informer 架构"
        subgraph "API 层"
            API_SERVER[API Server]
            LIST_WATCH[List-Watch]
        end
        
        subgraph "缓存层"
            SHARED_INFORMER[Shared Informer]
            LOCAL_CACHE[本地缓存]
            INDEXER[索引器]
        end
        
        subgraph "事件分发层"
            EVENT_HANDLER[事件处理器]
            RESOURCE_HANDLER[资源处理器]
            CONTROLLER_1[控制器 1]
            CONTROLLER_2[控制器 2]
            CONTROLLER_N[控制器 N]
        end
    end
    
    API_SERVER --> LIST_WATCH
    LIST_WATCH --> SHARED_INFORMER
    SHARED_INFORMER --> LOCAL_CACHE
    LOCAL_CACHE --> INDEXER
    
    SHARED_INFORMER --> EVENT_HANDLER
    EVENT_HANDLER --> RESOURCE_HANDLER
    RESOURCE_HANDLER --> CONTROLLER_1
    RESOURCE_HANDLER --> CONTROLLER_2
    RESOURCE_HANDLER --> CONTROLLER_N
```

#### 实现机制
```go
// Shared Informer 实现
type sharedInformer struct {
    objectType    runtime.Object
    resyncPeriod  time.Duration
    clock         clock.Clock
    
    // 本地缓存
    store cache.Store
    
    // 控制器列表
    controllers map[*controller]bool
    
    // 事件分发
    processor *sharedProcessor
}

// 添加事件处理器
func (s *sharedInformer) AddEventHandler(handler cache.ResourceEventHandler) {
    s.processor.addListener(newProcessListener(handler, 0, 0, s.clock))
}

// 事件分发处理
func (p *sharedProcessor) distribute(obj interface{}, sync bool) {
    for _, listener := range p.listeners {
        listener.add(obj)
    }
}
```

### 2. Work Queue 机制

#### 队列类型
```go
// 基础队列接口
type Interface interface {
    Add(item interface{})
    Len() int
    Get() (item interface{}, shutdown bool)
    Done(item interface{})
    ShutDown()
    ShuttingDown() bool
}

// 延时队列
type DelayingInterface interface {
    Interface
    AddAfter(item interface{}, duration time.Duration)
}

// 限速队列
type RateLimitingInterface interface {
    DelayingInterface
    AddRateLimited(item interface{})
    Forget(item interface{})
    NumRequeues(item interface{}) int
}
```

#### 限速策略
```go
// 指数退避限速器
func NewItemExponentialFailureRateLimiter(baseDelay time.Duration, maxDelay time.Duration) RateLimiter {
    return &ItemExponentialFailureRateLimiter{
        failures:    map[interface{}]int{},
        baseDelay:   baseDelay,
        maxDelay:    maxDelay,
    }
}

// 固定延时限速器
func NewItemFastSlowRateLimiter(fastDelay, slowDelay time.Duration, maxFastAttempts int) RateLimiter {
    return &ItemFastSlowRateLimiter{
        failures:        map[interface{}]int{},
        fastDelay:       fastDelay,
        slowDelay:       slowDelay,
        maxFastAttempts: maxFastAttempts,
    }
}
```

## 高可用和性能优化

### 1. Leader 选举机制

#### 选举过程
```mermaid
sequenceDiagram
    participant CM1 as Controller Manager 1
    participant CM2 as Controller Manager 2
    participant CM3 as Controller Manager 3
    participant ETCD as etcd

    Note over CM1, ETCD: Leader 选举过程
    
    CM1->>ETCD: 尝试获取锁
    CM2->>ETCD: 尝试获取锁
    CM3->>ETCD: 尝试获取锁
    
    ETCD->>CM1: 获取锁成功 (成为 Leader)
    ETCD->>CM2: 获取锁失败 (成为 Follower)
    ETCD->>CM3: 获取锁失败 (成为 Follower)
    
    CM1->>ETCD: 定期续约
    
    Note over CM1: Leader 执行控制器逻辑
    Note over CM2, CM3: Follower 待机
    
    alt Leader 故障
        CM1--xCM1: 进程终止
        CM2->>ETCD: 检测到锁过期，尝试获取
        ETCD->>CM2: 获取锁成功 (成为新 Leader)
        Note over CM2: 新 Leader 开始工作
    end
```

#### 配置示例
```yaml
# Leader 选举配置
apiVersion: v1
kind: Pod
metadata:
  name: kube-controller-manager
spec:
  containers:
  - name: kube-controller-manager
    image: k8s.gcr.io/kube-controller-manager:v1.21.0
    command:
    - kube-controller-manager
    - --leader-elect=true
    - --leader-elect-lease-duration=15s
    - --leader-elect-renew-deadline=10s
    - --leader-elect-retry-period=2s
    - --leader-elect-resource-lock=leases
    - --leader-elect-resource-name=kube-controller-manager
    - --leader-elect-resource-namespace=kube-system
```

### 2. 性能优化策略

#### 并发控制
```yaml
# 控制器并发配置
concurrent-deployment-syncs: 5        # 部署控制器并发数
concurrent-replicaset-syncs: 5        # 副本集控制器并发数
concurrent-endpoint-syncs: 5          # 端点控制器并发数
concurrent-namespace-syncs: 10        # 命名空间控制器并发数
concurrent-service-syncs: 1           # 服务控制器并发数
```

#### 缓存优化
```go
// 控制器缓存配置
type ControllerOptions struct {
    // 缓存同步超时
    CacheSyncTimeout time.Duration
    
    // Informer 重同步周期
    ResyncPeriod time.Duration
    
    // 工作队列大小
    WorkerCount int
    
    // 事件记录器
    EventRecorder record.EventRecorder
}
```

## 监控和故障排除

### 1. 关键监控指标

```yaml
# Controller Manager 监控指标
controller_manager_leader_election_master_status: Leader 状态
workqueue_adds_total: 工作队列添加总数
workqueue_depth: 工作队列深度
workqueue_queue_duration_seconds: 队列等待时间
workqueue_work_duration_seconds: 工作处理时间
rest_client_requests_total: API 请求总数
rest_client_request_duration_seconds: API 请求延迟
```

### 2. 故障诊断

#### 常见问题
```bash
# 检查 Controller Manager 状态
kubectl get pods -n kube-system -l component=kube-controller-manager

# 查看控制器日志
kubectl logs -n kube-system kube-controller-manager-master

# 检查 Leader 选举状态
kubectl get lease -n kube-system kube-controller-manager

# 查看控制器指标
curl http://localhost:10252/metrics
```

#### 性能问题排查
```bash
# 查看工作队列指标
curl http://localhost:10252/metrics | grep workqueue

# 分析 API 请求延迟
curl http://localhost:10252/metrics | grep rest_client_request_duration

# 检查内存使用情况
kubectl top pod -n kube-system -l component=kube-controller-manager
```

## 最佳实践

### 1. 控制器配置优化

```yaml
# 生产环境推荐配置
apiVersion: v1
kind: Pod
metadata:
  name: kube-controller-manager
spec:
  containers:
  - name: kube-controller-manager
    image: k8s.gcr.io/kube-controller-manager:v1.21.0
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
    command:
    - kube-controller-manager
    - --bind-address=0.0.0.0
    - --secure-port=10257
    - --kubeconfig=/etc/kubernetes/controller-manager.conf
    - --authentication-kubeconfig=/etc/kubernetes/controller-manager.conf
    - --authorization-kubeconfig=/etc/kubernetes/controller-manager.conf
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
    - --root-ca-file=/etc/kubernetes/pki/ca.crt
    - --service-account-private-key-file=/etc/kubernetes/pki/sa.key
    - --cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt
    - --cluster-signing-key-file=/etc/kubernetes/pki/ca.key
    - --use-service-account-credentials=true
    - --controllers=*,bootstrapsigner,tokencleaner
    - --leader-elect=true
    - --concurrent-deployment-syncs=10
    - --concurrent-replicaset-syncs=10
    - --concurrent-endpoint-syncs=10
    - --kube-api-qps=100
    - --kube-api-burst=100
```

### 2. 自定义控制器开发

```go
// 自定义控制器框架
func main() {
    cfg, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
    if err != nil {
        klog.Fatalf("Error building kubeconfig: %s", err.Error())
    }

    kubeClient, err := kubernetes.NewForConfig(cfg)
    if err != nil {
        klog.Fatalf("Error building kubernetes clientset: %s", err.Error())
    }

    kubeInformerFactory := kubeinformers.NewSharedInformerFactory(kubeClient, time.Second*30)

    controller := NewController(kubeClient, kubeInformerFactory.Apps().V1().Deployments())

    stopCh := signals.SetupSignalHandler()

    kubeInformerFactory.Start(stopCh)

    if err = controller.Run(2, stopCh); err != nil {
        klog.Fatalf("Error running controller: %s", err.Error())
    }
}
```