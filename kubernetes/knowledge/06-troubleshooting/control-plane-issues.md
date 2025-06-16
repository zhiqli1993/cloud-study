# Kubernetes 控制平面故障排查

## 概述

控制平面是 Kubernetes 集群的核心组件，包括 API Server、etcd、Controller Manager 和 Scheduler。控制平面故障会直接影响整个集群的可用性和功能。

## API Server 故障排查

### 常见故障现象

**API Server 不可用**：
- kubectl 命令无响应或报错
- 集群管理界面无法访问
- 新的 Pod 无法创建或更新

**故障排查步骤**：

```bash
#!/bin/bash
# API Server 故障排查脚本

echo "=== API Server 故障排查 ==="

# 1. 检查 API Server 进程状态
echo "1. API Server 进程状态："
ps aux | grep kube-apiserver | grep -v grep

# 2. 检查 API Server 容器状态（如果使用静态 Pod）
echo -e "\n2. API Server 容器状态："
docker ps | grep kube-apiserver

# 3. 检查 API Server 日志
echo -e "\n3. API Server 日志（最近50行）："
docker logs $(docker ps | grep kube-apiserver | awk '{print $1}') --tail=50

# 4. 检查 API Server 监听端口
echo -e "\n4. API Server 监听端口："
netstat -tlnp | grep 6443

# 5. 检查 API Server 配置文件
echo -e "\n5. API Server 配置文件："
cat /etc/kubernetes/manifests/kube-apiserver.yaml

# 6. 测试 API Server 连通性
echo -e "\n6. API Server 连通性测试："
curl -k https://localhost:6443/healthz
```

### API Server 启动失败

**常见原因和解决方案**：

```yaml
# API Server 常见启动问题
startup_issues:
  certificate_problems:
    symptoms:
      - "certificate signed by unknown authority"
      - "x509: certificate has expired"
    solutions:
      - "检查证书有效期"
      - "重新生成过期证书"
      - "验证 CA 证书"
    
  etcd_connection_issues:
    symptoms:
      - "connection refused to etcd"
      - "etcd cluster unavailable"
    solutions:
      - "检查 etcd 服务状态"
      - "验证 etcd 连接配置"
      - "检查网络连接"
    
  configuration_errors:
    symptoms:
      - "unknown flag"
      - "invalid configuration"
    solutions:
      - "检查配置文件语法"
      - "验证参数兼容性"
      - "查看官方文档"
```

## etcd 故障排查

### etcd 集群健康检查

```bash
#!/bin/bash
# etcd 健康检查脚本

echo "=== etcd 集群健康检查 ==="

# 设置 etcd 环境变量
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key

# 1. 检查 etcd 成员列表
echo "1. etcd 集群成员："
etcdctl member list

# 2. 检查 etcd 健康状态
echo -e "\n2. etcd 集群健康状态："
etcdctl endpoint health --cluster

# 3. 检查 etcd 性能
echo -e "\n3. etcd 性能检查："
etcdctl check perf

# 4. 检查 etcd 状态
echo -e "\n4. etcd 端点状态："
etcdctl endpoint status --cluster -w table

# 5. 检查 etcd 告警
echo -e "\n5. etcd 告警信息："
etcdctl alarm list

# 6. 检查 etcd 数据大小
echo -e "\n6. etcd 数据库大小："
etcdctl endpoint status --cluster -w table | grep -E "DB SIZE|ENDPOINT"
```

### etcd 数据恢复

```bash
#!/bin/bash
# etcd 数据恢复脚本

BACKUP_FILE=$1
RESTORE_DIR="/var/lib/etcd-restore"

if [ -z "$BACKUP_FILE" ]; then
    echo "用法: $0 <backup-file>"
    exit 1
fi

echo "=== etcd 数据恢复 ==="
echo "备份文件: $BACKUP_FILE"
echo "恢复目录: $RESTORE_DIR"

# 1. 停止 etcd 服务
echo "1. 停止 etcd 服务..."
systemctl stop etcd

# 2. 备份当前数据
echo "2. 备份当前数据..."
mv /var/lib/etcd /var/lib/etcd.bak.$(date +%Y%m%d_%H%M%S)

# 3. 从快照恢复数据
echo "3. 从快照恢复数据..."
etcdctl snapshot restore $BACKUP_FILE \
  --data-dir=$RESTORE_DIR \
  --initial-cluster-token=etcd-cluster-1 \
  --initial-advertise-peer-urls=https://127.0.0.1:2380

# 4. 移动恢复的数据
echo "4. 移动恢复的数据..."
mv $RESTORE_DIR /var/lib/etcd

# 5. 修复权限
echo "5. 修复数据目录权限..."
chown -R etcd:etcd /var/lib/etcd

# 6. 启动 etcd 服务
echo "6. 启动 etcd 服务..."
systemctl start etcd

# 7. 验证恢复结果
echo "7. 验证恢复结果..."
sleep 10
etcdctl endpoint health
```

## Controller Manager 故障排查

### Controller Manager 状态检查

```bash
#!/bin/bash
# Controller Manager 故障排查

echo "=== Controller Manager 故障排查 ==="

# 1. 检查 Controller Manager Pod 状态
echo "1. Controller Manager Pod 状态："
kubectl get pods -n kube-system | grep controller-manager

# 2. 检查 Controller Manager 日志
echo -e "\n2. Controller Manager 日志："
kubectl logs -n kube-system kube-controller-manager-$(hostname) --tail=50

# 3. 检查 Controller Manager 配置
echo -e "\n3. Controller Manager 配置："
cat /etc/kubernetes/manifests/kube-controller-manager.yaml

# 4. 检查控制器状态
echo -e "\n4. 控制器工作状态："
curl -k https://localhost:10257/metrics | grep "workqueue_depth"

# 5. 检查 Leader Election
echo -e "\n5. Leader Election 状态："
kubectl get endpoints -n kube-system kube-controller-manager -o yaml
```

### Controller Manager 常见问题

```yaml
# Controller Manager 常见问题诊断
controller_issues:
  leader_election_failed:
    symptoms:
      - "failed to acquire leader lease"
      - "multiple controller managers running"
    diagnosis:
      - "检查网络连接"
      - "验证 RBAC 权限"
      - "检查 API Server 可用性"
    
  resource_sync_issues:
    symptoms:
      - "resources not updating"
      - "stuck in pending state"
    diagnosis:
      - "检查控制器日志"
      - "验证资源配置"
      - "检查 API Server 响应"
    
  performance_issues:
    symptoms:
      - "high CPU usage"
      - "memory leaks"
    diagnosis:
      - "调整工作队列大小"
      - "优化控制器参数"
      - "监控资源使用"
```

## Scheduler 故障排查

### Scheduler 状态检查

```bash
#!/bin/bash
# Scheduler 故障排查

echo "=== Scheduler 故障排查 ==="

# 1. 检查 Scheduler Pod 状态
echo "1. Scheduler Pod 状态："
kubectl get pods -n kube-system | grep scheduler

# 2. 检查 Scheduler 日志
echo -e "\n2. Scheduler 日志："
kubectl logs -n kube-system kube-scheduler-$(hostname) --tail=50

# 3. 检查待调度的 Pod
echo -e "\n3. 待调度的 Pod："
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# 4. 检查节点可调度性
echo -e "\n4. 节点可调度性："
kubectl get nodes -o wide

# 5. 检查调度事件
echo -e "\n5. 调度相关事件："
kubectl get events --all-namespaces | grep -E "(Schedule|FailedScheduling)"
```

### Scheduler 性能优化

```yaml
# Scheduler 性能优化配置
apiVersion: kubescheduler.config.k8s.io/v1beta3
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: default-scheduler
  plugins:
    # 启用有用的插件
    filter:
      enabled:
      - name: NodeResourcesFit
      - name: NodeAffinity
      - name: PodTopologySpread
    score:
      enabled:
      - name: NodeResourcesFit
      - name: NodeAffinity
      - name: PodTopologySpread
  
  # 调度性能参数
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: LeastAllocated
        resources:
        - name: cpu
          weight: 1
        - name: memory
          weight: 1

# 高级调度选项
leaderElection:
  leaderElect: true
  leaseDuration: 15s
  renewDeadline: 10s
  retryPeriod: 2s
  
clientConnection:
  kubeconfig: /etc/kubernetes/scheduler.conf
  qps: 100
  burst: 100
```

## 控制平面高可用故障

### 负载均衡器故障

```bash
#!/bin/bash
# 负载均衡器故障排查

LOAD_BALANCER_IP=$1

echo "=== 负载均衡器故障排查 ==="
echo "负载均衡器 IP: $LOAD_BALANCER_IP"

# 1. 检查负载均衡器连通性
echo "1. 负载均衡器连通性："
curl -k https://$LOAD_BALANCER_IP:6443/healthz

# 2. 检查后端服务器状态
echo -e "\n2. 后端 API Server 状态："
for server in api-server-1 api-server-2 api-server-3; do
    echo "检查 $server:"
    curl -k https://$server:6443/healthz
done

# 3. 检查负载均衡配置
echo -e "\n3. 负载均衡配置："
# 这里需要根据实际使用的负载均衡器调整
# 例如 HAProxy、Nginx、云负载均衡器等

# 4. 检查 DNS 解析
echo -e "\n4. DNS 解析："
nslookup $LOAD_BALANCER_IP
```

### 控制平面组件重启

```bash
#!/bin/bash
# 控制平面组件重启脚本

COMPONENT=$1

case $COMPONENT in
  "apiserver")
    echo "重启 API Server..."
    docker restart $(docker ps | grep kube-apiserver | awk '{print $1}')
    ;;
  "etcd")
    echo "重启 etcd..."
    systemctl restart etcd
    ;;
  "controller-manager")
    echo "重启 Controller Manager..."
    docker restart $(docker ps | grep kube-controller-manager | awk '{print $1}')
    ;;
  "scheduler")
    echo "重启 Scheduler..."
    docker restart $(docker ps | grep kube-scheduler | awk '{print $1}')
    ;;
  "all")
    echo "重启所有控制平面组件..."
    systemctl restart etcd
    sleep 10
    docker restart $(docker ps | grep -E "kube-(apiserver|controller-manager|scheduler)" | awk '{print $1}')
    ;;
  *)
    echo "用法: $0 {apiserver|etcd|controller-manager|scheduler|all}"
    exit 1
    ;;
esac

echo "等待组件重启..."
sleep 30

echo "检查组件状态："
kubectl get componentstatuses
```

## 监控和告警

### 控制平面监控指标

```yaml
# Prometheus 控制平面监控规则
groups:
- name: control-plane
  rules:
  # API Server 监控
  - alert: APIServerDown
    expr: up{job="kubernetes-apiservers"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "API Server is down"
      
  - alert: APIServerHighLatency
    expr: apiserver_request_duration_seconds{quantile="0.99"} > 1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "API Server high latency"
      
  # etcd 监控
  - alert: EtcdDown
    expr: up{job="etcd"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "etcd is down"
      
  - alert: EtcdHighLatency
    expr: etcd_disk_wal_fsync_duration_seconds{quantile="0.99"} > 0.5
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "etcd high disk latency"
      
  # Controller Manager 监控
  - alert: ControllerManagerDown
    expr: up{job="kube-controller-manager"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Controller Manager is down"
      
  # Scheduler 监控
  - alert: SchedulerDown
    expr: up{job="kube-scheduler"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Scheduler is down"
```

### 控制平面健康检查脚本

```bash
#!/bin/bash
# 控制平面健康检查脚本

echo "=== Kubernetes 控制平面健康检查 ==="

# 1. 检查所有控制平面组件
echo "1. 控制平面组件状态："
kubectl get componentstatuses

# 2. 检查 API Server
echo -e "\n2. API Server 健康检查："
curl -k https://localhost:6443/healthz

# 3. 检查 etcd
echo -e "\n3. etcd 健康检查："
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

# 4. 检查控制平面 Pod
echo -e "\n4. 控制平面 Pod 状态："
kubectl get pods -n kube-system | grep -E "(apiserver|etcd|controller|scheduler)"

# 5. 检查节点状态
echo -e "\n5. 节点状态："
kubectl get nodes

# 6. 检查关键资源
echo -e "\n6. 关键资源状态："
kubectl get pods --all-namespaces | grep -E "(Pending|Error|CrashLoopBackOff)"

echo -e "\n=== 健康检查完成 ==="
```

通过系统性的控制平面故障排查，可以快速识别和解决影响集群稳定性的关键问题。
