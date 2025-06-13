# Istio 官方 Demo 应用

这个目录包含了 Istio 官方的示例应用，用于演示 Istio 服务网格的各种功能。

## 应用列表

### 1. Bookinfo 应用 📚
**位置**: `bookinfo/`

这是 Istio 最经典的示例应用，由四个微服务组成：
- **productpage**: 产品页面服务（Python）
- **details**: 图书详情服务（Ruby） 
- **reviews**: 评论服务（Java），有三个版本：
  - v1: 不调用 ratings 服务
  - v2: 调用 ratings 服务，显示黑色星星
  - v3: 调用 ratings 服务，显示红色星星
- **ratings**: 评分服务（Node.js）

**部署命令**:
```bash
# 部署应用
kubectl apply -f istio/demo/bookinfo/bookinfo.yaml

# 部署网关和虚拟服务
kubectl apply -f istio/demo/bookinfo/bookinfo-gateway.yaml

# 部署目标规则（用于流量管理）
kubectl apply -f istio/demo/bookinfo/destination-rule-all.yaml
```

**访问应用**:
```bash
# 获取入口网关地址
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

# 访问产品页面
curl http://$GATEWAY_URL/productpage
```

### 2. Httpbin 应用 🌐
**位置**: `httpbin/`

一个简单的 HTTP 请求和响应服务，用于测试各种 HTTP 操作。

**部署命令**:
```bash
kubectl apply -f istio/demo/httpbin/httpbin.yaml
```

**使用示例**:
```bash
# 测试 GET 请求
kubectl exec -it deploy/sleep -- curl httpbin:8000/get

# 测试 POST 请求
kubectl exec -it deploy/sleep -- curl -X POST httpbin:8000/post -d "hello=world"

# 测试延迟
kubectl exec -it deploy/sleep -- curl httpbin:8000/delay/5
```

### 3. Sleep 应用 😴
**位置**: `sleep/`

一个简单的客户端应用，包含 curl 工具，用于测试其他服务的连通性。

**部署命令**:
```bash
kubectl apply -f istio/demo/sleep/sleep.yaml
```

**使用示例**:
```bash
# 进入 sleep pod
kubectl exec -it deploy/sleep -- sh

# 测试与其他服务的连通性
kubectl exec -it deploy/sleep -- curl httpbin:8000/get
kubectl exec -it deploy/sleep -- curl productpage:9080/productpage
```

### 4. HelloWorld 应用 👋
**位置**: `helloworld/`

一个简单的 Hello World 服务，有两个版本，用于演示流量分割和版本管理。

**部署命令**:
```bash
kubectl apply -f istio/demo/helloworld/helloworld.yaml
```

**测试示例**:
```bash
# 测试服务调用
kubectl exec -it deploy/sleep -- curl helloworld:5000/hello
```

## 常用操作

### 启用自动注入
```bash
# 为默认命名空间启用 Istio sidecar 自动注入
kubectl label namespace default istio-injection=enabled
```

### 查看服务状态
```bash
# 查看所有 pod
kubectl get pods

# 查看服务
kubectl get services

# 查看 Istio 配置
kubectl get gateway,virtualservice,destinationrule
```

### 清理资源
```bash
# 清理 Bookinfo
kubectl delete -f istio/demo/bookinfo/

# 清理 Httpbin
kubectl delete -f istio/demo/httpbin/

# 清理 Sleep
kubectl delete -f istio/demo/sleep/

# 清理 HelloWorld
kubectl delete -f istio/demo/helloworld/
```

## 流量管理示例

### 1. 流量路由（以 Bookinfo 为例）
```yaml
# 将所有流量路由到 reviews v1
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
```

### 2. 流量分割
```yaml
# 50% 流量到 v1，50% 流量到 v3
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 50
    - destination:
        host: reviews
        subset: v3
      weight: 50
```

### 3. 基于用户的路由
```yaml
# 特定用户路由到 v2
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
```

## 可观测性

### 查看服务拓扑
```bash
# 安装 Kiali（如果未安装）
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/kiali.yaml

# 访问 Kiali
kubectl port-forward -n istio-system svc/kiali 20001:20001
```

### 查看指标
```bash
# 安装 Prometheus 和 Grafana（如果未安装）
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/grafana.yaml

# 访问 Grafana
kubectl port-forward -n istio-system svc/grafana 3000:3000
```

### 查看调用链
```bash
# 安装 Jaeger（如果未安装）
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/jaeger.yaml

# 访问 Jaeger
kubectl port-forward -n istio-system svc/tracing 16686:80
```

## 注意事项

1. 确保已经安装并配置好 Istio
2. 建议在专门的命名空间中部署这些应用
3. 部署前请确保集群资源充足
4. 某些功能需要启用相应的 Istio 组件

## 参考资料

- [Istio 官方文档](https://istio.io/latest/docs/)
- [Bookinfo 应用指南](https://istio.io/latest/docs/examples/bookinfo/)
- [流量管理](https://istio.io/latest/docs/concepts/traffic-management/)
- [安全策略](https://istio.io/latest/docs/concepts/security/)
