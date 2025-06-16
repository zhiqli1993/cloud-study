# Kubernetes 节点故障排查

## 概述

节点是 Kubernetes 集群的工作基础，包括 Master 节点和 Worker 节点。节点故障会影响 Pod 的调度和运行，是集群运维中的重要问题。

## 节点状态监控

### 节点状态检查

```bash
#!/bin/bash
# 节点状态检查脚本

NODE_NAME=${1:-$(hostname)}

echo "=== 节点故障排查 ==="
echo "节点名称: $NODE_NAME"

# 1. 检查节点基本状态
echo -e "\n1. 节点基本状态："
kubectl get node $NODE_NAME -o wide

# 2. 检查节点详细信息
echo -e "\n2. 节点详细信息："
kubectl describe node $NODE_NAME

# 3. 检查节点资源使用
echo -e "\n3. 节点资源使用："
kubectl top node $NODE_NAME

# 4. 检查节点标签和污点
echo -e "\n4. 节点标签："
kubectl get node $NODE_NAME --show-labels

echo -e "\n5. 节点污点："
kubectl describe node $NODE_NAME | grep -A 10 "Taints:"

# 6. 检查节点上的 Pod
echo -e "\n6. 节点上的 Pod："
kubectl get pods --all-namespaces --field-selector spec.nodeName=$NODE_NAME

# 7. 检查节点事件
echo -e "\n7. 节点相关事件："
kubectl get events --all-namespaces --field-selector involvedObject.name=$NODE_NAME
```

### 节点状态分类

```yaml
# 节点状态说明
node_conditions:
  Ready:
    description: "节点健康且可以接受 Pod"
    true: "节点正常工作"
    false: "节点有问题，不能接受新 Pod"
    unknown: "节点控制器在 40 秒内没有收到节点的心跳"
    
  OutOfDisk:
    description: "节点磁盘空间不足"
    true: "节点磁盘空间不足"
    false: "节点有足够的磁盘空间"
    
  MemoryPressure:
    description: "节点内存压力"
    true: "节点内存不足"
    false: "节点内存充足"
    
  DiskPressure:
    description: "节点磁盘压力"
    true: "节点磁盘空间或 inode 不足"
    false: "节点磁盘空间和 inode 充足"
    
  PIDPressure:
    description: "节点 PID 压力"
    true: "节点上进程数过多"
    false: "节点进程数正常"
    
  NetworkUnavailable:
    description: "节点网络不可用"
    true: "节点网络配置不正确"
    false: "节点网络配置正确"
```

## kubelet 故障排查

### kubelet 状态检查

```bash
#!/bin/bash
# kubelet 故障排查脚本

NODE_NAME=${1:-$(hostname)}

echo "=== kubelet 故障排查 ==="
echo "节点: $NODE_NAME"

# 1. 检查 kubelet 服务状态
echo "1. kubelet 服务状态："
systemctl status kubelet

# 2. 检查 kubelet 日志
echo -e "\n2. kubelet 日志（最近50行）："
journalctl -u kubelet -n 50 --no-pager

# 3. 检查 kubelet 配置
echo -e "\n3. kubelet 配置："
cat /var/lib/kubelet/config.yaml

# 4. 检查 kubelet 证书
echo -e "\n4. kubelet 证书状态："
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -text -noout | grep -A 2 "Validity"

# 5. 检查容器运行时连接
echo -e "\n5. 容器运行时连接："
systemctl status containerd
crictl version

# 6. 检查 kubelet 端口
echo -e "\n6. kubelet 监听端口："
netstat -tlnp | grep :10250

# 7. 检查磁盘空间
echo -e "\n7. 磁盘空间检查："
df -h
df -i

# 8. 检查内存使用
echo -e "\n8. 内存使用情况："
free -h

# 9. 检查系统负载
echo -e "\n9. 系统负载："
uptime
```

### kubelet 常见问题

```yaml
# kubelet 常见问题诊断
kubelet_issues:
  failed_to_start:
    symptoms:
      - "kubelet service failed to start"
      - "kubelet process not running"
    causes:
      - "配置文件错误"
      - "证书问题"
      - "权限不足"
    solutions:
      - "检查配置文件语法"
      - "验证证书有效性"
      - "检查文件权限"
      
  certificate_expired:
    symptoms:
      - "certificate has expired"
      - "x509: certificate signed by unknown authority"
    causes:
      - "kubelet 证书过期"
      - "CA 证书不匹配"
    solutions:
      - "重新生成 kubelet 证书"
      - "更新 CA 证书"
      - "重启 kubelet 服务"
      
  disk_pressure:
    symptoms:
      - "disk pressure detected"
      - "evicting pods due to disk pressure"
    causes:
      - "磁盘空间不足"
      - "inode 不足"
    solutions:
      - "清理磁盘空间"
      - "删除无用的镜像和容器"
      - "增加磁盘容量"
      
  memory_pressure:
    symptoms:
      - "memory pressure detected"
      - "evicting pods due to memory pressure"
    causes:
      - "内存不足"
      - "内存泄漏"
    solutions:
      - "增加内存"
      - "优化 Pod 资源限制"
      - "重启内存泄漏的进程"
```

## 容器运行时故障

### containerd 故障排查

```bash
#!/bin/bash
# containerd 故障排查脚本

echo "=== containerd 故障排查 ==="

# 1. 检查 containerd 服务状态
echo "1. containerd 服务状态："
systemctl status containerd

# 2. 检查 containerd 日志
echo -e "\n2. containerd 日志："
journalctl -u containerd -n 50 --no-pager

# 3. 检查 containerd 配置
echo -e "\n3. containerd 配置："
cat /etc/containerd/config.toml

# 4. 检查容器列表
echo -e "\n4. 运行中的容器："
crictl ps

# 5. 检查镜像列表
echo -e "\n5. 本地镜像："
crictl images

# 6. 检查容器运行时版本
echo -e "\n6. 运行时版本："
crictl version

# 7. 检查 containerd 插件
echo -e "\n7. containerd 插件："
ctr plugins ls

# 8. 检查网络插件
echo -e "\n8. CNI 网络插件："
ls -la /opt/cni/bin/
cat /etc/cni/net.d/*.conf 2>/dev/null || echo "未找到 CNI 配置"

# 9. 检查存储驱动
echo -e "\n9. 存储信息："
ctr content ls | head -10
```

### Docker 故障排查（如果使用 Docker）

```bash
#!/bin/bash
# Docker 故障排查脚本

echo "=== Docker 故障排查 ==="

# 1. 检查 Docker 服务状态
echo "1. Docker 服务状态："
systemctl status docker

# 2. 检查 Docker 日志
echo -e "\n2. Docker 日志："
journalctl -u docker -n 50 --no-pager

# 3. 检查 Docker 信息
echo -e "\n3. Docker 系统信息："
docker info

# 4. 检查 Docker 版本
echo -e "\n4. Docker 版本："
docker version

# 5. 检查运行中的容器
echo -e "\n5. 运行中的容器："
docker ps

# 6. 检查 Docker 镜像
echo -e "\n6. Docker 镜像："
docker images

# 7. 检查 Docker 网络
echo -e "\n7. Docker 网络："
docker network ls

# 8. 检查 Docker 存储
echo -e "\n8. Docker 存储使用："
docker system df

# 9. 检查 Docker 事件
echo -e "\n9. Docker 最近事件："
docker events --since 1h --until now
```

## 网络相关故障

### 节点网络诊断

```bash
#!/bin/bash
# 节点网络诊断脚本

NODE_NAME=${1:-$(hostname)}

echo "=== 节点网络诊断 ==="
echo "节点: $NODE_NAME"

# 1. 检查网络接口
echo "1. 网络接口状态："
ip addr show

# 2. 检查路由表
echo -e "\n2. 路由表："
ip route show

# 3. 检查 DNS 配置
echo -e "\n3. DNS 配置："
cat /etc/resolv.conf

# 4. 测试外网连接
echo -e "\n4. 外网连接测试："
ping -c 3 8.8.8.8

# 5. 测试 DNS 解析
echo -e "\n5. DNS 解析测试："
nslookup kubernetes.default.svc.cluster.local

# 6. 检查防火墙状态
echo -e "\n6. 防火墙状态："
iptables -L INPUT | head -10
systemctl status firewalld 2>/dev/null || echo "firewalld 未运行"

# 7. 检查网络端口
echo -e "\n7. 监听端口："
netstat -tlnp | grep -E "(10250|10255|30000|6443)"

# 8. 检查 CNI 插件
echo -e "\n8. CNI 插件状态："
ls -la /opt/cni/bin/
cat /etc/cni/net.d/*.conf 2>/dev/null | head -20

# 9. 检查 kube-proxy
echo -e "\n9. kube-proxy 状态："
kubectl get pods -n kube-system | grep kube-proxy
```

### CNI 网络插件故障

```bash
#!/bin/bash
# CNI 网络插件故障排查

echo "=== CNI 网络插件故障排查 ==="

# 1. 检查 CNI 插件文件
echo "1. CNI 插件文件："
ls -la /opt/cni/bin/

# 2. 检查 CNI 配置
echo -e "\n2. CNI 配置文件："
find /etc/cni/net.d/ -name "*.conf" -o -name "*.conflist" | head -5 | xargs cat

# 3. 检查网络 Pod 状态
echo -e "\n3. 网络相关 Pod 状态："
kubectl get pods -n kube-system | grep -E "(calico|flannel|weave|cilium)"

# 4. 检查网络 Pod 日志
echo -e "\n4. 网络 Pod 日志："
NETWORK_POD=$(kubectl get pods -n kube-system | grep -E "(calico|flannel|weave|cilium)" | head -1 | awk '{print $1}')
if [ "$NETWORK_POD" != "" ]; then
    kubectl logs -n kube-system $NETWORK_POD --tail=20
fi

# 5. 检查节点网络状态
echo -e "\n5. 节点网络接口："
ip addr show | grep -E "(cali|flannel|weave|cilium)"

# 6. 测试 Pod 间网络连通性
echo -e "\n6. 创建网络测试 Pod："
kubectl run net-test-1 --image=busybox --command -- sleep 3600 --restart=Never
kubectl run net-test-2 --image=busybox --command -- sleep 3600 --restart=Never

# 等待 Pod 启动
sleep 10

# 获取 Pod IP
POD1_IP=$(kubectl get pod net-test-1 -o jsonpath='{.status.podIP}')
POD2_IP=$(kubectl get pod net-test-2 -o jsonpath='{.status.podIP}')

echo "测试 Pod IP: $POD1_IP, $POD2_IP"

# 测试连通性
if [ "$POD1_IP" != "" ] && [ "$POD2_IP" != "" ]; then
    kubectl exec net-test-1 -- ping -c 3 $POD2_IP
fi

# 清理测试 Pod
kubectl delete pod net-test-1 net-test-2 --force --grace-period=0
```

## 存储相关故障

### 节点存储诊断

```bash
#!/bin/bash
# 节点存储诊断脚本

echo "=== 节点存储诊断 ==="

# 1. 检查磁盘空间
echo "1. 磁盘空间使用："
df -h

# 2. 检查 inode 使用
echo -e "\n2. inode 使用情况："
df -i

# 3. 检查大文件
echo -e "\n3. 大文件检查（大于100MB）："
find / -type f -size +100M 2>/dev/null | head -10

# 4. 检查 kubelet 数据目录
echo -e "\n4. kubelet 数据目录："
du -sh /var/lib/kubelet/

# 5. 检查容器存储
echo -e "\n5. 容器存储使用："
if command -v docker &> /dev/null; then
    docker system df
elif command -v crictl &> /dev/null; then
    crictl images | awk 'NR>1 {sum+=$3} END {print "Total size: " sum/1024/1024 " MB"}'
fi

# 6. 检查日志大小
echo -e "\n6. 日志目录大小："
du -sh /var/log/

# 7. 检查挂载点
echo -e "\n7. 挂载点信息："
mount | grep -E "(kubelet|docker|containerd)"

# 8. 检查存储相关进程
echo -e "\n8. 存储相关进程："
ps aux | grep -E "(kubelet|containerd|docker)" | grep -v grep

# 9. 检查磁盘 I/O
echo -e "\n9. 磁盘 I/O 统计："
iostat -x 1 3 2>/dev/null || echo "iostat 命令不可用"
```

### 清理节点存储

```bash
#!/bin/bash
# 节点存储清理脚本

echo "=== 节点存储清理 ==="

# 1. 清理容器镜像
echo "1. 清理未使用的容器镜像："
if command -v docker &> /dev/null; then
    docker image prune -f
    docker container prune -f
elif command -v crictl &> /dev/null; then
    crictl rmi --prune
fi

# 2. 清理日志文件
echo -e "\n2. 清理旧日志文件："
find /var/log -name "*.log" -mtime +7 -exec rm -f {} \;
journalctl --vacuum-time=7d

# 3. 清理临时文件
echo -e "\n3. 清理临时文件："
rm -rf /tmp/*
rm -rf /var/tmp/*

# 4. 清理 kubelet 缓存
echo -e "\n4. 清理 kubelet 缓存："
rm -rf /var/lib/kubelet/cpu_manager_state
rm -rf /var/lib/kubelet/memory_manager_state

# 5. 清理已完成的 Pod
echo -e "\n5. 清理已完成的 Pod："
kubectl get pods --all-namespaces --field-selector=status.phase=Succeeded -o name | xargs kubectl delete

# 6. 显示清理后的磁盘使用情况
echo -e "\n6. 清理后磁盘使用情况："
df -h
```

## 性能问题排查

### 节点性能分析

```bash
#!/bin/bash
# 节点性能分析脚本

echo "=== 节点性能分析 ==="

# 1. CPU 使用情况
echo "1. CPU 使用情况："
top -bn1 | head -20

# 2. 内存使用分析
echo -e "\n2. 内存使用分析："
free -h
cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable|Buffers|Cached)"

# 3. 磁盘 I/O 性能
echo -e "\n3. 磁盘 I/O 性能："
iostat -x 1 3 2>/dev/null || echo "iostat 不可用，使用 vmstat："
vmstat 1 3

# 4. 网络性能
echo -e "\n4. 网络统计："
cat /proc/net/dev | head -10

# 5. 进程资源使用 TOP 10
echo -e "\n5. CPU 使用最高的进程："
ps aux --sort=-%cpu | head -11

echo -e "\n6. 内存使用最高的进程："
ps aux --sort=-%mem | head -11

# 7. 文件描述符使用
echo -e "\n7. 文件描述符使用："
lsof | wc -l
echo "系统最大文件描述符数: $(cat /proc/sys/fs/file-max)"

# 8. 系统负载
echo -e "\n8. 系统负载历史："
uptime
cat /proc/loadavg

# 9. 检查系统瓶颈
echo -e "\n9. 系统瓶颈分析："
# CPU 负载
CPU_CORES=$(nproc)
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
if (( $(echo "$LOAD_AVG > $CPU_CORES" | bc -l) )); then
    echo "⚠️  CPU 负载较高: $LOAD_AVG (核心数: $CPU_CORES)"
fi

# 内存使用
MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')
if (( $(echo "$MEM_USAGE > 80" | bc -l) )); then
    echo "⚠️  内存使用率较高: ${MEM_USAGE}%"
fi

# 磁盘使用
df -h | awk 'NR>1 {if ($5+0 > 80) print "⚠️  磁盘使用率较高: " $5 " " $6}'
```

## 节点维护操作

### 节点排空和恢复

```bash
#!/bin/bash
# 节点维护脚本

NODE_NAME=$1
ACTION=$2

if [ -z "$NODE_NAME" ] || [ -z "$ACTION" ]; then
    echo "用法: $0 <node-name> <drain|uncordon|cordon>"
    exit 1
fi

case $ACTION in
    "drain")
        echo "=== 排空节点 $NODE_NAME ==="
        echo "1. 标记节点不可调度..."
        kubectl cordon $NODE_NAME
        
        echo "2. 驱逐节点上的 Pod..."
        kubectl drain $NODE_NAME --ignore-daemonsets --delete-emptydir-data --force
        
        echo "3. 验证节点状态..."
        kubectl get node $NODE_NAME
        kubectl get pods --all-namespaces --field-selector spec.nodeName=$NODE_NAME
        ;;
        
    "uncordon")
        echo "=== 恢复节点 $NODE_NAME ==="
        echo "1. 取消节点调度限制..."
        kubectl uncordon $NODE_NAME
        
        echo "2. 验证节点状态..."
        kubectl get node $NODE_NAME
        ;;
        
    "cordon")
        echo "=== 封锁节点 $NODE_NAME ==="
        echo "1. 标记节点不可调度..."
        kubectl cordon $NODE_NAME
        
        echo "2. 验证节点状态..."
        kubectl get node $NODE_NAME
        ;;
        
    *)
        echo "无效的操作: $ACTION"
        echo "支持的操作: drain, uncordon, cordon"
        exit 1
        ;;
esac
```

### 节点重启维护

```bash
#!/bin/bash
# 节点重启维护脚本

NODE_NAME=${1:-$(hostname)}

echo "=== 节点重启维护 ==="
echo "节点: $NODE_NAME"

# 1. 检查节点状态
echo "1. 当前节点状态："
kubectl get node $NODE_NAME

# 2. 排空节点
echo -e "\n2. 排空节点..."
kubectl cordon $NODE_NAME
kubectl drain $NODE_NAME --ignore-daemonsets --delete-emptydir-data --force --timeout=300s

# 3. 等待 Pod 迁移完成
echo -e "\n3. 等待 Pod 迁移完成..."
for i in {1..30}; do
    POD_COUNT=$(kubectl get pods --all-namespaces --field-selector spec.nodeName=$NODE_NAME | grep -v "DaemonSet" | wc -l)
    if [ $POD_COUNT -le 1 ]; then
        echo "Pod 迁移完成"
        break
    fi
    echo "等待 Pod 迁移... ($i/30)"
    sleep 10
done

# 4. 显示维护前状态
echo -e "\n4. 维护前系统状态："
systemctl status kubelet
systemctl status containerd

echo -e "\n节点已准备好进行维护操作（如重启、更新等）"
echo "维护完成后，请运行以下命令恢复节点："
echo "kubectl uncordon $NODE_NAME"
```

## 监控和告警

### 节点监控脚本

```bash
#!/bin/bash
# 节点监控脚本

NODE_NAME=${1:-$(hostname)}

while true; do
    echo "=== $(date) - 节点监控报告 ==="
    
    # 1. 节点状态
    kubectl get node $NODE_NAME --no-headers | awk '{print "节点状态: " $2}'
    
    # 2. 资源使用
    kubectl top node $NODE_NAME --no-headers | awk '{print "CPU: " $2 ", 内存: " $3}'
    
    # 3. Pod 数量
    POD_COUNT=$(kubectl get pods --all-namespaces --field-selector spec.nodeName=$NODE_NAME --no-headers | wc -l)
    echo "运行 Pod 数量: $POD_COUNT"
    
    # 4. 磁盘使用
    df -h / | tail -1 | awk '{print "磁盘使用: " $5}'
    
    # 5. 系统负载
    uptime | awk -F'load average:' '{print "系统负载: " $2}'
    
    echo "---"
    sleep 60
done
```

通过系统性的节点故障排查，可以快速识别和解决节点层面的各种问题，确保集群的稳定运行。
