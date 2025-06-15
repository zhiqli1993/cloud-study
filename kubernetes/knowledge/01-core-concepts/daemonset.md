# DaemonSet 资源详解

## 概述

DaemonSet 是 Kubernetes 中确保所有（或部分）节点运行一个 Pod 副本的工作负载控制器。当节点加入集群时，DaemonSet 会自动在新节点上创建 Pod；当节点从集群中移除时，这些 Pod 也会被回收。

## 核心特性

### 1. 节点覆盖
- 确保每个节点运行一个 Pod 副本
- 新节点自动获得 Pod
- 节点移除时自动清理 Pod

### 2. 系统级服务
- 适用于系统守护进程
- 日志收集、监控代理
- 网络插件、存储插件

### 3. 选择性部署
- 通过节点选择器控制部署范围
- 支持污点容忍配置
- 可以排除特定节点

## DaemonSet 配置详解

### 基础配置示例

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-daemonset         # DaemonSet 名称
  namespace: kube-system          # 通常部署在系统命名空间
  labels:                         # 标签
    app: fluentd
    component: logging
spec:
  selector:                       # 选择器
    matchLabels:
      app: fluentd
  template:                       # Pod 模板
    metadata:
      labels:
        app: fluentd
        component: logging
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd:v1.14
        env:
        - name: FLUENTD_CONF
          value: "fluent.conf"
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        ports:
        - containerPort: 24224
          name: forward
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: config
          mountPath: /fluentd/etc
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
          type: Directory
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
          type: DirectoryOrCreate
      - name: config
        configMap:
          name: fluentd-config
      tolerations:                # 污点容忍
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      nodeSelector:               # 节点选择器（可选）
        kubernetes.io/os: linux
  updateStrategy:                 # 更新策略
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  revisionHistoryLimit: 10        # 历史版本限制
```

### 配置项详解

#### metadata 字段
```yaml
metadata:
  name: node-exporter             # DaemonSet 名称
  namespace: monitoring           # 命名空间
  labels:                         # 标签
    app: node-exporter
    component: monitoring
    tier: infrastructure
  annotations:                    # 注解
    description: "Prometheus Node Exporter"
    version: "1.3.1"
```

#### spec.template 字段
```yaml
template:
  metadata:
    labels:                       # Pod 标签（必须匹配 selector）
      app: node-exporter
      component: monitoring
    annotations:                  # Pod 注解
      prometheus.io/scrape: "true"
      prometheus.io/port: "9100"
  spec:                          # Pod 规格
    # 与 Pod spec 相同
```

#### spec.updateStrategy 字段
```yaml
updateStrategy:
  type: RollingUpdate             # 更新策略类型
  # RollingUpdate: 滚动更新（默认）
  # OnDelete: 手动删除触发更新
  rollingUpdate:
    maxUnavailable: 1             # 最大不可用 Pod 数量（数量或百分比）
    # maxUnavailable: 25%         # 25% 的节点可以不可用
```

## 典型应用场景

### 1. 日志收集 (Fluentd)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
  labels:
    app: fluentd
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1.14-debian-elasticsearch7-1
        env:
        - name: FLUENT_ELASTICSEARCH_HOST
          value: "elasticsearch.logging.svc.cluster.local"
        - name: FLUENT_ELASTICSEARCH_PORT
          value: "9200"
        - name: FLUENT_ELASTICSEARCH_SCHEME
          value: "http"
        - name: FLUENT_UID
          value: "0"
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        ports:
        - containerPort: 24224
          name: forward
          protocol: TCP
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: fluentd-config
          mountPath: /fluentd/etc
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
          limits:
            cpu: 500m
            memory: 500Mi
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
          type: Directory
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
          type: DirectoryOrCreate
      - name: fluentd-config
        configMap:
          name: fluentd-config
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      - operator: Exists
        effect: NoExecute
      - operator: Exists
        effect: NoSchedule
```

### 2. 监控代理 (Node Exporter)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
  labels:
    app: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9100"
        prometheus.io/path: "/metrics"
    spec:
      hostNetwork: true           # 使用主机网络
      hostPID: true              # 使用主机 PID 命名空间
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.3.1
        args:
        - --web.listen-address=0.0.0.0:9100
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --path.rootfs=/host/root
        - --collector.filesystem.mount-points-exclude
        - "^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)"
        ports:
        - containerPort: 9100
          hostPort: 9100
          name: metrics
          protocol: TCP
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
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        securityContext:
          runAsNonRoot: true
          runAsUser: 65534
      volumes:
      - name: proc
        hostPath:
          path: /proc
          type: Directory
      - name: sys
        hostPath:
          path: /sys
          type: Directory
      - name: root
        hostPath:
          path: /
          type: Directory
      tolerations:
      - operator: Exists
```

### 3. 网络插件 (Calico)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: calico-node
  namespace: kube-system
  labels:
    k8s-app: calico-node
spec:
  selector:
    matchLabels:
      k8s-app: calico-node
  template:
    metadata:
      labels:
        k8s-app: calico-node
    spec:
      hostNetwork: true
      serviceAccountName: calico-node
      containers:
      - name: calico-node
        image: calico/node:v3.21.0
        env:
        - name: DATASTORE_TYPE
          value: "kubernetes"
        - name: FELIX_TYPHAK8SSERVICENAME
          value: "calico-typha"
        - name: CALICO_NODENAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: CALICO_NETWORKING_BACKEND
          value: "bird"
        - name: CLUSTER_TYPE
          value: "k8s,bgp"
        - name: CALICO_DISABLE_FILE_LOGGING
          value: "true"
        - name: FELIX_DEFAULTENDPOINTTOHOSTACTION
          value: "ACCEPT"
        - name: FELIX_IPV6SUPPORT
          value: "false"
        - name: WAIT_FOR_DATASTORE
          value: "true"
        - name: FELIX_LOGSEVERITYSCREEN
          value: "info"
        - name: FELIX_HEALTHENABLED
          value: "true"
        ports:
        - containerPort: 9099
          name: felix-metrics
          protocol: TCP
        - containerPort: 9100
          name: felix-prometheus
          protocol: TCP
        livenessProbe:
          exec:
            command:
            - /bin/calico-node
            - -felix-live
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 6
        readinessProbe:
          exec:
            command:
            - /bin/calico-node
            - -felix-ready
          periodSeconds: 10
        volumeMounts:
        - name: lib-modules
          mountPath: /lib/modules
          readOnly: true
        - name: var-run-calico
          mountPath: /var/run/calico
          readOnly: false
        - name: var-lib-calico
          mountPath: /var/lib/calico
          readOnly: false
        - name: xtables-lock
          mountPath: /run/xtables.lock
          readOnly: false
        - name: cni-bin-dir
          mountPath: /host/opt/cni/bin
          readOnly: false
        - name: cni-net-dir
          mountPath: /host/etc/cni/net.d
          readOnly: false
        securityContext:
          privileged: true
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: var-run-calico
        hostPath:
          path: /var/run/calico
      - name: var-lib-calico
        hostPath:
          path: /var/lib/calico
      - name: xtables-lock
        hostPath:
          path: /run/xtables.lock
          type: FileOrCreate
      - name: cni-bin-dir
        hostPath:
          path: /opt/cni/bin
      - name: cni-net-dir
        hostPath:
          path: /etc/cni/net.d
      tolerations:
      - operator: Exists
        effect: NoSchedule
      - operator: Exists
        effect: NoExecute
      - operator: Exists
        key: CriticalAddonsOnly
```

### 4. 存储插件 (CSI Driver)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: csi-driver-node
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: csi-driver-node
  template:
    metadata:
      labels:
        app: csi-driver-node
    spec:
      hostNetwork: true
      serviceAccountName: csi-driver-node-sa
      containers:
      - name: driver-registrar
        image: k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.5.0
        args:
        - --v=2
        - --csi-address=/csi/csi.sock
        - --kubelet-registration-path=/var/lib/kubelet/plugins/csi-driver/csi.sock
        env:
        - name: KUBE_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        volumeMounts:
        - name: plugin-dir
          mountPath: /csi/
        - name: registration-dir
          mountPath: /registration/
        resources:
          requests:
            cpu: 10m
            memory: 20Mi
          limits:
            cpu: 100m
            memory: 100Mi
      
      - name: csi-driver
        image: csi-driver:latest
        args:
        - --endpoint=$(CSI_ENDPOINT)
        - --nodeid=$(NODE_ID)
        - --v=2
        env:
        - name: CSI_ENDPOINT
          value: unix:///csi/csi.sock
        - name: NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        ports:
        - containerPort: 9898
          name: healthz
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /healthz
            port: healthz
          initialDelaySeconds: 10
          timeoutSeconds: 3
          periodSeconds: 10
          failureThreshold: 5
        volumeMounts:
        - name: plugin-dir
          mountPath: /csi
        - name: pods-mount-dir
          mountPath: /var/lib/kubelet/pods
          mountPropagation: Bidirectional
        - name: device-dir
          mountPath: /dev
        securityContext:
          privileged: true
          capabilities:
            add: ["SYS_ADMIN"]
          allowPrivilegeEscalation: true
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      
      volumes:
      - name: registration-dir
        hostPath:
          path: /var/lib/kubelet/plugins_registry/
          type: DirectoryOrCreate
      - name: plugin-dir
        hostPath:
          path: /var/lib/kubelet/plugins/csi-driver/
          type: DirectoryOrCreate
      - name: pods-mount-dir
        hostPath:
          path: /var/lib/kubelet/pods
          type: Directory
      - name: device-dir
        hostPath:
          path: /dev
      tolerations:
      - operator: Exists
```

## 节点选择和调度

### 1. 节点选择器

```yaml
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/os: linux   # 只在 Linux 节点运行
        node-type: worker         # 只在 worker 节点运行
        zone: us-west-1a          # 特定可用区
```

### 2. 节点亲和性

```yaml
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values: ["amd64", "arm64"]
              - key: node-role.kubernetes.io/worker
                operator: Exists
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: instance-type
                operator: In
                values: ["m5.large", "m5.xlarge"]
```

### 3. 污点容忍

```yaml
spec:
  template:
    spec:
      tolerations:
      # 容忍所有污点
      - operator: Exists
      
      # 容忍特定污点
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
        operator: Exists
      
      # 容忍带值的污点
      - key: dedicated
        operator: Equal
        value: gpu
        effect: NoSchedule
      
      # 容忍临时污点
      - key: node.kubernetes.io/not-ready
        operator: Exists
        effect: NoExecute
        tolerationSeconds: 300
```

## 更新策略

### 1. 滚动更新

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1           # 最大不可用 Pod 数量
      # maxUnavailable: 25%       # 或百分比
```

**滚动更新特点：**
- 逐个节点更新 Pod
- 确保服务连续性
- 可以控制更新速度

### 2. OnDelete 更新

```yaml
spec:
  updateStrategy:
    type: OnDelete                # 手动删除触发更新
```

**OnDelete 特点：**
- 完全手动控制
- 适用于关键系统组件
- 需要逐个手动删除 Pod

## 特权和安全

### 1. 特权容器

```yaml
spec:
  template:
    spec:
      containers:
      - name: privileged-app
        image: myapp:latest
        securityContext:
          privileged: true        # 特权模式
          capabilities:
            add:
            - SYS_ADMIN
            - NET_ADMIN
          allowPrivilegeEscalation: true
```

### 2. 主机资源访问

```yaml
spec:
  template:
    spec:
      hostNetwork: true           # 主机网络
      hostPID: true               # 主机 PID 命名空间
      hostIPC: true               # 主机 IPC 命名空间
      dnsPolicy: ClusterFirstWithHostNet  # DNS 策略
      
      containers:
      - name: host-access
        image: myapp:latest
        volumeMounts:
        - name: host-proc
          mountPath: /host/proc
          readOnly: true
        - name: host-sys
          mountPath: /host/sys
          readOnly: true
        - name: host-dev
          mountPath: /host/dev
        
      volumes:
      - name: host-proc
        hostPath:
          path: /proc
      - name: host-sys
        hostPath:
          path: /sys
      - name: host-dev
        hostPath:
          path: /dev
```

## 监控和可观测性

### 1. 监控指标

```yaml
# DaemonSet 关键监控指标
- kube_daemonset_status_desired_number_scheduled: 期望调度的 Pod 数量
- kube_daemonset_status_current_number_scheduled: 当前调度的 Pod 数量
- kube_daemonset_status_number_ready: 就绪的 Pod 数量
- kube_daemonset_status_number_available: 可用的 Pod 数量
- kube_daemonset_status_number_unavailable: 不可用的 Pod 数量
- kube_daemonset_updated_number_scheduled: 已更新的 Pod 数量
```

### 2. 健康检查

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
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3
```

### 3. 日志配置

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:latest
        env:
        - name: LOG_LEVEL
          value: "INFO"
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
```

## 故障排除

### 1. 常见问题

```bash
# 1. 查看 DaemonSet 状态
kubectl get daemonset my-daemonset

# 2. 查看 Pod 分布
kubectl get pods -l app=my-app -o wide

# 3. 检查节点标签
kubectl get nodes --show-labels

# 4. 查看节点污点
kubectl describe node node-name | grep Taints

# 5. 检查事件
kubectl get events --field-selector involvedObject.kind=DaemonSet
```

### 2. 调试方法

```bash
# 查看特定节点的 Pod
kubectl get pods -l app=my-app --field-selector spec.nodeName=node-name

# 查看 Pod 调度失败原因
kubectl describe pod pod-name

# 检查容器日志
kubectl logs -l app=my-app

# 进入容器调试
kubectl exec -it pod-name -- /bin/bash
```

## 最佳实践

### 1. 资源配置

```yaml
resources:
  requests:
    cpu: 100m                   # 保守的资源请求
    memory: 128Mi
  limits:
    cpu: 500m                   # 合理的资源限制
    memory: 512Mi
```

### 2. 安全配置

```yaml
securityContext:
  runAsNonRoot: true            # 尽量不以 root 运行
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
    add:
    - NET_BIND_SERVICE          # 只添加必要的能力
```

### 3. 容忍配置

```yaml
tolerations:
- operator: Exists              # 容忍所有污点，确保覆盖所有节点
  effect: NoSchedule
- operator: Exists
  effect: NoExecute
  tolerationSeconds: 300        # 节点故障时的容忍时间
```

### 4. 更新策略

```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1           # 保守的更新策略
```

### 5. 标签和注解

```yaml
metadata:
  labels:
    app: my-daemon              # 一致的标签
    component: system
    tier: infrastructure
  annotations:
    description: "System daemon for monitoring"
    version: "1.0.0"
```

## 高级特性

### 1. 多架构支持

```yaml
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values: ["amd64", "arm64"]
      containers:
      - name: app
        image: myapp:latest-$(ARCH)  # 多架构镜像
        env:
        - name: ARCH
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
```

### 2. 优雅关闭

```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 60
      containers:
      - name: app
        image: myapp:latest
        lifecycle:
          preStop:
            exec:
              command:
              - /bin/sh
              - -c
              - |
                # 优雅关闭逻辑
                kill -TERM $(pidof myapp)
                while pidof myapp; do
                  sleep 1
                done
```

### 3. 依赖管理

```yaml
spec:
  template:
    spec:
      initContainers:
      - name: wait-for-dependency
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