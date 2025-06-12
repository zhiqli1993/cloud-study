#!/bin/bash

# Kind Uninstall Script
# Supports Linux, macOS, and Windows platforms
# Usage: ./uninstall-kind.sh

set -e

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
            OS="darwin"
            ;;
        mingw*|msys*|cygwin*)
            OS="windows"
            ;;
        *)
            print_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
    
    if [[ "$OS" == "windows" ]]; then
        BINARY_NAME="kind.exe"
    else
        BINARY_NAME="kind"
    fi
    
    print_info "Detected platform: $OS"
}

# Find kind installation
find_kind_installation() {
    local kind_path=""
    
    # Check if kind is in PATH
    if command -v kind >/dev/null 2>&1; then
        kind_path=$(which kind 2>/dev/null || command -v kind)
        if [[ -n "$kind_path" ]]; then
            echo "$kind_path"
            return 0
        fi
    fi
    
    # Search in common installation directories
    local common_dirs=(
        "/usr/local/bin"
        "/usr/bin"
        "$HOME/.local/bin"
        "$HOME/bin"
    )
    
    # Add Windows-specific directories
    if [[ "$OS" == "windows" ]]; then
        common_dirs+=(
            "/c/Program Files/Git/usr/local/bin"
            "$HOME/AppData/Local/Microsoft/WindowsApps"
        )
    fi
    
    for dir in "${common_dirs[@]}"; do
        if [[ -f "$dir/$BINARY_NAME" ]]; then
            echo "$dir/$BINARY_NAME"
            return 0
        fi
    done
    
    return 1
}

# Remove kind clusters
remove_clusters() {
    if command -v kind >/dev/null 2>&1; then
        print_info "Checking for existing kind clusters..."
        
        local clusters=$(kind get clusters 2>/dev/null || true)
        if [[ -n "$clusters" ]]; then
            print_warning "Found existing kind clusters:"
            echo "$clusters"
            echo
            read -p "Do you want to delete all kind clusters? [y/N]: " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Deleting kind clusters..."
                echo "$clusters" | while read -r cluster; do
                    if [[ -n "$cluster" ]]; then
                        print_info "Deleting cluster: $cluster"
                        kind delete cluster --name "$cluster" || true
                    fi
                done
                print_success "All kind clusters deleted"
            else
                print_warning "Skipping cluster deletion"
            fi
        else
            print_info "No kind clusters found"
        fi
    fi
}

# Remove Docker networks created by kind
cleanup_docker_networks() {
    if command -v docker >/dev/null 2>&1; then
        print_info "Cleaning up Docker networks created by kind..."
        
        # Remove kind networks
        local kind_networks=$(docker network ls --filter name=kind --format "{{.Name}}" 2>/dev/null || true)
        if [[ -n "$kind_networks" ]]; then
            echo "$kind_networks" | while read -r network; do
                if [[ -n "$network" ]]; then
                    print_info "Removing Docker network: $network"
                    docker network rm "$network" 2>/dev/null || true
                fi
            done
        fi
        
        print_success "Docker network cleanup completed"
    else
        print_warning "Docker not found, skipping network cleanup"
    fi
}

# Remove kind binary
remove_kind_binary() {
    local kind_path=$(find_kind_installation)
    
    if [[ -z "$kind_path" ]]; then
        print_warning "Kind binary not found in common locations"
        return 0
    fi
    
    print_info "Found kind installation: $kind_path"
    
    # Get current version
    local current_version="unknown"
    if [[ -x "$kind_path" ]]; then
        current_version=$("$kind_path" version 2>/dev/null | grep 'kind' | awk '{print $2}' || echo "unknown")
    fi
    
    print_info "Current kind version: $current_version"
    echo
    read -p "Do you want to remove the kind binary? [y/N]: " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if rm "$kind_path" 2>/dev/null; then
            print_success "Kind binary removed: $kind_path"
        else
            print_error "Failed to remove kind binary: $kind_path"
            print_info "You may need to run this script with sudo or remove it manually"
            print_info "Manual removal: sudo rm $kind_path"
            return 1
        fi
    else
        print_warning "Skipping binary removal"
    fi
}

# Remove kind configuration directory
remove_kind_config() {
    local config_dir="$HOME/.kind"
    
    if [[ -d "$config_dir" ]]; then
        print_info "Found kind configuration directory: $config_dir"
        echo
        read -p "Do you want to remove kind configuration directory? [y/N]: " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if rm -rf "$config_dir" 2>/dev/null; then
                print_success "Kind configuration directory removed: $config_dir"
            else
                print_error "Failed to remove kind configuration directory: $config_dir"
                print_info "Manual removal: rm -rf $config_dir"
            fi
        else
            print_warning "Skipping configuration directory removal"
        fi
    else
        print_info "No kind configuration directory found"
    fi
}

# Verify uninstallation
verify_uninstallation() {
    print_info "Verifying uninstallation..."
    
    if command -v kind >/dev/null 2>&1; then
        local remaining_path=$(which kind 2>/dev/null || command -v kind)
        print_warning "Kind binary still found at: $remaining_path"
        print_warning "Uninstallation may be incomplete"
    else
        print_success "Kind binary successfully removed from PATH"
    fi
    
    # Check for remaining clusters
    if command -v docker >/dev/null 2>&1; then
        local remaining_containers=$(docker ps -a --filter name=kind --format "{{.Names}}" 2>/dev/null || true)
        if [[ -n "$remaining_containers" ]]; then
            print_warning "Found remaining kind containers:"
            echo "$remaining_containers"
            print_info "You may want to remove them manually with: docker rm -f <container_name>"
        fi
        
        local remaining_images=$(docker images --filter reference="kindest/*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)
        if [[ -n "$remaining_images" ]]; then
            print_warning "Found remaining kind images:"
            echo "$remaining_images"
            print_info "You may want to remove them manually with: docker rmi <image_name>"
        fi
    fi
}

# Main function
main() {
    print_info "Kind Uninstall Script"
    print_info "===================="
    print_info ""
    print_warning "This script will help you remove kind and its associated resources."
    print_warning "Please make sure you have backed up any important data."
    print_info ""
    
    # Detect platform
    detect_platform
    
    # Check if kind is installed
    if ! command -v kind >/dev/null 2>&1 && [[ -z $(find_kind_installation) ]]; then
        print_info "Kind is not installed or not found in PATH"
        exit 0
    fi
    
    echo
    read -p "Do you want to proceed with kind uninstallation? [y/N]: " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    print_info ""
    print_info "Starting uninstallation process..."
    
    # Remove clusters first
    remove_clusters
    
    # Cleanup Docker resources
    cleanup_docker_networks
    
    # Remove binary
    remove_kind_binary
    
    # Remove configuration
    remove_kind_config
    
    # Verify uninstallation
    verify_uninstallation
    
    print_info ""
    print_success "Kind uninstallation completed!"
    print_info ""
    print_info "Note: Docker images used by kind clusters may still exist."
    print_info "You can remove them manually if needed:"
    print_info "  docker images --filter reference='kindest/*'"
    print_info "  docker rmi <image_name>"
    print_info ""
    print_info "Thank you for using kind!"
}

# Run main function
main "$@"
