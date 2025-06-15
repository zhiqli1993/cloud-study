# CronJob 资源详解

## 概述

CronJob 是 Kubernetes 中用于按时间调度运行 Job 的控制器。它基于 Unix cron 格式创建定时任务，适用于定期备份、数据清理、报告生成等场景。

## 核心特性

### 1. 时间调度
- 基于 Cron 表达式的时间调度
- 支持复杂的时间模式
- 自动创建和管理 Job

### 2. 并发控制
- 防止重叠执行
- 控制历史 Job 数量
- 支持暂停和恢复

### 3. 失败处理
- 继承 Job 的重试机制
- 支持成功/失败历史限制
- 错过调度的处理策略

## CronJob 配置详解

### 基础配置示例

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
  labels:
    app: backup
spec:
  schedule: "0 2 * * *"           # Cron 表达式：每天凌晨 2 点
  timeZone: "Asia/Shanghai"       # 时区设置
  concurrencyPolicy: Forbid       # 并发策略
  successfulJobsHistoryLimit: 3   # 保留成功 Job 数量
  failedJobsHistoryLimit: 1       # 保留失败 Job 数量
  startingDeadlineSeconds: 300    # 错过调度的截止时间
  suspend: false                  # 是否暂停
  jobTemplate:                    # Job 模板
    spec:
      backoffLimit: 3
      activeDeadlineSeconds: 1800
      template:
        metadata:
          labels:
            app: backup
        spec:
          containers:
          - name: backup
            image: postgres:13
            command:
            - /bin/bash
            - -c
            - |
              BACKUP_FILE="/backup/db_$(date +%Y%m%d_%H%M%S).sql"
              pg_dump -h $DB_HOST -U $DB_USER $DB_NAME > $BACKUP_FILE
              echo "Backup completed: $BACKUP_FILE"
            env:
            - name: DB_HOST
              value: "postgresql-service"
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: username
            - name: DB_NAME
              value: "myapp"
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: password
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
            resources:
              requests:
                cpu: 100m
                memory: 256Mi
              limits:
                cpu: 500m
                memory: 512Mi
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure
```

### Cron 表达式详解

```yaml
# Cron 表达式格式：分 时 日 月 周
# ┌───────────── 分钟 (0-59)
# │ ┌─────────── 小时 (0-23)
# │ │ ┌───────── 日期 (1-31)
# │ │ │ ┌─────── 月份 (1-12)
# │ │ │ │ ┌───── 星期 (0-6, 0=周日)
# │ │ │ │ │
# * * * * *

# 常用示例：
schedule: "0 0 * * *"             # 每天午夜
schedule: "0 */6 * * *"           # 每 6 小时
schedule: "30 3 * * 1"            # 每周一凌晨 3:30
schedule: "0 0 1 * *"             # 每月 1 号午夜
schedule: "15 14 1 * *"           # 每月 1 号下午 2:15
schedule: "0 22 * * 1-5"          # 工作日晚上 10 点
schedule: "23 0-20/2 * * *"       # 每天 0-20 点之间每 2 小时的第 23 分钟
```

### 典型应用场景

#### 1. 数据库备份

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-backup
spec:
  schedule: "0 3 * * *"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: mysql-backup
            image: mysql:8.0
            command:
            - /bin/bash
            - -c
            - |
              BACKUP_FILE="/backup/mysql_$(date +%Y%m%d_%H%M%S).sql"
              mysqldump -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE > $BACKUP_FILE
              
              # 压缩备份文件
              gzip $BACKUP_FILE
              
              # 删除 7 天前的备份
              find /backup -name "mysql_*.sql.gz" -mtime +7 -delete
              
              echo "Backup completed and old backups cleaned"
            env:
            - name: MYSQL_HOST
              value: "mysql-service"
            - name: MYSQL_DATABASE
              value: "myapp"
            - name: MYSQL_USER
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: username
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: password
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: mysql-backup-pvc
          restartPolicy: OnFailure
```

#### 2. 日志清理

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: log-cleanup
spec:
  schedule: "0 1 * * *"           # 每天凌晨 1 点
  concurrencyPolicy: Allow
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: log-cleaner
            image: busybox
            command:
            - /bin/sh
            - -c
            - |
              echo "Starting log cleanup..."
              
              # 删除 30 天前的日志文件
              find /var/log/apps -name "*.log" -mtime +30 -delete
              
              # 清理空目录
              find /var/log/apps -type d -empty -delete
              
              # 压缩 7 天前的日志
              find /var/log/apps -name "*.log" -mtime +7 -exec gzip {} \;
              
              echo "Log cleanup completed"
            volumeMounts:
            - name: app-logs
              mountPath: /var/log/apps
            resources:
              requests:
                cpu: 50m
                memory: 64Mi
              limits:
                cpu: 200m
                memory: 128Mi
          volumes:
          - name: app-logs
            hostPath:
              path: /var/log/applications
              type: DirectoryOrCreate
          restartPolicy: OnFailure
```

#### 3. 数据同步

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: data-sync
spec:
  schedule: "*/15 * * * *"        # 每 15 分钟
  concurrencyPolicy: Replace      # 替换正在运行的 Job
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      activeDeadlineSeconds: 600  # 10 分钟超时
      template:
        spec:
          containers:
          - name: sync
            image: alpine/curl
            command:
            - /bin/sh
            - -c
            - |
              echo "Starting data synchronization..."
              
              # 从 API 获取数据
              curl -H "Authorization: Bearer $API_TOKEN" \
                   -o /tmp/data.json \
                   $API_ENDPOINT/data
              
              # 处理数据并同步到数据库
              if [ -f /tmp/data.json ]; then
                echo "Data retrieved successfully"
                # 这里添加数据处理逻辑
                python /scripts/process_data.py /tmp/data.json
              else
                echo "Failed to retrieve data"
                exit 1
              fi
              
              echo "Data synchronization completed"
            env:
            - name: API_ENDPOINT
              valueFrom:
                configMapKeyRef:
                  name: sync-config
                  key: api_endpoint
            - name: API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: api-secret
                  key: token
            volumeMounts:
            - name: scripts
              mountPath: /scripts
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 300m
                memory: 256Mi
          volumes:
          - name: scripts
            configMap:
              name: sync-scripts
              defaultMode: 0755
          restartPolicy: OnFailure
```

## 并发策略

### 1. Allow（允许）

```yaml
spec:
  concurrencyPolicy: Allow      # 允许并发执行多个 Job
```

### 2. Forbid（禁止）

```yaml
spec:
  concurrencyPolicy: Forbid     # 禁止并发，跳过新的调度
```

### 3. Replace（替换）

```yaml
spec:
  concurrencyPolicy: Replace    # 停止当前 Job，启动新的 Job
```

## 管理和监控

### 1. 查看 CronJob 状态

```bash
# 查看 CronJob 列表
kubectl get cronjobs

# 查看详细信息
kubectl describe cronjob my-cronjob

# 查看相关的 Job
kubectl get jobs -l app=my-cronjob

# 查看最近的执行日志
kubectl logs -l job-name=my-cronjob-$(date +%s)
```

### 2. 手动触发

```bash
# 从 CronJob 创建一次性 Job
kubectl create job manual-backup --from=cronjob/database-backup
```

### 3. 暂停和恢复

```bash
# 暂停 CronJob
kubectl patch cronjob my-cronjob -p '{"spec":{"suspend":true}}'

# 恢复 CronJob
kubectl patch cronjob my-cronjob -p '{"spec":{"suspend":false}}'
```

## 最佳实践

### 1. 时间设置

```yaml
spec:
  schedule: "0 2 * * *"           # 避开高峰时间
  timeZone: "Asia/Shanghai"       # 明确指定时区
  startingDeadlineSeconds: 300    # 设置合理的启动截止时间
```

### 2. 资源管理

```yaml
jobTemplate:
  spec:
    activeDeadlineSeconds: 3600   # 设置任务超时
    template:
      spec:
        containers:
        - name: task
          resources:
            requests:
              cpu: 100m           # 合理的资源请求
              memory: 256Mi
            limits:
              cpu: 500m           # 避免资源耗尽
              memory: 512Mi
```

### 3. 错误处理

```yaml
spec:
  failedJobsHistoryLimit: 3       # 保留失败历史便于调试
  jobTemplate:
    spec:
      backoffLimit: 2             # 合理的重试次数
```

### 4. 清理策略

```yaml
spec:
  successfulJobsHistoryLimit: 3   # 限制成功 Job 数量
  failedJobsHistoryLimit: 1       # 限制失败 Job 数量
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 100  # 自动清理已完成的 Job
```

### 5. 安全配置

```yaml
jobTemplate:
  spec:
    template:
      spec:
        serviceAccountName: cronjob-sa
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
        containers:
        - name: task
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
```