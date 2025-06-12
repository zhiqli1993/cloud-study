#!/bin/bash

# Kubernetes Docker Registry Proxy Installation Script
# For configuring and deploying Docker Registry proxy in Kubernetes clusters

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NAMESPACE="${NAMESPACE:-default}"
REGISTRY_PROXY_NAME="${REGISTRY_PROXY_NAME:-registry-proxy}"
VERBOSE="${VERBOSE:-false}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Help information
show_help() {
    cat << EOF
Kubernetes Docker Registry Proxy Installation Script

Usage: $0 [options]

Options:
    -h, --help              Show help information
    -n, --namespace NAME    Specify Kubernetes namespace (default: default)
    -v, --verbose           Enable verbose output
    --dry-run              Show commands to be executed without running them
    --uninstall            Uninstall Registry proxy
    --check-deps           Check dependencies
    --config-only          Only generate configuration files
    --skip-deploy          Skip deployment steps

Environment Variables:
    NAMESPACE              Kubernetes namespace
    REGISTRY_PROXY_NAME    Registry proxy name
    HTTP_PROXY             HTTP proxy address
    HTTPS_PROXY            HTTPS proxy address
    NO_PROXY               Addresses to bypass proxy
    DOCKER_REGISTRY_USER   Docker Registry username
    DOCKER_REGISTRY_PASS   Docker Registry password
    DOCKER_REGISTRY_EMAIL  Docker Registry email
    DOCKER_REGISTRY_SERVER Docker Registry server address

Examples:
    # Basic installation
    $0

    # Install with specific namespace
    $0 --namespace registry-system

    # Install with proxy environment variables
    HTTP_PROXY=http://proxy.company.com:8080 \\
    HTTPS_PROXY=http://proxy.company.com:8080 \\
    $0

    # Configure private Registry authentication
    DOCKER_REGISTRY_SERVER=registry.company.com \\
    DOCKER_REGISTRY_USER=myuser \\
    DOCKER_REGISTRY_PASS=mypass \\
    DOCKER_REGISTRY_EMAIL=user@company.com \\
    $0

    # Uninstall
    $0 --uninstall
EOF
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    local deps=("kubectl" "docker")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        else
            log_debug "$dep installed: $(command -v "$dep")"
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install these tools before running this script"
        return 1
    fi
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_error "Please ensure kubectl is properly configured and cluster is accessible"
        return 1
    fi
    
    log_info "All dependency checks passed"
    return 0
}

# Create namespace
create_namespace() {
    log_info "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace "$NAMESPACE"
        log_info "Namespace $NAMESPACE created successfully"
    fi
}

# Create Registry authentication Secret
create_registry_secret() {
    local server="${DOCKER_REGISTRY_SERVER:-registry.company.com}"
    local username="${DOCKER_REGISTRY_USER:-}"
    local password="${DOCKER_REGISTRY_PASS:-}"
    local email="${DOCKER_REGISTRY_EMAIL:-user@company.com}"
    
    if [[ -n "$username" && -n "$password" ]]; then
        log_info "Creating Registry authentication Secret..."
        
        kubectl create secret docker-registry registry-secret \
            --namespace="$NAMESPACE" \
            --docker-server="$server" \
            --docker-username="$username" \
            --docker-password="$password" \
            --docker-email="$email" \
            --dry-run=client -o yaml | kubectl apply -f -
        
        log_info "Registry authentication Secret created successfully"
    else
        log_warn "No Registry authentication information provided, using default configuration"
    fi
}

# Generate proxy configuration
generate_proxy_config() {
    local config_file="$PROJECT_DIR/configs/docker-daemon-proxy.json"
    local http_proxy="${HTTP_PROXY:-}"
    local https_proxy="${HTTPS_PROXY:-}"
    local no_proxy="${NO_PROXY:-localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,*.local,*.internal}"
    
    if [[ -n "$http_proxy" || -n "$https_proxy" ]]; then
        log_info "Updating proxy configuration..."
        
        # Use jq to update configuration file (if available)
        if command -v jq &> /dev/null; then
            local temp_file=$(mktemp)
            jq --arg http_proxy "$http_proxy" \
               --arg https_proxy "$https_proxy" \
               --arg no_proxy "$no_proxy" \
               '.proxies.default.httpProxy = $http_proxy |
                .proxies.default.httpsProxy = $https_proxy |
                .proxies.default.noProxy = $no_proxy' \
               "$config_file" > "$temp_file"
            mv "$temp_file" "$config_file"
            log_info "Proxy configuration updated successfully"
        else
            log_warn "jq not installed, please manually edit $config_file"
        fi
    fi
}

# Apply Kubernetes configurations
apply_kubernetes_configs() {
    log_info "Applying Kubernetes configurations..."
    
    # Apply authentication and RBAC configuration
    if [[ -f "$PROJECT_DIR/configs/private-registry-secret.yaml" ]]; then
        log_debug "Applying Registry authentication configuration..."
        kubectl apply -f "$PROJECT_DIR/configs/private-registry-secret.yaml" -n "$NAMESPACE"
    fi
    
    # Apply Registry proxy deployment
    if [[ -f "$PROJECT_DIR/manifests/registry-proxy-deployment.yaml" ]]; then
        log_debug "Applying Registry proxy deployment..."
        kubectl apply -f "$PROJECT_DIR/manifests/registry-proxy-deployment.yaml" -n "$NAMESPACE"
    fi
    
    log_info "Kubernetes configurations applied successfully"
}

# 等待部署就绪
wait_for_deployment() {
    log_info "等待Registry代理部署就绪..."
    
    if kubectl wait --for=condition=available \
        --timeout=300s \
        deployment/"$REGISTRY_PROXY_NAME" \
        -n "$NAMESPACE"; then
        log_info "Registry代理部署成功"
        return 0
    else
        log_error "Registry代理部署超时"
        return 1
    fi
}

# 验证部署
verify_deployment() {
    log_info "验证Registry代理部署..."
    
    # 检查Pod状态
    local pods=$(kubectl get pods -l app=registry-proxy -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    if [[ -z "$pods" ]]; then
        log_error "未找到Registry代理Pod"
        return 1
    fi
    
    log_info "找到Registry代理Pod: $pods"
    
    # 检查服务状态
    if kubectl get service registry-proxy -n "$NAMESPACE" &> /dev/null; then
        local service_ip=$(kubectl get service registry-proxy -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
        log_info "Registry代理服务地址: $service_ip:5000"
    fi
    
    # 测试Registry API
    local pod_name=$(echo "$pods" | cut -d' ' -f1)
    if kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s http://localhost:5000/v2/ &> /dev/null; then
        log_info "Registry API响应正常"
    else
        log_warn "Registry API响应异常，请检查配置"
    fi
    
    return 0
}

# 显示部署信息
show_deployment_info() {
    log_info "Registry代理部署信息:"
    
    echo ""
    echo "=== Pod状态 ==="
    kubectl get pods -l app=registry-proxy -n "$NAMESPACE" -o wide
    
    echo ""
    echo "=== 服务信息 ==="
    kubectl get services -l app=registry-proxy -n "$NAMESPACE"
    
    echo ""
    echo "=== Ingress信息 ==="
    kubectl get ingress -l app=registry-proxy -n "$NAMESPACE" 2>/dev/null || echo "未配置Ingress"
    
    echo ""
    echo "=== 配置信息 ==="
    echo "命名空间: $NAMESPACE"
    echo "Registry代理名称: $REGISTRY_PROXY_NAME"
    
    local service_ip=$(kubectl get service registry-proxy -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "N/A")
    echo "内部访问地址: http://$service_ip:5000"
    
    local nodeport=$(kubectl get service registry-proxy-nodeport -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    if [[ "$nodeport" != "N/A" ]]; then
        echo "外部访问端口: $nodeport"
    fi
    
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 配置Docker daemon使用代理:"
    echo "   编辑 /etc/docker/daemon.json 添加:"
    echo "   {\"registry-mirrors\": [\"http://$service_ip:5000\"]}"
    echo ""
    echo "2. 或者在Pod中使用:"
    echo "   image: $service_ip:5000/library/nginx:latest"
    echo ""
    echo "3. 查看代理日志:"
    echo "   kubectl logs -l app=registry-proxy -n $NAMESPACE -f"
}

# 卸载Registry代理
uninstall_registry_proxy() {
    log_info "开始卸载Registry代理..."
    
    # 删除部署
    if kubectl get deployment "$REGISTRY_PROXY_NAME" -n "$NAMESPACE" &> /dev/null; then
        kubectl delete deployment "$REGISTRY_PROXY_NAME" -n "$NAMESPACE"
        log_info "删除部署: $REGISTRY_PROXY_NAME"
    fi
    
    # 删除服务
    if kubectl get service registry-proxy -n "$NAMESPACE" &> /dev/null; then
        kubectl delete service registry-proxy -n "$NAMESPACE"
        log_info "删除服务: registry-proxy"
    fi
    
    if kubectl get service registry-proxy-nodeport -n "$NAMESPACE" &> /dev/null; then
        kubectl delete service registry-proxy-nodeport -n "$NAMESPACE"
        log_info "删除NodePort服务: registry-proxy-nodeport"
    fi
    
    # 删除Ingress
    if kubectl get ingress registry-proxy-ingress -n "$NAMESPACE" &> /dev/null; then
        kubectl delete ingress registry-proxy-ingress -n "$NAMESPACE"
        log_info "删除Ingress: registry-proxy-ingress"
    fi
    
    # 删除ConfigMap
    if kubectl get configmap registry-proxy-config -n "$NAMESPACE" &> /dev/null; then
        kubectl delete configmap registry-proxy-config -n "$NAMESPACE"
        log_info "删除ConfigMap: registry-proxy-config"
    fi
    
    # 删除Secret
    if kubectl get secret registry-secret -n "$NAMESPACE" &> /dev/null; then
        kubectl delete secret registry-secret -n "$NAMESPACE"
        log_info "删除Secret: registry-secret"
    fi
    
    # 删除PVC
    if kubectl get pvc registry-proxy-pvc -n "$NAMESPACE" &> /dev/null; then
        kubectl delete pvc registry-proxy-pvc -n "$NAMESPACE"
        log_info "删除PVC: registry-proxy-pvc"
    fi
    
    # 删除RBAC
    if kubectl get clusterrole registry-proxy-role &> /dev/null; then
        kubectl delete clusterrole registry-proxy-role
        log_info "删除ClusterRole: registry-proxy-role"
    fi
    
    if kubectl get clusterrolebinding registry-proxy-binding &> /dev/null; then
        kubectl delete clusterrolebinding registry-proxy-binding
        log_info "删除ClusterRoleBinding: registry-proxy-binding"
    fi
    
    log_info "Registry代理卸载完成"
}

# 主函数
main() {
    local dry_run=false
    local uninstall=false
    local check_deps_only=false
    local config_only=false
    local skip_deploy=false
    
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
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --uninstall)
                uninstall=true
                shift
                ;;
            --check-deps)
                check_deps_only=true
                shift
                ;;
            --config-only)
                config_only=true
                shift
                ;;
            --skip-deploy)
                skip_deploy=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "Kubernetes Docker Registry 代理安装脚本"
    log_info "项目目录: $PROJECT_DIR"
    log_info "命名空间: $NAMESPACE"
    
    # 检查依赖项
    if ! check_dependencies; then
        exit 1
    fi
    
    if [[ "$check_deps_only" == "true" ]]; then
        log_info "依赖项检查完成"
        exit 0
    fi
    
    # 卸载模式
    if [[ "$uninstall" == "true" ]]; then
        uninstall_registry_proxy
        exit 0
    fi
    
    # 生成配置
    if [[ "$dry_run" == "false" ]]; then
        generate_proxy_config
    fi
    
    if [[ "$config_only" == "true" ]]; then
        log_info "配置文件生成完成"
        exit 0
    fi
    
    # 部署Registry代理
    if [[ "$skip_deploy" == "false" && "$dry_run" == "false" ]]; then
        create_namespace
        create_registry_secret
        apply_kubernetes_configs
        
        if wait_for_deployment; then
            verify_deployment
            show_deployment_info
        else
            log_error "部署失败"
            exit 1
        fi
    elif [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] 将执行以下操作:"
        log_info "1. 创建命名空间: $NAMESPACE"
        log_info "2. 创建Registry认证Secret"
        log_info "3. 应用Kubernetes配置"
        log_info "4. 等待部署就绪"
        log_info "5. 验证部署状态"
    fi
    
    log_info "Registry代理安装完成"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
