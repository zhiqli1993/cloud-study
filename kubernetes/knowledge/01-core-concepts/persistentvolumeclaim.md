# PersistentVolumeClaim 资源详解

## 概述

PersistentVolumeClaim (PVC) 是用户对存储的请求，类似于 Pod 对计算资源的请求。PVC 消耗 PersistentVolume 资源，可以请求特定的大小和访问模式。

## 核心特性

### 1. 存储请求
- 声明存储需求
- 指定容量和访问模式
- 自动绑定到合适的 PV

### 2. 命名空间级资源
- 属于特定命名空间
- 可被同命名空间的 Pod 使用
- 支持资源配额控制

### 3. 动态供应
- 自动创建 PV
- 基于 StorageClass
- 简化存储管理

## PVC 配置详解

### 基础配置示例

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
  namespace: default
  labels:
    app: myapp
    component: database
spec:
  accessModes:                  # 访问模式
  - ReadWriteOnce               # 必须与 PV 匹配
  resources:                    # 资源请求
    requests:
      storage: 10Gi             # 存储容量请求
  storageClassName: fast-ssd    # 存储类名
  selector:                     # 可选：PV 选择器
    matchLabels:
      environment: production
    matchExpressions:
    - key: type
      operator: In
      values: ["ssd", "nvme"]
  volumeMode: Filesystem        # 卷模式
  dataSource:                   # 可选：数据源
    name: source-pvc            # 克隆源
    kind: PersistentVolumeClaim
```

### 访问模式配置

```yaml
spec:
  accessModes:
  # 单节点读写（最常用）
  - ReadWriteOnce
  
  # 多节点只读
  # - ReadOnlyMany
  
  # 多节点读写
  # - ReadWriteMany
  
  # 单 Pod 读写（Kubernetes 1.22+）
  # - ReadWriteOncePod
```

### 存储类配置

```yaml
# 1. 使用特定存储类
spec:
  storageClassName: fast-ssd

# 2. 使用默认存储类
spec:
  storageClassName: ""          # 空字符串表示默认

# 3. 静态绑定（不使用存储类）
spec:
  storageClassName: manual      # 或者完全省略此字段
```

## 不同场景的 PVC 配置

### 1. 数据库存储

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  labels:
    app: mysql
    tier: database
spec:
  accessModes:
  - ReadWriteOnce               # 数据库通常是单节点
  resources:
    requests:
      storage: 50Gi
  storageClassName: high-iops   # 高性能存储
```

### 2. 共享文件存储

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-files-pvc
  labels:
    app: fileserver
    type: shared
spec:
  accessModes:
  - ReadWriteMany               # 多 Pod 共享
  resources:
    requests:
      storage: 100Gi
  storageClassName: nfs         # NFS 存储类
```

### 3. 日志存储

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-logs-pvc
  labels:
    app: myapp
    component: logging
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: standard    # 标准性能即可
```

### 4. 缓存存储

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cache-pvc
  labels:
    app: redis
    component: cache
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: fast-ssd    # 快速存储
```

## 选择器配置

### 1. 标签选择器

```yaml
spec:
  selector:
    matchLabels:
      environment: production
      type: ssd
      zone: us-west-1a
```

### 2. 表达式选择器

```yaml
spec:
  selector:
    matchExpressions:
    - key: performance
      operator: In
      values: ["high", "ultra"]
    - key: encryption
      operator: Exists
    - key: legacy
      operator: DoesNotExist
```

## 数据源配置

### 1. 从现有 PVC 克隆

```yaml
spec:
  dataSource:
    name: source-pvc
    kind: PersistentVolumeClaim
  resources:
    requests:
      storage: 20Gi             # 可以大于等于源 PVC
```

### 2. 从快照恢复

```yaml
spec:
  dataSource:
    name: pvc-snapshot-20231201
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  resources:
    requests:
      storage: 15Gi
```

### 3. 从预填充数据源

```yaml
spec:
  dataSourceRef:
    name: popular-dataset
    kind: VolumePopulator
    apiGroup: populator.storage.k8s.io
  resources:
    requests:
      storage: 5Gi
```

## PVC 生命周期管理

### 1. 创建和绑定

```bash
# 创建 PVC
kubectl apply -f pvc.yaml

# 查看 PVC 状态
kubectl get pvc

# 查看绑定详情
kubectl describe pvc app-data-pvc

# PVC 状态：
# Pending: 等待绑定
# Bound: 已绑定到 PV
# Lost: 关联的 PV 丢失
```

### 2. 使用 PVC

```yaml
# 在 Pod 中使用 PVC
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: app-storage
      mountPath: /app/data
  volumes:
  - name: app-storage
    persistentVolumeClaim:
      claimName: app-data-pvc    # 引用 PVC
```

### 3. 扩容 PVC

```yaml
# 修改 PVC 的存储请求（需要存储类支持扩容）
spec:
  resources:
    requests:
      storage: 30Gi             # 从 20Gi 扩容到 30Gi
```

### 4. 删除 PVC

```bash
# 删除 PVC
kubectl delete pvc app-data-pvc

# 注意：删除前确保没有 Pod 在使用
# PV 的回收策略决定数据是否保留
```

## 在不同工作负载中使用

### 1. Deployment 中使用

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 1                   # PVC RWO 只能单副本
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: nginx
        volumeMounts:
        - name: web-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: web-content
        persistentVolumeClaim:
          claimName: web-content-pvc
```

### 2. StatefulSet 中使用

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  replicas: 3
  serviceName: database
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:13
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:         # 每个副本自动创建 PVC
  - metadata:
      name: data
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 20Gi
      storageClassName: fast-ssd
```

### 3. Job 中使用

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing
spec:
  template:
    spec:
      containers:
      - name: processor
        image: data-processor:latest
        volumeMounts:
        - name: input-data
          mountPath: /input
          readOnly: true
        - name: output-data
          mountPath: /output
      volumes:
      - name: input-data
        persistentVolumeClaim:
          claimName: input-pvc
      - name: output-data
        persistentVolumeClaim:
          claimName: output-pvc
      restartPolicy: Never
```

## 监控和故障排除

### 1. 查看 PVC 状态

```bash
# 列出 PVC
kubectl get pvc

# 查看详细信息
kubectl describe pvc app-data-pvc

# 查看 PVC 和 PV 绑定关系
kubectl get pvc,pv
```

### 2. 常见问题排查

```bash
# 1. PVC 处于 Pending 状态
kubectl describe pvc pending-pvc
# 检查：
# - 是否有合适的 PV 可绑定
# - StorageClass 是否存在
# - 资源配额是否足够

# 2. 无法删除 PVC
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.volumes[*].persistentVolumeClaim.claimName}{"\n"}{end}' | grep pvc-name
# 检查是否有 Pod 仍在使用

# 3. 扩容失败
kubectl describe pvc expandable-pvc
# 检查：
# - StorageClass 是否支持扩容
# - 底层存储是否支持在线扩容
```

### 3. 事件监控

```bash
# 查看 PVC 相关事件
kubectl get events --field-selector involvedObject.kind=PersistentVolumeClaim

# 查看存储相关事件
kubectl get events --field-selector reason=VolumeBinding
```

## 性能优化

### 1. 存储类选择

```yaml
# 高性能工作负载
spec:
  storageClassName: high-iops-ssd

# 普通工作负载
spec:
  storageClassName: standard

# 归档数据
spec:
  storageClassName: cold-storage
```

### 2. 容量规划

```yaml
spec:
  resources:
    requests:
      storage: 100Gi            # 预留足够空间避免频繁扩容
```

### 3. 访问模式优化

```yaml
# 单实例应用
accessModes:
- ReadWriteOnce               # 性能最好

# 多实例只读
accessModes:
- ReadOnlyMany               # 避免写冲突

# 分布式应用
accessModes:
- ReadWriteMany              # 确保存储支持
```

## 最佳实践

### 1. 命名规范

```yaml
metadata:
  name: app-component-env-pvc   # 应用-组件-环境-pvc
  # 例如：mysql-data-prod-pvc
```

### 2. 标签管理

```yaml
metadata:
  labels:
    app: myapp                  # 应用名称
    component: database         # 组件
    environment: production     # 环境
    backup-policy: daily        # 备份策略
    performance: high           # 性能要求
```

### 3. 资源配额

```yaml
# 在命名空间中设置 PVC 配额
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
spec:
  hard:
    persistentvolumeclaims: "10"
    requests.storage: "100Gi"
```

### 4. 安全考虑

```yaml
# 使用专用的 ServiceAccount
spec:
  template:
    spec:
      serviceAccountName: storage-user
      securityContext:
        fsGroup: 2000           # 文件系统组
```

### 5. 备份策略

```yaml
# 定期创建快照
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: daily-backup-pvc
  labels:
    backup-schedule: daily
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: important-data-pvc
```