#!/bin/bash

# Docker Uninstallation Script
# Supports Linux and macOS platforms
# Usage: ./uninstall-docker.sh

set -e

# Output colors
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

# Ask for user confirmation
ask_confirmation() {
    local question="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        local prompt="$question [Y/n]: "
    else
        local prompt="$question [y/N]: "
    fi
    
    read -p "$prompt" response
    response=${response:-$default}
    
    if [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        return 0
    else
        return 1
    fi
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
        *)
            print_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
    
    print_info "Detected platform: $OS"
}

# Check if Docker is installed
check_docker_installation() {
    if command -v docker >/dev/null 2>&1; then
        local version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        print_info "Docker is installed (version: $version)"
        return 0
    else
        print_warning "Docker is not installed or not in PATH"
        return 1
    fi
}

# Stop all running containers
stop_containers() {
    print_info "Checking for running Docker containers..."
    
    local running_containers=$(docker ps -q 2>/dev/null || true)
    if [[ -n "$running_containers" ]]; then
        print_warning "Found running containers:"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null || true
        
        if ask_confirmation "Stop all running containers?"; then
            print_info "Stopping all running containers..."
            docker stop $running_containers
            print_success "All containers stopped"
        fi
    else
        print_info "No running containers found"
    fi
}

# Remove all containers
remove_containers() {
    print_info "Checking for Docker containers..."
    
    local all_containers=$(docker ps -aq 2>/dev/null || true)
    if [[ -n "$all_containers" ]]; then
        print_warning "Found containers (including stopped ones)"
        
        if ask_confirmation "Remove all containers (including stopped ones)?"; then
            print_info "Removing all containers..."
            docker rm -f $all_containers 2>/dev/null || true
            print_success "All containers removed"
        fi
    else
        print_info "No containers found"
    fi
}

# Remove all images
remove_images() {
    print_info "Checking for Docker images..."
    
    local all_images=$(docker images -q 2>/dev/null || true)
    if [[ -n "$all_images" ]]; then
        print_warning "Found Docker images:"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null || true
        
        if ask_confirmation "Remove all Docker images?"; then
            print_info "Removing all Docker images..."
            docker rmi -f $all_images 2>/dev/null || true
            print_success "All images removed"
        fi
    else
        print_info "No Docker images found"
    fi
}

# Remove Docker networks
remove_networks() {
    print_info "Checking for Docker networks..."
    
    local custom_networks=$(docker network ls --filter type=custom -q 2>/dev/null || true)
    if [[ -n "$custom_networks" ]]; then
        print_warning "Found custom Docker networks:"
        docker network ls --filter type=custom --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" 2>/dev/null || true
        
        if ask_confirmation "Remove custom Docker networks?"; then
            print_info "Removing custom Docker networks..."
            docker network rm $custom_networks 2>/dev/null || true
            print_success "Custom networks removed"
        fi
    else
        print_info "No custom Docker networks found"
    fi
}

# Remove Docker volumes
remove_volumes() {
    print_info "Checking for Docker volumes..."
    
    local all_volumes=$(docker volume ls -q 2>/dev/null || true)
    if [[ -n "$all_volumes" ]]; then
        print_warning "Found Docker volumes:"
        docker volume ls 2>/dev/null || true
        
        if ask_confirmation "Remove all Docker volumes? (This will delete all data in volumes!)"; then
            print_info "Removing all Docker volumes..."
            docker volume rm $all_volumes 2>/dev/null || true
            print_success "All volumes removed"
        fi
    else
        print_info "No Docker volumes found"
    fi
}

# Clean up Docker system
cleanup_docker_system() {
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        if ask_confirmation "Run Docker system cleanup (remove unused data)?"; then
            print_info "Running Docker system cleanup..."
            docker system prune -af --volumes 2>/dev/null || true
            print_success "Docker system cleanup completed"
        fi
    fi
}

# Uninstall Docker on Linux
uninstall_docker_linux() {
    print_info "Uninstalling Docker on Linux..."
    
    # Stop Docker service
    if systemctl is-active --quiet docker 2>/dev/null; then
        if ask_confirmation "Stop Docker service?"; then
            print_info "Stopping Docker service..."
            sudo systemctl stop docker
            print_success "Docker service stopped"
        fi
    fi
    
    # Disable Docker service
    if systemctl is-enabled --quiet docker 2>/dev/null; then
        if ask_confirmation "Disable Docker service?"; then
            print_info "Disabling Docker service..."
            sudo systemctl disable docker
            print_success "Docker service disabled"
        fi
    fi
    
    # Remove Docker packages
    if ask_confirmation "Remove Docker packages?"; then
        print_info "Removing Docker packages..."
        
        if command -v apt-get >/dev/null 2>&1; then
            # Debian/Ubuntu
            sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
            sudo apt-get autoremove -y 2>/dev/null || true
            
            # Remove Docker repository
            if ask_confirmation "Remove Docker APT repository?"; then
                sudo rm -f /etc/apt/sources.list.d/docker.list
                sudo rm -f /etc/apt/keyrings/docker.gpg
                print_success "Docker repository removed"
            fi
            
        elif command -v yum >/dev/null 2>&1; then
            # CentOS/RHEL
            sudo yum remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
            
        elif command -v dnf >/dev/null 2>&1; then
            # Fedora
            sudo dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
        fi
        
        print_success "Docker packages removed"
    fi
    
    # Remove Docker directories
    if ask_confirmation "Remove Docker data directories? (/var/lib/docker, /etc/docker)"; then
        print_info "Removing Docker directories..."
        sudo rm -rf /var/lib/docker 2>/dev/null || true
        sudo rm -rf /etc/docker 2>/dev/null || true
        sudo rm -rf /var/lib/containerd 2>/dev/null || true
        print_success "Docker directories removed"
    fi
    
    # Remove user from docker group
    if groups $USER | grep -q '\bdocker\b'; then
        if ask_confirmation "Remove user from docker group?"; then
            print_info "Removing user from docker group..."
            sudo deluser $USER docker 2>/dev/null || true
            print_success "User removed from docker group"
            print_warning "You may need to logout and login again for group changes to take effect"
        fi
    fi
}

# Uninstall Docker on macOS
uninstall_docker_macos() {
    print_info "Uninstalling Docker on macOS..."
    
    # Check if Docker Desktop is installed via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list --cask docker >/dev/null 2>&1; then
        if ask_confirmation "Uninstall Docker Desktop via Homebrew?"; then
            print_info "Uninstalling Docker Desktop..."
            brew uninstall --cask docker
            print_success "Docker Desktop uninstalled via Homebrew"
        fi
    else
        print_info "Docker Desktop not found in Homebrew"
        
        # Manual removal for Docker Desktop installed outside Homebrew
        if [[ -d "/Applications/Docker.app" ]]; then
            if ask_confirmation "Remove Docker Desktop from Applications folder?"; then
                print_info "Removing Docker Desktop..."
                sudo rm -rf /Applications/Docker.app
                print_success "Docker Desktop removed from Applications"
            fi
        fi
    fi
    
    # Remove Docker configuration and data
    local user_dirs=(
        "$HOME/.docker"
        "$HOME/Library/Containers/com.docker.docker"
        "$HOME/Library/Application Support/Docker Desktop"
        "$HOME/Library/Group Containers/group.com.docker"
        "$HOME/Library/HTTPStorages/com.docker.docker"
        "$HOME/Library/Logs/Docker Desktop"
        "$HOME/Library/Preferences/com.docker.docker.plist"
        "$HOME/Library/Saved Application State/com.electron.dockerdesktop.savedState"
    )
    
    local found_dirs=()
    for dir in "${user_dirs[@]}"; do
        if [[ -e "$dir" ]]; then
            found_dirs+=("$dir")
        fi
    done
    
    if [[ ${#found_dirs[@]} -gt 0 ]]; then
        print_warning "Found Docker configuration and data directories:"
        printf '%s\n' "${found_dirs[@]}"
        
        if ask_confirmation "Remove Docker configuration and data directories?"; then
            for dir in "${found_dirs[@]}"; do
                rm -rf "$dir" 2>/dev/null || true
            done
            print_success "Docker configuration and data directories removed"
        fi
    fi
}

# Remove Docker configuration
remove_docker_config() {
    local config_dirs=(
        "$HOME/.docker"
    )
    
    local found_dirs=()
    for dir in "${config_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            found_dirs+=("$dir")
        fi
    done
    
    if [[ ${#found_dirs[@]} -gt 0 ]]; then
        print_warning "Found Docker configuration directories:"
        printf '%s\n' "${found_dirs[@]}"
        
        if ask_confirmation "Remove Docker configuration directories?"; then
            for dir in "${found_dirs[@]}"; do
                rm -rf "$dir" 2>/dev/null || true
            done
            print_success "Docker configuration directories removed"
        fi
    else
        print_info "No Docker configuration directories found"
    fi
}

# Verify uninstallation
verify_uninstallation() {
    print_info "Verifying Docker uninstallation..."
    
    if command -v docker >/dev/null 2>&1; then
        print_warning "Docker command is still available"
        print_info "Location: $(which docker)"
        
        if ask_confirmation "Remove Docker binary manually?"; then
            local docker_path=$(which docker)
            if [[ -w "$docker_path" ]]; then
                rm -f "$docker_path"
                print_success "Docker binary removed"
            else
                sudo rm -f "$docker_path"
                print_success "Docker binary removed (with sudo)"
            fi
        fi
    else
        print_success "Docker command is no longer available"
    fi
    
    # Check for remaining processes
    local docker_processes=$(ps aux | grep -i docker | grep -v grep | wc -l)
    if [[ $docker_processes -gt 0 ]]; then
        print_warning "Found Docker-related processes still running:"
        ps aux | grep -i docker | grep -v grep || true
        
        if ask_confirmation "Kill remaining Docker processes?"; then
            sudo pkill -f docker 2>/dev/null || true
            print_success "Docker processes killed"
        fi
    else
        print_info "No Docker processes found"
    fi
}

# Main function
main() {
    print_info "Docker Uninstallation Script"
    print_info "============================"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root"
        print_info "Please run as a regular user. The script will use sudo when needed."
        exit 1
    fi
    
    # Detect platform
    detect_platform
    
    # Check if Docker is installed
    if ! check_docker_installation; then
        print_info "Docker appears to be not installed. Checking configuration files..."
        remove_docker_config
        print_success "Uninstallation completed (Docker was not installed)"
        exit 0
    fi
    
    print_warning "This will completely remove Docker and all its data!"
    print_warning "All containers, images, volumes and networks will be deleted!"
    
    if ! ask_confirmation "Are you sure you want to continue with uninstallation?"; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    # Docker cleanup steps (only if Docker daemon is running)
    if docker info >/dev/null 2>&1; then
        stop_containers
        remove_containers
        remove_images
        remove_networks
        remove_volumes
        cleanup_docker_system
    else
        print_warning "Docker daemon is not running, skipping container/image cleanup"
    fi
    
    # Platform-specific uninstallation
    case "$OS" in
        linux)
            uninstall_docker_linux
            ;;
        darwin)
            uninstall_docker_macos
            ;;
    esac
    
    # Remove configuration
    remove_docker_config
    
    # Verify uninstallation
    verify_uninstallation
    
    print_success "Docker uninstallation completed!"
    print_info ""
    print_info "Manual cleanup steps (if needed):"
    print_info "- Restart your computer to ensure all services are stopped"
    print_info "- Check for remaining Docker files in /var/lib/docker (Linux)"
    print_info "- Remove any custom Docker configurations you may have added"
    
    if [[ "$OS" == "linux" ]]; then
        print_info "- You may need to logout and login again for group changes to take effect"
    fi
    
    print_info ""
    print_info "If you want to reinstall Docker later, you can use the install script."
}

# Run main function
main "$@"
