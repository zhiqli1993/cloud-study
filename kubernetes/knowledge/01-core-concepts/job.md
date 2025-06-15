# Job 资源详解

## 概述

Job 是 Kubernetes 中用于运行一次性任务的工作负载控制器。Job 确保指定数量的 Pod 成功完成，适用于批处理任务、数据处理、备份等场景。

## 核心特性

### 1. 一次性执行
- 任务完成后 Pod 不会重启
- 保证指定数量的 Pod 成功完成
- 支持并行和串行执行

### 2. 失败重试
- 自动重试失败的 Pod
- 可配置重试次数限制
- 支持退避策略

### 3. 完成跟踪
- 跟踪任务完成状态
- 提供执行时间统计
- 支持超时控制

## Job 配置详解

### 基础配置示例

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-calculation
  labels:
    app: pi-job
spec:
  completions: 1                # 成功完成的 Pod 数量
  parallelism: 1                # 并行运行的 Pod 数量
  backoffLimit: 3               # 失败重试次数
  activeDeadlineSeconds: 300    # 超时时间（5分钟）
  ttlSecondsAfterFinished: 100  # 完成后保留时间
  template:
    metadata:
      labels:
        app: pi-job
    spec:
      containers:
      - name: pi
        image: perl:5.34
        command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      restartPolicy: Never       # 重启策略：Never 或 OnFailure
  manualSelector: false         # 是否手动管理选择器
```

### 并行处理示例

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-processing
spec:
  completions: 10               # 总共需要完成 10 个任务
  parallelism: 3                # 同时运行 3 个 Pod
  backoffLimit: 5
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          echo "Processing item $JOB_COMPLETION_INDEX"
          sleep 30
          echo "Item $JOB_COMPLETION_INDEX completed"
        env:
        - name: JOB_COMPLETION_INDEX
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['batch.kubernetes.io/job-completion-index']
      restartPolicy: OnFailure
```

### 数据处理任务

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 3
  template:
    spec:
      containers:
      - name: processor
        image: python:3.9
        command:
        - python
        - -c
        - |
          import time
          import os
          
          # 模拟数据处理
          print("Starting data processing...")
          for i in range(10):
              print(f"Processing batch {i+1}/10")
              time.sleep(2)
          
          print("Data processing completed successfully")
        volumeMounts:
        - name: data-volume
          mountPath: /data
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 1Gi
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: data-pvc
      restartPolicy: OnFailure
```

## 工作模式

### 1. 单一完成模式

```yaml
spec:
  completions: 1                # 只需要 1 个 Pod 成功
  parallelism: 1                # 同时只运行 1 个 Pod
```

### 2. 固定完成数量模式

```yaml
spec:
  completions: 5                # 需要 5 个 Pod 成功
  parallelism: 2                # 同时运行 2 个 Pod
```

### 3. 工作队列模式

```yaml
spec:
  completions: null             # 不指定完成数量
  parallelism: 3                # 并行度为 3
  # Pod 从队列获取任务，自行决定何时退出
```

## 监控和管理

### 1. 查看 Job 状态

```bash
# 查看 Job 列表
kubectl get jobs

# 查看 Job 详情
kubectl describe job my-job

# 查看 Job 的 Pod
kubectl get pods -l job-name=my-job

# 查看 Job 日志
kubectl logs -l job-name=my-job
```

### 2. Job 清理

```bash
# 手动删除 Job（包括 Pod）
kubectl delete job my-job

# 设置自动清理
spec:
  ttlSecondsAfterFinished: 100  # 完成后 100 秒自动删除
```

## 最佳实践

### 1. 资源配置

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

### 2. 错误处理

```yaml
spec:
  backoffLimit: 3               # 合理的重试次数
  activeDeadlineSeconds: 3600   # 设置超时时间
```

### 3. 安全配置

```yaml
template:
  spec:
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
    containers:
    - name: app
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
```