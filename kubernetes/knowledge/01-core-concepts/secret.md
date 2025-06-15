# Secret 资源详解

## 概述

Secret 是 Kubernetes 中用于存储敏感信息的资源对象，如密码、OAuth 令牌、SSH 密钥等。与 ConfigMap 不同，Secret 专门设计用于处理机密数据，提供了额外的安全保护。

## 核心特性

### 1. 安全存储
- Base64 编码存储（注意：这不是加密）
- 支持静态加密（etcd 级别）
- 内存文件系统挂载（tmpfs）

### 2. 访问控制
- RBAC 权限控制
- 命名空间隔离
- 服务账户自动挂载控制

### 3. 多种用途
- 镜像拉取认证
- TLS 证书
- 应用程序密钥
- OAuth 令牌

## Secret 类型

### 1. Opaque（默认类型）
通用的用户定义数据

### 2. kubernetes.io/service-account-token
服务账户令牌

### 3. kubernetes.io/dockercfg
Docker 配置文件

### 4. kubernetes.io/dockerconfigjson
Docker 配置 JSON 文件

### 5. kubernetes.io/basic-auth
基本认证凭据

### 6. kubernetes.io/ssh-auth
SSH 认证凭据

### 7. kubernetes.io/tls
TLS 证书和密钥

## Secret 配置详解

### 基础配置示例

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets             # Secret 名称
  namespace: default            # 命名空间
  labels:                       # 标签
    app: my-app
    type: credentials
  annotations:                  # 注解
    description: "应用敏感配置"
type: Opaque                    # Secret 类型
data:                          # Base64 编码的数据
  username: YWRtaW4=            # admin (base64 编码)
  password: cGFzc3dvcmQxMjM=    # password123 (base64 编码)
  api_key: YWJjZGVmZ2hpams=     # abcdefghijk (base64 编码)
  database_url: bXlzcWw6Ly91c2VyOnBhc3NAaG9zdDozMzA2L2Ri  # mysql://user:pass@host:3306/db
stringData:                    # 未编码的数据（创建时自动编码）
  config.json: |
    {
      "database": {
        "host": "mysql.example.com",
        "username": "app_user",
        "password": "secret123"
      },
      "api": {
        "key": "sk-1234567890abcdef",
        "endpoint": "https://api.example.com"
      }
    }
immutable: false               # 是否不可变（Kubernetes 1.21+）
```

### 创建 Secret 的多种方式

#### 1. 从字面值创建

```bash
# 创建基本 Secret
kubectl create secret generic app-secret \
  --from-literal=username=admin \
  --from-literal=password=password123 \
  --from-literal=api-key=abcdefghijk

# 创建基本认证 Secret
kubectl create secret generic basic-auth \
  --from-literal=username=admin \
  --from-literal=password=password123 \
  --type=kubernetes.io/basic-auth
```

#### 2. 从文件创建

```bash
# 从单个文件创建
kubectl create secret generic file-secret --from-file=credentials.txt

# 从多个文件创建
kubectl create secret generic multi-file-secret \
  --from-file=username.txt \
  --from-file=password.txt \
  --from-file=api-key.txt

# 指定键名
kubectl create secret generic custom-key-secret \
  --from-file=my-key=credentials.txt

# 从目录创建
kubectl create secret generic dir-secret --from-file=./secret-files/
```

#### 3. 创建 Docker 配置 Secret

```bash
# 创建 Docker 配置 Secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=user@example.com

# 从现有 Docker 配置创建
kubectl create secret generic regcred \
  --from-file=.dockerconfigjson=$HOME/.docker/config.json \
  --type=kubernetes.io/dockerconfigjson
```

#### 4. 创建 TLS Secret

```bash
# 从现有证书和密钥创建
kubectl create secret tls tls-secret \
  --cert=server.crt \
  --key=server.key

# 从 PEM 格式文件创建
kubectl create secret generic tls-certs \
  --from-file=tls.crt=server.crt \
  --from-file=tls.key=server.key \
  --from-file=ca.crt=ca.crt
```

#### 5. 创建 SSH 认证 Secret

```bash
# 创建 SSH 密钥 Secret
kubectl create secret generic ssh-key-secret \
  --from-file=ssh-privatekey=$HOME/.ssh/id_rsa \
  --from-file=ssh-publickey=$HOME/.ssh/id_rsa.pub \
  --type=kubernetes.io/ssh-auth
```

## 不同类型的 Secret 配置

### 1. Opaque Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: opaque-secret
type: Opaque
data:
  username: YWRtaW4=            # admin
  password: cGFzc3dvcmQ=        # password
stringData:                    # 可以混合使用 data 和 stringData
  config: |
    host=example.com
    port=3306
```

### 2. Docker 配置 Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: docker-config-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ewogICJhdXRocyI6IHsKICAgICJyZWdpc3RyeS5leGFtcGxlLmNvbSI6IHsKICAgICAgInVzZXJuYW1lIjogIm15dXNlciIsCiAgICAgICJwYXNzd29yZCI6ICJteXBhc3N3b3JkIiwKICAgICAgImF1dGgiOiAiYlhsMWMyVnlPbTE1Y0dGemMzZHZjbVE9IgogICAgfQogIH0KfQ==
```

### 3. TLS Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi...     # Base64 编码的证书
  tls.key: LS0tLS1CRUdJTi...     # Base64 编码的私钥
```

### 4. 基本认证 Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth-secret
type: kubernetes.io/basic-auth
data:
  username: YWRtaW4=            # admin
  password: cGFzc3dvcmQ=        # password
```

### 5. SSH 认证 Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ssh-auth-secret
type: kubernetes.io/ssh-auth
data:
  ssh-privatekey: LS0tLS1CRUdJTi...  # Base64 编码的私钥
  ssh-publickey: c3NoLXJzYS...       # Base64 编码的公钥（可选）
```

## 使用 Secret

### 1. 作为环境变量

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-pod
spec:
  containers:
  - name: app
    image: nginx
    env:
    # 单个密钥
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: app-secrets       # Secret 名称
          key: username           # 键名
          optional: false         # 是否可选
    
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: password
    
    # 批量导入所有密钥
    envFrom:
    - secretRef:
        name: app-secrets         # 导入所有键值对
        optional: true            # Secret 可选
    - prefix: "SECRET_"           # 添加前缀
      secretRef:
        name: app-secrets
```

### 2. 作为卷挂载

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    # 挂载整个 Secret
    - name: secret-volume
      mountPath: /etc/secrets    # 挂载目录
      readOnly: true             # 只读挂载
    
    # 挂载特定的密钥
    - name: database-creds
      mountPath: /etc/database/username
      subPath: username          # 挂载单个文件
      readOnly: true
    
    - name: database-creds
      mountPath: /etc/database/password
      subPath: password
      readOnly: true
  
  volumes:
  # 挂载整个 Secret
  - name: secret-volume
    secret:
      secretName: app-secrets
      defaultMode: 0400          # 默认文件权限（只读）
      optional: false            # Secret 是否可选
  
  # 挂载特定的密钥
  - name: database-creds
    secret:
      secretName: app-secrets
      items:                     # 选择特定的密钥
      - key: username            # Secret 中的键
        path: username           # 挂载后的文件名
        mode: 0400               # 文件权限
      - key: password
        path: password
        mode: 0400
```

### 3. 镜像拉取 Secret

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-image-pod
spec:
  containers:
  - name: app
    image: registry.example.com/my-app:latest
  imagePullSecrets:              # 镜像拉取 Secret
  - name: regcred                # Docker 配置 Secret 名称
```

### 4. TLS Secret 在 Ingress 中使用

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  tls:                           # TLS 配置
  - hosts:
    - example.com
    secretName: tls-secret       # TLS Secret 名称
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

## 高级功能

### 1. 不可变 Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: immutable-secret
type: Opaque
data:
  api_key: YWJjZGVmZ2hpams=
immutable: true                 # 设置为不可变
```

**不可变 Secret 的特点：**
- 创建后无法修改
- 提高集群性能
- 防止意外更改
- 要更新需要创建新的 Secret

### 2. 自动挂载服务账户令牌控制

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service-account
automountServiceAccountToken: false  # 禁用自动挂载

---
apiVersion: v1
kind: Pod
metadata:
  name: no-token-pod
spec:
  serviceAccountName: my-service-account
  automountServiceAccountToken: false  # Pod 级别禁用
  containers:
  - name: app
    image: nginx
```

### 3. Secret 投影卷

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: projected-secret-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: projected-volume
      mountPath: /etc/credentials
      readOnly: true
  volumes:
  - name: projected-volume
    projected:                   # 投影卷
      sources:
      - secret:                  # 来自 Secret
          name: database-secret
          items:
          - key: username
            path: db-username
          - key: password
            path: db-password
      - secret:                  # 来自另一个 Secret
          name: api-secret
          items:
          - key: api_key
            path: api-key
      - configMap:               # 也可以包含 ConfigMap
          name: app-config
          items:
          - key: config.yaml
            path: config.yaml
```

## 最佳实践

### 1. 安全原则

```yaml
# 1. 最小权限原则
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]                 # 只给必要的权限
  resourceNames: ["app-secrets"] # 限制特定的 Secret

# 2. 命名空间隔离
metadata:
  namespace: production          # 使用专门的命名空间

# 3. 标签和注解
metadata:
  labels:
    app: my-app
    environment: production
    sensitivity: high            # 标记敏感级别
  annotations:
    description: "生产环境数据库凭据"
    contact: "security@example.com"
```

### 2. 数据编码

```bash
# 手动创建 Base64 编码
echo -n "password123" | base64
# cGFzc3dvcmQxMjM=

# 解码验证
echo "cGFzc3dvcmQxMjM=" | base64 -d
# password123

# 使用 stringData 避免手动编码（推荐）
stringData:
  password: "password123"       # 自动编码
```

### 3. 版本管理

```yaml
# 版本化 Secret 名称
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets-v2          # 版本化命名
  labels:
    app: my-app
    version: v2
type: Opaque
data:
  # 新版本的密钥
```

### 4. 生命周期管理

```yaml
# 使用 Deployment 中的环境变量引用
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets-v2
              key: password
        # 当更新 Secret 版本时，需要重启 Pod
        # 可以添加注解来触发滚动更新
      annotations:
        secret-version: "v2"      # 更改此值触发更新
```

### 5. 证书管理

```yaml
# TLS 证书 Secret 示例
apiVersion: v1
kind: Secret
metadata:
  name: web-tls
  annotations:
    cert-manager.io/issuer: "letsencrypt-prod"  # 使用 cert-manager
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi...
  tls.key: LS0tLS1CRUdJTi...

# 使用 cert-manager 自动管理证书
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: web-tls
spec:
  secretName: web-tls-secret     # 自动创建的 Secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - example.com
  - www.example.com
```

## 监控和调试

### 1. 查看 Secret

```bash
# 列出 Secret
kubectl get secrets
kubectl get secret                # 简写

# 查看详细信息（不显示数据）
kubectl describe secret app-secrets

# 查看 Secret 内容（小心敏感信息）
kubectl get secret app-secrets -o yaml

# 解码特定键的值
kubectl get secret app-secrets -o jsonpath='{.data.password}' | base64 -d

# 查看所有键名
kubectl get secret app-secrets -o jsonpath='{.data}' | jq 'keys'
```

### 2. 调试 Secret 问题

```bash
# 检查 Pod 中的环境变量
kubectl exec pod-name -- env | grep -i secret

# 检查挂载的 Secret 文件
kubectl exec pod-name -- ls -la /etc/secrets/
kubectl exec pod-name -- cat /etc/secrets/password

# 检查 Secret 权限
kubectl auth can-i get secret app-secrets

# 检查服务账户的 Secret
kubectl describe serviceaccount default
```

### 3. 常见问题排查

```bash
# 1. Secret 不存在
kubectl get secret app-secrets -n production

# 2. 权限问题
kubectl auth can-i get secrets --as=system:serviceaccount:default:my-sa

# 3. 镜像拉取失败
kubectl describe pod pod-name | grep -A 5 "Failed to pull image"
kubectl get secret regcred -o yaml

# 4. TLS 证书问题
kubectl describe ingress my-ingress
openssl x509 -in <(kubectl get secret tls-secret -o jsonpath='{.data.tls\.crt}' | base64 -d) -text -noout
```

## 安全考虑

### 1. etcd 加密

```yaml
# 启用 etcd 静态加密
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-encoded-32-byte-key>
  - identity: {}  # 回退到未加密（用于解密旧数据）
```

### 2. RBAC 最佳实践

```yaml
# 限制性的 RBAC 规则
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["app-secrets"] # 只能访问特定 Secret

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-secret-binding
subjects:
- kind: ServiceAccount
  name: app-service-account
roleRef:
  kind: Role
  name: app-secret-reader
  apiGroup: rbac.authorization.k8s.io
```

### 3. 网络策略

```yaml
# 限制访问 Secret 的 Pod 网络
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: secret-access-policy
spec:
  podSelector:
    matchLabels:
      access-secrets: "true"
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
  egress:
  - to:
    - podSelector:
        matchLabels:
          role: database
```

### 4. 密钥轮换

```yaml
# 实现密钥轮换的模式
apiVersion: batch/v1
kind: CronJob
metadata:
  name: secret-rotation
spec:
  schedule: "0 2 * * 0"  # 每周日凌晨2点
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: rotator
            image: secret-rotator:latest
            command:
            - /bin/sh
            - -c
            - |
              # 生成新密钥
              NEW_PASSWORD=$(openssl rand -base64 32)
              
              # 更新外部系统
              update-external-system --password="$NEW_PASSWORD"
              
              # 更新 Kubernetes Secret
              kubectl patch secret app-secrets \
                -p='{"stringData":{"password":"'$NEW_PASSWORD'"}}'
              
              # 触发应用重启
              kubectl rollout restart deployment my-app
          restartPolicy: OnFailure
```

## 外部密钥管理集成

### 1. 使用 External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "demo"

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: vault-secret
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secrets
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: secret/database
      property: password
```

### 2. 使用 CSI Secret Store

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secrets-store-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets-store"
      readOnly: true
  volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "app-vault-secrets"
```