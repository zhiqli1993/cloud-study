#!/bin/bash

# Registry代理访问测试脚本
# 用于验证Kubernetes集群中的Docker Registry代理配置

set -euo pipefail

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
NAMESPACE="${NAMESPACE:-default}"
REGISTRY_SERVICE="${REGISTRY_SERVICE:-registry-proxy}"
VERBOSE="${VERBOSE:-false}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试结果计数
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

log_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}[PASS]${NC} $test_name: $message"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}[FAIL]${NC} $test_name: $message"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# 帮助信息
show_help() {
    cat << EOF
Registry代理访问测试脚本

用法: $0 [选项]

选项:
    -h, --help              显示帮助信息
    -n, --namespace NAME    指定Kubernetes命名空间 (默认: default)
    -s, --service NAME      指定Registry服务名称 (默认: registry-proxy)
    -v, --verbose           启用详细输出
    --quick                 快速测试（跳过镜像拉取测试）
    --cleanup              清理测试资源
    --external-test        测试外部Registry访问

环境变量:
    NAMESPACE              Kubernetes命名空间
    REGISTRY_SERVICE       Registry服务名称
    VERBOSE                启用详细输出
    HTTP_PROXY             HTTP代理地址（用于测试）
    HTTPS_PROXY            HTTPS代理地址（用于测试）

示例:
    # 基本测试
    $0

    # 指定命名空间测试
    $0 --namespace registry-system

    # 详细输出测试
    $0 --verbose

    # 快速测试
    $0 --quick

    # 清理测试资源
    $0 --cleanup
EOF
}

# 检查依赖项
check_dependencies() {
    log_info "检查测试依赖项..."
    
    local deps=("kubectl" "curl")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        else
            log_debug "$dep 已安装: $(command -v "$dep")"
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少以下依赖项: ${missing_deps[*]}"
        return 1
    fi
    
    # 检查kubectl连接
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到Kubernetes集群"
        return 1
    fi
    
    log_info "依赖项检查通过"
    return 0
}

# 测试Registry服务是否存在
test_registry_service() {
    log_info "测试Registry服务..."
    
    if kubectl get service "$REGISTRY_SERVICE" -n "$NAMESPACE" &> /dev/null; then
        local service_ip=$(kubectl get service "$REGISTRY_SERVICE" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
        local service_port=$(kubectl get service "$REGISTRY_SERVICE" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
        log_test_result "Registry服务存在" "PASS" "服务地址: $service_ip:$service_port"
        echo "REGISTRY_ENDPOINT=http://$service_ip:$service_port" > /tmp/registry-test-env
        return 0
    else
        log_test_result "Registry服务存在" "FAIL" "服务不存在"
        return 1
    fi
}

# 测试Registry Pod状态
test_registry_pods() {
    log_info "测试Registry Pod状态..."
    
    local pods=$(kubectl get pods -l app=registry-proxy -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    if [[ -z "$pods" ]]; then
        log_test_result "Registry Pod状态" "FAIL" "未找到Registry Pod"
        return 1
    fi
    
    local ready_pods=0
    local total_pods=0
    
    for pod in $pods; do
        total_pods=$((total_pods + 1))
        local pod_status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        local pod_ready=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        
        log_debug "Pod $pod: status=$pod_status, ready=$pod_ready"
        
        if [[ "$pod_status" == "Running" && "$pod_ready" == "True" ]]; then
            ready_pods=$((ready_pods + 1))
        fi
    done
    
    if [[ $ready_pods -eq $total_pods ]]; then
        log_test_result "Registry Pod状态" "PASS" "$ready_pods/$total_pods Pod就绪"
        return 0
    else
        log_test_result "Registry Pod状态" "FAIL" "$ready_pods/$total_pods Pod就绪"
        return 1
    fi
}

# 测试Registry API响应
test_registry_api() {
    log_info "测试Registry API响应..."
    
    if [[ ! -f /tmp/registry-test-env ]]; then
        log_test_result "Registry API响应" "FAIL" "无法获取服务端点"
        return 1
    fi
    
    source /tmp/registry-test-env
    
    # 创建测试Pod
    kubectl run registry-test-client --image=curlimages/curl:8.5.0 --rm -i --restart=Never \
        --namespace="$NAMESPACE" \
        --command -- /bin/sh -c "
        echo 'Testing Registry API...'
        if curl -s -f ${REGISTRY_ENDPOINT}/v2/; then
            echo 'Registry API test: PASS'
            exit 0
        else
            echo 'Registry API test: FAIL'
            exit 1
        fi
    " > /tmp/registry-api-test.log 2>&1
    
    if [[ $? -eq 0 ]]; then
        log_test_result "Registry API响应" "PASS" "API响应正常"
        return 0
    else
        log_test_result "Registry API响应" "FAIL" "API响应异常"
        log_debug "API测试日志: $(cat /tmp/registry-api-test.log)"
        return 1
    fi
}

# 测试镜像拉取
test_image_pull() {
    local quick_test="${1:-false}"
    
    if [[ "$quick_test" == "true" ]]; then
        log_info "跳过镜像拉取测试（快速模式）"
        return 0
    fi
    
    log_info "测试镜像拉取..."
    
    if [[ ! -f /tmp/registry-test-env ]]; then
        log_test_result "镜像拉取测试" "FAIL" "无法获取服务端点"
        return 1
    fi
    
    source /tmp/registry-test-env
    
    # 创建测试Pod使用Registry代理拉取镜像
    local test_pod_name="registry-pull-test-$(date +%s)"
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $test_pod_name
  namespace: $NAMESPACE
  labels:
    test: registry-pull
spec:
  restartPolicy: Never
  containers:
  - name: test-container
    image: alpine:3.18
    command: ["/bin/sh", "-c", "echo 'Image pull test successful' && sleep 10"]
  imagePullSecrets:
  - name: registry-secret
EOF
    
    # 等待Pod状态
    local timeout=120
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local pod_status=$(kubectl get pod "$test_pod_name" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
        
        if [[ "$pod_status" == "Succeeded" || "$pod_status" == "Running" ]]; then
            log_test_result "镜像拉取测试" "PASS" "镜像拉取成功"
            kubectl delete pod "$test_pod_name" -n "$NAMESPACE" --ignore-not-found=true &>/dev/null
            return 0
        elif [[ "$pod_status" == "Failed" ]]; then
            log_test_result "镜像拉取测试" "FAIL" "镜像拉取失败"
            kubectl describe pod "$test_pod_name" -n "$NAMESPACE" 2>/dev/null | grep -A 10 "Events:" || true
            kubectl delete pod "$test_pod_name" -n "$NAMESPACE" --ignore-not-found=true &>/dev/null
            return 1
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    log_test_result "镜像拉取测试" "FAIL" "测试超时"
    kubectl delete pod "$test_pod_name" -n "$NAMESPACE" --ignore-not-found=true &>/dev/null
    return 1
}

# 测试Registry代理功能
test_registry_proxy() {
    log_info "测试Registry代理功能..."
    
    if [[ ! -f /tmp/registry-test-env ]]; then
        log_test_result "Registry代理功能" "FAIL" "无法获取服务端点"
        return 1
    fi
    
    source /tmp/registry-test-env
    
    # 测试catalog API
    kubectl run registry-proxy-test --image=curlimages/curl:8.5.0 --rm -i --restart=Never \
        --namespace="$NAMESPACE" \
        --command -- /bin/sh -c "
        echo 'Testing Registry proxy functionality...'
        
        # 测试catalog API
        echo 'Testing catalog API...'
        if curl -s -f ${REGISTRY_ENDPOINT}/v2/_catalog; then
            echo 'Catalog API: PASS'
        else
            echo 'Catalog API: FAIL'
        fi
        
        # 测试镜像信息API
        echo 'Testing image info API...'
        if curl -s -f ${REGISTRY_ENDPOINT}/v2/library/alpine/tags/list; then
            echo 'Image info API: PASS'
        else
            echo 'Image info API: FAIL'
        fi
    " > /tmp/registry-proxy-test.log 2>&1
    
    if grep -q "Catalog API: PASS" /tmp/registry-proxy-test.log; then
        log_test_result "Registry代理功能" "PASS" "代理功能正常"
        return 0
    else
        log_test_result "Registry代理功能" "FAIL" "代理功能异常"
        log_debug "代理测试日志: $(cat /tmp/registry-proxy-test.log)"
        return 1
    fi
}

# 测试外部Registry访问
test_external_registry() {
    log_info "测试外部Registry访问..."
    
    # 测试是否能够访问外部Registry（通过代理）
    kubectl run external-registry-test --image=curlimages/curl:8.5.0 --rm -i --restart=Never \
        --namespace="$NAMESPACE" \
        --env="HTTP_PROXY=${HTTP_PROXY:-}" \
        --env="HTTPS_PROXY=${HTTPS_PROXY:-}" \
        --command -- /bin/sh -c "
        echo 'Testing external registry access...'
        
        # 测试Docker Hub访问
        echo 'Testing Docker Hub access...'
        if curl -s -f --connect-timeout 10 https://registry-1.docker.io/v2/; then
            echo 'Docker Hub access: PASS'
        else
            echo 'Docker Hub access: FAIL'
        fi
        
        # 测试镜像加速器访问
        echo 'Testing mirror access...'
        if curl -s -f --connect-timeout 10 https://dockerhub.azk8s.cn/v2/; then
            echo 'Mirror access: PASS'
        else
            echo 'Mirror access: FAIL'
        fi
    " > /tmp/external-registry-test.log 2>&1
    
    if grep -q "Docker Hub access: PASS\|Mirror access: PASS" /tmp/external-registry-test.log; then
        log_test_result "外部Registry访问" "PASS" "外部Registry可访问"
        return 0
    else
        log_test_result "外部Registry访问" "WARN" "外部Registry访问受限"
        log_debug "外部访问测试日志: $(cat /tmp/external-registry-test.log)"
        return 1
    fi
}

# 测试配置文件
test_configuration() {
    log_info "测试配置文件..."
    
    # 检查ConfigMap
    if kubectl get configmap registry-proxy-config -n "$NAMESPACE" &> /dev/null; then
        log_test_result "ConfigMap配置" "PASS" "配置文件存在"
    else
        log_test_result "ConfigMap配置" "FAIL" "配置文件不存在"
    fi
    
    # 检查Secret
    if kubectl get secret registry-secret -n "$NAMESPACE" &> /dev/null; then
        log_test_result "Secret配置" "PASS" "认证配置存在"
    else
        log_test_result "Secret配置" "WARN" "认证配置不存在"
    fi
    
    # 检查PVC
    if kubectl get pvc registry-proxy-pvc -n "$NAMESPACE" &> /dev/null; then
        local pvc_status=$(kubectl get pvc registry-proxy-pvc -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        if [[ "$pvc_status" == "Bound" ]]; then
            log_test_result "存储配置" "PASS" "存储已绑定"
        else
            log_test_result "存储配置" "WARN" "存储状态: $pvc_status"
        fi
    else
        log_test_result "存储配置" "FAIL" "存储配置不存在"
    fi
}

# 清理测试资源
cleanup_test_resources() {
    log_info "清理测试资源..."
    
    # 删除测试Pod
    kubectl delete pods -l test=registry-pull -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete pods -l test=registry-test -n "$NAMESPACE" --ignore-not-found=true
    
    # 清理临时文件
    rm -f /tmp/registry-test-env
    rm -f /tmp/registry-api-test.log
    rm -f /tmp/registry-proxy-test.log
    rm -f /tmp/external-registry-test.log
    
    log_info "测试资源清理完成"
}

# 显示测试报告
show_test_report() {
    echo ""
    echo "=========================================="
    echo "          Registry代理测试报告"
    echo "=========================================="
    echo "总测试数: $TOTAL_TESTS"
    echo "通过测试: $PASSED_TESTS"
    echo "失败测试: $FAILED_TESTS"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}测试结果: 全部通过${NC}"
        echo ""
        echo "Registry代理配置正常，可以正常使用。"
    elif [[ $PASSED_TESTS -gt $FAILED_TESTS ]]; then
        echo -e "${YELLOW}测试结果: 部分通过${NC}"
        echo ""
        echo "Registry代理基本功能正常，但存在一些问题需要关注。"
    else
        echo -e "${RED}测试结果: 主要功能异常${NC}"
        echo ""
        echo "Registry代理存在严重问题，请检查配置和部署状态。"
    fi
    
    echo ""
    echo "故障排除建议:"
    echo "1. 检查Pod日志: kubectl logs -l app=registry-proxy -n $NAMESPACE"
    echo "2. 检查服务状态: kubectl get svc registry-proxy -n $NAMESPACE"
    echo "3. 检查配置: kubectl get configmap registry-proxy-config -n $NAMESPACE -o yaml"
    echo "4. 检查网络连接: kubectl exec -it <pod-name> -n $NAMESPACE -- wget -O- http://registry-proxy:5000/v2/"
    echo "=========================================="
}

# 主函数
main() {
    local quick_test=false
    local cleanup_only=false
    local external_test=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -s|--service)
                REGISTRY_SERVICE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --quick)
                quick_test=true
                shift
                ;;
            --cleanup)
                cleanup_only=true
                shift
                ;;
            --external-test)
                external_test=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "Registry代理访问测试"
    log_info "命名空间: $NAMESPACE"
    log_info "服务名称: $REGISTRY_SERVICE"
    
    # 检查依赖项
    if ! check_dependencies; then
        exit 1
    fi
    
    # 清理模式
    if [[ "$cleanup_only" == "true" ]]; then
        cleanup_test_resources
        exit 0
    fi
    
    # 运行测试
    test_registry_service
    test_registry_pods
    test_configuration
    test_registry_api
    test_registry_proxy
    test_image_pull "$quick_test"
    
    if [[ "$external_test" == "true" ]]; then
        test_external_registry
    fi
    
    # 显示测试报告
    show_test_report
    
    # 清理测试资源
    cleanup_test_resources
    
    # 返回适当的退出码
    if [[ $FAILED_TESTS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
