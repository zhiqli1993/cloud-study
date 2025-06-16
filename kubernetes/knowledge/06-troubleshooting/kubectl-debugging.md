# kubectl 调试命令大全

## 概述

kubectl 是 Kubernetes 集群管理的核心工具，掌握其调试命令对于故障排查至关重要。本文档提供了完整的 kubectl 调试命令参考。

## 基础查看命令

### 集群状态查看

```bash
# 集群信息
kubectl cluster-info
kubectl cluster-info dump  # 详细集群信息

# 版本信息
kubectl version
kubectl version --short

# 组件状态
kubectl get componentstatuses
kubectl get cs  # 简写

# 节点信息
kubectl get nodes
kubectl get nodes -o wide
kubectl describe node <node-name>
kubectl top nodes
```

### 资源查看命令

```bash
# 查看所有资源
kubectl get all
kubectl get all --all-namespaces
kubectl get all -A  # 简写

# 查看特定资源
kubectl get pods
kubectl get pods -o wide
kubectl get pods --show-labels
kubectl get pods -l app=nginx  # 标签选择器
kubectl get pods --field-selector=status.phase=Running

# 查看资源详情
kubectl describe pod <pod-name>
kubectl describe pod <pod-name> -n <namespace>

# 查看资源 YAML
kubectl get pod <pod-name> -o yaml
kubectl get pod <pod-name> -o json
```

## Pod 调试命令

### Pod 状态诊断

```bash
# Pod 基础信息
kubectl get pods -o wide --show-labels
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get pods --sort-by=.status.startTime

# Pod 详细描述
kubectl describe pod <pod-name>
kubectl describe pod <pod-name> -n <namespace>

# Pod 事件查看
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector involvedObject.name=<pod-name>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Pod 状态筛选
kubectl get pods --field-selector=status.phase=Pending
kubectl get pods --field-selector=status.phase=Failed
kubectl get pods --field-selector=status.phase=Running
```

### Pod 日志查看

```bash
# 基础日志查看
kubectl logs <pod-name>
kubectl logs <pod-name> -n <namespace>

# 多容器 Pod 日志
kubectl logs <pod-name> -c <container-name>

# 实时日志
kubectl logs -f <pod-name>
kubectl logs -f <pod-name> -c <container-name>

# 历史日志
kubectl logs <pod-name> --previous
kubectl logs <pod-name> --previous -c <container-name>

# 日志过滤
kubectl logs <pod-name> --tail=100
kubectl logs <pod-name> --since=1h
kubectl logs <pod-name> --since-time='2023-01-01T00:00:00Z'

# 多 Pod 日志
kubectl logs -l app=nginx  # 标签选择器
kubectl logs -l app=nginx -f --max-log-requests=10
```

### Pod 执行命令

```bash
# 进入 Pod
kubectl exec -it <pod-name> -- /bin/bash
kubectl exec -it <pod-name> -- /bin/sh
kubectl exec -it <pod-name> -c <container-name> -- /bin/bash

# 执行单次命令
kubectl exec <pod-name> -- ls -la
kubectl exec <pod-name> -- cat /etc/hostname
kubectl exec <pod-name> -- ps aux

# 在多容器 Pod 中执行命令
kubectl exec <pod-name> -c <container-name> -- command

# 执行命令并获取输出
kubectl exec <pod-name> -- env | grep PATH
kubectl exec <pod-name> -- df -h
kubectl exec <pod-name> -- netstat -tlnp
```

### Pod 文件操作

```bash
# 文件拷贝
kubectl cp <pod-name>:/path/to/file ./local-file
kubectl cp ./local-file <pod-name>:/path/to/file
kubectl cp <pod-name>:/path/to/file ./local-file -c <container-name>

# 目录拷贝
kubectl cp <pod-name>:/path/to/dir ./local-dir
kubectl cp ./local-dir <pod-name>:/path/to/dir

# 查看文件内容
kubectl exec <pod-name> -- cat /etc/resolv.conf
kubectl exec <pod-name> -- tail -f /var/log/app.log
```

## 服务和网络调试

### Service 调试

```bash
# Service 信息
kubectl get services
kubectl get svc -o wide
kubectl describe service <service-name>

# Endpoints 查看
kubectl get endpoints
kubectl describe endpoints <service-name>

# Service 端口转发
kubectl port-forward service/<service-name> 8080:80
kubectl port-forward pod/<pod-name> 8080:80

# Service 连通性测试
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh
# 在测试 Pod 中：
# nslookup <service-name>
# wget -qO- http://<service-name>:80
```

### 网络调试

```bash
# 网络策略查看
kubectl get networkpolicies
kubectl describe networkpolicy <policy-name>

# DNS 调试
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local

# 网络连通性测试
kubectl run netshoot --image=nicolaka/netshoot --rm -it --restart=Never -- bash
# 在 netshoot 容器中可使用各种网络工具：
# ping, nslookup, dig, curl, telnet, netstat, ss, tcpdump 等
```

## 资源使用和性能调试

### 资源使用查看

```bash
# 节点资源使用
kubectl top nodes
kubectl top nodes --sort-by=cpu
kubectl top nodes --sort-by=memory

# Pod 资源使用
kubectl top pods
kubectl top pods --all-namespaces
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory
kubectl top pods -n <namespace>

# 容器资源使用
kubectl top pods --containers
kubectl top pods <pod-name> --containers
```

### 资源配额和限制

```bash
# 资源配额
kubectl get resourcequota
kubectl describe resourcequota <quota-name>

# 限制范围
kubectl get limitrange
kubectl describe limitrange <limitrange-name>

# Pod 资源规格
kubectl describe pod <pod-name> | grep -A 10 "Requests:\|Limits:"
```

## 配置和密钥调试

### ConfigMap 调试

```bash
# ConfigMap 查看
kubectl get configmaps
kubectl describe configmap <configmap-name>
kubectl get configmap <configmap-name> -o yaml

# ConfigMap 内容查看
kubectl get configmap <configmap-name> -o jsonpath='{.data}'
```

### Secret 调试

```bash
# Secret 查看
kubectl get secrets
kubectl describe secret <secret-name>
kubectl get secret <secret-name> -o yaml

# Secret 解码
kubectl get secret <secret-name> -o jsonpath='{.data.username}' | base64 -d
kubectl get secret <secret-name> -o jsonpath='{.data.password}' | base64 -d
```

## 高级调试技术

### 调试模式和临时容器

```bash
# 调试已有 Pod（Kubernetes 1.25+）
kubectl debug <pod-name> -it --image=busybox

# 调试节点
kubectl debug node/<node-name> -it --image=busybox

# 创建调试 Pod 的副本
kubectl debug <pod-name> -it --copy-to=debug-pod --container=debug-container --image=busybox

# 临时容器（Ephemeral Container）
kubectl alpha debug <pod-name> -it --image=busybox --target=<container-name>
```

### 资源创建和测试

```bash
# 快速创建测试资源
kubectl create deployment test-nginx --image=nginx
kubectl expose deployment test-nginx --port=80 --type=ClusterIP

# 创建测试 Pod
kubectl run test-pod --image=busybox --command -- sleep 3600
kubectl run test-pod --image=nginx --port=80

# 临时运行命令
kubectl run test --image=busybox --rm -it --restart=Never -- sh
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- sh
```

## 日志和事件分析

### 事件调试

```bash
# 查看所有事件
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --sort-by='.firstTimestamp'

# 过滤事件
kubectl get events --field-selector type=Warning
kubectl get events --field-selector reason=Failed
kubectl get events --field-selector involvedObject.kind=Pod

# 持续监控事件
kubectl get events --watch
kubectl get events --watch-only
```

### 日志聚合查看

```bash
# 多 Pod 日志聚合
kubectl logs -l app=nginx --prefix=true
kubectl logs -l app=nginx --timestamps=true

# 日志输出格式
kubectl logs <pod-name> --output=json
kubectl logs <pod-name> | jq .

# 日志导出
kubectl logs <pod-name> > pod.log
kubectl logs -l app=nginx --prefix=true > app.log
```

## 排查脚本示例

### Pod 快速诊断脚本

```bash
#!/bin/bash
# Pod 快速诊断脚本

POD_NAME=$1
NAMESPACE=${2:-default}

if [ -z "$POD_NAME" ]; then
    echo "用法: $0 <pod-name> [namespace]"
    exit 1
fi

echo "=== Pod 快速诊断 ==="
echo "Pod: $POD_NAME"
echo "Namespace: $NAMESPACE"

# 1. Pod 基本信息
echo -e "\n1. Pod 基本信息："
kubectl get pod $POD_NAME -n $NAMESPACE -o wide

# 2. Pod 状态详情
echo -e "\n2. Pod 状态详情："
kubectl describe pod $POD_NAME -n $NAMESPACE

# 3. Pod 日志
echo -e "\n3. Pod 日志（最后20行）："
kubectl logs $POD_NAME -n $NAMESPACE --tail=20

# 4. Pod 事件
echo -e "\n4. 相关事件："
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$POD_NAME

# 5. 资源使用
echo -e "\n5. 资源使用："
kubectl top pod $POD_NAME -n $NAMESPACE 2>/dev/null || echo "Metrics Server 不可用"

# 6. 网络测试
echo -e "\n6. 网络连通性测试："
kubectl exec $POD_NAME -n $NAMESPACE -- ping -c 3 8.8.8.8 2>/dev/null || echo "网络测试失败或 Pod 不支持 ping"
```

### 集群健康检查脚本

```bash
#!/bin/bash
# 集群健康检查脚本

echo "=== Kubernetes 集群健康检查 ==="

# 1. 集群基本信息
echo "1. 集群信息："
kubectl cluster-info

# 2. 节点状态
echo -e "\n2. 节点状态："
kubectl get nodes

# 3. 组件状态
echo -e "\n3. 组件状态："
kubectl get componentstatuses

# 4. 系统 Pod 状态
echo -e "\n4. 系统 Pod 状态："
kubectl get pods -n kube-system

# 5. 异常 Pod 统计
echo -e "\n5. 异常 Pod 统计："
kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded

# 6. 资源使用概览
echo -e "\n6. 资源使用概览："
kubectl top nodes 2>/dev/null || echo "Metrics Server 不可用"

# 7. 持久卷状态
echo -e "\n7. 持久卷状态："
kubectl get pv,pvc --all-namespaces

# 8. 最近事件
echo -e "\n8. 最近事件（Warning）："
kubectl get events --all-namespaces --field-selector type=Warning --sort-by='.lastTimestamp' | tail -10
```

## 性能分析和优化

### 性能诊断命令

```bash
# API Server 性能
kubectl get --raw /metrics | grep apiserver

# etcd 性能
kubectl get --raw /api/v1/nodes/<node-name>/proxy/metrics | grep etcd

# 资源使用趋势
watch kubectl top nodes
watch kubectl top pods --all-namespaces

# 集群容量分析
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### 故障排查最佳实践

```bash
# 1. 系统性检查顺序
kubectl get nodes                    # 节点状态
kubectl get pods --all-namespaces   # Pod 状态
kubectl get events --sort-by='.lastTimestamp' | tail -20  # 最近事件
kubectl logs -n kube-system -l component=kube-apiserver   # 核心组件日志

# 2. 资源依赖检查
kubectl get pods -o wide | grep <pod-name>  # Pod 调度位置
kubectl describe node <node-name>           # 节点资源状态
kubectl get pvc,pv                          # 存储状态
kubectl get svc,endpoints                   # 服务状态

# 3. 配置验证
kubectl get configmap,secret  # 配置和密钥
kubectl auth can-i <verb> <resource>  # 权限检查
kubectl get networkpolicy     # 网络策略
```

通过熟练掌握这些 kubectl 调试命令，可以快速定位和解决 Kubernetes 集群中的各种问题。
