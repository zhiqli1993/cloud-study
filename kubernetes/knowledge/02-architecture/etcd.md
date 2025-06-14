# etcd 架构详解

## 概述

etcd 是 Kubernetes 集群的分布式键值存储数据库，基于 Raft 共识算法实现强一致性，负责存储集群的所有配置信息和状态数据。

## 核心架构

```mermaid
graph TB
    subgraph "etcd 集群架构"
        subgraph "etcd 节点内部"
            subgraph "Node 1 (Leader)"
                HTTP1[HTTP API]
                GRPC1[gRPC API]
                RAFT1[Raft 状态机]
                WAL1[WAL 日志]
                SNAP1[快照存储]
                STORE1[键值存储]
            end
            
            subgraph "Node 2 (Follower)"
                HTTP2[HTTP API]
                GRPC2[gRPC API]
                RAFT2[Raft 状态机]
                WAL2[WAL 日志]
                SNAP2[快照存储]
                STORE2[键值存储]
            end
            
            subgraph "Node 3 (Follower)"
                HTTP3[HTTP API]
                GRPC3[gRPC API]
                RAFT3[Raft 状态机]
                WAL3[WAL 日志]
                SNAP3[快照存储]
                STORE3[键值存储]
            end
        end
        
        subgraph "客户端层"
            API_SERVER[API Server]
            ETCDCTL[etcdctl]
            CLIENT_APP[客户端应用]
        end
        
        subgraph "网络层"
            PEER_NET[节点间通信]
            CLIENT_NET[客户端通信]
        end
    end
    
    %% API 连接
    API_SERVER --> HTTP1
    API_SERVER --> GRPC1
    ETCDCTL --> HTTP1
    CLIENT_APP --> GRPC1
    
    %% 集群内部通信
    RAFT1 -.-> RAFT2
    RAFT1 -.-> RAFT3
    RAFT2 -.-> RAFT1
    RAFT2 -.-> RAFT3
    RAFT3 -.-> RAFT1
    RAFT3 -.-> RAFT2
    
    %% 内部组件连接
    HTTP1 --> RAFT1
    GRPC1 --> RAFT1
    RAFT1 --> WAL1
    RAFT1 --> STORE1
    WAL1 --> SNAP1
    
    HTTP2 --> RAFT2
    GRPC2 --> RAFT2
    RAFT2 --> WAL2
    RAFT2 --> STORE2
    WAL2 --> SNAP2
    
    HTTP3 --> RAFT3
    GRPC3 --> RAFT3
    RAFT3 --> WAL3
    RAFT3 --> STORE3
    WAL3 --> SNAP3
```

## Raft 共识算法详解

### 1. 节点状态转换

```mermaid
stateDiagram-v2
    [*] --> Follower
    Follower --> Candidate : 选举超时
    Candidate --> Leader : 获得多数票
    Candidate --> Follower : 发现更高任期
    Leader --> Follower : 发现更高任期
    Follower --> Follower : 接收心跳
    Leader --> Leader : 发送心跳
    Candidate --> Candidate : 选举分票，重新选举
```

### 2. Leader 选举过程

```mermaid
sequenceDiagram
    participant F1 as Follower 1
    participant F2 as Follower 2
    participant F3 as Follower 3

    Note over F1, F3: 初始状态：所有节点都是 Follower
    
    F1->>F1: 选举超时，成为 Candidate
    F1->>F1: 递增任期号，为自己投票
    F1->>F2: RequestVote RPC
    F1->>F3: RequestVote RPC
    
    F2->>F1: 同意投票
    F3->>F1: 同意投票
    
    Note over F1: 获得多数票，成为 Leader
    
    F1->>F2: AppendEntries RPC (心跳)
    F1->>F3: AppendEntries RPC (心跳)
    
    F2->>F1: 确认心跳
    F3->>F1: 确认心跳
```

### 3. 日志复制机制

```mermaid
sequenceDiagram
    participant Client as 客户端
    participant Leader as Leader
    participant F1 as Follower 1
    participant F2 as Follower 2

    Client->>Leader: 写请求
    Leader->>Leader: 添加日志条目
    
    par 并行复制
        Leader->>F1: AppendEntries RPC
        Leader->>F2: AppendEntries RPC
    end
    
    F1->>Leader: 确认复制
    F2->>Leader: 确认复制
    
    Note over Leader: 多数节点确认，提交日志
    
    Leader->>Leader: 应用到状态机
    Leader->>Client: 返回成功响应
    
    par 通知提交
        Leader->>F1: 下次心跳通知提交
        Leader->>F2: 下次心跳通知提交
    end
    
    F1->>F1: 应用到状态机
    F2->>F2: 应用到状态机
```

## 存储架构详解

### 1. 数据存储结构

```mermaid
graph TB
    subgraph "etcd 存储层次"
        subgraph "内存层"
            TREE[BTree 索引]
            CACHE[读缓存]
            BUFFER[写缓冲区]
        end
        
        subgraph "WAL 层"
            WAL_FILE[WAL 文件]
            WAL_ENTRY[日志条目]
            WAL_META[元数据]
        end
        
        subgraph "快照层"
            SNAP_FILE[快照文件]
            SNAP_DATA[快照数据]
            SNAP_META[快照元数据]
        end
        
        subgraph "磁盘层"
            DB_FILE[数据库文件]
            BACKEND[BoltDB 后端]
            BUCKETS[存储桶]
        end
    end
    
    TREE --> CACHE
    CACHE --> BUFFER
    BUFFER --> WAL_FILE
    WAL_FILE --> WAL_ENTRY
    WAL_ENTRY --> WAL_META
    
    BUFFER --> SNAP_FILE
    SNAP_FILE --> SNAP_DATA
    SNAP_DATA --> SNAP_META
    
    SNAP_FILE --> DB_FILE
    DB_FILE --> BACKEND
    BACKEND --> BUCKETS
```

### 2. 键值存储设计

#### 键空间组织
```
/registry/
├── apiregistration.k8s.io/
│   └── apiservices/
├── apps/
│   ├── deployments/
│   ├── replicasets/
│   └── daemonsets/
├── /
│   ├── pods/
│   ├── services/
│   ├── configmaps/
│   └── secrets/
└── extensions/
    └── ingresses/
```

#### 版本控制机制
```go
type KeyValue struct {
    Key            []byte
    CreateRevision int64  // 创建时的全局版本号
    ModRevision    int64  // 最后修改时的全局版本号
    Version        int64  // 键的版本号（递增）
    Value          []byte
    Lease          int64  // 租约 ID
}
```

### 3. 事务处理

#### MVCC (多版本并发控制)
```mermaid
graph LR
    subgraph "MVCC 机制"
        subgraph "版本链"
            V1[Version 1<br/>Key: /foo<br/>Value: bar<br/>Rev: 1]
            V2[Version 2<br/>Key: /foo<br/>Value: baz<br/>Rev: 3]
            V3[Version 3<br/>Key: /foo<br/>Value: qux<br/>Rev: 5]
        end
        
        subgraph "读操作"
            READ_LATEST[读取最新版本<br/>Rev: 5]
            READ_HISTORICAL[读取历史版本<br/>Rev: 3]
        end
        
        V1 --> V2
        V2 --> V3
        READ_LATEST --> V3
        READ_HISTORICAL --> V2
    end
```

#### 事务语义
```yaml
# 事务示例：原子性更新多个键
# 条件：如果 /foo 的版本是 1
# 成功：设置 /foo = "bar", /count = "1"
# 失败：设置 /error = "conflict"

txn:
  compare:
    - key: "/foo"
      target: "VERSION"
      version: 1
  success:
    - request_put:
        key: "/foo"
        value: "bar"
    - request_put:
        key: "/count"
        value: "1"
  failure:
    - request_put:
        key: "/error"
        value: "conflict"
```

## Watch 机制详解

### 1. Watch 架构

```mermaid
graph TB
    subgraph "Watch 系统架构"
        subgraph "客户端"
            CLIENT1[客户端 1]
            CLIENT2[客户端 2]
            CLIENT3[客户端 3]
        end
        
        subgraph "etcd Server"
            subgraph "Watch 子系统"
                WATCH_MGR[Watch 管理器]
                WATCH_GROUP[Watch 组]
                EVENT_QUEUE[事件队列]
            end
            
            subgraph "存储子系统"
                MVCC_STORE[MVCC 存储]
                REVISION[版本控制]
                INDEX[索引系统]
            end
        end
        
        CLIENT1 --> WATCH_MGR
        CLIENT2 --> WATCH_MGR
        CLIENT3 --> WATCH_MGR
        
        WATCH_MGR --> WATCH_GROUP
        WATCH_GROUP --> EVENT_QUEUE
        
        MVCC_STORE --> EVENT_QUEUE
        REVISION --> INDEX
        INDEX --> MVCC_STORE
    end
```

### 2. Watch 事件流

```mermaid
sequenceDiagram
    participant Client as 客户端
    participant WatchMgr as Watch 管理器
    participant Store as MVCC 存储
    participant EventQ as 事件队列

    Client->>WatchMgr: 创建 Watch
    WatchMgr->>Store: 注册监听器
    Store->>WatchMgr: 确认注册
    WatchMgr->>Client: Watch 创建成功

    Note over Store: 数据发生变更
    
    Store->>EventQ: 生成变更事件
    EventQ->>WatchMgr: 推送事件
    WatchMgr->>Client: 发送事件通知
    
    Client->>WatchMgr: 确认接收
    
    loop 持续监听
        Store->>EventQ: 新的变更事件
        EventQ->>WatchMgr: 推送事件
        WatchMgr->>Client: 发送事件通知
        Client->>WatchMgr: 确认接收
    end
```

## 性能优化

### 1. 读性能优化

#### 读优化策略
- **序列化读**: 可以从任何节点读取，不保证强一致性
- **线性化读**: 从 Leader 读取，保证强一致性
- **本地读缓存**: 在内存中缓存热点数据

```go
// 线性化读配置
clientv3.OpGet("key", clientv3.WithSerializable()) // 序列化读
clientv3.OpGet("key")                              // 线性化读
```

### 2. 写性能优化

#### 批量写入
```go
// 批量操作减少网络往返
txn := client.Txn(ctx)
txn.Then(
    clientv3.OpPut("key1", "value1"),
    clientv3.OpPut("key2", "value2"),
    clientv3.OpPut("key3", "value3"),
)
txn.Commit()
```

#### 异步写入
```go
// 异步写入提高吞吐量
ch := make(chan clientv3.OpResponse, 100)
for i := 0; i < 100; i++ {
    go func(i int) {
        resp, err := client.Put(ctx, fmt.Sprintf("key%d", i), fmt.Sprintf("value%d", i))
        ch <- clientv3.OpResponse{Put: resp, Err: err}
    }(i)
}
```

### 3. 存储优化

#### 压缩策略
```yaml
# 自动压缩配置
--auto-compaction-mode=periodic
--auto-compaction-retention=1h

# 手动压缩
etcdctl compact 1000
```

#### 碎片整理
```bash
# 碎片整理命令
etcdctl defrag

# 检查碎片情况
etcdctl endpoint status --cluster -w table
```

## 运维管理

### 1. 集群部署配置

#### 静态配置
```yaml
# etcd.yaml
name: etcd-1
data-dir: /var/lib/etcd
listen-client-urls: https://10.0.0.1:2379
advertise-client-urls: https://10.0.0.1:2379
listen-peer-urls: https://10.0.0.1:2380
initial-advertise-peer-urls: https://10.0.0.1:2380
initial-cluster: etcd-1=https://10.0.0.1:2380,etcd-2=https://10.0.0.2:2380,etcd-3=https://10.0.0.3:2380
initial-cluster-state: new
initial-cluster-token: etcd-cluster-1

# 安全配置
client-cert-auth: true
trusted-ca-file: /etc/etcd/ca.crt
cert-file: /etc/etcd/server.crt
key-file: /etc/etcd/server.key
peer-client-cert-auth: true
peer-trusted-ca-file: /etc/etcd/ca.crt
peer-cert-file: /etc/etcd/peer.crt
peer-key-file: /etc/etcd/peer.key
```

### 2. 监控指标

#### 关键指标
```yaml
# 性能指标
- etcd_server_has_leader: 是否有 Leader
- etcd_server_leader_changes_seen_total: Leader 变更次数
- etcd_server_proposals_committed_total: 提交的提案数
- etcd_server_proposals_applied_total: 应用的提案数
- etcd_disk_wal_fsync_duration_seconds: WAL fsync 延迟
- etcd_disk_backend_commit_duration_seconds: 后端提交延迟

# 容量指标
- etcd_mvcc_db_total_size_in_bytes: 数据库总大小
- etcd_mvcc_db_total_size_in_use_in_bytes: 使用中的数据库大小
- etcd_server_quota_backend_bytes: 后端配额

# 网络指标
- etcd_network_client_grpc_received_bytes_total: gRPC 接收字节数
- etcd_network_client_grpc_sent_bytes_total: gRPC 发送字节数
```

### 3. 备份恢复

#### 备份策略
```bash
# 创建快照备份
etcdctl snapshot save backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.crt \
  --cert=/etc/etcd/server.crt \
  --key=/etc/etcd/server.key

# 验证快照
etcdctl snapshot status backup.db -w table
```

#### 恢复流程
```bash
# 从快照恢复
etcdctl snapshot restore backup.db \
  --name etcd-1 \
  --initial-cluster etcd-1=https://10.0.0.1:2380,etcd-2=https://10.0.0.2:2380,etcd-3=https://10.0.0.3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls https://10.0.0.1:2380
```

## 故障排除

### 1. 常见问题诊断

#### 集群健康检查
```bash
# 检查集群状态
etcdctl endpoint health --cluster

# 检查成员列表
etcdctl member list

# 检查性能
etcdctl check perf
```

#### 网络分区处理
```bash
# 检查网络连通性
etcdctl endpoint status --cluster -w table

# 查看 Leader 状态
etcdctl endpoint status --cluster | grep "true"
```

### 2. 性能问题调优

#### 慢查询分析
```bash
# 启用慢查询日志
--log-level=debug
--enable-pprof

# 分析慢查询
curl http://localhost:2379/debug/pprof/trace
```

#### I/O 优化
```yaml
# 磁盘优化配置
--wal-dir=/fast-ssd/etcd/wal
--data-dir=/ssd/etcd/data
--max-wals=5
--max-snapshots=5
```