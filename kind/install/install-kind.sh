#!/bin/bash

# Kind Installation/Upgrade Script
# Supports Linux, macOS, and Windows platforms
# Usage: ./install-kind.sh [version]

set -e

# Default version (latest if not specified)
KIND_VERSION=${1:-"latest"}

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

# Detect operating system and architecture
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
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
    
    case "$arch" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="arm"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    
    if [[ "$OS" == "windows" ]]; then
        BINARY_NAME="kind.exe"
    else
        BINARY_NAME="kind"
    fi
    
    print_info "Detected platform: $OS-$ARCH"
}

# Get the latest version from GitHub API
get_latest_version() {
    if command -v curl >/dev/null 2>&1; then
        local latest_version=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        local latest_version=$(wget -qO- https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        print_error "Neither curl nor wget is available. Please install one of them."
        exit 1
    fi
    
    if [[ -z "$latest_version" ]]; then
        print_error "Failed to get latest version"
        exit 1
    fi
    
    echo "$latest_version"
}

# Check if kind is already installed and get version
check_current_version() {
    if command -v kind >/dev/null 2>&1; then
        local current_version=$(kind version 2>/dev/null | grep 'kind' | awk '{print $2}' || echo "unknown")
        echo "$current_version"
    else
        echo "not_installed"
    fi
}

# Download and install kind
install_kind() {
    local version="$1"
    local download_url="https://kind.sigs.k8s.io/dl/${version}/kind-${OS}-${ARCH}"
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    local temp_file="${temp_dir}/${BINARY_NAME}"
    
    print_info "Downloading kind ${version} for ${OS}-${ARCH}..."
    
    # Download the binary
    if command -v curl >/dev/null 2>&1; then
        if ! curl -L -o "$temp_file" "$download_url"; then
            print_error "Failed to download kind"
            rm -rf "$temp_dir"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -O "$temp_file" "$download_url"; then
            print_error "Failed to download kind"
            rm -rf "$temp_dir"
            exit 1
        fi
    else
        print_error "Neither curl nor wget is available. Please install one of them."
        exit 1
    fi
    
    # Make it executable
    chmod +x "$temp_file"
    
    # Determine installation directory
    local install_dir=""
    if [[ "$OS" == "windows" ]]; then
        # For Windows, try to install in a directory that's likely in PATH
        if [[ -d "/c/Program Files/Git/usr/local/bin" ]]; then
            install_dir="/c/Program Files/Git/usr/local/bin"
        elif [[ -d "/usr/local/bin" ]]; then
            install_dir="/usr/local/bin"
        else
            install_dir="$HOME/bin"
            mkdir -p "$install_dir"
            print_warning "Installed to $install_dir. Make sure this directory is in your PATH."
        fi
    else
        # For Unix-like systems
        if [[ -w "/usr/local/bin" ]]; then
            install_dir="/usr/local/bin"
        elif [[ -w "$HOME/.local/bin" ]]; then
            install_dir="$HOME/.local/bin"
            mkdir -p "$install_dir"
        else
            install_dir="$HOME/bin"
            mkdir -p "$install_dir"
            print_warning "Installed to $install_dir. Make sure this directory is in your PATH."
        fi
    fi
    
    # Move the binary to installation directory
    local install_path="${install_dir}/${BINARY_NAME}"
    
    if ! mv "$temp_file" "$install_path"; then
        print_error "Failed to install kind to $install_path"
        print_info "You may need to run this script with sudo or install manually"
        print_info "Manual installation: mv $temp_file /usr/local/bin/$BINARY_NAME"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    print_success "Kind $version installed successfully to $install_path"
    
    # Verify installation
    if command -v kind >/dev/null 2>&1; then
        local installed_version=$(kind version 2>/dev/null | grep 'kind' | awk '{print $2}' || echo "unknown")
        print_success "Verification: kind version $installed_version"
    else
        print_warning "kind command not found in PATH. You may need to restart your shell or add $install_dir to your PATH."
    fi
}

# Main function
main() {
    print_info "Kind Installation/Upgrade Script"
    print_info "================================="
    
    # Detect platform
    detect_platform
    
    # Determine version to install
    local target_version="$KIND_VERSION"
    if [[ "$target_version" == "latest" ]]; then
        print_info "Getting latest version..."
        target_version=$(get_latest_version)
        print_info "Latest version: $target_version"
    fi
    
    # Check current installation
    local current_version=$(check_current_version)
    if [[ "$current_version" == "not_installed" ]]; then
        print_info "Kind is not currently installed"
    else
        print_info "Current kind version: $current_version"
        if [[ "$current_version" == "$target_version" ]]; then
            print_success "Kind $target_version is already installed"
            exit 0
        fi
    fi
    
    # Install or upgrade
    if [[ "$current_version" == "not_installed" ]]; then
        print_info "Installing kind $target_version..."
    else
        print_info "Upgrading kind from $current_version to $target_version..."
    fi
    
    install_kind "$target_version"
    
    print_success "Installation completed!"
    print_info ""
    print_info "Usage examples:"
    print_info "  kind create cluster                    # Create a cluster"
    print_info "  kind create cluster --name my-cluster  # Create a named cluster"
    print_info "  kind get clusters                      # List clusters"
    print_info "  kind delete cluster                    # Delete default cluster"
    print_info ""
    print_info "For more information, visit: https://kind.sigs.k8s.io/"
}

# Run main function
main "$@"
