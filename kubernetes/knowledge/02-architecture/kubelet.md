# kubelet 架构详解

## 概述

kubelet 是运行在每个节点上的主要节点代理，负责管理节点上 Pod 的生命周期、容器运行时交互、资源监控和节点状态报告。它是 Kubernetes 集群中连接 Control Plane 和 Worker Node 的关键组件。

## 核心架构

```mermaid
graph TB
    subgraph "kubelet 架构"
        subgraph "API 接口层"
            HTTP_SERVER[HTTP Server]
            GRPC_SERVER[gRPC Server]
            STREAMING_SERVER[Streaming Server]
        end
        
        subgraph "Pod 管理层"
            POD_MANAGER[Pod Manager]
            POD_WORKERS[Pod Workers]
            STATUS_MANAGER[Status Manager]
            PROBE_MANAGER[Probe Manager]
        end
        
        subgraph "容器运行时层"
            CRI_CLIENT[CRI Client]
            RUNTIME_SERVICE[Runtime Service]
            IMAGE_SERVICE[Image Service]
        end
        
        subgraph "存储管理层"
            VOLUME_MANAGER[Volume Manager]
            CSI_DRIVER[CSI Driver]
            MOUNT_MANAGER[Mount Manager]
        end
        
        subgraph "网络管理层"
            CNI_MANAGER[CNI Manager]
            NETWORK_PLUGIN[Network Plugin]
            PORT_FORWARD[Port Forward]
        end
        
        subgraph "资源管理层"
            CGROUP_MANAGER[cgroup Manager]
            RESOURCE_ANALYZER[Resource Analyzer]
            QOS_MANAGER[QoS Manager]
        end
        
        subgraph "监控和日志"
            CADVISOR[cAdvisor]
            LOG_MANAGER[Log Manager]
            EVENTS[Event Generator]
        end
    end
    
    subgraph "外部组件"
        API_SERVER[API Server]
        CONTAINER_RUNTIME[Container Runtime]
        CNI_PLUGINS[CNI Plugins]
        CSI_PLUGINS[CSI Plugins]
    end
    
    HTTP_SERVER --> POD_MANAGER
    GRPC_SERVER --> STREAMING_SERVER
    
    POD_MANAGER --> POD_WORKERS
    POD_WORKERS --> STATUS_MANAGER
    STATUS_MANAGER --> PROBE_MANAGER
    
    POD_WORKERS --> CRI_CLIENT
    CRI_CLIENT --> RUNTIME_SERVICE
    CRI_CLIENT --> IMAGE_SERVICE
    
    POD_MANAGER --> VOLUME_MANAGER
    VOLUME_MANAGER --> CSI_DRIVER
    CSI_DRIVER --> MOUNT_MANAGER
    
    POD_MANAGER --> CNI_MANAGER
    CNI_MANAGER --> NETWORK_PLUGIN
    NETWORK_PLUGIN --> PORT_FORWARD
    
    POD_WORKERS --> CGROUP_MANAGER
    CGROUP_MANAGER --> RESOURCE_ANALYZER
    RESOURCE_ANALYZER --> QOS_MANAGER
    
    STATUS_MANAGER --> CADVISOR
    CADVISOR --> LOG_MANAGER
    LOG_MANAGER --> EVENTS
    
    HTTP_SERVER --> API_SERVER
    CRI_CLIENT --> CONTAINER_RUNTIME
    CNI_MANAGER --> CNI_PLUGINS
    CSI_DRIVER --> CSI_PLUGINS
```

## Pod 生命周期管理

### 1. Pod 同步流程

```mermaid
sequenceDiagram
    participant API as API Server
    participant KUBELET as kubelet
    participant POD_MGR as Pod Manager
    participant WORKER as Pod Worker
    participant CRI as Container Runtime
    participant CNI as CNI Plugin

    API->>KUBELET: Pod 规格同步
    KUBELET->>POD_MGR: 更新 Pod 列表
    POD_MGR->>WORKER: 创建 Pod Worker
    
    WORKER->>WORKER: 验证 Pod 规格
    WORKER->>CNI: 设置 Pod 网络
    CNI->>WORKER: 网络配置完成
    
    WORKER->>CRI: 创建 Pod 沙箱
    CRI->>WORKER: 沙箱创建成功
    
    loop 每个容器
        WORKER->>CRI: 拉取镜像
        CRI->>WORKER: 镜像拉取完成
        WORKER->>CRI: 创建容器
        CRI->>WORKER: 容器创建成功
        WORKER->>CRI: 启动容器
        CRI->>WORKER: 容器启动成功
    end
    
    WORKER->>KUBELET: 更新 Pod 状态
    KUBELET->>API: 报告 Pod 状态
```

### 2. Pod 状态机

```mermaid
stateDiagram-v2
    [*] --> Pending
    Pending --> Running : 容器启动成功
    Pending --> Failed : 启动失败
    Running --> Succeeded : 正常完成
    Running --> Failed : 异常终止
    Running --> Unknown : 节点失联
    Failed --> [*]
    Succeeded --> [*]
    Unknown --> Running : 节点恢复
    Unknown --> Failed : 确认失败
    
    note right of Pending
        镜像拉取
        卷挂载
        网络配置
    end note
    
    note right of Running
        健康检查
        资源监控
        日志收集
    end note
```

## 容器运行时接口 (CRI)

### 1. CRI 架构

```mermaid
graph TB
    subgraph "CRI 接口层"
        subgraph "kubelet CRI 客户端"
            RUNTIME_CLIENT[Runtime Client]
            IMAGE_CLIENT[Image Client]
        end
        
        subgraph "CRI 实现"
            CRI_RUNTIME[CRI Runtime]
            subgraph "Runtime 实现"
                CONTAINERD[containerd]
                CRI_O[CRI-O]
                DOCKER[Docker (deprecated)]
            end
        end
        
        subgraph "底层容器引擎"
            OCI_RUNTIME[OCI Runtime]
            RUNC[runc]
            KATA[Kata Containers]
        end
    end
    
    RUNTIME_CLIENT --> CRI_RUNTIME
    IMAGE_CLIENT --> CRI_RUNTIME
    
    CRI_RUNTIME --> CONTAINERD
    CRI_RUNTIME --> CRI_O
    CRI_RUNTIME --> DOCKER
    
    CONTAINERD --> OCI_RUNTIME
    CRI_O --> OCI_RUNTIME
    
    OCI_RUNTIME --> RUNC
    OCI_RUNTIME --> KATA
```

### 2. CRI 服务接口

#### Runtime Service
```protobuf
service RuntimeService {
    // Pod 沙箱管理
    rpc RunPodSandbox(RunPodSandboxRequest) returns (RunPodSandboxResponse);
    rpc StopPodSandbox(StopPodSandboxRequest) returns (StopPodSandboxResponse);
    rpc RemovePodSandbox(RemovePodSandboxRequest) returns (RemovePodSandboxResponse);
    rpc PodSandboxStatus(PodSandboxStatusRequest) returns (PodSandboxStatusResponse);
    rpc ListPodSandbox(ListPodSandboxRequest) returns (ListPodSandboxResponse);
    
    // 容器管理
    rpc CreateContainer(CreateContainerRequest) returns (CreateContainerResponse);
    rpc StartContainer(StartContainerRequest) returns (StartContainerResponse);
    rpc StopContainer(StopContainerRequest) returns (StopContainerResponse);
    rpc RemoveContainer(RemoveContainerRequest) returns (RemoveContainerResponse);
    rpc ListContainers(ListContainersRequest) returns (ListContainersResponse);
    rpc ContainerStatus(ContainerStatusRequest) returns (ContainerStatusResponse);
    
    // 执行命令
    rpc ExecSync(ExecSyncRequest) returns (ExecSyncResponse);
    rpc Exec(ExecRequest) returns (ExecResponse);
    rpc Attach(AttachRequest) returns (AttachResponse);
    rpc PortForward(PortForwardRequest) returns (PortForwardResponse);
}
```

#### Image Service
```protobuf
service ImageService {
    // 镜像管理
    rpc ListImages(ListImagesRequest) returns (ListImagesResponse);
    rpc ImageStatus(ImageStatusRequest) returns (ImageStatusResponse);
    rpc PullImage(PullImageRequest) returns (PullImageResponse);
    rpc RemoveImage(RemoveImageRequest) returns (RemoveImageResponse);
    rpc ImageFsInfo(ImageFsInfoRequest) returns (ImageFsInfoResponse);
}
```

## 存储管理

### 1. Volume 管理架构

```mermaid
graph TB
    subgraph "Volume 管理系统"
        subgraph "Volume Manager"
            DESIRED_STATE[期望状态]
            ACTUAL_STATE[实际状态]
            RECONCILER[协调器]
        end
        
        subgraph "Volume 插件"
            IN_TREE[In-tree 插件]
            FLEXVOLUME[FlexVolume]
            CSI_PLUGIN[CSI 插件]
        end
        
        subgraph "挂载管理"
            MOUNT_UTILS[挂载工具]
            DEVICE_MANAGER[设备管理器]
            FILESYSTEM[文件系统]
        end
        
        subgraph "存储后端"
            LOCAL_STORAGE[本地存储]
            NETWORK_STORAGE[网络存储]
            CLOUD_STORAGE[云存储]
        end
    end
    
    DESIRED_STATE --> RECONCILER
    ACTUAL_STATE --> RECONCILER
    
    RECONCILER --> IN_TREE
    RECONCILER --> FLEXVOLUME
    RECONCILER --> CSI_PLUGIN
    
    IN_TREE --> MOUNT_UTILS
    FLEXVOLUME --> MOUNT_UTILS
    CSI_PLUGIN --> MOUNT_UTILS
    
    MOUNT_UTILS --> DEVICE_MANAGER
    DEVICE_MANAGER --> FILESYSTEM
    
    FILESYSTEM --> LOCAL_STORAGE
    FILESYSTEM --> NETWORK_STORAGE
    FILESYSTEM --> CLOUD_STORAGE
```

### 2. CSI 集成

```mermaid
sequenceDiagram
    participant KUBELET as kubelet
    participant CSI_NODE as CSI Node Driver
    participant CSI_CTRL as CSI Controller
    participant STORAGE as Storage Backend

    Note over KUBELET, STORAGE: Volume 挂载流程
    
    KUBELET->>CSI_NODE: NodeStageVolume
    CSI_NODE->>STORAGE: 准备存储设备
    STORAGE->>CSI_NODE: 设备就绪
    CSI_NODE->>KUBELET: 暂存完成
    
    KUBELET->>CSI_NODE: NodePublishVolume
    CSI_NODE->>CSI_NODE: 挂载到 Pod 目录
    CSI_NODE->>KUBELET: 发布完成
    
    Note over KUBELET: Pod 使用 Volume
    
    KUBELET->>CSI_NODE: NodeUnpublishVolume
    CSI_NODE->>KUBELET: 取消发布完成
    
    KUBELET->>CSI_NODE: NodeUnstageVolume
    CSI_NODE->>STORAGE: 释放存储设备
    STORAGE->>CSI_NODE: 释放完成
    CSI_NODE->>KUBELET: 取消暂存完成
```

## 网络管理

### 1. CNI 集成架构

```mermaid
graph TB
    subgraph "CNI 网络管理"
        subgraph "kubelet 网络层"
            NETWORK_PLUGIN[Network Plugin]
            CNI_MANAGER[CNI Manager]
        end
        
        subgraph "CNI 插件"
            MAIN_PLUGIN[主插件]
            CHAINED_PLUGINS[链式插件]
            IPAM_PLUGIN[IPAM 插件]
        end
        
        subgraph "网络配置"
            CNI_CONFIG[CNI 配置]
            NETWORK_CONFIG[网络配置]
            RUNTIME_CONFIG[运行时配置]
        end
        
        subgraph "网络实现"
            BRIDGE[Bridge]
            VLAN[VLAN]
            OVERLAY[Overlay]
            ROUTED[Routed]
        end
    end
    
    NETWORK_PLUGIN --> CNI_MANAGER
    CNI_MANAGER --> MAIN_PLUGIN
    MAIN_PLUGIN --> CHAINED_PLUGINS
    CHAINED_PLUGINS --> IPAM_PLUGIN
    
    CNI_MANAGER --> CNI_CONFIG
    CNI_CONFIG --> NETWORK_CONFIG
    NETWORK_CONFIG --> RUNTIME_CONFIG
    
    MAIN_PLUGIN --> BRIDGE
    MAIN_PLUGIN --> VLAN
    MAIN_PLUGIN --> OVERLAY
    MAIN_PLUGIN --> ROUTED
```

### 2. Pod 网络设置流程

```bash
# CNI 调用示例
{
  "cniVersion": "1.0.0",
  "name": "my-network",
  "type": "bridge",
  "bridge": "cni0",
  "isDefaultGateway": true,
  "ipMasq": true,
  "hairpinMode": true,
  "ipam": {
    "type": "host-local",
    "subnet": "10.244.0.0/16",
    "gateway": "10.244.0.1"
  }
}
```

## 资源管理

### 1. cgroup 管理

```mermaid
graph TB
    subgraph "cgroup 管理体系"
        subgraph "cgroup 层次"
            ROOT_CGROUP[根 cgroup]
            KUBEPODS[kubepods]
            QOS_CLASSES[QoS 类别]
            POD_CGROUPS[Pod cgroups]
            CONTAINER_CGROUPS[容器 cgroups]
        end
        
        subgraph "资源控制器"
            CPU_CONTROLLER[CPU 控制器]
            MEMORY_CONTROLLER[内存控制器]
            BLKIO_CONTROLLER[块 I/O 控制器]
            PIDS_CONTROLLER[进程数控制器]
        end
        
        subgraph "QoS 分类"
            GUARANTEED[Guaranteed]
            BURSTABLE[Burstable]
            BESTEFFORT[BestEffort]
        end
    end
    
    ROOT_CGROUP --> KUBEPODS
    KUBEPODS --> QOS_CLASSES
    QOS_CLASSES --> POD_CGROUPS
    POD_CGROUPS --> CONTAINER_CGROUPS
    
    QOS_CLASSES --> GUARANTEED
    QOS_CLASSES --> BURSTABLE
    QOS_CLASSES --> BESTEFFORT
    
    CONTAINER_CGROUPS --> CPU_CONTROLLER
    CONTAINER_CGROUPS --> MEMORY_CONTROLLER
    CONTAINER_CGROUPS --> BLKIO_CONTROLLER
    CONTAINER_CGROUPS --> PIDS_CONTROLLER
```

### 2. QoS 管理策略

```yaml
# Guaranteed QoS
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    resources:
      requests:
        cpu: "1000m"
        memory: "1Gi"
      limits:
        cpu: "1000m"    # requests == limits
        memory: "1Gi"   # requests == limits

---
# Burstable QoS
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    resources:
      requests:
        cpu: "500m"
        memory: "512Mi"
      limits:
        cpu: "1000m"    # limits > requests
        memory: "1Gi"   # limits > requests

---
# BestEffort QoS
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    # 没有 resources 配置
```

## 健康检查

### 1. 探针类型

```mermaid
graph TB
    subgraph "健康检查探针"
        subgraph "探针类型"
            LIVENESS[存活探针]
            READINESS[就绪探针]
            STARTUP[启动探针]
        end
        
        subgraph "检查方式"
            HTTP_GET[HTTP GET]
            TCP_SOCKET[TCP Socket]
            EXEC_COMMAND[执行命令]
            GRPC[gRPC]
        end
        
        subgraph "检查结果"
            SUCCESS[成功]
            FAILURE[失败]
            UNKNOWN[未知]
        end
        
        subgraph "处理动作"
            RESTART[重启容器]
            REMOVE_ENDPOINT[移除端点]
            DELAY_CHECK[延迟检查]
        end
    end
    
    LIVENESS --> HTTP_GET
    READINESS --> HTTP_GET
    STARTUP --> HTTP_GET
    
    LIVENESS --> TCP_SOCKET
    READINESS --> TCP_SOCKET
    STARTUP --> TCP_SOCKET
    
    LIVENESS --> EXEC_COMMAND
    READINESS --> EXEC_COMMAND
    STARTUP --> EXEC_COMMAND
    
    HTTP_GET --> SUCCESS
    HTTP_GET --> FAILURE
    HTTP_GET --> UNKNOWN
    
    SUCCESS --> REMOVE_ENDPOINT
    FAILURE --> RESTART
    UNKNOWN --> DELAY_CHECK
```

### 2. 探针配置示例

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: nginx
    ports:
    - containerPort: 80
    
    # 启动探针
    startupProbe:
      httpGet:
        path: /health
        port: 80
      initialDelaySeconds: 10    # 初始延迟
      periodSeconds: 10          # 检查间隔
      timeoutSeconds: 5          # 超时时间
      failureThreshold: 30       # 失败阈值
      successThreshold: 1        # 成功阈值
    
    # 存活探针
    livenessProbe:
      httpGet:
        path: /health
        port: 80
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
      successThreshold: 1
    
    # 就绪探针
    readinessProbe:
      httpGet:
        path: /ready
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3
      successThreshold: 1
```

## 节点状态管理

### 1. 节点状态报告

```mermaid
sequenceDiagram
    participant KUBELET as kubelet
    participant CADVISOR as cAdvisor
    participant API as API Server
    participant CONTROLLER as Node Controller

    loop 定期状态更新
        KUBELET->>CADVISOR: 获取资源使用情况
        CADVISOR->>KUBELET: 返回监控数据
        
        KUBELET->>KUBELET: 更新节点状态
        KUBELET->>API: 上报节点状态
        API->>CONTROLLER: 通知状态变更
        
        CONTROLLER->>CONTROLLER: 检查节点健康
        
        alt 节点健康
            CONTROLLER->>API: 更新 Ready 条件
        else 节点不健康
            CONTROLLER->>API: 更新 NotReady 条件
            CONTROLLER->>API: 添加污点
        end
    end
```

### 2. 节点状态结构

```yaml
# 节点状态示例
apiVersion: v1
kind: Node
status:
  conditions:
  - type: Ready
    status: "True"
    lastHeartbeatTime: "2023-01-01T12:00:00Z"
    lastTransitionTime: "2023-01-01T11:00:00Z"
    reason: KubeletReady
    message: kubelet is posting ready status
  - type: OutOfDisk
    status: "False"
    lastHeartbeatTime: "2023-01-01T12:00:00Z"
    lastTransitionTime: "2023-01-01T11:00:00Z"
    reason: KubeletHasSufficientDisk
    message: kubelet has sufficient disk space available
  - type: MemoryPressure
    status: "False"
    lastHeartbeatTime: "2023-01-01T12:00:00Z"
    lastTransitionTime: "2023-01-01T11:00:00Z"
    reason: KubeletHasSufficientMemory
    message: kubelet has sufficient memory available
  - type: DiskPressure
    status: "False"
    lastHeartbeatTime: "2023-01-01T12:00:00Z"
    lastTransitionTime: "2023-01-01T11:00:00Z"
    reason: KubeletHasNoDiskPressure
    message: kubelet has no disk pressure
  - type: PIDPressure
    status: "False"
    lastHeartbeatTime: "2023-01-01T12:00:00Z"
    lastTransitionTime: "2023-01-01T11:00:00Z"
    reason: KubeletHasSufficientPID
    message: kubelet has sufficient PID available
  capacity:
    cpu: "4"
    ephemeral-storage: "100Gi"
    hugepages-1Gi: "0"
    hugepages-2Mi: "0"
    memory: "8Gi"
    pods: "110"
  allocatable:
    cpu: "3800m"
    ephemeral-storage: "92Gi"
    hugepages-1Gi: "0"
    hugepages-2Mi: "0"
    memory: "7.5Gi"
    pods: "110"
```

## 性能优化

### 1. kubelet 配置优化

```yaml
# kubelet 配置文件
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
address: 0.0.0.0
port: 10250
readOnlyPort: 10255
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
clusterDomain: cluster.local
clusterDNS:
- 10.96.0.10
runtimeRequestTimeout: 15m
hairpinMode: hairpin-veth
maxPods: 110
podCIDR: 10.244.0.0/24
resolvConf: /etc/resolv.conf
rotateCertificates: true
serverTLSBootstrap: true
staticPodPath: /etc/kubernetes/manifests
syncFrequency: 1m
fileCheckFrequency: 20s
httpCheckFrequency: 20s
nodeStatusUpdateFrequency: 10s
nodeStatusReportFrequency: 1m
imageMinimumGCAge: 2m
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
volumeStatsAggPeriod: 1m
kubeletCgroups: /systemd/system.slice
systemCgroups: /systemd/system.slice
cgroupRoot: /
cgroupsPerQOS: true
cgroupDriver: systemd
runtimeRequestTimeout: 2m
serializeImagePulls: false
maxParallelImagePulls: 5
```

### 2. 资源限制和预留

```yaml
# 节点资源配置
kind: KubeletConfiguration
systemReserved:
  cpu: 500m
  memory: 1Gi
  ephemeral-storage: 10Gi
kubeReserved:
  cpu: 500m
  memory: 1Gi
  ephemeral-storage: 10Gi
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"
evictionSoft:
  memory.available: "200Mi"
  nodefs.available: "15%"
  nodefs.inodesFree: "10%"
  imagefs.available: "20%"
evictionSoftGracePeriod:
  memory.available: "1m30s"
  nodefs.available: "1m30s"
  nodefs.inodesFree: "1m30s"
  imagefs.available: "1m30s"
```

## 故障排除

### 1. 常见问题诊断

```bash
# 检查 kubelet 状态
systemctl status kubelet

# 查看 kubelet 日志
journalctl -u kubelet -f

# 检查 kubelet 配置
kubelet --help
cat /var/lib/kubelet/config.yaml

# 查看节点状态
kubectl describe node <node-name>

# 检查 Pod 状态
kubectl get pods -o wide
kubectl describe pod <pod-name>
```

### 2. 性能问题排查

```bash
# 查看资源使用情况
kubectl top node
kubectl top pod --all-namespaces

# 检查 cgroup 限制
cat /sys/fs/cgroup/memory/kubepods/memory.limit_in_bytes
cat /sys/fs/cgroup/cpu/kubepods/cpu.cfs_quota_us

# 分析容器运行时
crictl ps
crictl logs <container-id>
crictl stats

# 网络诊断
ip addr show
iptables -L -n
```

## 最佳实践

### 1. kubelet 部署配置

```yaml
# systemd 服务配置
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 2. 监控和告警

```yaml
# kubelet 监控指标
kubelet_running_pods: 运行中的 Pod 数量
kubelet_running_containers: 运行中的容器数量
kubelet_volume_stats_capacity_bytes: 卷容量
kubelet_volume_stats_available_bytes: 卷可用空间
kubelet_node_config_error: 节点配置错误
kubelet_pleg_relist_duration_seconds: PLEG 重新列举耗时
kubelet_pod_start_duration_seconds: Pod 启动耗时
```

### 3. 安全加固

```yaml
# 安全配置
authentication:
  webhook:
    enabled: true
    cacheTTL: 0s
authorization:
  mode: Webhook
tlsCertFile: /var/lib/kubelet/pki/kubelet.crt
tlsPrivateKeyFile: /var/lib/kubelet/pki/kubelet.key
tlsCipherSuites:
- TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305
- TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
- TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
- TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
- TLS_RSA_WITH_AES_256_GCM_SHA384
- TLS_RSA_WITH_AES_128_GCM_SHA256
