#!/bin/bash

# Docker Registry Mirror Configuration Script
# For Linux systems

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or has sudo privileges
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    elif command -v sudo &> /dev/null; then
        SUDO="sudo"
        log_info "Detected sudo privileges, will use sudo for commands"
    else
        log_error "Root privileges or sudo access required to configure Docker"
        exit 1
    fi
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed, please install Docker first"
        exit 1
    fi
    log_success "Docker is installed"
}

# Backup existing configuration
backup_config() {
    if [ -f /etc/docker/daemon.json ]; then
        log_info "Backing up existing Docker configuration..."
        $SUDO cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
        log_success "Configuration backed up"
    fi
}

# Create Docker configuration directory
create_docker_dir() {
    log_info "Creating Docker configuration directory..."
    $SUDO mkdir -p /etc/docker
}

# Generate Docker daemon configuration
generate_config() {
    log_info "Generating Docker registry mirror configuration..."
    
    cat << 'EOF' | $SUDO tee /etc/docker/daemon.json > /dev/null
{
  "registry-mirrors": [
    "https://dockerhub.azk8s.cn",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://registry.docker-cn.com"
  ],
  "insecure-registries": [
    "localhost:5000",
    "registry.local:5000",
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"],
  "data-root": "/var/lib/docker",
  "dns": ["8.8.8.8", "114.114.114.114"],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "default-ulimits": {
    "nofile": {
      "name": "nofile",
      "hard": 64000,
      "soft": 64000
    }
  }
}
EOF
    
    log_success "Configuration file generated"
}

# Validate configuration file format
validate_config() {
    log_info "Validating configuration file format..."
    if ! python3 -m json.tool /etc/docker/daemon.json > /dev/null 2>&1; then
        log_error "Configuration file format is invalid"
        exit 1
    fi
    log_success "Configuration file format is valid"
}

# Restart Docker service
restart_docker() {
    log_info "Restarting Docker service..."
    
    if command -v systemctl &> /dev/null; then
        $SUDO systemctl daemon-reload
        $SUDO systemctl restart docker
        log_success "Docker service restarted"
    else
        log_warning "Cannot automatically restart Docker service, please restart manually"
        return 1
    fi
}

# Verify configuration
verify_config() {
    log_info "Verifying registry mirror configuration..."
    
    # Wait for Docker service to fully start
    sleep 3
    
    if docker info 2>/dev/null | grep -q "Registry Mirrors"; then
        log_success "Registry mirror configuration successful!"
        echo
        echo "Configured registry mirrors:"
        docker info 2>/dev/null | grep -A 10 "Registry Mirrors:" | head -n 6
    else
        log_warning "Cannot verify registry mirror configuration, please check Docker service status"
    fi
}

# Test image pulling
test_pull() {
    log_info "Testing image pull speed..."
    echo
    echo "Testing pull of hello-world image:"
    
    if time docker pull hello-world; then
        log_success "Image pull test successful!"
    else
        log_warning "Image pull test failed, please check network connection"
    fi
}

# Show usage instructions
show_usage() {
    echo "Docker Registry Mirror Configuration Script"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help     Show help information"
    echo "  -t, --test     Test image pulling after configuration"
    echo "  -v, --verify   Only verify current configuration"
    echo
    echo "Examples:"
    echo "  $0              # Configure registry mirrors"
    echo "  $0 -t           # Configure registry mirrors and test"
    echo "  $0 -v           # Verify current configuration"
}

# Verify configuration only
verify_only() {
    check_docker
    verify_config
}

# Main function
main() {
    local test_pull_flag=false
    local verify_only_flag=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -t|--test)
                test_pull_flag=true
                shift
                ;;
            -v|--verify)
                verify_only_flag=true
                shift
                ;;
            *)
                log_error "Unknown parameter: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # If only verifying configuration
    if [ "$verify_only_flag" = true ]; then
        verify_only
        exit 0
    fi
    
    echo "========================================"
    echo "  Docker Registry Mirror Configuration"
    echo "========================================"
    echo
    
    # Execute configuration process
    check_permissions
    check_docker
    backup_config
    create_docker_dir
    generate_config
    validate_config
    restart_docker
    verify_config
    
    # If test flag is specified
    if [ "$test_pull_flag" = true ]; then
        echo
        test_pull
    fi
    
    echo
    log_success "Docker registry mirror configuration completed!"
    echo
    echo "Common commands:"
    echo "  docker info                    # View Docker info and registry mirror configuration"
    echo "  docker pull nginx:latest       # Test image pulling"
    echo "  docker system prune -a         # Clean Docker cache"
    echo
    echo "To restore original configuration, use backup file:"
    echo "  sudo cp /etc/docker/daemon.json.backup.* /etc/docker/daemon.json"
    echo "  sudo systemctl restart docker"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
