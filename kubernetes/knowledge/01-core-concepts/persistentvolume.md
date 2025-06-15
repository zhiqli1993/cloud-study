# PersistentVolume 资源详解

## 概述

PersistentVolume (PV) 是集群级的存储资源，由管理员预先配置或通过 StorageClass 动态供应。PV 独立于 Pod 的生命周期，为集群提供持久化存储能力。

## 核心特性

### 1. 集群级资源
- 不属于任何命名空间
- 集群管理员管理
- 独立的生命周期

### 2. 存储抽象
- 屏蔽底层存储实现
- 统一的存储接口
- 支持多种存储类型

### 3. 动态和静态供应
- 静态：管理员预创建
- 动态：根据需求自动创建
- 灵活的存储管理

## PV 配置详解

### 基础配置示例

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-example
  labels:
    type: local
    environment: production
spec:
  capacity:
    storage: 10Gi               # 存储容量
  accessModes:                  # 访问模式
  - ReadWriteOnce               # RWO: 单节点读写
  # - ReadOnlyMany              # ROX: 多节点只读
  # - ReadWriteMany             # RWX: 多节点读写
  # - ReadWriteOncePod          # RWOP: 单 Pod 读写
  persistentVolumeReclaimPolicy: Retain  # 回收策略
  storageClassName: manual      # 存储类名
  volumeMode: Filesystem        # 卷模式：Filesystem 或 Block
  hostPath:                     # 存储类型：HostPath
    path: /data/pv
    type: DirectoryOrCreate
```

### 不同存储类型配置

#### 1. HostPath 存储

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hostpath-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: hostpath
  hostPath:
    path: /mnt/data
    type: DirectoryOrCreate
```

#### 2. NFS 存储

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
spec:
  capacity:
    storage: 20Gi
  accessModes:
  - ReadWriteMany               # NFS 支持多节点读写
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: nfs-server.example.com
    path: /exported/path
    readOnly: false
```

#### 3. AWS EBS 存储

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: aws-ebs-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: gp2
  awsElasticBlockStore:
    volumeID: vol-12345678
    fsType: ext4
```

#### 4. CSI 存储

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: csi-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: csi-rbd
  csi:
    driver: rbd.csi.ceph.com
    volumeHandle: 0001-0024-fed5480a-f3f9-4c27-9de0-2c6558a4c8b2-0000000000000001-7f4d9f7e-8e2b-4e8b-8e2b-4e8b8e2b4e8b
    fsType: ext4
    volumeAttributes:
      clusterID: "b8e3d9c5-c5b5-4c5e-9c5e-9c5e9c5e9c5e"
      pool: "rbd"
      staticVolume: "true"
    nodeStageSecretRef:
      name: csi-rbd-secret
      namespace: default
```

## 访问模式详解

### 1. ReadWriteOnce (RWO)
```yaml
# 单节点读写 - 最常用
accessModes:
- ReadWriteOnce

# 适用场景：
# - 数据库存储
# - 应用程序数据
# - 单实例应用
```

### 2. ReadOnlyMany (ROX)
```yaml
# 多节点只读
accessModes:
- ReadOnlyMany

# 适用场景：
# - 静态资源
# - 配置文件
# - 共享库文件
```

### 3. ReadWriteMany (RWX)
```yaml
# 多节点读写
accessModes:
- ReadWriteMany

# 适用场景：
# - 共享文件系统
# - 多实例应用共享数据
# - 分布式应用
```

### 4. ReadWriteOncePod (RWOP)
```yaml
# 单 Pod 读写（Kubernetes 1.22+）
accessModes:
- ReadWriteOncePod

# 适用场景：
# - 确保只有一个 Pod 访问
# - 高安全性要求
# - 防止数据竞争
```

## 回收策略

### 1. Retain（保留）
```yaml
persistentVolumeReclaimPolicy: Retain

# 特点：
# - PVC 删除后，PV 状态变为 Released
# - 数据保留，需要手动清理
# - 适用于重要数据
```

### 2. Delete（删除）
```yaml
persistentVolumeReclaimPolicy: Delete

# 特点：
# - PVC 删除后，PV 和底层存储都被删除
# - 数据无法恢复
# - 适用于临时数据
```

### 3. Recycle（回收）- 已弃用
```yaml
persistentVolumeReclaimPolicy: Recycle

# 注意：此策略已被弃用
# 建议使用动态供应和 Delete 策略
```

## PV 生命周期

### 1. 状态转换

```yaml
# Available: 可用，未绑定
# Bound: 已绑定到 PVC
# Released: PVC 已删除，但资源未回收
# Failed: 自动回收失败

# 查看 PV 状态
kubectl get pv
```

### 2. 绑定过程

```bash
# 1. 创建 PV
kubectl apply -f pv.yaml

# 2. 创建 PVC
kubectl apply -f pvc.yaml

# 3. 查看绑定状态
kubectl get pv,pvc

# 4. PV 自动绑定到匹配的 PVC
```

## 动态供应

### 1. StorageClass 配置

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### 2. PVC 请求动态供应

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 30Gi
  storageClassName: fast-ssd    # 指定 StorageClass
```

## 卷扩容

### 1. 启用扩容的 StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable-storage
provisioner: kubernetes.io/aws-ebs
allowVolumeExpansion: true      # 允许扩容
```

### 2. 扩容操作

```yaml
# 修改 PVC 的存储请求
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: expandable-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi             # 从 30Gi 扩容到 50Gi
  storageClassName: expandable-storage
```

## 卷快照

### 1. VolumeSnapshotClass

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-hostpath-snapclass
driver: hostpath.csi.k8s.io
deletionPolicy: Delete
```

### 2. 创建快照

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: pvc-snapshot
spec:
  volumeSnapshotClassName: csi-hostpath-snapclass
  source:
    persistentVolumeClaimName: source-pvc
```

### 3. 从快照恢复

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  dataSource:
    name: pvc-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

## 监控和管理

### 1. 查看 PV 状态

```bash
# 列出所有 PV
kubectl get pv

# 查看详细信息
kubectl describe pv pv-name

# 查看 PV 使用情况
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,ACCESS:.spec.accessModes,RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase,CLAIM:.spec.claimRef.name
```

### 2. 故障排除

```bash
# 检查 PV 和 PVC 绑定
kubectl get pv,pvc

# 查看事件
kubectl get events --field-selector involvedObject.kind=PersistentVolume

# 检查存储类
kubectl get storageclass

# 检查 CSI 驱动
kubectl get csinode
kubectl get csidriver
```

## 最佳实践

### 1. 命名规范

```yaml
metadata:
  name: app-env-purpose-001     # 应用-环境-用途-序号
  labels:
    app: myapp
    environment: production
    purpose: database
    type: ssd
```

### 2. 标签管理

```yaml
metadata:
  labels:
    storage-type: ssd           # 存储类型
    performance: high           # 性能等级
    backup: enabled             # 备份策略
    encryption: enabled         # 加密状态
```

### 3. 容量规划

```yaml
spec:
  capacity:
    storage: 100Gi              # 预留足够空间
  # 考虑：
  # - 数据增长趋势
  # - 备份空间需求
  # - 性能影响
```

### 4. 安全配置

```yaml
# 加密存储
parameters:
  encrypted: "true"

# 访问控制
metadata:
  annotations:
    pv.kubernetes.io/bound-by-controller: "yes"
```

### 5. 备份策略

```yaml
# 使用卷快照
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: backup-snapshot-$(date +%Y%m%d)
  labels:
    backup-policy: daily
spec:
  volumeSnapshotClassName: backup-snapclass
  source:
    persistentVolumeClaimName: important-data-pvc
```