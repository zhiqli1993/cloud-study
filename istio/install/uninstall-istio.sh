#!/bin/bash

# Istio Uninstallation Script
# Supports Linux, macOS, and Windows platforms
# Usage: ./uninstall-istio.sh [--purge]

set -e

# Parse arguments
PURGE_MODE=false
if [[ "$1" == "--purge" ]]; then
    PURGE_MODE=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
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

# Detect operating system
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$os" in
        linux*)
            OS="linux"
            ;;
        darwin*)
            OS="osx"
            ;;
        mingw*|msys*|cygwin*)
            OS="win"
            ;;
        *)
            print_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
    
    if [[ "$OS" == "win" ]]; then
        BINARY_NAME="istioctl.exe"
    else
        BINARY_NAME="istioctl"
    fi
    
    print_info "Detected platform: $OS"
}

# Check if istioctl is installed
check_istioctl_installed() {
    if ! command -v istioctl >/dev/null 2>&1; then
        print_warning "istioctl is not installed or not in PATH"
        return 1
    fi
    return 0
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl >/dev/null 2>&1; then
        print_warning "kubectl is not installed. Cannot uninstall Istio from cluster."
        return 1
    fi
    return 0
}

# Uninstall Istio from Kubernetes cluster
uninstall_istio_from_cluster() {
    print_info "Uninstalling Istio from Kubernetes cluster..."
    
    # Check if kubectl is available and cluster is accessible
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubectl configuration."
        return 1
    fi
    
    # Check if Istio is installed in the cluster
    if ! kubectl get namespace istio-system >/dev/null 2>&1; then
        print_warning "Istio system namespace not found. Istio may not be installed in this cluster."
    else
        print_info "Found Istio installation in cluster"
        
        # Uninstall Istio
        if [[ "$PURGE_MODE" == "true" ]]; then
            print_info "Running: istioctl uninstall --purge -y"
            if istioctl uninstall --purge -y; then
                print_success "Istio uninstalled successfully (purge mode)"
            else
                print_error "Failed to uninstall Istio from cluster"
                return 1
            fi
        else
            print_info "Running: istioctl uninstall -y"
            if istioctl uninstall -y; then
                print_success "Istio uninstalled successfully"
            else
                print_error "Failed to uninstall Istio from cluster"
                return 1
            fi
        fi
    fi
    
    # Remove istio-injection labels from namespaces
    print_info "Removing istio-injection labels from namespaces..."
    local labeled_namespaces=$(kubectl get namespaces -l istio-injection=enabled -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$labeled_namespaces" ]]; then
        for ns in $labeled_namespaces; do
            print_info "Removing istio-injection label from namespace: $ns"
            kubectl label namespace "$ns" istio-injection- >/dev/null 2>&1 || true
        done
        print_success "Removed istio-injection labels from namespaces"
    else
        print_info "No namespaces with istio-injection labels found"
    fi
    
    # Clean up remaining resources if purge mode
    if [[ "$PURGE_MODE" == "true" ]]; then
        print_info "Cleaning up remaining Istio resources..."
        
        # Remove Istio CRDs
        print_info "Removing Istio CRDs..."
        kubectl get crd -o name | grep -E 'istio\.io|maistra\.io' | xargs -r kubectl delete >/dev/null 2>&1 || true
        
        # Remove Istio namespaces
        for ns in istio-system istio-operator; do
            if kubectl get namespace "$ns" >/dev/null 2>&1; then
                print_info "Removing namespace: $ns"
                kubectl delete namespace "$ns" --timeout=60s >/dev/null 2>&1 || true
            fi
        done
        
        print_success "Purge cleanup completed"
    fi
    
    return 0
}

# Remove istioctl binary
remove_istioctl_binary() {
    print_info "Removing istioctl binary..."
    
    # Find istioctl location
    local istioctl_path=$(which istioctl 2>/dev/null || echo "")
    
    if [[ -z "$istioctl_path" ]]; then
        print_warning "istioctl binary not found in PATH"
        return 0
    fi
    
    print_info "Found istioctl at: $istioctl_path"
    
    # Try to remove the binary
    if rm "$istioctl_path" 2>/dev/null; then
        print_success "istioctl binary removed successfully"
    else
        print_error "Failed to remove istioctl binary at $istioctl_path"
        print_info "You may need to run this script with sudo or remove it manually"
        print_info "Manual removal: sudo rm $istioctl_path"
        return 1
    fi
    
    return 0
}

# Clean up istioctl configuration
cleanup_istioctl_config() {
    print_info "Cleaning up istioctl configuration..."
    
    # Remove istioctl config directory if it exists
    local config_dirs=(
        "$HOME/.istioctl"
        "$HOME/.config/istio"
    )
    
    for config_dir in "${config_dirs[@]}"; do
        if [[ -d "$config_dir" ]]; then
            print_info "Removing configuration directory: $config_dir"
            if rm -rf "$config_dir"; then
                print_success "Removed $config_dir"
            else
                print_warning "Failed to remove $config_dir"
            fi
        fi
    done
    
    return 0
}

# Main function
main() {
    print_info "Istio Uninstallation Script"
    print_info "==========================="
    
    if [[ "$PURGE_MODE" == "true" ]]; then
        print_warning "Running in PURGE mode - this will remove ALL Istio resources"
    fi
    
    # Detect platform
    detect_platform
    
    # Check if istioctl is installed
    if check_istioctl_installed; then
        local current_version=$(istioctl version --client --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        print_info "Current istioctl version: $current_version"
    fi
    
    # Ask for confirmation
    print_warning "This will uninstall Istio from your system and cluster."
    if [[ "$PURGE_MODE" == "true" ]]; then
        print_warning "PURGE mode will remove ALL Istio resources including CRDs!"
    fi
    
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstallation cancelled."
        exit 0
    fi
    
    # Uninstall from cluster if kubectl is available
    if check_kubectl && check_istioctl_installed; then
        print_info ""
        read -p "Do you want to uninstall Istio from your Kubernetes cluster? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            uninstall_istio_from_cluster
        else
            print_info "Skipping cluster uninstallation"
        fi
    else
        print_warning "Skipping cluster uninstallation (kubectl or istioctl not available)"
    fi
    
    # Remove istioctl binary
    print_info ""
    read -p "Do you want to remove the istioctl binary? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        remove_istioctl_binary
    else
        print_info "Keeping istioctl binary"
    fi
    
    # Clean up configuration
    if [[ "$PURGE_MODE" == "true" ]]; then
        cleanup_istioctl_config
    fi
    
    print_success "Uninstallation completed!"
    print_info ""
    print_info "If you want to reinstall Istio later, you can use:"
    print_info "  ./install-istio.sh"
    print_info ""
    print_info "For more information, visit: https://istio.io/latest/docs/"
}

# Run main function
main "$@"
