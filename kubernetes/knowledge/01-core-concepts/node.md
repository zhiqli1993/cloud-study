# Node 资源详解

## 概述

Node 是 Kubernetes 集群中的工作节点，代表集群中的一台物理机或虚拟机。每个 Node 运行着必要的服务来支持 Pod 运行，包括 kubelet、容器运行时和 kube-proxy。

## 核心特性

### 1. 工作负载承载
- 运行 Pod 和容器
- 提供计算、存储、网络资源
- 支持多种容器运行时

### 2. 集群组件
- kubelet 节点代理
- kube-proxy 网络代理
- 容器运行时 (containerd, CRI-O)

### 3. 资源管理
- CPU、内存、存储容量
- 可分配资源跟踪
- 资源预留和隔离

## Node 配置详解

### 节点状态信息

```yaml
apiVersion: v1
kind: Node
metadata:
  name: worker-node-1
  labels:
    kubernetes.io/hostname: worker-node-1
    kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    node-role.kubernetes.io/worker: ""
    zone: us-west-2a
    instance-type: m5.large
  annotations:
    node.alpha.kubernetes.io/ttl: "0"
    volumes.kubernetes.io/controller-managed-attach-detach: "true"
spec:
  podCIDR: 10.244.1.0/24          # Pod CIDR 范围
  podCIDRs:
  - 10.244.1.0/24
  providerID: aws:///us-west-2a/i-1234567890abcdef0
  taints:                         # 节点污点
  - effect: NoSchedule
    key: node.kubernetes.io/unschedulable
    timeAdded: "2023-12-01T10:00:00Z"
status:
  capacity:                       # 节点总容量
    cpu: "4"
    ephemeral-storage: 20Gi
    hugepages-1Gi: "0"
    hugepages-2Mi: "0"
    memory: 16Gi
    pods: "110"
  allocatable:                    # 可分配资源
    cpu: 3800m
    ephemeral-storage: 18Gi
    hugepages-1Gi: "0"
    hugepages-2Mi: "0"
    memory: 14Gi
    pods: "110"
  conditions:                     # 节点状态条件
  - lastHeartbeatTime: "2023-12-01T12:00:00Z"
    lastTransitionTime: "2023-12-01T10:00:00Z"
    message: kubelet has sufficient memory available
    reason: KubeletHasSufficientMemory
    status: "False"
    type: MemoryPressure
  - lastHeartbeatTime: "2023-12-01T12:00:00Z"
    lastTransitionTime: "2023-12-01T10:00:00Z"
    message: kubelet has no disk pressure
    reason: KubeletHasNoDiskPressure
    status: "False"
    type: DiskPressure
  - lastHeartbeatTime: "2023-12-01T12:00:00Z"
    lastTransitionTime: "2023-12-01T10:00:00Z"
    message: kubelet has sufficient PID available
    reason: KubeletHasSufficientPID
    status: "False"
    type: PIDPressure
  - lastHeartbeatTime: "2023-12-01T12:00:00Z"
    lastTransitionTime: "2023-12-01T10:00:00Z"
    message: kubelet is posting ready status
    reason: KubeletReady
    status: "True"
    type: Ready
  addresses:                      # 节点地址
  - address: 172.20.1.10
    type: InternalIP
  - address: 203.0.113.10
    type: ExternalIP
  - address: worker-node-1
    type: Hostname
  nodeInfo:                       # 节点系统信息
    architecture: amd64
    bootID: 12345678-1234-1234-1234-123456789012
    containerRuntimeVersion: containerd://1.6.8
    kernelVersion: 5.4.0-74-generic
    kubeProxyVersion: v1.28.0
    kubeletVersion: v1.28.0
    machineID: 12345678901234567890123456789012
    operatingSystem: linux
    osImage: Ubuntu 20.04.3 LTS
    systemUUID: 12345678-1234-1234-1234-123456789012
```

## 节点标签管理

### 1. 内置标签

```yaml
# 系统自动添加的标签
metadata:
  labels:
    kubernetes.io/hostname: worker-node-1
    kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    beta.kubernetes.io/instance-type: m5.large
    failure-domain.beta.kubernetes.io/zone: us-west-2a
    failure-domain.beta.kubernetes.io/region: us-west-2
    topology.kubernetes.io/zone: us-west-2a
    topology.kubernetes.io/region: us-west-2
    node.kubernetes.io/instance-type: m5.large
```

### 2. 自定义标签

```yaml
# 运维团队添加的标签
metadata:
  labels:
    environment: production
    team: backend
    workload-type: compute-intensive
    storage-type: ssd
    network-zone: dmz
    maintenance-window: weekend
    cost-center: engineering
    backup-policy: daily
```

### 3. 节点角色标签

```yaml
# 主节点标签
node-role.kubernetes.io/control-plane: ""
node-role.kubernetes.io/master: ""         # 已弃用

# 工作节点标签
node-role.kubernetes.io/worker: ""

# 边缘节点标签
node-role.kubernetes.io/edge: ""

# 特殊用途节点
node-role.kubernetes.io/ingress: ""
node-role.kubernetes.io/monitoring: ""
```

## 节点污点管理

### 1. 内置污点

```yaml
# 节点不可调度
taints:
- effect: NoSchedule
  key: node.kubernetes.io/unschedulable

# 节点未就绪
- effect: NoExecute
  key: node.kubernetes.io/not-ready
  tolerationSeconds: 300

# 节点无法访问
- effect: NoExecute
  key: node.kubernetes.io/unreachable
  tolerationSeconds: 300

# 内存压力
- effect: NoSchedule
  key: node.kubernetes.io/memory-pressure

# 磁盘压力
- effect: NoSchedule
  key: node.kubernetes.io/disk-pressure

# PID 压力
- effect: NoSchedule
  key: node.kubernetes.io/pid-pressure
```

### 2. 自定义污点

```yaml
# 专用节点污点
taints:
- effect: NoSchedule
  key: dedicated
  value: gpu-workload

# 维护窗口污点
- effect: NoExecute
  key: maintenance
  value: "true"

# 特殊硬件污点
- effect: NoSchedule
  key: hardware
  value: high-memory

# 网络区域污点
- effect: PreferNoSchedule
  key: network-zone
  value: restricted
```

## 节点资源管理

### 1. 资源容量

```bash
# 查看节点资源
kubectl describe node worker-node-1

# 查看资源使用情况
kubectl top node

# 查看节点分配的 Pod
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=worker-node-1
```

### 2. 资源预留

```yaml
# kubelet 配置 (通常在 /var/lib/kubelet/config.yaml)
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
systemReserved:                  # 系统预留
  cpu: 100m
  memory: 100Mi
  ephemeral-storage: 1Gi
kubeReserved:                    # Kubernetes 组件预留
  cpu: 100m
  memory: 100Mi
  ephemeral-storage: 1Gi
evictionHard:                    # 驱逐阈值
  memory.available: "100Mi"
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"
```

### 3. 资源限制

```yaml
# 通过 LimitRange 限制节点上的 Pod 资源
apiVersion: v1
kind: LimitRange
metadata:
  name: node-resource-limits
spec:
  limits:
  - default:
      cpu: 200m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
```

## 节点管理操作

### 1. 节点维护

```bash
# 标记节点不可调度
kubectl cordon worker-node-1

# 驱逐节点上的 Pod
kubectl drain worker-node-1 --ignore-daemonsets --delete-emptydir-data

# 恢复节点调度
kubectl uncordon worker-node-1
```

### 2. 节点标签管理

```bash
# 添加标签
kubectl label node worker-node-1 environment=production

# 删除标签
kubectl label node worker-node-1 environment-

# 修改标签
kubectl label node worker-node-1 environment=staging --overwrite
```

### 3. 节点污点管理

```bash
# 添加污点
kubectl taint node worker-node-1 key=value:NoSchedule

# 删除污点
kubectl taint node worker-node-1 key=value:NoSchedule-

# 修改污点
kubectl taint node worker-node-1 key=newvalue:NoSchedule --overwrite
```

## 节点监控

### 1. 节点状态监控

```bash
# 查看节点状态
kubectl get nodes
kubectl get nodes -o wide

# 查看节点详情
kubectl describe node worker-node-1

# 监控节点资源使用
kubectl top nodes
```

### 2. 节点指标收集

```yaml
# Node Exporter DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: node-exporter
        image: prom/node-exporter:latest
        args:
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --collector.filesystem.mount-points-exclude
        - "^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)"
        ports:
        - containerPort: 9100
          name: metrics
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /host/root
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /
      tolerations:
      - operator: Exists
```

## 节点故障排除

### 1. 常见问题

```bash
# 节点状态异常
kubectl describe node worker-node-1

# 检查节点组件
systemctl status kubelet
systemctl status docker  # 或 containerd

# 查看节点日志
journalctl -u kubelet -f
journalctl -u docker -f

# 检查网络连接
ping <master-ip>
telnet <master-ip> 6443
```

### 2. 资源压力处理

```bash
# 检查磁盘使用
df -h
du -sh /var/lib/docker
du -sh /var/lib/kubelet

# 清理容器和镜像
docker system prune -f
crictl rmi --prune

# 检查内存使用
free -h
top
kubectl top node worker-node-1
```

## 节点扩容和缩容

### 1. 手动扩容

```bash
# 准备新节点
# 1. 安装 kubelet, kubeadm, kubectl
# 2. 配置容器运行时
# 3. 获取 join token

# 在主节点生成 join 命令
kubeadm token create --print-join-command

# 在新节点执行 join
kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### 2. 自动扩容 (Cluster Autoscaler)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.21.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/my-cluster
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi
```

## 最佳实践

### 1. 节点标签策略

```yaml
# 标准化标签
metadata:
  labels:
    # 基础信息
    kubernetes.io/hostname: worker-node-1
    kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    
    # 环境信息
    environment: production
    cluster: main
    
    # 硬件信息
    instance-type: m5.large
    storage-type: ssd
    network-speed: 10gbps
    
    # 功能标签
    workload-type: general
    gpu: "false"
    spot-instance: "false"
    
    # 运维标签
    team: platform
    cost-center: engineering
    maintenance-window: weekend
```

### 2. 污点策略

```yaml
# 生产环境专用节点
taints:
- effect: NoSchedule
  key: environment
  value: production

# GPU 节点专用
- effect: NoSchedule
  key: nvidia.com/gpu
  value: "true"

# 高内存节点
- effect: PreferNoSchedule
  key: memory-optimized
  value: "true"
```

### 3. 资源规划

```yaml
# 节点容量规划考虑因素:
# 1. 系统预留: 10-20% CPU, 10-20% Memory
# 2. Kubernetes 组件预留: 2-4% CPU, 1-3% Memory  
# 3. 驱逐阈值: 10% 磁盘, 100Mi 内存
# 4. Pod 密度: 建议每节点不超过 100-110 个 Pod
```

### 4. 安全配置

```yaml
# kubelet 安全配置
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  webhook:
    enabled: true
  anonymous:
    enabled: false
authorization:
  mode: Webhook
readOnlyPort: 0
protectKernelDefaults: true
makeIPTablesUtilChains: true
```