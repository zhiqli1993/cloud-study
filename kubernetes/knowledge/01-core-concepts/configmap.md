# ConfigMap 资源详解

## 概述

ConfigMap 是 Kubernetes 中用于存储非机密配置数据的资源对象。它允许将配置数据与容器镜像解耦，使得应用程序配置更加灵活和可维护。

## 核心特性

### 1. 配置解耦
- 将配置数据从容器镜像中分离
- 支持配置热更新（需要应用程序支持）
- 环境间配置差异管理

### 2. 多种数据格式
- 键值对
- 配置文件
- 二进制数据（通过 Base64 编码）

### 3. 灵活使用方式
- 环境变量注入
- 命令行参数
- 卷挂载文件

## ConfigMap 配置详解

### 基础配置示例

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config              # ConfigMap 名称
  namespace: default            # 命名空间
  labels:                       # 标签
    app: my-app
    type: config
  annotations:                  # 注解
    description: "应用配置文件"
data:                          # 配置数据（字符串键值对）
  # 简单键值对
  database_host: "mysql.example.com"
  database_port: "3306"
  log_level: "INFO"
  debug_mode: "false"
  
  # 配置文件内容
  app.properties: |
    server.port=8080
    server.host=0.0.0.0
    spring.datasource.url=jdbc:mysql://mysql.example.com:3306/mydb
    spring.datasource.username=app_user
    logging.level.com.example=INFO
    
  nginx.conf: |
    server {
        listen 80;
        server_name example.com;
        
        location / {
            proxy_pass http://backend:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
        }
    }
    
  config.yaml: |
    database:
      host: mysql.example.com
      port: 3306
      name: mydb
      pool_size: 10
    redis:
      host: redis.example.com
      port: 6379
      database: 0
    logging:
      level: INFO
      format: json
    features:
      feature_a: true
      feature_b: false
      
binaryData:                     # 二进制数据（Base64 编码）
  ssl.crt: LS0tLS1CRUdJTi...     # Base64 编码的证书文件
immutable: false                # 是否不可变（Kubernetes 1.19+）
```

### 创建 ConfigMap 的多种方式

#### 1. 从字面值创建

```bash
# 单个键值对
kubectl create configmap literal-config --from-literal=key1=value1

# 多个键值对
kubectl create configmap multi-literal \
  --from-literal=database_host=mysql.example.com \
  --from-literal=database_port=3306 \
  --from-literal=log_level=INFO
```

#### 2. 从文件创建

```bash
# 从单个文件创建
kubectl create configmap file-config --from-file=app.properties

# 从多个文件创建
kubectl create configmap multi-file-config \
  --from-file=app.properties \
  --from-file=nginx.conf

# 从目录创建（包含目录下所有文件）
kubectl create configmap dir-config --from-file=./config-dir/

# 指定键名
kubectl create configmap custom-key-config \
  --from-file=custom-app-config=app.properties
```

#### 3. 从环境文件创建

```bash
# 从 .env 文件创建
# .env 文件内容：
# DATABASE_HOST=mysql.example.com
# DATABASE_PORT=3306
# LOG_LEVEL=INFO

kubectl create configmap env-config --from-env-file=.env
```

#### 4. 混合创建

```bash
kubectl create configmap mixed-config \
  --from-literal=api_key=abc123 \
  --from-file=config.yaml \
  --from-env-file=.env
```

## 使用 ConfigMap

### 1. 作为环境变量

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-env-pod
spec:
  containers:
  - name: app
    image: nginx
    env:
    # 单个键值对
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config        # ConfigMap 名称
          key: database_host      # 键名
          optional: false         # 是否可选（默认 false）
    
    # 使用不同的环境变量名
    - name: DB_PORT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_port
    
    # 批量导入所有键值对
    envFrom:
    - configMapRef:
        name: app-config          # 导入所有键值对
        optional: true            # ConfigMap 可选
    - prefix: "CONFIG_"           # 添加前缀
      configMapRef:
        name: app-config
```

### 2. 作为卷挂载

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-volume-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    # 挂载整个 ConfigMap
    - name: config-volume
      mountPath: /etc/config     # 挂载目录
      readOnly: true             # 只读挂载
    
    # 挂载特定的键
    - name: app-properties
      mountPath: /app/config/app.properties
      subPath: app.properties    # 挂载单个文件
      readOnly: true
    
    # 自定义文件权限
    - name: nginx-config
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
      readOnly: true
  
  volumes:
  # 挂载整个 ConfigMap
  - name: config-volume
    configMap:
      name: app-config
      defaultMode: 0644          # 默认文件权限
      optional: false            # ConfigMap 是否可选
  
  # 挂载特定的键
  - name: app-properties
    configMap:
      name: app-config
      items:                     # 选择特定的键
      - key: app.properties      # ConfigMap 中的键
        path: app.properties     # 挂载后的文件名
        mode: 0600               # 文件权限
  
  # 自定义挂载
  - name: nginx-config
    configMap:
      name: app-config
      items:
      - key: nginx.conf
        path: nginx.conf
        mode: 0644
```

### 3. 作为命令行参数

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-args-pod
spec:
  containers:
  - name: app
    image: myapp
    command: ["/app/server"]
    args:
    - "--host=$(DATABASE_HOST)"   # 使用环境变量
    - "--port=$(DATABASE_PORT)"
    - "--log-level=$(LOG_LEVEL)"
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_host
    - name: DATABASE_PORT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_port
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: log_level
```

## 高级功能

### 1. 不可变 ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config
data:
  api_endpoint: "https://api.example.com"
  timeout: "30"
immutable: true                 # 设置为不可变
```

**不可变 ConfigMap 的特点：**
- 创建后无法修改
- 提高集群性能（减少 API Server 和 kubelet 的负载）
- 防止意外更改
- 要更新需要创建新的 ConfigMap 并更新引用

### 2. 可选的 ConfigMap

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: optional-config-pod
spec:
  containers:
  - name: app
    image: nginx
    env:
    - name: OPTIONAL_CONFIG
      valueFrom:
        configMapKeyRef:
          name: optional-config   # 这个 ConfigMap 可能不存在
          key: some_key
          optional: true          # 设置为可选
    envFrom:
    - configMapRef:
        name: optional-config
        optional: true            # 整个 ConfigMap 可选
    volumeMounts:
    - name: optional-volume
      mountPath: /etc/optional
  volumes:
  - name: optional-volume
    configMap:
      name: optional-config
      optional: true              # 卷也可以设置为可选
```

### 3. 配置热更新

```yaml
# 虽然 ConfigMap 可以动态更新，但需要应用程序支持配置重载
apiVersion: v1
kind: Pod
metadata:
  name: hot-reload-pod
  annotations:
    configmap/checksum: "abc123"  # 可以添加校验和来触发重新部署
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d
    # 需要应用程序监听文件变化或提供重载信号
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "nginx -s reload"]
  volumes:
  - name: config-volume
    configMap:
      name: nginx-config
```

## 最佳实践

### 1. 命名规范

```yaml
metadata:
  name: myapp-config            # 使用应用名前缀
  # name: myapp-database-config # 按功能分组
  # name: myapp-config-v1       # 版本化命名
  labels:
    app: myapp                  # 应用标识
    component: config           # 组件类型
    environment: production     # 环境标识
    version: v1.0               # 版本
```

### 2. 数据组织

```yaml
data:
  # 推荐：按功能组织
  database.properties: |
    host=mysql.example.com
    port=3306
    database=myapp
    
  redis.properties: |
    host=redis.example.com
    port=6379
    database=0
    
  # 避免：单个大文件包含所有配置
  # all-config: |
  #   # 包含所有配置的大文件
```

### 3. 环境分离

```yaml
# 开发环境
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: development
data:
  api_endpoint: "https://dev-api.example.com"
  log_level: "DEBUG"
  replica_count: "1"

---
# 生产环境
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: production
data:
  api_endpoint: "https://api.example.com"
  log_level: "INFO"
  replica_count: "3"
```

### 4. 版本管理

```yaml
# 使用版本化的 ConfigMap 名称
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config-v2         # 版本化命名
  labels:
    app: myapp
    version: v2
data:
  # 新版本的配置
  
---
# 在 Deployment 中引用特定版本
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: app
        envFrom:
        - configMapRef:
            name: myapp-config-v2  # 引用特定版本
```

### 5. 配置验证

```yaml
# 使用 Init Container 验证配置
apiVersion: v1
kind: Pod
metadata:
  name: validated-config-pod
spec:
  initContainers:
  - name: config-validator
    image: busybox
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "Validating configuration..."
      if [ ! -f /config/app.properties ]; then
        echo "Error: app.properties not found"
        exit 1
      fi
      if [ -z "$DATABASE_HOST" ]; then
        echo "Error: DATABASE_HOST not set"
        exit 1
      fi
      echo "Configuration validation passed"
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_host
    volumeMounts:
    - name: config-volume
      mountPath: /config
  
  containers:
  - name: app
    image: myapp
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  
  volumes:
  - name: config-volume
    configMap:
      name: app-config
```

### 6. 大小限制考虑

```yaml
# ConfigMap 有大小限制（默认 1MB）
# 对于大型配置文件，考虑分割或使用其他方案

# 方案1：分割大配置文件
apiVersion: v1
kind: ConfigMap
metadata:
  name: large-config-part1
data:
  part1.conf: |
    # 配置文件第一部分

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: large-config-part2
data:
  part2.conf: |
    # 配置文件第二部分

# 方案2：使用 Secret（对于敏感大文件）
# 方案3：使用 Volume 挂载外部存储
```

## 监控和调试

### 1. 查看 ConfigMap

```bash
# 列出 ConfigMap
kubectl get configmaps
kubectl get cm                    # 简写

# 查看详细信息
kubectl describe configmap app-config

# 查看内容
kubectl get configmap app-config -o yaml
kubectl get configmap app-config -o jsonpath='{.data}'

# 查看特定键的值
kubectl get configmap app-config -o jsonpath='{.data.database_host}'
```

### 2. 调试配置问题

```bash
# 检查 Pod 中的环境变量
kubectl exec pod-name -- env | grep DATABASE

# 检查挂载的配置文件
kubectl exec pod-name -- cat /etc/config/app.properties

# 检查 ConfigMap 是否被正确挂载
kubectl exec pod-name -- ls -la /etc/config/

# 查看 Pod 的配置引用
kubectl describe pod pod-name | grep -A 10 "Environment\|Mounts"
```

### 3. 常见问题排查

```bash
# 1. ConfigMap 不存在
kubectl get configmap app-config
# 如果不存在，检查名称和命名空间

# 2. 键不存在
kubectl get configmap app-config -o yaml | grep -A 5 data:
# 检查键名是否正确

# 3. 权限问题
kubectl auth can-i get configmap --as=system:serviceaccount:default:my-sa

# 4. 挂载问题
kubectl describe pod pod-name
# 查看事件和挂载详情
```

## 安全考虑

### 1. 敏感数据分离

```yaml
# ConfigMap 用于非敏感配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_host: "mysql.example.com"
  database_port: "3306"
  log_level: "INFO"

---
# Secret 用于敏感信息
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  database_password: cGFzc3dvcmQ=  # base64 编码
  api_key: YWJjMTIz              # base64 编码
```

### 2. RBAC 权限控制

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: configmap-reader
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
  resourceNames: ["app-config"]  # 限制特定的 ConfigMap

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: configmap-reader-binding
subjects:
- kind: ServiceAccount
  name: my-service-account
roleRef:
  kind: Role
  name: configmap-reader
  apiGroup: rbac.authorization.k8s.io
```

### 3. 网络策略（如适用）

```yaml
# 虽然 ConfigMap 存储在 etcd 中，但可以限制 Pod 间的配置共享
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-config-access
spec:
  podSelector:
    matchLabels:
      app: sensitive-app
  policyTypes:
  - Ingress
  - Egress
  # 限制网络访问
```