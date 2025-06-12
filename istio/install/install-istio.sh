#!/bin/bash

# Istio Installation/Upgrade Script
# Supports Linux, macOS, and Windows platforms
# Usage: ./install-istio.sh [version] [profile]

set -e

# Default values
ISTIO_VERSION=${1:-"latest"}
ISTIO_PROFILE=${2:-"default"}

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
    
    case "$arch" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="armv7"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    
    if [[ "$OS" == "win" ]]; then
        BINARY_NAME="istioctl.exe"
    else
        BINARY_NAME="istioctl"
    fi
    
    print_info "Detected platform: $OS-$ARCH"
}

# Get the latest version from GitHub API
get_latest_version() {
    if command -v curl >/dev/null 2>&1; then
        local latest_version=$(curl -s https://api.github.com/repos/istio/istio/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        local latest_version=$(wget -qO- https://api.github.com/repos/istio/istio/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
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

# Check if istioctl is already installed and get version
check_current_version() {
    if command -v istioctl >/dev/null 2>&1; then
        local current_version=$(istioctl version --client --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        echo "$current_version"
    else
        echo "not_installed"
    fi
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl >/dev/null 2>&1; then
        print_warning "kubectl is not installed. You'll need kubectl to deploy Istio to a Kubernetes cluster."
        print_info "You can install kubectl from: https://kubernetes.io/docs/tasks/tools/"
        return 1
    fi
    return 0
}

# Download and install istioctl
install_istioctl() {
    local version="$1"
    # Remove 'v' prefix if present for the download URL
    local version_number="${version#v}"
    
    # Determine file format based on OS
    local file_extension=""
    local extract_command=""
    if [[ "$OS" == "win" ]]; then
        file_extension=".zip"
        extract_command="unzip"
    else
        file_extension=".tar.gz"
        extract_command="tar -xzf"
    fi
    
    local download_url="https://github.com/istio/istio/releases/download/${version}/istio-${version_number}-${OS}-${ARCH}${file_extension}"
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    local temp_archive="${temp_dir}/istio${file_extension}"
    
    print_info "Downloading Istio ${version} for ${OS}-${ARCH}..."
    print_info "Download URL: $download_url"
    
    # Download the archive
    if command -v curl >/dev/null 2>&1; then
        if ! curl -L -o "$temp_archive" "$download_url"; then
            print_error "Failed to download Istio"
            rm -rf "$temp_dir"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -O "$temp_archive" "$download_url"; then
            print_error "Failed to download Istio"
            rm -rf "$temp_dir"
            exit 1
        fi
    else
        print_error "Neither curl nor wget is available. Please install one of them."
        exit 1
    fi
    
    # Extract the archive
    print_info "Extracting Istio archive..."
    if [[ "$OS" == "win" ]]; then
        if ! unzip -q "$temp_archive" -d "$temp_dir"; then
            print_error "Failed to extract Istio archive"
            rm -rf "$temp_dir"
            exit 1
        fi
    else
        if ! tar -xzf "$temp_archive" -C "$temp_dir"; then
            print_error "Failed to extract Istio archive"
            rm -rf "$temp_dir"
            exit 1
        fi
    fi
    
    # Find the istioctl binary
    local istio_dir="${temp_dir}/istio-${version_number}"
    local istioctl_path="${istio_dir}/bin/${BINARY_NAME}"
    
    if [[ ! -f "$istioctl_path" ]]; then
        print_error "istioctl binary not found in downloaded archive"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Make it executable
    chmod +x "$istioctl_path"
    
    # Determine installation directory
    local install_dir=""
    if [[ "$OS" == "win" ]]; then
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
    
    if ! cp "$istioctl_path" "$install_path"; then
        print_error "Failed to install istioctl to $install_path"
        print_info "You may need to run this script with sudo or install manually"
        print_info "Manual installation: cp $istioctl_path /usr/local/bin/$BINARY_NAME"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    print_success "istioctl $version installed successfully to $install_path"
    
    # Verify installation
    if command -v istioctl >/dev/null 2>&1; then
        local installed_version=$(istioctl version --client --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        print_success "Verification: istioctl version $installed_version"
    else
        print_warning "istioctl command not found in PATH. You may need to restart your shell or add $install_dir to your PATH."
    fi
}

# Install Istio to Kubernetes cluster
install_istio_to_cluster() {
    local profile="$1"
    
    print_info "Installing Istio to Kubernetes cluster with profile: $profile"
    
    # Check if kubectl is available and cluster is accessible
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubectl configuration."
        return 1
    fi
    
    # Install Istio
    print_info "Running: istioctl install --set values.defaultRevision=default -y"
    if istioctl install --set values.defaultRevision=default -y; then
        print_success "Istio installed successfully to the cluster"
    else
        print_error "Failed to install Istio to the cluster"
        return 1
    fi
    
    # Label the default namespace for Istio injection
    print_info "Enabling automatic sidecar injection for default namespace..."
    if kubectl label namespace default istio-injection=enabled --overwrite; then
        print_success "Automatic sidecar injection enabled for default namespace"
    else
        print_warning "Failed to enable automatic sidecar injection for default namespace"
    fi
    
    # Verify installation
    print_info "Verifying Istio installation..."
    if istioctl verify-install; then
        print_success "Istio installation verified successfully"
    else
        print_warning "Istio installation verification failed"
    fi
    
    return 0
}

# Show usage examples
show_usage_examples() {
    print_info ""
    print_info "istioctl is now installed! Here are some usage examples:"
    print_info ""
    print_info "Basic Commands:"
    print_info "  istioctl version                      # Show version information"
    print_info "  istioctl install --set values.defaultRevision=default -y  # Install Istio to cluster"
    print_info "  istioctl uninstall --purge -y         # Uninstall Istio from cluster"
    print_info "  istioctl verify-install               # Verify Istio installation"
    print_info ""
    print_info "Configuration:"
    print_info "  istioctl proxy-config cluster <pod>   # Show cluster configuration"
    print_info "  istioctl proxy-status                 # Show proxy status"
    print_info "  istioctl analyze                      # Analyze configuration"
    print_info ""
    print_info "Traffic Management:"
    print_info "  kubectl label namespace default istio-injection=enabled  # Enable sidecar injection"
    print_info "  kubectl apply -f <your-app.yaml>      # Deploy application with sidecars"
    print_info ""
    print_info "For more information, visit: https://istio.io/latest/docs/"
}

# Main function
main() {
    print_info "Istio Installation Script"
    print_info "========================="
    
    # Detect platform
    detect_platform
    
    # Determine version to install
    local target_version="$ISTIO_VERSION"
    if [[ "$target_version" == "latest" ]]; then
        print_info "Getting latest version..."
        target_version=$(get_latest_version)
        print_info "Latest version: $target_version"
    fi
    
    # Check current installation
    local current_version=$(check_current_version)
    if [[ "$current_version" == "not_installed" ]]; then
        print_info "istioctl is not currently installed"
    else
        print_info "Current istioctl version: $current_version"
        if [[ "v$current_version" == "$target_version" || "$current_version" == "$target_version" ]]; then
            print_success "istioctl $target_version is already installed"
        else
            print_info "Upgrading istioctl from $current_version to $target_version..."
        fi
    fi
    
    # Install or upgrade istioctl
    if [[ "$current_version" == "not_installed" || "v$current_version" != "$target_version" ]]; then
        if [[ "$current_version" == "not_installed" ]]; then
            print_info "Installing istioctl $target_version..."
        else
            print_info "Upgrading istioctl from $current_version to $target_version..."
        fi
        
        install_istioctl "$target_version"
    fi
    
    # Check if user wants to install Istio to cluster
    print_info ""
    read -p "Do you want to install Istio to your Kubernetes cluster now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Check kubectl
        if check_kubectl; then
            install_istio_to_cluster "$ISTIO_PROFILE"
        fi
    else
        print_info "Skipping cluster installation. You can install Istio to your cluster later using:"
        print_info "  istioctl install --set values.defaultRevision=default -y"
    fi
    
    print_success "Installation completed!"
    show_usage_examples
}

# Run main function
main "$@"
