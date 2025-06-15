# Ingress 资源详解

## 概述

Ingress 是 Kubernetes 中管理外部访问集群服务的 API 对象，通常处理 HTTP 和 HTTPS 流量。它提供负载均衡、SSL 终止和基于名称的虚拟主机功能。

## 核心特性

### 1. HTTP/HTTPS 路由
- 基于主机名的路由
- 基于路径的路由
- SSL/TLS 终止

### 2. 负载均衡
- 自动负载均衡到后端服务
- 会话亲和性支持
- 健康检查集成

### 3. 高级功能
- 重写和重定向
- 认证和授权
- 限流和缓存

## Ingress 配置详解

### 基础配置示例

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: default
  labels:
    app: web
  annotations:                    # 控制器特定配置
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx         # Ingress 类名（推荐）
  tls:                           # TLS 配置
  - hosts:
    - example.com
    - www.example.com
    secretName: example-tls       # TLS 证书 Secret
  rules:                         # 路由规则
  - host: example.com            # 主机名
    http:
      paths:                     # 路径规则
      - path: /                  # 路径
        pathType: Prefix         # 路径类型
        backend:
          service:
            name: web-service    # 后端服务
            port:
              number: 80         # 服务端口
  - host: api.example.com
    http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

### 路径类型详解

```yaml
# 1. Exact - 精确匹配
- path: /api/v1
  pathType: Exact
  # 只匹配 /api/v1，不匹配 /api/v1/ 或 /api/v1/users

# 2. Prefix - 前缀匹配
- path: /api
  pathType: Prefix
  # 匹配 /api、/api/、/api/v1、/api/v1/users 等

# 3. ImplementationSpecific - 由 Ingress 控制器决定
- path: /api/*
  pathType: ImplementationSpecific
  # 具体行为取决于 Ingress 控制器实现
```

### 多域名和路径示例

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.com
    - admin.myapp.com
    secretName: myapp-tls
  rules:
  # 主站点
  - host: myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
      - path: /api(/|$)(.*)        # 正则表达式路径
        pathType: ImplementationSpecific
        backend:
          service:
            name: backend-service
            port:
              number: 8080
      - path: /static
        pathType: Prefix
        backend:
          service:
            name: static-service
            port:
              number: 80
  
  # 管理后台
  - host: admin.myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 3000
```

### NGINX Ingress 控制器注解

```yaml
metadata:
  annotations:
    # 基础配置
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    
    # 认证配置
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required'
    
    # 限流配置
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    
    # 代理配置
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    
    # 会话亲和性
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "route"
    nginx.ingress.kubernetes.io/session-cookie-expires: "86400"
    
    # 自定义错误页面
    nginx.ingress.kubernetes.io/custom-http-errors: "404,503"
    nginx.ingress.kubernetes.io/default-backend: error-pages
    
    # CORS 配置
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://myapp.com"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE"
    nginx.ingress.kubernetes.io/cors-allow-headers: "DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization"
```

### TLS/SSL 配置

#### 1. 基本 TLS 配置

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: example-tls
  namespace: default
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi...     # Base64 编码的证书
  tls.key: LS0tLS1CRUdJTi...     # Base64 编码的私钥

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  tls:
  - hosts:
    - secure.example.com
    secretName: example-tls       # 引用 TLS Secret
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-service
            port:
              number: 80
```

#### 2. 使用 cert-manager 自动证书

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auto-tls-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls         # cert-manager 会自动创建这个 Secret
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

### 高级路由配置

#### 1. 基于权重的流量分割

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: canary-ingress
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"    # 10% 流量
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-canary     # 金丝雀版本
            port:
              number: 80

---
# 主版本 Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: main-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-main       # 主版本
            port:
              number: 80
```

#### 2. 基于请求头的路由

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: header-based-routing
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-header: "X-Canary"
    nginx.ingress.kubernetes.io/canary-by-header-value: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-canary
            port:
              number: 80
```

### 中间件和插件配置

#### 1. 认证中间件

```yaml
# 创建认证 Secret
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth
type: Opaque
data:
  auth: YWRtaW46JGFwcjEkSDY...   # htpasswd 生成的用户密码

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auth-ingress
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required - Admin Area'
spec:
  rules:
  - host: admin.myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
```

#### 2. OAuth 认证

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: oauth-ingress
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "https://auth.myapp.com/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://auth.myapp.com/oauth2/start?rd=$escaped_request_uri"
    nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User,X-Auth-Request-Email"
spec:
  rules:
  - host: secure.myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: protected-service
            port:
              number: 80
```

### 监控和可观测性

#### 1. 监控配置

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitored-ingress
  annotations:
    nginx.ingress.kubernetes.io/enable-access-log: "true"
    nginx.ingress.kubernetes.io/enable-rewrite-log: "true"
    prometheus.io/scrape: "true"
    prometheus.io/port: "10254"
    prometheus.io/path: "/metrics"
spec:
  rules:
  - host: myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

#### 2. 自定义指标

```yaml
# 在 NGINX Ingress 控制器中启用自定义指标
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  enable-vts-status: "true"
  vts-default-filter-key: "$geoip_country_code country::*"
```

### 故障排除

#### 1. 常见问题检查

```bash
# 1. 检查 Ingress 状态
kubectl get ingress
kubectl describe ingress my-ingress

# 2. 检查 Ingress 控制器
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# 3. 检查后端服务
kubectl get services
kubectl get endpoints

# 4. 检查 DNS 解析
nslookup myapp.com
dig myapp.com

# 5. 测试连通性
curl -H "Host: myapp.com" http://ingress-ip/
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80
```

#### 2. 调试配置

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: debug-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/enable-access-log: "true"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Debug-Ingress: true";
      more_set_headers "X-Debug-Backend: $service_name";
spec:
  rules:
  - host: debug.myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: debug-service
            port:
              number: 80
```

## 最佳实践

### 1. 安全配置

```yaml
metadata:
  annotations:
    # 强制 HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # 设置安全头
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: DENY";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "X-XSS-Protection: 1; mode=block";
      more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains";
```

### 2. 性能优化

```yaml
metadata:
  annotations:
    # 连接和超时设置
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "5"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    # 缓冲设置
    nginx.ingress.kubernetes.io/proxy-buffering: "on"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "4k"
    # 压缩
    nginx.ingress.kubernetes.io/enable-gzip: "true"
```

### 3. 资源组织

```yaml
# 按环境分组
metadata:
  name: myapp-prod-ingress
  namespace: production
  labels:
    app: myapp
    environment: production
    component: ingress
```

### 4. 证书管理

```yaml
# 使用通配符证书
spec:
  tls:
  - hosts:
    - "*.myapp.com"
    secretName: wildcard-myapp-tls
```