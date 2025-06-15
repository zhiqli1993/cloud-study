# StorageClass 资源详解

## 概述

StorageClass 为管理员提供了一种描述存储"类"的方法。不同的类可能会映射到不同的服务质量等级、备份策略或由集群管理员确定的其他策略。StorageClass 是动态卷供应的基础。

## 核心特性

### 1. 动态供应
- 自动创建 PersistentVolume
- 根据需求动态分配存储
- 简化存储管理流程

### 2. 存储抽象
- 定义存储的"类别"
- 封装存储提供商的差异
- 统一的存储接口

### 3. 策略配置
- 供应商参数配置
- 回收策略定义
- 卷绑定模式控制

## StorageClass 配置详解

### 基础配置示例

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  labels:
    performance: high
    type: ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"  # 设为默认存储类
provisioner: kubernetes.io/aws-ebs    # 存储供应商
parameters:                           # 供应商特定参数
  type: gp3                          # EBS 卷类型
  iops: "3000"                       # IOPS 配置
  throughput: "125"                  # 吞吐量 (MiB/s)
  encrypted: "true"                  # 启用加密
  fsType: ext4                       # 文件系统类型
reclaimPolicy: Delete                # 回收策略
allowVolumeExpansion: true           # 允许卷扩容
volumeBindingMode: WaitForFirstConsumer  # 卷绑定模式
mountOptions:                        # 挂载选项
- debug
- rsize=1048576
```

### 配置项详解

#### metadata 字段
```yaml
metadata:
  name: high-performance-ssd         # StorageClass 名称
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"  # 默认存储类
    description: "High performance SSD storage for databases"
  labels:
    tier: premium                    # 存储层级
    encryption: enabled              # 加密状态
    backup: daily                    # 备份策略
```

#### provisioner 字段
```yaml
# 内置供应商
provisioner: kubernetes.io/aws-ebs           # AWS EBS
provisioner: kubernetes.io/gce-pd            # Google Cloud PD
provisioner: kubernetes.io/azure-disk        # Azure Disk
provisioner: kubernetes.io/cinder            # OpenStack Cinder
provisioner: kubernetes.io/vsphere-volume    # vSphere
provisioner: kubernetes.io/no-provisioner    # 静态供应

# CSI 供应商
provisioner: ebs.csi.aws.com                 # AWS EBS CSI
provisioner: pd.csi.storage.gke.io           # GKE CSI
provisioner: disk.csi.azure.com              # Azure CSI
provisioner: rook-ceph.rbd.csi.ceph.com      # Ceph RBD CSI
```

#### volumeBindingMode 字段
```yaml
# 立即绑定（默认）
volumeBindingMode: Immediate

# 等待第一个消费者（推荐用于多可用区）
volumeBindingMode: WaitForFirstConsumer
```

#### reclaimPolicy 字段
```yaml
# 删除策略（默认）
reclaimPolicy: Delete

# 保留策略
reclaimPolicy: Retain
```

## 不同云提供商的配置

### 1. AWS EBS StorageClass

```yaml
# GP3 高性能存储
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

---
# IO2 超高性能存储
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-io2
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "10000"
  encrypted: "true"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

---
# SC1 冷存储
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-sc1
provisioner: ebs.csi.aws.com
parameters:
  type: sc1
  encrypted: "true"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### 2. Google Cloud PD StorageClass

```yaml
# SSD 持久磁盘
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gce-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd     # 区域性持久磁盘
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

---
# 标准持久磁盘
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gce-standard
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-standard
  replication-type: none
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### 3. Azure Disk StorageClass

```yaml
# Premium SSD
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-premium
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  cachingmode: ReadOnly
  diskEncryptionSetID: /subscriptions/.../diskEncryptionSets/myDES
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

---
# Standard HDD
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-standard
provisioner: disk.csi.azure.com
parameters:
  skuName: Standard_LRS
  cachingmode: None
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### 4. 本地存储 StorageClass

```yaml
# Local Path Provisioner
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
parameters:
  nodePath: /opt/local-path-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete

---
# HostPath
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hostpath
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

## CSI 存储配置

### 1. Ceph RBD StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-rbd
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: replicapool
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
allowVolumeExpansion: true
reclaimPolicy: Delete
```

### 2. CephFS StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-filesystem
provisioner: rook-ceph.cephfs.csi.ceph.com
parameters:
  clusterID: rook-ceph
  fsName: myfs
  pool: myfs-data0
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-cephfs-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
allowVolumeExpansion: true
reclaimPolicy: Delete
```

### 3. NFS StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /exported/path
  subDir: k8s-volumes
mountOptions:
- nfsvers=4.1
- proto=tcp
- timeo=600
volumeBindingMode: Immediate
allowVolumeExpansion: false
reclaimPolicy: Delete
```

## 性能调优配置

### 1. 高性能数据库存储

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: database-storage
  labels:
    performance: ultra-high
    purpose: database
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "20000"                   # 超高 IOPS
  encrypted: "true"
  fsType: xfs                     # XFS 文件系统
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
mountOptions:
- noatime                         # 提高性能
- largeio
- inode64
```

### 2. 大数据存储

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: bigdata-storage
  labels:
    purpose: analytics
    tier: standard
provisioner: ebs.csi.aws.com
parameters:
  type: st1                       # 吞吐量优化
  encrypted: "true"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
mountOptions:
- noatime
- rsize=1048576                   # 大读取块
- wsize=1048576                   # 大写入块
```

### 3. 归档存储

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: archive-storage
  labels:
    tier: cold
    purpose: backup
provisioner: ebs.csi.aws.com
parameters:
  type: sc1                       # 冷存储
  encrypted: "true"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain             # 保留数据
```

## 拓扑感知配置

### 1. 可用区感知

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: zone-aware-storage
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer  # 关键：等待调度
allowedTopologies:
- matchLabelExpressions:
  - key: topology.ebs.csi.aws.com/zone
    values:
    - us-west-2a
    - us-west-2b
    - us-west-2c
```

### 2. 节点类型感知

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: compute-optimized-storage
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
volumeBindingMode: WaitForFirstConsumer
allowedTopologies:
- matchLabelExpressions:
  - key: node.kubernetes.io/instance-type
    values:
    - c5.large
    - c5.xlarge
    - c5.2xlarge
```

## 安全配置

### 1. 加密存储

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: encrypted-storage
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  kmsKeyId: arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### 2. 访问控制

```yaml
# RBAC 配置
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: storage-admin
rules:
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: storage-admin-binding
subjects:
- kind: ServiceAccount
  name: storage-admin
roleRef:
  kind: Role
  name: storage-admin
  apiGroup: rbac.authorization.k8s.io
```

## 监控和管理

### 1. 查看 StorageClass

```bash
# 列出所有 StorageClass
kubectl get storageclass
kubectl get sc                   # 简写

# 查看详细信息
kubectl describe storageclass fast-ssd

# 查看默认 StorageClass
kubectl get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
```

### 2. 设置默认 StorageClass

```bash
# 取消当前默认 StorageClass
kubectl patch storageclass <current-default> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# 设置新的默认 StorageClass
kubectl patch storageclass <new-default> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 3. 故障排除

```bash
# 检查 PVC 绑定问题
kubectl describe pvc <pvc-name>

# 查看存储相关事件
kubectl get events --field-selector reason=VolumeBinding

# 检查 CSI 驱动
kubectl get csidriver
kubectl get csinodes
```

## 最佳实践

### 1. 命名规范

```yaml
metadata:
  name: provider-type-performance  # 提供商-类型-性能
  # 例如：aws-ssd-high, gcp-pd-standard, azure-premium
```

### 2. 标签策略

```yaml
metadata:
  labels:
    provider: aws                 # 云提供商
    type: ssd                     # 存储类型
    performance: high             # 性能等级
    tier: premium                 # 存储层级
    encryption: enabled           # 加密状态
    backup: daily                 # 备份策略
```

### 3. 分层存储策略

```yaml
# 高性能层
high-performance:
  iops: 10000+
  throughput: 500MB/s+
  use-cases: [database, cache]

# 标准层
standard:
  iops: 3000
  throughput: 125MB/s
  use-cases: [web-apps, general]

# 经济层
economy:
  iops: 100-3000
  throughput: 40-250MB/s
  use-cases: [backup, archive]
```

### 4. 多环境配置

```yaml
# 开发环境
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: dev-storage
  labels:
    environment: development
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-standard
  replication-type: none
reclaimPolicy: Delete

# 生产环境
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: prod-storage
  labels:
    environment: production
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  replication-type: regional-pd
reclaimPolicy: Retain             # 生产数据保留
```

### 5. 成本优化

```yaml
# 根据工作负载选择合适的存储类型
cost-optimization:
  frequent-access: gp3/pd-ssd      # 频繁访问
  moderate-access: gp2/pd-standard # 中等访问
  infrequent-access: sc1/pd-standard # 不频繁访问
  backup-archive: glacier/coldline  # 备份归档
```