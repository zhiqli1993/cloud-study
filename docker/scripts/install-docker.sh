#!/bin/bash

# Docker Installation/Upgrade Script  
# Supports Linux and macOS platforms
# Usage: ./install-docker.sh

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
        *)
            print_error "Unsupported operating system: $os"
            print_info "This script supports Linux and macOS. For Windows, please use Docker Desktop."
            exit 1
            ;;
    esac
    
    case "$arch" in
        x86_64|amd64)
            ARCH="x86_64"
            ;;
        arm64|aarch64)
            ARCH="aarch64"
            ;;
        armv7l)
            ARCH="armhf"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    
    print_info "Detected platform: $OS-$ARCH"
}

# Check if Docker is already installed and get version
check_current_version() {
    if command -v docker >/dev/null 2>&1; then
        local current_version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        echo "$current_version"
    else
        echo "not_installed"
    fi
}

# Check if user is in docker group (Linux only)
check_docker_group() {
    if [[ "$OS" == "linux" ]]; then
        if ! groups $USER | grep -q '\bdocker\b'; then
            print_warning "User $USER is not in docker group"
            print_info "You can add yourself to the docker group with these commands:"
            print_info "  sudo usermod -aG docker $USER"
            print_info "  newgrp docker"
            print_info "Or logout and login again"
            return 1
        fi
    fi
    return 0
}

# Install Docker on Linux
install_docker_linux() {
    print_info "Installing Docker on Linux..."
    
    # Update package index
    print_info "Updating package index..."
    if command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu
        sudo apt-get update
        
        # Install prerequisites
        sudo apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker's official GPG key
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Set up repository
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Update package index again
        sudo apt-get update
        
        # Install Docker Engine
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    elif command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL/Fedora
        sudo yum update -y
        
        # Install prerequisites
        sudo yum install -y yum-utils
        
        # Add Docker repository
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        
        # Install Docker Engine
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora
        sudo dnf update -y
        
        # Install prerequisites
        sudo dnf install -y dnf-plugins-core
        
        # Add Docker repository
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        
        # Install Docker Engine
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    else
        print_error "Unsupported Linux distribution. Please install Docker manually."
        print_info "Visit: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # Start and enable Docker service
    print_info "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    print_info "Adding user to docker group..."
    sudo usermod -aG docker $USER
    
    print_success "Docker installed successfully on Linux"
    print_warning "Please logout and login again, or run 'newgrp docker' to use Docker without sudo"
}

# Install Docker on macOS
install_docker_macos() {
    print_info "Installing Docker on macOS..."
    
    # Check if Homebrew is installed
    if ! command -v brew >/dev/null 2>&1; then
        print_error "Homebrew is not installed. Please install Homebrew first:"
        print_info "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    # Install Docker Desktop using Homebrew
    print_info "Installing Docker Desktop via Homebrew..."
    brew install --cask docker
    
    print_success "Docker Desktop installed successfully on macOS"
    print_info "Please launch Docker Desktop from Applications folder"
    print_info "Docker commands will be available after Docker Desktop starts"
}

# Verify Docker installation
verify_installation() {
    print_info "Verifying Docker installation..."
    
    # Wait for Docker to be ready
    sleep 2
    
    if command -v docker >/dev/null 2>&1; then
        local version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        print_success "Docker version: $version"
        
        # Test Docker with hello-world (only if Docker daemon is running)
        if docker info >/dev/null 2>&1; then
            print_info "Testing Docker with hello-world container..."
            if docker run --rm hello-world >/dev/null 2>&1; then
                print_success "Docker is working properly"
            else
                print_warning "Docker is installed but test container failed"
            fi
        else
            if [[ "$OS" == "darwin" ]]; then
                print_warning "Docker Desktop is not running. Please launch it from Applications folder."
            else
                print_warning "Docker daemon is not running. Try: sudo systemctl start docker"
            fi
        fi
    else
        print_error "Docker installation verification failed"
        return 1
    fi
}

# Main function
main() {
    print_info "Docker Installation Script"
    print_info "=========================="
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root"
        print_info "Please run as a regular user. The script will use sudo when needed."
        exit 1
    fi
    
    # Detect platform
    detect_platform
    
    # Check current installation
    local current_version=$(check_current_version)
    if [[ "$current_version" != "not_installed" ]]; then
        print_info "Docker is installed (version: $current_version)"
        
        # Check if Docker is working properly
        if docker info >/dev/null 2>&1; then
            print_success "Docker is installed and working properly"
            check_docker_group
            exit 0
        else
            print_warning "Docker is installed but not working properly"
            print_info "Continuing with installation/repair..."
        fi
    else
        print_info "Docker is currently not installed"
    fi
    
    # Install Docker based on platform
    case "$OS" in
        linux)
            install_docker_linux
            ;;
        darwin)
            install_docker_macos
            ;;
    esac
    
    # Verify installation
    verify_installation
    
    print_success "Installation completed!"
    print_info ""
    print_info "Usage examples:"
    print_info "  docker --version                      # Check Docker version"
    print_info "  docker info                           # Show system information"
    print_info "  docker run hello-world                # Test with hello-world"
    print_info "  docker run -it ubuntu bash            # Run interactive Ubuntu container"
    print_info "  docker ps                             # List running containers"
    print_info "  docker images                         # List images"
    print_info ""
    
    if [[ "$OS" == "linux" ]]; then
        print_info "Note: If you encounter permission errors, you may need to:"
        print_info "  1. Logout and login again, or run: newgrp docker"
        print_info "  2. Or use sudo before docker commands"
    fi
    
    print_info "For more information visit: https://docs.docker.com/"
}

# Run main function
main "$@"
