# Pod 资源详解

## 概述

Pod 是 Kubernetes 中最小的可部署和可管理的计算单元。一个 Pod 代表集群中运行的一个进程，封装了一个或多个应用容器、存储资源、唯一的网络 IP 以及控制容器运行的选项。

## 核心特性

### 1. 共享资源
- **网络**: Pod 内所有容器共享同一个 IP 地址和端口空间
- **存储**: Pod 内所有容器可以访问共享的 Volume
- **生命周期**: Pod 内所有容器具有相同的生命周期

### 2. 原子性
- Pod 作为一个整体进行调度、部署和管理
- Pod 内容器要么全部成功，要么全部失败

## Pod 配置详解

### 基础配置示例

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod                    # Pod 名称
  namespace: default              # 命名空间
  labels:                         # 标签
    app: my-app
    version: v1.0
  annotations:                    # 注解
    description: "示例 Pod"
spec:
  containers:                     # 容器列表
  - name: app-container           # 容器名称
    image: nginx:1.20             # 镜像
    imagePullPolicy: IfNotPresent # 镜像拉取策略
    ports:                        # 端口配置
    - containerPort: 80
      name: http
      protocol: TCP
    env:                          # 环境变量
    - name: APP_ENV
      value: "production"
    - name: SECRET_KEY
      valueFrom:
        secretKeyRef:
          name: app-secret
          key: key
    resources:                    # 资源限制
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
    volumeMounts:                 # 卷挂载
    - name: config-volume
      mountPath: /etc/config
    - name: data-volume
      mountPath: /data
  volumes:                        # 卷定义
  - name: config-volume
    configMap:
      name: app-config
  - name: data-volume
    persistentVolumeClaim:
      claimName: data-pvc
  restartPolicy: Always           # 重启策略
  terminationGracePeriodSeconds: 30  # 优雅终止时间
```

### 配置项详解

#### metadata 字段
```yaml
metadata:
  name: pod-name                  # 必需：Pod 名称，在 namespace 内唯一
  namespace: default              # 可选：命名空间，默认为 default
  labels:                         # 可选：标签键值对
    app: my-app                   # 用于选择器匹配
    tier: frontend
    version: v1.0
  annotations:                    # 可选：注解，存储元数据
    kubernetes.io/created-by: "user@example.com"
    description: "应用前端 Pod"
  generateName: pod-              # 可选：名称前缀，用于生成唯一名称
```

#### spec.containers 字段
```yaml
containers:
- name: main-container            # 必需：容器名称
  image: nginx:1.20              # 必需：容器镜像
  imagePullPolicy: IfNotPresent  # 可选：镜像拉取策略
  # Always: 总是拉取
  # IfNotPresent: 本地不存在时拉取（默认）
  # Never: 从不拉取
  
  command: ["/bin/sh"]           # 可选：覆盖镜像的 ENTRYPOINT
  args: ["-c", "while true; do echo hello; sleep 10; done"]  # 可选：覆盖镜像的 CMD
  
  workingDir: /app               # 可选：工作目录
  
  ports:                         # 可选：容器端口
  - name: http                   # 端口名称
    containerPort: 80            # 容器端口
    protocol: TCP                # 协议：TCP（默认）、UDP、SCTP
    hostPort: 8080              # 可选：主机端口
    hostIP: "0.0.0.0"           # 可选：主机 IP
  
  env:                           # 可选：环境变量
  - name: ENV_VAR_NAME           # 环境变量名
    value: "direct-value"        # 直接值
  - name: SECRET_VALUE           # 从 Secret 获取
    valueFrom:
      secretKeyRef:
        name: my-secret
        key: secret-key
        optional: false          # 是否可选
  - name: CONFIGMAP_VALUE        # 从 ConfigMap 获取
    valueFrom:
      configMapKeyRef:
        name: my-config
        key: config-key
  - name: FIELD_VALUE            # 从字段获取
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: RESOURCE_VALUE         # 从资源获取
    valueFrom:
      resourceFieldRef:
        resource: limits.memory
        divisor: 1Mi
  
  envFrom:                       # 可选：批量环境变量
  - configMapRef:                # 从 ConfigMap 导入所有键值对
      name: my-config
      optional: true
  - secretRef:                   # 从 Secret 导入所有键值对
      name: my-secret
      optional: false
  - prefix: "APP_"               # 添加前缀
    configMapRef:
      name: app-config
```

#### 资源管理配置
```yaml
resources:
  requests:                      # 资源请求（最小需求）
    cpu: "100m"                  # CPU：100 毫核
    memory: "128Mi"              # 内存：128 MiB
    ephemeral-storage: "1Gi"     # 临时存储：1 GiB
    nvidia.com/gpu: "1"          # 扩展资源：GPU
  limits:                        # 资源限制（最大允许）
    cpu: "500m"                  # CPU：500 毫核
    memory: "512Mi"              # 内存：512 MiB
    ephemeral-storage: "2Gi"     # 临时存储：2 GiB
    nvidia.com/gpu: "1"          # 扩展资源：GPU
```

#### 健康检查配置
```yaml
livenessProbe:                   # 存活探针
  httpGet:                       # HTTP 检查
    path: /health
    port: 8080
    httpHeaders:
    - name: Custom-Header
      value: "health-check"
  initialDelaySeconds: 30        # 初始延迟：30秒
  periodSeconds: 10              # 检查间隔：10秒
  timeoutSeconds: 5              # 超时时间：5秒
  successThreshold: 1            # 成功阈值：1次
  failureThreshold: 3            # 失败阈值：3次

readinessProbe:                  # 就绪探针
  tcpSocket:                     # TCP 检查
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3

startupProbe:                    # 启动探针
  exec:                          # 命令检查
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 30
```

#### 安全上下文配置
```yaml
securityContext:                 # 容器安全上下文
  runAsUser: 1000                # 运行用户 ID
  runAsGroup: 2000               # 运行组 ID
  runAsNonRoot: true             # 不以 root 运行
  allowPrivilegeEscalation: false # 禁止权限提升
  readOnlyRootFilesystem: true   # 只读根文件系统
  capabilities:                  # Linux 能力
    add:
    - NET_BIND_SERVICE
    drop:
    - ALL
  seccompProfile:                # Seccomp 配置
    type: RuntimeDefault
  seLinuxOptions:                # SELinux 配置
    level: "s0:c123,c456"
```

#### 卷挂载配置
```yaml
volumeMounts:
- name: config-volume            # 卷名称
  mountPath: /etc/config         # 挂载路径
  subPath: app.conf              # 子路径（可选）
  readOnly: true                 # 只读挂载
- name: data-volume
  mountPath: /data
  mountPropagation: None         # 挂载传播：None、HostToContainer、Bidirectional
- name: secret-volume
  mountPath: /etc/secrets
  defaultMode: 0400              # 文件权限
```

### Pod 级别配置

#### Pod 安全上下文
```yaml
spec:
  securityContext:               # Pod 级别安全上下文
    runAsUser: 1000              # 默认用户 ID
    runAsGroup: 2000             # 默认组 ID
    runAsNonRoot: true           # 禁止 root 用户
    fsGroup: 3000                # 文件系统组 ID
    fsGroupChangePolicy: Always  # 文件系统组变更策略
    seccompProfile:              # Seccomp 配置
      type: RuntimeDefault
    seLinuxOptions:              # SELinux 配置
      level: "s0:c123,c456"
    supplementalGroups: [4000, 5000]  # 附加组
    sysctls:                     # 系统参数
    - name: net.core.somaxconn
      value: "1024"
```

#### 调度配置
```yaml
spec:
  nodeSelector:                  # 节点选择器
    kubernetes.io/arch: amd64
    environment: production
  
  nodeName: worker-node-1        # 指定节点名称
  
  affinity:                      # 亲和性配置
    nodeAffinity:                # 节点亲和性
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: zone
            operator: In
            values: ["us-west-1a", "us-west-1b"]
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: instance-type
            operator: In
            values: ["m5.large"]
    
    podAffinity:                 # Pod 亲和性
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values: ["database"]
        topologyKey: kubernetes.io/hostname
    
    podAntiAffinity:             # Pod 反亲和性
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values: ["web"]
          topologyKey: kubernetes.io/hostname
  
  tolerations:                   # 污点容忍
  - key: "node.kubernetes.io/not-ready"
    operator: "Exists"
    effect: "NoExecute"
    tolerationSeconds: 300
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
  
  topologySpreadConstraints:     # 拓扑分散约束
  - maxSkew: 1
    topologyKey: zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: web
```

#### 其他配置
```yaml
spec:
  restartPolicy: Always          # 重启策略：Always、OnFailure、Never
  terminationGracePeriodSeconds: 30  # 优雅终止时间
  activeDeadlineSeconds: 3600    # 活跃截止时间
  dnsPolicy: ClusterFirst        # DNS 策略
  dnsConfig:                     # DNS 配置
    nameservers:
    - 1.2.3.4
    searches:
    - my.dns.search.suffix
    options:
    - name: ndots
      value: "2"
  hostNetwork: false             # 是否使用主机网络
  hostPID: false                 # 是否使用主机 PID 命名空间
  hostIPC: false                 # 是否使用主机 IPC 命名空间
  hostname: my-pod               # 主机名
  subdomain: my-subdomain        # 子域名
  setHostnameAsFQDN: false       # 是否设置主机名为 FQDN
  shareProcessNamespace: false   # 是否共享进程命名空间
  serviceAccountName: my-sa      # 服务账户名称
  automountServiceAccountToken: true  # 是否自动挂载服务账户令牌
  priority: 1000                 # 优先级
  priorityClassName: high-priority    # 优先级类名
  runtimeClassName: kata         # 运行时类名
  schedulerName: my-scheduler    # 调度器名称
  preemptionPolicy: PreemptLowerPriority  # 抢占策略
  overhead:                      # 开销
    cpu: 10m
    memory: 10Mi
```

## 卷类型配置

### EmptyDir 卷
```yaml
volumes:
- name: cache-volume
  emptyDir:
    sizeLimit: 1Gi               # 大小限制
    medium: Memory               # 存储介质：""（默认磁盘）、Memory（内存）
```

### HostPath 卷
```yaml
volumes:
- name: host-volume
  hostPath:
    path: /var/log               # 主机路径
    type: Directory              # 类型：Directory、File、Socket 等
```

### ConfigMap 卷
```yaml
volumes:
- name: config-volume
  configMap:
    name: my-config             # ConfigMap 名称
    defaultMode: 0644           # 默认文件权限
    optional: false             # 是否可选
    items:                      # 选择特定项
    - key: config.yaml
      path: app-config.yaml
      mode: 0600
```

### Secret 卷
```yaml
volumes:
- name: secret-volume
  secret:
    secretName: my-secret       # Secret 名称
    defaultMode: 0400           # 默认文件权限
    optional: false             # 是否可选
    items:                      # 选择特定项
    - key: tls.crt
      path: server.crt
      mode: 0644
```

### PersistentVolumeClaim 卷
```yaml
volumes:
- name: data-volume
  persistentVolumeClaim:
    claimName: data-pvc         # PVC 名称
    readOnly: false             # 是否只读
```

## 生命周期钩子

```yaml
spec:
  containers:
  - name: app
    image: nginx
    lifecycle:
      postStart:                 # 启动后钩子
        exec:
          command:
          - /bin/sh
          - -c
          - echo "Container started" > /tmp/poststart
        # httpGet:               # HTTP 钩子
        #   path: /poststart
        #   port: 8080
        # tcpSocket:             # TCP 钩子
        #   port: 8080
      preStop:                   # 停止前钩子
        exec:
          command:
          - /bin/sh
          - -c
          - sleep 15
```

## 初始化容器

```yaml
spec:
  initContainers:                # 初始化容器
  - name: init-db
    image: busybox
    command: ['sh', '-c', 'until nslookup mydb; do echo waiting for mydb; sleep 2; done;']
  - name: init-storage
    image: busybox
    command: ['sh', '-c', 'mkdir -p /shared/data && chown 1000:1000 /shared/data']
    volumeMounts:
    - name: shared-volume
      mountPath: /shared
  containers:
  - name: app
    image: myapp
    volumeMounts:
    - name: shared-volume
      mountPath: /app/data
  volumes:
  - name: shared-volume
    emptyDir: {}
```

## Pod 状态详解

### 阶段 (Phase)
- **Pending**: Pod 已被创建，但一个或多个容器镜像尚未创建
- **Running**: Pod 已经绑定到一个节点，所有容器都已被创建
- **Succeeded**: Pod 中的所有容器都已成功终止
- **Failed**: Pod 中的所有容器都已终止，且至少有一个容器失败终止
- **Unknown**: 无法获取 Pod 状态

### 条件 (Conditions)
- **PodScheduled**: Pod 已被调度到一个节点
- **ContainersReady**: Pod 中所有容器都已就绪
- **Initialized**: 所有初始化容器已成功启动
- **Ready**: Pod 能够服务请求

### 容器状态
- **Waiting**: 容器仍在运行启动前需要的操作
- **Running**: 容器正在正常运行
- **Terminated**: 容器已执行并已完成运行

## 最佳实践

### 1. 资源管理
```yaml
resources:
  requests:
    cpu: 100m                   # 总是设置 requests
    memory: 128Mi
  limits:
    cpu: 500m                   # 设置合理的 limits
    memory: 512Mi
```

### 2. 健康检查
```yaml
livenessProbe:                  # 设置存活探针
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:                 # 设置就绪探针
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 3. 安全配置
```yaml
securityContext:
  runAsNonRoot: true            # 不以 root 运行
  runAsUser: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
```

### 4. 标签和注解
```yaml
metadata:
  labels:
    app: my-app                 # 应用名称
    version: v1.0               # 版本
    tier: frontend              # 层级
    environment: production     # 环境
  annotations:
    description: "应用描述"
    contact: "team@example.com"
```