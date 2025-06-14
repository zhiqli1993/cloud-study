# kube-proxy 架构详解

## 概述

kube-proxy 是运行在每个节点上的网络代理，负责维护节点上的网络规则，实现 Service 的负载均衡和服务发现。它是 Kubernetes 网络模型的核心实现组件。

## 核心架构

```mermaid
graph TB
    subgraph "kube-proxy 架构"
        subgraph "控制层"
            CONFIG_SYNC[配置同步]
            SERVICE_WATCH[Service 监听]
            ENDPOINT_WATCH[Endpoint 监听]
            NODE_WATCH[Node 监听]
        end
        
        subgraph "代理模式"
            IPTABLES_MODE[iptables 模式]
            IPVS_MODE[IPVS 模式]
            USERSPACE_MODE[用户空间模式]
            KERNELSPACE_MODE[内核空间模式]
        end
        
        subgraph "规则管理"
            RULE_SYNC[规则同步]
            CHAIN_MANAGER[链管理器]
            NAT_RULES[NAT 规则]
            FILTER_RULES[过滤规则]
        end
        
        subgraph "负载均衡"
            LB_ALGORITHM[负载均衡算法]
            SESSION_AFFINITY[会话亲和性]
            HEALTH_CHECK[健康检查]
        end
        
        subgraph "网络工具"
            IPTABLES[iptables]
            IPSET[ipset]
            IPVS[IPVS]
            NETLINK[netlink]
        end
    end
    
    subgraph "外部组件"
        API_SERVER[API Server]
        CNI_PLUGIN[CNI 插件]
        KERNEL[Linux 内核]
    end
    
    CONFIG_SYNC --> SERVICE_WATCH
    CONFIG_SYNC --> ENDPOINT_WATCH
    CONFIG_SYNC --> NODE_WATCH
    
    SERVICE_WATCH --> IPTABLES_MODE
    SERVICE_WATCH --> IPVS_MODE
    SERVICE_WATCH --> USERSPACE_MODE
    
    IPTABLES_MODE --> RULE_SYNC
    IPVS_MODE --> RULE_SYNC
    USERSPACE_MODE --> RULE_SYNC
    
    RULE_SYNC --> CHAIN_MANAGER
    CHAIN_MANAGER --> NAT_RULES
    CHAIN_MANAGER --> FILTER_RULES
    
    RULE_SYNC --> LB_ALGORITHM
    LB_ALGORITHM --> SESSION_AFFINITY
    SESSION_AFFINITY --> HEALTH_CHECK
    
    NAT_RULES --> IPTABLES
    FILTER_RULES --> IPTABLES
    LB_ALGORITHM --> IPVS
    HEALTH_CHECK --> IPSET
    
    SERVICE_WATCH --> API_SERVER
    IPTABLES --> KERNEL
    IPVS --> KERNEL
```

## 代理模式详解

### 1. iptables 模式

#### 工作原理
```mermaid
graph TB
    subgraph "iptables 模式架构"
        subgraph "流量路径"
            CLIENT[客户端]
            NETFILTER[Netfilter 钩子]
            PREROUTING[PREROUTING 链]
            OUTPUT[OUTPUT 链]
            POSTROUTING[POSTROUTING 链]
        end
        
        subgraph "规则链"
            KUBE_SERVICES[KUBE-SERVICES]
            KUBE_SVC_XXX[KUBE-SVC-XXX]
            KUBE_SEP_XXX[KUBE-SEP-XXX]
            KUBE_MARK_MASQ[KUBE-MARK-MASQ]
        end
        
        subgraph "后端 Pod"
            POD1[Pod 1]
            POD2[Pod 2]
            POD3[Pod 3]
        end
    end
    
    CLIENT --> NETFILTER
    NETFILTER --> PREROUTING
    PREROUTING --> KUBE_SERVICES
    
    KUBE_SERVICES --> KUBE_SVC_XXX
    KUBE_SVC_XXX --> KUBE_SEP_XXX
    KUBE_SEP_XXX --> KUBE_MARK_MASQ
    
    KUBE_SEP_XXX --> POD1
    KUBE_SEP_XXX --> POD2
    KUBE_SEP_XXX --> POD3
    
    OUTPUT --> KUBE_SERVICES
    POSTROUTING --> KUBE_MARK_MASQ
```

#### iptables 规则示例
```bash
# Service 主链规则
-A KUBE-SERVICES -d 10.96.0.1/32 -p tcp -m tcp --dport 443 -j KUBE-SVC-NPX46M4PTMTKRN6Y

# Service 分发规则
-A KUBE-SVC-NPX46M4PTMTKRN6Y -m statistic --mode random --probability 0.33333333349 -j KUBE-SEP-ID6YWIT3F6WNZ47P
-A KUBE-SVC-NPX46M4PTMTKRN6Y -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-YCS0DXZDXPBD4J4C
-A KUBE-SVC-NPX46M4PTMTKRN6Y -j KUBE-SEP-4EZBCR6Q4P6MZRM4

# Endpoint 规则
-A KUBE-SEP-ID6YWIT3F6WNZ47P -s 10.244.0.2/32 -j KUBE-MARK-MASQ
-A KUBE-SEP-ID6YWIT3F6WNZ47P -p tcp -m tcp -j DNAT --to-destination 10.244.0.2:8080

# MASQUERADE 规则
-A KUBE-MARK-MASQ -j MARK --set-xmark 0x4000/0x4000
-A KUBE-POSTROUTING -m mark --mark 0x4000/0x4000 -j MASQUERADE
```

### 2. IPVS 模式

#### 工作原理
```mermaid
graph TB
    subgraph "IPVS 模式架构"
        subgraph "虚拟服务器"
            VIRTUAL_SERVER[虚拟服务器]
            SERVICE_IP[Service IP]
            SCHEDULER[调度算法]
        end
        
        subgraph "真实服务器"
            REAL_SERVER1[Real Server 1]
            REAL_SERVER2[Real Server 2]
            REAL_SERVER3[Real Server 3]
        end
        
        subgraph "IPVS 核心"
            IPVS_KERNEL[IPVS 内核模块]
            CONNECTION_TABLE[连接表]
            LOAD_BALANCER[负载均衡器]
        end
        
        subgraph "辅助组件"
            IPSET_RULES[ipset 规则]
            IPTABLES_RULES[iptables 规则]
            DUMMY_INTERFACE[虚拟接口]
        end
    end
    
    VIRTUAL_SERVER --> SERVICE_IP
    SERVICE_IP --> SCHEDULER
    SCHEDULER --> IPVS_KERNEL
    
    IPVS_KERNEL --> CONNECTION_TABLE
    CONNECTION_TABLE --> LOAD_BALANCER
    
    LOAD_BALANCER --> REAL_SERVER1
    LOAD_BALANCER --> REAL_SERVER2
    LOAD_BALANCER --> REAL_SERVER3
    
    SCHEDULER --> IPSET_RULES
    IPSET_RULES --> IPTABLES_RULES
    SERVICE_IP --> DUMMY_INTERFACE
```

#### IPVS 配置示例
```bash
# 查看 IPVS 规则
ipvsadm -L -n
# IP Virtual Server version 1.2.1 (size=4096)
# Prot LocalAddress:Port Scheduler Flags
#   -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
# TCP  10.96.0.1:443 rr
#   -> 10.244.0.2:8080             Masq    1      0          0
#   -> 10.244.0.3:8080             Masq    1      0          0
#   -> 10.244.0.4:8080             Masq    1      0          0

# IPVS 调度算法
rr    # Round Robin
wrr   # Weighted Round Robin
lc    # Least Connections
wlc   # Weighted Least Connections
sh    # Source Hashing
dh    # Destination Hashing
```

### 3. 模式对比

```yaml
# 性能对比
iptables 模式:
  优点:
    - 成熟稳定，兼容性好
    - 无需额外内核模块
    - 规则清晰，易于调试
  缺点:
    - 性能随 Service 数量线性下降
    - 规则数量庞大时性能差
    - 负载均衡算法有限

IPVS 模式:
  优点:
    - 高性能，O(1) 查找复杂度
    - 丰富的负载均衡算法
    - 支持会话保持
    - 更好的网络吞吐量
  缺点:
    - 需要 IPVS 内核模块
    - 调试相对复杂
    - 对内核版本有要求
```

## Service 类型处理

### 1. ClusterIP Service

```mermaid
sequenceDiagram
    participant Client as 客户端 Pod
    participant Proxy as kube-proxy
    participant IPTables as iptables
    participant Backend as 后端 Pod

    Client->>IPTables: 访问 Service IP
    IPTables->>IPTables: 匹配 KUBE-SERVICES 规则
    IPTables->>IPTables: 随机选择后端
    IPTables->>Backend: DNAT 到后端 Pod
    Backend->>Client: 返回响应
    
    Note over Proxy: 持续同步 Service/Endpoints 变更
    Proxy->>IPTables: 更新规则
```

### 2. NodePort Service

```mermaid
graph TB
    subgraph "NodePort Service 流量路径"
        subgraph "外部流量"
            EXTERNAL_CLIENT[外部客户端]
            NODE_IP[节点 IP:NodePort]
        end
        
        subgraph "节点处理"
            NODEPORT_RULE[NodePort 规则]
            SERVICE_RULE[Service 规则]
        end
        
        subgraph "后端选择"
            LOCAL_BACKEND[本地后端]
            REMOTE_BACKEND[远程后端]
        end
        
        subgraph "策略选项"
            EXTERNAL_POLICY[externalTrafficPolicy]
            LOCAL_ONLY[Local]
            CLUSTER_WIDE[Cluster]
        end
    end
    
    EXTERNAL_CLIENT --> NODE_IP
    NODE_IP --> NODEPORT_RULE
    NODEPORT_RULE --> SERVICE_RULE
    
    SERVICE_RULE --> EXTERNAL_POLICY
    EXTERNAL_POLICY --> LOCAL_ONLY
    EXTERNAL_POLICY --> CLUSTER_WIDE
    
    LOCAL_ONLY --> LOCAL_BACKEND
    CLUSTER_WIDE --> LOCAL_BACKEND
    CLUSTER_WIDE --> REMOTE_BACKEND
```

### 3. LoadBalancer Service

```yaml
# LoadBalancer Service 示例
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
  selector:
    app: my-app
  externalTrafficPolicy: Local  # 或 Cluster
  loadBalancerSourceRanges:
  - 10.0.0.0/8
  - 192.168.0.0/16
```

## 会话亲和性

### 1. ClientIP 亲和性

```mermaid
graph TB
    subgraph "会话亲和性机制"
        subgraph "iptables 实现"
            CLIENT_IP[客户端 IP]
            RECENT_MODULE[recent 模块]
            HASH_TABLE[哈希表]
        end
        
        subgraph "IPVS 实现"
            SOURCE_HASH[源 IP 哈希]
            PERSISTENCE[持久连接]
            TIMEOUT[超时设置]
        end
        
        subgraph "后端选择"
            SAME_BACKEND[相同后端]
            NEW_BACKEND[新后端]
        end
    end
    
    CLIENT_IP --> RECENT_MODULE
    RECENT_MODULE --> HASH_TABLE
    HASH_TABLE --> SAME_BACKEND
    
    CLIENT_IP --> SOURCE_HASH
    SOURCE_HASH --> PERSISTENCE
    PERSISTENCE --> TIMEOUT
    TIMEOUT --> SAME_BACKEND
    
    HASH_TABLE --> NEW_BACKEND
    TIMEOUT --> NEW_BACKEND
```

### 2. 配置示例

```yaml
# Service 会话亲和性配置
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-app
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3小时
```

## 健康检查和端点管理

### 1. 端点状态同步

```mermaid
sequenceDiagram
    participant Proxy as kube-proxy
    participant API as API Server
    participant Endpoints as Endpoints Controller
    participant Rules as 规则引擎

    loop 监听循环
        API->>Proxy: Endpoints 变更事件
        Proxy->>Proxy: 解析端点状态
        
        alt 端点就绪
            Proxy->>Rules: 添加后端规则
        else 端点未就绪
            Proxy->>Rules: 移除后端规则
        end
        
        Rules->>Rules: 应用规则变更
    end
    
    Note over Proxy: 定期健康检查
    Proxy->>Proxy: 检查端点连通性
```

### 2. 端点过滤策略

```go
// 端点过滤逻辑
func (proxier *Proxier) filterEndpoints(endpoints []discovery.Endpoint) []discovery.Endpoint {
    var filtered []discovery.Endpoint
    
    for _, endpoint := range endpoints {
        // 检查端点就绪状态
        if endpoint.Conditions.Ready != nil && *endpoint.Conditions.Ready {
            // 检查端点终止状态
            if endpoint.Conditions.Terminating == nil || !*endpoint.Conditions.Terminating {
                filtered = append(filtered, endpoint)
            }
        }
    }
    
    return filtered
}
```

## 网络策略集成

### 1. NetworkPolicy 支持

```mermaid
graph TB
    subgraph "网络策略架构"
        subgraph "策略定义"
            NETWORK_POLICY[NetworkPolicy]
            INGRESS_RULES[入站规则]
            EGRESS_RULES[出站规则]
        end
        
        subgraph "实现层"
            CNI_PLUGIN[CNI 插件]
            KUBE_PROXY[kube-proxy]
            IPTABLES_IMPL[iptables 实现]
        end
        
        subgraph "规则应用"
            POD_SELECTOR[Pod 选择器]
            NAMESPACE_SELECTOR[命名空间选择器]
            TRAFFIC_FILTER[流量过滤]
        end
    end
    
    NETWORK_POLICY --> INGRESS_RULES
    NETWORK_POLICY --> EGRESS_RULES
    
    INGRESS_RULES --> CNI_PLUGIN
    EGRESS_RULES --> CNI_PLUGIN
    
    CNI_PLUGIN --> IPTABLES_IMPL
    KUBE_PROXY --> IPTABLES_IMPL
    
    IPTABLES_IMPL --> POD_SELECTOR
    IPTABLES_IMPL --> NAMESPACE_SELECTOR
    IPTABLES_IMPL --> TRAFFIC_FILTER
```

### 2. 规则协调

```yaml
# NetworkPolicy 示例
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    ports:
    - protocol: TCP
      port: 8080
```

## 性能优化

### 1. 规则优化策略

```bash
# iptables 优化
# 使用 ipset 减少规则数量
ipset create KUBE-CLUSTER-IP hash:ip,port
ipset add KUBE-CLUSTER-IP 10.96.0.1,tcp:443
iptables -A KUBE-SERVICES -m set --match-set KUBE-CLUSTER-IP dst,dst -j KUBE-SVC-XXX

# IPVS 优化
# 启用连接复用
echo 1 > /proc/sys/net/ipv4/vs/conn_reuse_mode

# 调整连接超时
echo 900 > /proc/sys/net/ipv4/vs/timeout_tcp
echo 120 > /proc/sys/net/ipv4/vs/timeout_tcp_fin
```

### 2. 监控指标

```yaml
# kube-proxy 关键指标
kubeproxy_sync_proxy_rules_duration_seconds: 规则同步耗时
kubeproxy_sync_proxy_rules_last_timestamp_seconds: 最后同步时间
kubeproxy_network_programming_duration_seconds: 网络编程延迟
rest_client_requests_total: API 请求总数
rest_client_request_duration_seconds: API 请求延迟
```

## 故障排除

### 1. 常见问题诊断

```bash
# 检查 kube-proxy 状态
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# 查看 kube-proxy 日志
kubectl logs -n kube-system -l k8s-app=kube-proxy

# 检查 iptables 规则
iptables -t nat -L KUBE-SERVICES
iptables -t nat -L KUBE-SVC-XXX

# 检查 IPVS 规则
ipvsadm -L -n

# 检查 Service 和 Endpoints
kubectl get svc
kubectl get endpoints
```

### 2. 网络连通性测试

```bash
# 测试 Service 连通性
kubectl run test-pod --image=busybox --rm -it -- sh
nslookup my-service
wget -O- http://my-service:80

# 检查 DNS 解析
kubectl exec -it test-pod -- nslookup kubernetes.default

# 测试跨节点连通性
kubectl exec -it pod1 -- ping <pod2-ip>
```

## 配置和部署

### 1. DaemonSet 部署

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-proxy
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: kube-proxy
  template:
    metadata:
      labels:
        k8s-app: kube-proxy
    spec:
      containers:
      - name: kube-proxy
        image: k8s.gcr.io/kube-proxy:v1.21.0
        command:
        - /usr/local/bin/kube-proxy
        - --config=/var/lib/kube-proxy/config.conf
        - --hostname-override=$(NODE_NAME)
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        securityContext:
          privileged: true
        volumeMounts:
        - name: kube-proxy
          mountPath: /var/lib/kube-proxy
        - name: xtables-lock
          mountPath: /run/xtables.lock
        - name: lib-modules
          mountPath: /lib/modules
          readOnly: true
      hostNetwork: true
      serviceAccountName: kube-proxy
      volumes:
      - name: kube-proxy
        configMap:
          name: kube-proxy
      - name: xtables-lock
        hostPath:
          path: /run/xtables.lock
          type: FileOrCreate
      - name: lib-modules
        hostPath:
          path: /lib/modules
```

### 2. 配置优化

```yaml
# kube-proxy 配置
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
bindAddress: 0.0.0.0
clientConnection:
  kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
clusterCIDR: 10.244.0.0/16
configSyncPeriod: 15m0s
conntrack:
  maxPerCore: 32768
  min: 131072
  tcpCloseWaitTimeout: 1h0m0s
  tcpEstablishedTimeout: 24h0m0s
enableProfiling: false
healthzBindAddress: 0.0.0.0:10256
hostnameOverride: ""
iptables:
  masqueradeAll: false
  masqueradeBit: 14
  minSyncPeriod: 0s
  syncPeriod: 30s
ipvs:
  excludeCIDRs: null
  minSyncPeriod: 0s
  scheduler: "rr"
  strictARP: false
  syncPeriod: 30s
  tcpFinTimeout: 0s
  tcpTimeout: 0s
  udpTimeout: 0s
kind: KubeProxyConfiguration
metricsBindAddress: 127.0.0.1:10249
mode: "ipvs"  # 或 "iptables"
nodePortAddresses: null
oomScoreAdj: -999
portRange: ""
udpIdleTimeout: 250ms
winkernel:
  enableDSR: false
  networkName: ""
  sourceVip: ""
```

## 最佳实践

### 1. 性能调优

```bash
# 内核参数优化
echo 'net.netfilter.nf_conntrack_max = 1000000' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_tcp_timeout_established = 86400' >> /etc/sysctl.conf
echo 'net.core.netdev_max_backlog = 5000' >> /etc/sysctl.conf

# IPVS 调优
echo 'net.ipv4.vs.conn_reuse_mode = 1' >> /etc/sysctl.conf
echo 'net.ipv4.vs.expire_nodest_conn = 1' >> /etc/sysctl.conf
```

### 2. 监控告警

```yaml
# kube-proxy 监控规则
groups:
- name: kube-proxy
  rules:
  - alert: KubeProxyDown
    expr: up{job="kube-proxy"} == 0
    for: 5m
    
  - alert: KubeProxyRulesSyncFailure
    expr: increase(kubeproxy_sync_proxy_rules_duration_seconds_count{quantile="0.99"}[5m]) > 0
    for: 5m
    
  - alert: KubeProxyHighLatency
    expr: histogram_quantile(0.99, kubeproxy_network_programming_duration_seconds_bucket) > 1
    for: 10m
```

### 3. 安全加固

```yaml
# RBAC 配置
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:kube-proxy
rules:
- apiGroups: [""]
  resources: ["services", "endpoints"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get"]
- apiGroups: ["discovery.k8s.io"]
  resources: ["endpointslices"]
  verbs: ["get", "list", "watch"]
```