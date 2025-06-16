# 容器调试的高级技术

## 概述

容器调试是 Kubernetes 故障排查的核心技能。本文档介绍了各种高级的容器调试技术，包括传统方法和 Kubernetes 1.23+ 引入的新特性。

## 传统容器调试方法

### 使用 kubectl exec 调试

```bash
# 进入运行中的容器
kubectl exec -it <pod-name> -- /bin/bash
kubectl exec -it <pod-name> -- /bin/sh

# 多容器 Pod 中指定容器
kubectl exec -it <pod-name> -c <container-name> -- /bin/bash

# 执行调试命令
kubectl exec <pod-name> -- ps aux
kubectl exec <pod-name> -- netstat -tlnp
kubectl exec <pod-name> -- df -h
kubectl exec <pod-name> -- env
```

### 创建调试 Sidecar 容器

```yaml
# 在现有 Pod 中添加调试容器
apiVersion: v1
kind: Pod
metadata:
  name: app-with-debug
spec:
  containers:
  - name: app
    image: myapp:latest
    ports:
    - containerPort: 8080
  - name: debug
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: shared-data
      mountPath: /shared
  volumes:
  - name: shared-data
    emptyDir: {}
```

## 临时容器 (Ephemeral Containers)

### 临时容器概念

临时容器是 Kubernetes 1.23+ 的新特性，允许在运行中的 Pod 中添加临时的调试容器。

```bash
# 启用临时容器功能
# 需要在 kube-apiserver 中设置: --feature-gates=EphemeralContainers=true

# 添加临时容器到现有 Pod
kubectl debug <pod-name> -it --image=busybox --target=<container-name>

# 使用不同的镜像进行调试
kubectl debug <pod-name> -it --image=nicolaka/netshoot --target=<container-name>
```

### 临时容器示例

```yaml
# 手动创建临时容器规范
apiVersion: v1
kind: EphemeralContainers
metadata:
  name: myapp-pod
ephemeralContainers:
- name: debugger
  image: busybox
  command: ['sh']
  stdin: true
  tty: true
  targetContainerName: myapp
```

```bash
# 应用临时容器
kubectl patch pod myapp-pod --subresource ephemeralcontainers --patch-file=ephemeral-container.yaml

# 连接到临时容器
kubectl attach myapp-pod -c debugger -it
```

## kubectl debug 命令

### 基础用法

```bash
# 调试 Pod（创建调试容器）
kubectl debug <pod-name> -it --image=busybox

# 指定目标容器
kubectl debug <pod-name> -it --image=busybox --target=<container-name>

# 调试节点
kubectl debug node/<node-name> -it --image=busybox

# 复制 Pod 进行调试
kubectl debug <pod-name> -it --copy-to=<new-pod-name> --container=debug --image=busybox
```

### 高级调试选项

```bash
# 使用特权模式调试
kubectl debug node/<node-name> -it --image=busybox -- chroot /host

# 使用网络调试工具
kubectl debug <pod-name> -it --image=nicolaka/netshoot

# 共享进程命名空间
kubectl debug <pod-name> -it --image=busybox --share-processes --copy-to=debug-copy

# 设置环境变量
kubectl debug <pod-name> -it --image=busybox --env="DEBUG=true"
```

## 专用调试镜像

### 网络调试镜像

```bash
# nicolaka/netshoot - 综合网络调试工具
kubectl run netshoot --rm -i --tty --image nicolaka/netshoot -- /bin/bash

# 包含的工具：
# - ping, traceroute, nslookup, dig
# - curl, wget, telnet, netcat
# - tcpdump, nmap, iperf3
# - ss, netstat, lsof
```

### 系统调试镜像

```bash
# busybox - 轻量级 Unix 工具集
kubectl run busybox --rm -i --tty --image busybox -- /bin/sh

# alpine - 包含更多工具的轻量级发行版
kubectl run alpine --rm -i --tty --image alpine -- /bin/sh

# ubuntu - 完整的调试环境
kubectl run ubuntu --rm -i --tty --image ubuntu -- /bin/bash
```

### 性能分析镜像

```bash
# brendangregg/perf-tools - 性能分析工具
kubectl run perf-tools --rm -i --tty --image brendangregg/perf-tools --privileged

# prom/node-exporter - 系统指标收集
kubectl run node-exporter --rm -i --tty --image prom/node-exporter
```

## 容器文件系统调试

### 文件系统挂载调试

```bash
# 检查容器内挂载点
kubectl exec <pod-name> -- mount | grep -v "tmpfs\|proc\|sys"

# 检查磁盘使用
kubectl exec <pod-name> -- df -h

# 检查 inode 使用
kubectl exec <pod-name> -- df -i

# 查看具体目录大小
kubectl exec <pod-name> -- du -sh /var/log
kubectl exec <pod-name> -- du -sh /tmp
```

### 卷和存储调试

```yaml
# 调试存储问题的测试 Pod
apiVersion: v1
kind: Pod
metadata:
  name: volume-debug
spec:
  containers:
  - name: debugger
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: test-volume
      mountPath: /test-mount
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-pvc
```

## 网络调试技术

### 容器网络诊断

```bash
# 创建网络调试 Pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: network-debug
spec:
  containers:
  - name: netshoot
    image: nicolaka/netshoot
    command: ['sleep', '3600']
  hostNetwork: false  # 使用 Pod 网络
EOF

# 进入网络调试容器
kubectl exec -it network-debug -- bash

# 网络诊断命令
kubectl exec network-debug -- ip addr show
kubectl exec network-debug -- ip route show
kubectl exec network-debug -- netstat -tlnp
kubectl exec network-debug -- ss -tlnp
```

### 跨容器网络测试

```bash
# 创建服务端测试容器
kubectl run server --image=nginx --port=80

# 创建客户端测试容器
kubectl run client --image=busybox --command -- sleep 3600

# 获取服务端 IP
SERVER_IP=$(kubectl get pod server -o jsonpath='{.status.podIP}')

# 测试连通性
kubectl exec client -- ping -c 3 $SERVER_IP
kubectl exec client -- wget -qO- http://$SERVER_IP

# 端口扫描
kubectl exec client -- nc -zv $SERVER_IP 80
```

## 性能调试和分析

### 容器资源使用分析

```bash
# 实时查看容器资源使用
kubectl top pods --containers

# 详细资源信息
kubectl describe pod <pod-name> | grep -A 10 "Requests:\|Limits:"

# 容器内进程分析
kubectl exec <pod-name> -- top -n 1
kubectl exec <pod-name> -- ps aux --sort=-%cpu
kubectl exec <pod-name> -- ps aux --sort=-%mem
```

### 性能分析工具

```bash
# 使用 htop 进行进程监控
kubectl exec -it <pod-name> -- htop

# 使用 iotop 监控 I/O
kubectl exec -it <pod-name> -- iotop

# 使用 strace 跟踪系统调用
kubectl exec -it <pod-name> -- strace -p <pid>

# 使用 tcpdump 抓包分析
kubectl exec -it <pod-name> -- tcpdump -i eth0 -w capture.pcap
```

## 故障容器调试

### 崩溃容器分析

```bash
# 查看崩溃容器的日志
kubectl logs <pod-name> --previous

# 查看容器退出代码
kubectl describe pod <pod-name> | grep "Exit Code"

# 查看容器重启次数
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[0].restartCount}'
```

### 无法启动的容器调试

```yaml
# 修改容器命令进行调试
apiVersion: v1
kind: Pod
metadata:
  name: debug-failing-app
spec:
  containers:
  - name: app
    image: failing-app:latest
    command: ['sleep', '3600']  # 覆盖原始命令
    # 或者使用调试模式
    args: ['--debug', '--verbose']
```

### Init 容器调试

```bash
# 查看 Init 容器日志
kubectl logs <pod-name> -c <init-container-name>

# 查看 Init 容器状态
kubectl describe pod <pod-name> | grep -A 10 "Init Containers:"
```

## 调试工具集成

### 集成调试工具的 Dockerfile

```dockerfile
# 创建包含调试工具的基础镜像
FROM alpine:latest

# 安装常用调试工具
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    netcat-openbsd \
    bind-tools \
    tcpdump \
    strace \
    htop \
    iotop \
    lsof \
    procps \
    util-linux

# 安装网络工具
RUN apk add --no-cache \
    iperf3 \
    mtr \
    nmap \
    socat

# 设置工作目录
WORKDIR /debug

# 默认启动 bash
CMD ["/bin/bash"]
```

### 多阶段构建调试镜像

```dockerfile
# 生产镜像（精简）
FROM alpine:latest as production
COPY app /usr/local/bin/app
CMD ["/usr/local/bin/app"]

# 调试镜像（包含调试工具）
FROM production as debug
RUN apk add --no-cache bash curl wget netcat-openbsd bind-tools tcpdump
```

## 调试脚本和自动化

### 容器健康检查脚本

```bash
#!/bin/bash
# 容器健康检查脚本

POD_NAME=$1
NAMESPACE=${2:-default}

echo "=== 容器健康检查 ==="
echo "Pod: $POD_NAME"
echo "Namespace: $NAMESPACE"

# 1. 容器状态
echo -e "\n1. 容器状态："
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[*].state}' | jq .

# 2. 容器资源使用
echo -e "\n2. 容器资源使用："
kubectl top pod $POD_NAME -n $NAMESPACE --containers 2>/dev/null || echo "Metrics 不可用"

# 3. 容器内进程
echo -e "\n3. 容器内进程："
kubectl exec $POD_NAME -n $NAMESPACE -- ps aux | head -10

# 4. 容器网络状态
echo -e "\n4. 容器网络状态："
kubectl exec $POD_NAME -n $NAMESPACE -- netstat -tlnp 2>/dev/null || echo "netstat 不可用"

# 5. 容器文件系统
echo -e "\n5. 容器文件系统："
kubectl exec $POD_NAME -n $NAMESPACE -- df -h
```

### 自动化调试部署

```yaml
# 调试工具 DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: debug-toolkit
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: debug-toolkit
  template:
    metadata:
      labels:
        name: debug-toolkit
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: debug
        image: nicolaka/netshoot
        command: ['sleep', '86400']
        securityContext:
          privileged: true
        volumeMounts:
        - name: host-root
          mountPath: /host
          readOnly: true
      volumes:
      - name: host-root
        hostPath:
          path: /
      tolerations:
      - operator: Exists
        effect: NoSchedule
```

## 调试最佳实践

### 调试流程

1. **收集基础信息**
   ```bash
   kubectl get pod <pod-name> -o wide
   kubectl describe pod <pod-name>
   kubectl logs <pod-name>
   ```

2. **网络连通性测试**
   ```bash
   kubectl exec <pod-name> -- ping 8.8.8.8
   kubectl exec <pod-name> -- nslookup kubernetes.default.svc.cluster.local
   ```

3. **资源使用分析**
   ```bash
   kubectl top pod <pod-name> --containers
   kubectl exec <pod-name> -- top -n 1
   ```

4. **深入分析**
   ```bash
   kubectl debug <pod-name> -it --image=nicolaka/netshoot
   ```

### 安全注意事项

- 避免在生产环境中使用特权容器
- 调试完成后及时清理调试资源
- 使用最小权限原则
- 注意调试工具可能暴露敏感信息

通过掌握这些高级容器调试技术，可以更有效地诊断和解决 Kubernetes 环境中的容器问题。
