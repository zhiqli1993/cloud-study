# StatefulSet 资源详解

## 概述

StatefulSet 是 Kubernetes 中用于管理有状态应用的工作负载控制器。与 Deployment 不同，StatefulSet 为每个 Pod 维护一个稳定的、持久的标识符，适用于需要稳定网络标识、持久存储或有序部署和扩缩容的应用。

## 核心特性

### 1. 稳定的网络标识
- 每个 Pod 有稳定的网络标识符
- 重新调度后 Pod 名称不变
- 配合 Headless Service 提供 DNS 记录

### 2. 持久化存储
- 每个 Pod 都有独立的 PVC
- Pod 重建后数据保持不变
- 支持有状态数据管理

### 3. 有序部署和扩缩容
- 按顺序创建和删除 Pod
- 支持滚动更新
- 优雅的扩缩容操作

## StatefulSet 配置详解

### 基础配置示例

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web-statefulset           # StatefulSet 名称
  namespace: default              # 命名空间
  labels:                         # 标签
    app: nginx
    type: stateful
spec:
  serviceName: nginx-headless     # 关联的 Headless Service
  replicas: 3                     # 副本数量
  selector:                       # 选择器
    matchLabels:
      app: nginx
  template:                       # Pod 模板
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
  volumeClaimTemplates:           # 存储卷声明模板
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
      storageClassName: fast-ssd
  updateStrategy:                 # 更新策略
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  podManagementPolicy: OrderedReady  # Pod 管理策略
  revisionHistoryLimit: 10        # 历史版本限制
```

### 配置项详解

#### metadata 字段
```yaml
metadata:
  name: database-cluster          # StatefulSet 名称
  namespace: production           # 命名空间
  labels:                         # 标签
    app: postgresql
    tier: database
    environment: production
  annotations:                    # 注解
    description: "PostgreSQL 集群"
    version: "13.4"
```

#### spec.serviceName 字段
```yaml
spec:
  serviceName: postgresql-headless  # 必需：Headless Service 名称
  # 提供稳定的网络标识
  # 每个 Pod 的 DNS 记录：<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

#### spec.podManagementPolicy 字段
```yaml
spec:
  podManagementPolicy: OrderedReady  # Pod 管理策略
  # OrderedReady: 按顺序创建和删除（默认）
  # Parallel: 并行创建和删除
```

#### spec.updateStrategy 字段
```yaml
spec:
  updateStrategy:
    type: RollingUpdate           # 更新策略类型
    # RollingUpdate: 滚动更新（默认）
    # OnDelete: 手动删除触发更新
    rollingUpdate:
      maxUnavailable: 1           # 最大不可用 Pod 数量
      partition: 0                # 分区更新（保留旧版本的 Pod 数量）
```

## Headless Service 配置

### 基础 Headless Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
  labels:
    app: nginx
spec:
  clusterIP: None                 # 设置为 None 创建 Headless Service
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    name: web
```

### 完整的服务配置

```yaml
# Headless Service - 用于 StatefulSet
apiVersion: v1
kind: Service
metadata:
  name: postgresql-headless
  labels:
    app: postgresql
spec:
  clusterIP: None
  selector:
    app: postgresql
  ports:
  - port: 5432
    targetPort: 5432
    name: postgresql

---
# 普通 Service - 用于外部访问
apiVersion: v1
kind: Service
metadata:
  name: postgresql-service
  labels:
    app: postgresql
spec:
  selector:
    app: postgresql
  ports:
  - port: 5432
    targetPort: 5432
    name: postgresql
  type: ClusterIP
```

## 存储卷声明模板

### 基础 VolumeClaimTemplate

```yaml
volumeClaimTemplates:
- metadata:
    name: data                    # 卷名称
    labels:
      app: postgresql
  spec:
    accessModes: ["ReadWriteOnce"] # 访问模式
    resources:
      requests:
        storage: 10Gi             # 存储大小
    storageClassName: ssd         # 存储类
```

### 多卷配置

```yaml
volumeClaimTemplates:
- metadata:
    name: data                    # 数据卷
  spec:
    accessModes: ["ReadWriteOnce"]
    resources:
      requests:
        storage: 20Gi
    storageClassName: fast-ssd

- metadata:
    name: logs                    # 日志卷
  spec:
    accessModes: ["ReadWriteOnce"]
    resources:
      requests:
        storage: 5Gi
    storageClassName: standard

- metadata:
    name: backup                  # 备份卷
  spec:
    accessModes: ["ReadWriteOnce"]
    resources:
      requests:
        storage: 50Gi
    storageClassName: backup-storage
```

## 典型应用场景

### 1. 数据库集群 (PostgreSQL)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
spec:
  serviceName: postgresql-headless
  replicas: 3
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: mydb
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
          name: postgresql
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1000m
            memory: 2Gi
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 20Gi
      storageClassName: fast-ssd
```

### 2. 分布式存储 (Cassandra)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cassandra
spec:
  serviceName: cassandra-headless
  replicas: 3
  selector:
    matchLabels:
      app: cassandra
  template:
    metadata:
      labels:
        app: cassandra
    spec:
      containers:
      - name: cassandra
        image: cassandra:3.11
        env:
        - name: CASSANDRA_SEEDS
          value: "cassandra-0.cassandra-headless.default.svc.cluster.local"
        - name: CASSANDRA_CLUSTER_NAME
          value: "MyCluster"
        - name: CASSANDRA_DC
          value: "DC1"
        - name: CASSANDRA_RACK
          value: "Rack1"
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        ports:
        - containerPort: 7000
          name: intra-node
        - containerPort: 7001
          name: tls-intra-node
        - containerPort: 7199
          name: jmx
        - containerPort: 9042
          name: cql
        volumeMounts:
        - name: data
          mountPath: /var/lib/cassandra
        livenessProbe:
          exec:
            command:
            - /bin/bash
            - -c
            - nodetool status
          initialDelaySeconds: 90
          periodSeconds: 30
        readinessProbe:
          exec:
            command:
            - /bin/bash
            - -c
            - nodetool status | grep $POD_IP | grep UN
          initialDelaySeconds: 60
          periodSeconds: 10
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 50Gi
      storageClassName: fast-ssd
```

### 3. 消息队列 (Kafka)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
spec:
  serviceName: kafka-headless
  replicas: 3
  selector:
    matchLabels:
      app: kafka
  template:
    metadata:
      labels:
        app: kafka
    spec:
      containers:
      - name: kafka
        image: confluentinc/cp-kafka:6.2.0
        env:
        - name: KAFKA_BROKER_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: KAFKA_ZOOKEEPER_CONNECT
          value: "zookeeper:2181"
        - name: KAFKA_LISTENER_SECURITY_PROTOCOL_MAP
          value: "PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT"
        - name: KAFKA_ADVERTISED_LISTENERS
          value: "PLAINTEXT://$(POD_NAME).kafka-headless:29092,PLAINTEXT_HOST://localhost:9092"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        ports:
        - containerPort: 29092
          name: kafka-internal
        - containerPort: 9092
          name: kafka-external
        volumeMounts:
        - name: data
          mountPath: /var/lib/kafka/data
        livenessProbe:
          exec:
            command:
            - sh
            - -c
            - kafka-broker-api-versions --bootstrap-server localhost:9092
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1000m
            memory: 2Gi
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 30Gi
      storageClassName: fast-ssd
```

## 扩缩容操作

### 1. 手动扩缩容

```bash
# 扩容到 5 个副本
kubectl scale statefulset my-statefulset --replicas=5

# 缩容到 1 个副本
kubectl scale statefulset my-statefulset --replicas=1

# 查看扩缩容状态
kubectl rollout status statefulset my-statefulset
```

### 2. 声明式扩缩容

```yaml
# 修改 replicas 字段
spec:
  replicas: 5                     # 从 3 扩容到 5
```

### 3. 自动扩缩容 (VPA)

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: statefulset-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: my-statefulset
  updatePolicy:
    updateMode: "Auto"            # Auto、Off、Initial
  resourcePolicy:
    containerPolicies:
    - containerName: app
      maxAllowed:
        cpu: 2000m
        memory: 4Gi
      minAllowed:
        cpu: 100m
        memory: 128Mi
```

## 更新策略详解

### 1. 滚动更新 (RollingUpdate)

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1           # 最大不可用 Pod 数量
      partition: 0                # 分区更新
```

**滚动更新流程：**
1. 从最高序号的 Pod 开始更新
2. 等待 Pod 就绪后更新下一个
3. 保证最大不可用数量不超过限制

### 2. 分区更新

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 2                # 保留序号 < 2 的 Pod 不更新
```

**分区更新特点：**
- 只更新序号 >= partition 的 Pod
- 用于金丝雀发布
- 可以逐步增加更新范围

### 3. OnDelete 更新

```yaml
spec:
  updateStrategy:
    type: OnDelete                # 手动删除触发更新
```

**OnDelete 特点：**
- 只有手动删除 Pod 时才会用新配置重建
- 提供完全的手动控制
- 适用于需要精确控制更新时机的场景

## 初始化和依赖管理

### 1. Init Container 配置

```yaml
spec:
  template:
    spec:
      initContainers:
      - name: init-permissions
        image: busybox
        command:
        - sh
        - -c
        - |
          chown -R 999:999 /var/lib/postgresql/data
          chmod 700 /var/lib/postgresql/data
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        securityContext:
          runAsUser: 0

      - name: wait-for-dependencies
        image: busybox
        command:
        - sh
        - -c
        - |
          until nslookup dependency-service; do
            echo "Waiting for dependency..."
            sleep 2
          done
```

### 2. 启动顺序控制

```yaml
# 使用 readinessProbe 控制启动顺序
readinessProbe:
  exec:
    command:
    - sh
    - -c
    - |
      # 检查前一个 Pod 是否就绪
      if [ "${HOSTNAME##*-}" = "0" ]; then
        # 第一个 Pod，直接检查自身
        pg_isready -U $POSTGRES_USER
      else
        # 后续 Pod，检查前一个 Pod 和自身
        PREV_POD=$((${HOSTNAME##*-} - 1))
        PREV_HOST="${HOSTNAME%-*}-${PREV_POD}.${SERVICE_NAME}"
        pg_isready -h $PREV_HOST -U $POSTGRES_USER && \
        pg_isready -U $POSTGRES_USER
      fi
  initialDelaySeconds: 10
  periodSeconds: 5
```

## 故障恢复和数据迁移

### 1. Pod 故障恢复

```bash
# 查看 StatefulSet 状态
kubectl get statefulset my-statefulset

# 查看 Pod 状态
kubectl get pods -l app=my-app

# 强制删除故障 Pod
kubectl delete pod my-statefulset-1 --force --grace-period=0

# 查看 PVC 状态
kubectl get pvc
```

### 2. 数据迁移

```yaml
# 使用 Job 进行数据迁移
apiVersion: batch/v1
kind: Job
metadata:
  name: data-migration
spec:
  template:
    spec:
      containers:
      - name: migrator
        image: postgres:13
        command:
        - sh
        - -c
        - |
          pg_dump -h old-db-host -U user old_db | \
          psql -h new-db-host -U user new_db
        env:
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
      restartPolicy: Never
  backoffLimit: 3
```

### 3. 备份和恢复

```yaml
# 定期备份 CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
spec:
  schedule: "0 2 * * *"           # 每天凌晨 2 点
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:13
            command:
            - sh
            - -c
            - |
              BACKUP_FILE="/backup/$(date +%Y%m%d_%H%M%S).sql"
              pg_dump -h postgresql-0.postgresql-headless \
                      -U $POSTGRES_USER $POSTGRES_DB > $BACKUP_FILE
              echo "Backup completed: $BACKUP_FILE"
            env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: username
            - name: POSTGRES_DB
              value: mydb
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure
```

## 监控和可观测性

### 1. 监控指标

```yaml
# StatefulSet 关键监控指标
- kube_statefulset_status_replicas: 期望副本数
- kube_statefulset_status_replicas_ready: 就绪副本数
- kube_statefulset_status_replicas_current: 当前副本数
- kube_statefulset_status_replicas_updated: 已更新副本数
- kube_statefulset_metadata_generation: 配置代次
- kube_statefulset_status_observed_generation: 观察到的代次
```

### 2. 健康检查配置

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 60    # 给足够的启动时间
          periodSeconds: 10
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 3
        
        startupProbe:               # 启动探针，适用于启动慢的应用
          httpGet:
            path: /startup
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 30      # 最多等待 5 分钟
```

## 最佳实践

### 1. 命名和标签

```yaml
metadata:
  name: postgresql-cluster        # 描述性名称
  labels:
    app: postgresql               # 应用名称
    component: database           # 组件类型
    tier: data                    # 层级
    environment: production       # 环境
    version: "13.4"              # 版本
```

### 2. 资源配置

```yaml
resources:
  requests:
    cpu: 500m                     # 合理的资源请求
    memory: 1Gi
  limits:
    cpu: 2000m                    # 设置适当的限制
    memory: 4Gi
```

### 3. 安全配置

```yaml
securityContext:
  runAsNonRoot: true              # 不以 root 运行
  runAsUser: 999                  # 指定用户 ID
  fsGroup: 999                    # 文件系统组
  allowPrivilegeEscalation: false # 禁止权限提升
```

### 4. 存储配置

```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: ["ReadWriteOnce"]
    resources:
      requests:
        storage: 20Gi             # 根据实际需求设置
    storageClassName: fast-ssd    # 选择合适的存储类
```

### 5. 网络配置

```yaml
# 配置 Pod 反亲和性，避免单点故障
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values: ["postgresql"]
        topologyKey: kubernetes.io/hostname
```

## 常见问题和解决方案

### 1. Pod 启动顺序问题

```yaml
# 使用 readinessProbe 控制启动顺序
readinessProbe:
  exec:
    command:
    - sh
    - -c
    - |
      # 检查依赖服务是否就绪
      if [ "${HOSTNAME##*-}" != "0" ]; then
        # 非第一个 Pod，等待前面的 Pod
        PREV_INDEX=$((${HOSTNAME##*-} - 1))
        nslookup ${HOSTNAME%-*}-${PREV_INDEX}.${SERVICE_NAME}
      fi
      # 检查自身服务
      check_self_ready
```

### 2. 存储卷删除问题

```bash
# StatefulSet 删除后，PVC 不会自动删除
kubectl delete statefulset my-statefulset

# 需要手动删除 PVC（注意数据丢失）
kubectl delete pvc -l app=my-app

# 或者保留 PVC 用于数据恢复
kubectl get pvc -l app=my-app
```

### 3. 网络分区问题

```yaml
# 配置适当的 podDisruptionBudget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: postgresql-pdb
spec:
  minAvailable: 2                 # 最少保持 2 个 Pod 可用
  selector:
    matchLabels:
      app: postgresql
```