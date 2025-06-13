#!/bin/bash

# Istio Demo Applications Deployment Script
# Author: Cloud Study Repository
# Purpose: Quick deployment of Istio official sample applications

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Unable to connect to Kubernetes cluster"
        exit 1
    fi
    
    print_success "kubectl check passed"
}

# Check if Istio is installed
check_istio() {
    if ! kubectl get namespace istio-system &> /dev/null; then
        print_error "istio-system namespace not detected, please install Istio first"
        exit 1
    fi
    
    if ! kubectl get pods -n istio-system -l app=istiod | grep -q Running; then
        print_error "Istio control plane is not running, please check Istio installation"
        exit 1
    fi
    
    print_success "Istio check passed"
}

# Enable Istio automatic injection
enable_istio_injection() {
    local namespace=${1:-default}
    print_info "Enabling Istio sidecar auto-injection for namespace '$namespace'..."
    
    kubectl label namespace "$namespace" istio-injection=enabled --overwrite
    print_success "Istio auto-injection enabled"
}

# Deploy Bookinfo application
deploy_bookinfo() {
    print_info "Deploying Bookinfo application..."
    
    kubectl apply -f bookinfo/bookinfo.yaml
    kubectl apply -f bookinfo/bookinfo-gateway.yaml
    kubectl apply -f bookinfo/destination-rule-all.yaml
    
    print_success "Bookinfo application deployment completed"
}

# Deploy Httpbin application
deploy_httpbin() {
    print_info "Deploying Httpbin application..."
    
    kubectl apply -f httpbin/httpbin.yaml
    
    print_success "Httpbin application deployment completed"
}

# Deploy Sleep application
deploy_sleep() {
    print_info "Deploying Sleep application..."
    
    kubectl apply -f sleep/sleep.yaml
    
    print_success "Sleep application deployment completed"
}

# Deploy HelloWorld application
deploy_helloworld() {
    print_info "Deploying HelloWorld application..."
    
    kubectl apply -f helloworld/helloworld.yaml
    
    print_success "HelloWorld application deployment completed"
}

# Wait for pods to be ready
wait_for_pods() {
    local app_name=$1
    local timeout=${2:-300}
    
    print_info "Waiting for $app_name application pods to be ready..."
    
    if kubectl wait --for=condition=ready pod -l app="$app_name" --timeout="${timeout}s" &> /dev/null; then
        print_success "$app_name application pods are ready"
    else
        print_warning "$app_name application pods not ready within ${timeout}s, please check manually"
    fi
}

# Show application status
show_status() {
    print_info "Application deployment status:"
    echo ""
    
    echo "Pods status:"
    kubectl get pods -l app=productpage -o wide 2>/dev/null || echo "  Bookinfo not deployed"
    kubectl get pods -l app=httpbin -o wide 2>/dev/null || echo "  Httpbin not deployed"
    kubectl get pods -l app=sleep -o wide 2>/dev/null || echo "  Sleep not deployed"
    kubectl get pods -l app=helloworld -o wide 2>/dev/null || echo "  HelloWorld not deployed"
    
    echo ""
    echo "Services status:"
    kubectl get svc productpage 2>/dev/null || echo "  Bookinfo productpage service not deployed"
    kubectl get svc httpbin 2>/dev/null || echo "  Httpbin service not deployed"
    kubectl get svc sleep 2>/dev/null || echo "  Sleep service not deployed"
    kubectl get svc helloworld 2>/dev/null || echo "  HelloWorld service not deployed"
    
    echo ""
    echo "Istio configurations:"
    kubectl get gateway,virtualservice,destinationrule 2>/dev/null || echo "  No Istio configurations"
}

# Show access information
show_access_info() {
    print_info "Application access information:"
    echo ""
    
    # Check Istio Ingress Gateway
    if kubectl get svc istio-ingressgateway -n istio-system &> /dev/null; then
        echo "Istio Ingress Gateway:"
        kubectl get svc istio-ingressgateway -n istio-system
        echo ""
        
        echo "Commands to get Bookinfo access URL:"
        echo "export INGRESS_HOST=\$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
        echo "export INGRESS_PORT=\$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name==\"http2\")].port}')"
        echo "export GATEWAY_URL=\$INGRESS_HOST:\$INGRESS_PORT"
        echo "curl http://\$GATEWAY_URL/productpage"
        echo ""
    fi
    
    echo "Test command examples:"
    echo "# Enter sleep pod for testing"
    echo "kubectl exec -it deploy/sleep -- sh"
    echo ""
    echo "# Test httpbin"
    echo "kubectl exec -it deploy/sleep -- curl httpbin:8000/get"
    echo ""
    echo "# Test helloworld"
    echo "kubectl exec -it deploy/sleep -- curl helloworld:5000/hello"
    echo ""
    echo "# Test bookinfo"
    echo "kubectl exec -it deploy/sleep -- curl productpage:9080/productpage"
}

# Clean up all applications
cleanup_all() {
    print_info "Cleaning up all demo applications..."
    
    kubectl delete -f bookinfo/ --ignore-not-found=true
    kubectl delete -f httpbin/ --ignore-not-found=true
    kubectl delete -f sleep/ --ignore-not-found=true
    kubectl delete -f helloworld/ --ignore-not-found=true
    
    print_success "All demo applications cleaned up"
}

# Show help information
show_help() {
    echo "Istio Demo Applications Deployment Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -a, --all              Deploy all demo applications"
    echo "  -b, --bookinfo         Deploy Bookinfo application"
    echo "  -h, --httpbin          Deploy Httpbin application"
    echo "  -s, --sleep            Deploy Sleep application"
    echo "  -w, --helloworld       Deploy HelloWorld application"
    echo "  -i, --injection [ns]   Enable Istio auto-injection for namespace (default: default)"
    echo "  -c, --cleanup          Clean up all demo applications"
    echo "  -t, --status           Show application status"
    echo "  -f, --info             Show access information"
    echo "  --help                 Show this help information"
    echo ""
    echo "Examples:"
    echo "  $0 --all               # Deploy all applications"
    echo "  $0 -b -s               # Deploy Bookinfo and Sleep"
    echo "  $0 -i myapp            # Enable auto-injection for myapp namespace"
    echo "  $0 --cleanup           # Clean up all applications"
}

# Main function
main() {
    local deploy_all=false
    local deploy_bookinfo=false
    local deploy_httpbin=false
    local deploy_sleep=false
    local deploy_helloworld=false
    local enable_injection=false
    local injection_namespace="default"
    local show_status_only=false
    local show_info_only=false
    local cleanup=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                deploy_all=true
                shift
                ;;
            -b|--bookinfo)
                deploy_bookinfo=true
                shift
                ;;
            -h|--httpbin)
                deploy_httpbin=true
                shift
                ;;
            -s|--sleep)
                deploy_sleep=true
                shift
                ;;
            -w|--helloworld)
                deploy_helloworld=true
                shift
                ;;
            -i|--injection)
                enable_injection=true
                if [[ -n $2 && $2 != -* ]]; then
                    injection_namespace=$2
                    shift
                fi
                shift
                ;;
            -c|--cleanup)
                cleanup=true
                shift
                ;;
            -t|--status)
                show_status_only=true
                shift
                ;;
            -f|--info)
                show_info_only=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Change to script directory
    cd "$(dirname "$0")"
    
    # If only showing status or info, no need to check environment
    if [[ $show_status_only == true ]]; then
        show_status
        exit 0
    fi
    
    if [[ $show_info_only == true ]]; then
        show_access_info
        exit 0
    fi
    
    # Check environment
    print_info "Checking environment..."
    check_kubectl
    check_istio
    
    # Execute cleanup
    if [[ $cleanup == true ]]; then
        cleanup_all
        exit 0
    fi
    
    # Enable auto-injection
    if [[ $enable_injection == true ]]; then
        enable_istio_injection "$injection_namespace"
    fi
    
    # Deploy applications
    if [[ $deploy_all == true ]]; then
        deploy_bookinfo
        deploy_httpbin
        deploy_sleep
        deploy_helloworld
        
        # Wait for pods to be ready
        wait_for_pods "productpage"
        wait_for_pods "httpbin"
        wait_for_pods "sleep"
        wait_for_pods "helloworld"
        
    else
        if [[ $deploy_bookinfo == true ]]; then
            deploy_bookinfo
            wait_for_pods "productpage"
        fi
        
        if [[ $deploy_httpbin == true ]]; then
            deploy_httpbin
            wait_for_pods "httpbin"
        fi
        
        if [[ $deploy_sleep == true ]]; then
            deploy_sleep
            wait_for_pods "sleep"
        fi
        
        if [[ $deploy_helloworld == true ]]; then
            deploy_helloworld
            wait_for_pods "helloworld"
        fi
    fi
    
    # If no deployment options specified, show help
    if [[ $deploy_all == false && $deploy_bookinfo == false && $deploy_httpbin == false && $deploy_sleep == false && $deploy_helloworld == false && $enable_injection == false ]]; then
        show_help
        exit 0
    fi
    
    # Show deployment status and access information
    echo ""
    show_status
    echo ""
    show_access_info
}

# Execute main function
main "$@"
