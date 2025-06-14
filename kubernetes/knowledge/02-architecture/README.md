# Kubernetes 架构详解

## 概述

本目录包含 Kubernetes 各核心组件的详细架构原理和实现机制。每个组件按照单独的文件进行组织，便于深入学习和理解。

## 目录结构

- [API Server](./api-server.md) - Kubernetes 集群的统一入口
- [etcd](./etcd.md) - 分布式键值存储数据库
- [Scheduler](./scheduler.md) - Pod 调度器
- [Controller Manager](./controller-manager.md) - 控制器管理器
- [kubelet](./kubelet.md) - 节点代理
- [kube-proxy](./kube-proxy.md) - 网络代理
- [Container Runtime](./container-runtime.md) - 容器运行时
- [CoreDNS](./coredns.md) - 集群 DNS 服务

## 整体交互架构

```mermaid
graph TB
    subgraph "Control Plane"
        subgraph "API Server"
            API_AUTH[认证授权]
            API_ADMISSION[准入控制]
            API_VALIDATION[验证]
            API_STORAGE[存储层]
        end
        
        subgraph "etcd Cluster"
            ETCD1[etcd-1]
            ETCD2[etcd-2]
            ETCD3[etcd-3]
        end
        
        subgraph "Scheduler"
            SCH_QUEUE[调度队列]
            SCH_FILTER[过滤算法]
            SCH_SCORE[评分算法]
            SCH_BIND[绑定操作]
        end
        
        subgraph "Controller Manager"
            NODE_CTRL[节点控制器]
            REPL_CTRL[副本控制器]
            EP_CTRL[端点控制器]
            SA_CTRL[服务账户控制器]
        end
    end
    
    subgraph "Worker Nodes"
        subgraph "Node 1"
            KUBELET1[kubelet]
            PROXY1[kube-proxy]
            RUNTIME1[Container Runtime]
            subgraph "Pod Management"
                POD_SYNC1[Pod 同步]
                HEALTH1[健康检查]
                RESOURCE1[资源管理]
            end
        end
        
        subgraph "Node N"
            KUBELETN[kubelet]
            PROXYN[kube-proxy]
            RUNTIMEN[Container Runtime]
            subgraph "Pod Management "
                POD_SYNCN[Pod 同步]
                HEALTHN[健康检查]
                RESOURCEN[资源管理]
            end
        end
    end
    
    subgraph "网络层"
        CNI[CNI 插件]
        SERVICE_MESH[服务网格]
        INGRESS[Ingress 控制器]
    end
    
    subgraph "存储层"
        CSI[CSI 插件]
        PV[持久卷]
        SC[存储类]
    end
    
    %% API Server 连接
    API_STORAGE --> ETCD1
    API_STORAGE --> ETCD2
    API_STORAGE --> ETCD3
    
    %% 控制器连接
    SCH_QUEUE --> API_AUTH
    NODE_CTRL --> API_AUTH
    REPL_CTRL --> API_AUTH
    EP_CTRL --> API_AUTH
    SA_CTRL --> API_AUTH
    
    %% 节点连接
    KUBELET1 --> API_AUTH
    KUBELETN --> API_AUTH
    PROXY1 --> API_AUTH
    PROXYN --> API_AUTH
    
    %% 调度流程
    SCH_QUEUE --> SCH_FILTER
    SCH_FILTER --> SCH_SCORE
    SCH_SCORE --> SCH_BIND
    SCH_BIND --> API_STORAGE
    
    %% kubelet 内部流程
    KUBELET1 --> POD_SYNC1
    POD_SYNC1 --> HEALTH1
    HEALTH1 --> RESOURCE1
    RESOURCE1 --> RUNTIME1
    
    KUBELETN --> POD_SYNCN
    POD_SYNCN --> HEALTHN
    HEALTHN --> RESOURCEN
    RESOURCEN --> RUNTIMEN
    
    %% 网络集成
    PROXY1 --> CNI
    PROXYN --> CNI
    CNI --> SERVICE_MESH
    SERVICE_MESH --> INGRESS
    
    %% 存储集成
    KUBELET1 --> CSI
    KUBELETN --> CSI
    CSI --> PV
    PV --> SC
```

## 数据流向图

```mermaid
sequenceDiagram
    participant Client as 客户端
    participant API as API Server
    participant ETCD as etcd
    participant SCH as Scheduler
    participant CM as Controller Manager
    participant KUBELET as kubelet
    participant RUNTIME as Container Runtime

    Note over Client, RUNTIME: Pod 创建完整流程

    Client->>API: 1. 提交 Deployment
    API->>API: 2. 认证、授权、准入控制
    API->>ETCD: 3. 存储 Deployment 对象
    
    CM->>API: 4. 监听 Deployment 事件
    CM->>API: 5. 创建 ReplicaSet
    API->>ETCD: 6. 存储 ReplicaSet 对象
    
    CM->>API: 7. 监听 ReplicaSet 事件
    CM->>API: 8. 创建 Pod
    API->>ETCD: 9. 存储 Pod 对象（未调度）
    
    SCH->>API: 10. 监听未调度 Pod
    SCH->>SCH: 11. 执行调度算法
    SCH->>API: 12. 绑定 Pod 到节点
    API->>ETCD: 13. 更新 Pod 绑定信息
    
    KUBELET->>API: 14. 获取节点 Pod 列表
    KUBELET->>KUBELET: 15. 同步 Pod 状态
    KUBELET->>RUNTIME: 16. 创建容器
    RUNTIME->>KUBELET: 17. 返回容器状态
    KUBELET->>API: 18. 更新 Pod 状态
    API->>ETCD: 19. 存储最新状态

    Note over Client, RUNTIME: 整个流程涉及多个组件协作
```

## 组件交互模式

### 声明式 API 模式
- 用户声明期望状态
- 控制器持续监控实际状态
- 自动调节使实际状态趋向期望状态

### 控制器模式
- Watch：监听资源变化
- Reconcile：协调状态差异
- Update：更新资源状态

### 事件驱动模式
- 基于事件的异步通信
- 组件间松耦合
- 高可扩展性和容错性

## 核心特性

### 高可用性
- 多副本部署
- leader 选举机制
- 自动故障转移

### 可扩展性
- 插件化架构
- CRI/CNI/CSI 接口
- 自定义资源和控制器

### 安全性
- RBAC 授权
- 网络策略
- Pod 安全策略
- 密钥管理

### 可观测性
- 指标收集
- 日志聚合
- 分布式追踪
- 事件记录
