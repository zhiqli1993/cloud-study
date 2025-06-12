#!/bin/bash

# Docker 安装/升级脚本  
# 支持 Linux 和 macOS 平台
# 使用方法: ./install-docker.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印彩色输出
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 检测操作系统和架构
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
            print_error "不支持的操作系统: $os"
            print_info "此脚本支持 Linux 和 macOS。Windows 请使用 Docker Desktop。"
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
            print_error "不支持的架构: $arch"
            exit 1
            ;;
    esac
    
    print_info "检测到平台: $OS-$ARCH"
}

# 检查 Docker 是否已安装并获取版本
check_current_version() {
    if command -v docker >/dev/null 2>&1; then
        local current_version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        echo "$current_version"
    else
        echo "not_installed"
    fi
}

# 检查用户是否在 docker 组中 (仅 Linux)
check_docker_group() {
    if [[ "$OS" == "linux" ]]; then
        if ! groups $USER | grep -q '\bdocker\b'; then
            print_warning "用户 $USER 不在 docker 组中"
            print_info "您可以使用以下命令将自己添加到 docker 组："
            print_info "  sudo usermod -aG docker $USER"
            print_info "  newgrp docker"
            print_info "或者退出并重新登录"
            return 1
        fi
    fi
    return 0
}

# 在 Linux 上安装 Docker
install_docker_linux() {
    print_info "正在 Linux 上安装 Docker..."
    
    # 更新包索引
    print_info "正在更新包索引..."
    if command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu
        sudo apt-get update
        
        # 安装前置依赖
        sudo apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # 添加 Docker 官方 GPG 密钥
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # 设置仓库
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # 再次更新包索引
        sudo apt-get update
        
        # 安装 Docker Engine
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    elif command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL/Fedora
        sudo yum update -y
        
        # 安装前置依赖
        sudo yum install -y yum-utils
        
        # 添加 Docker 仓库
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        
        # 安装 Docker Engine
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora
        sudo dnf update -y
        
        # 安装前置依赖
        sudo dnf install -y dnf-plugins-core
        
        # 添加 Docker 仓库
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        
        # 安装 Docker Engine
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    else
        print_error "不支持的 Linux 发行版。请手动安装 Docker。"
        print_info "访问: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # 启动并启用 Docker 服务
    print_info "正在启动 Docker 服务..."
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # 将当前用户添加到 docker 组
    print_info "正在将用户添加到 docker 组..."
    sudo usermod -aG docker $USER
    
    print_success "Docker 在 Linux 上安装成功"
    print_warning "请退出并重新登录，或运行 'newgrp docker' 来免 sudo 使用 Docker"
}

# 在 macOS 上安装 Docker
install_docker_macos() {
    print_info "正在 macOS 上安装 Docker..."
    
    # 检查是否安装了 Homebrew
    if ! command -v brew >/dev/null 2>&1; then
        print_error "Homebrew 未安装。请先安装 Homebrew："
        print_info "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    # 使用 Homebrew 安装 Docker Desktop
    print_info "正在通过 Homebrew 安装 Docker Desktop..."
    brew install --cask docker
    
    print_success "Docker Desktop 在 macOS 上安装成功"
    print_info "请从应用程序文件夹启动 Docker Desktop"
    print_info "Docker Desktop 启动后 Docker 命令将可用"
}

# 验证 Docker 安装
verify_installation() {
    print_info "正在验证 Docker 安装..."
    
    # 等待 Docker 准备就绪
    sleep 2
    
    if command -v docker >/dev/null 2>&1; then
        local version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        print_success "Docker 版本: $version"
        
        # 使用 hello-world 测试 Docker (仅在 Docker 守护进程运行时)
        if docker info >/dev/null 2>&1; then
            print_info "正在使用 hello-world 容器测试 Docker..."
            if docker run --rm hello-world >/dev/null 2>&1; then
                print_success "Docker 工作正常"
            else
                print_warning "Docker 已安装但测试容器失败"
            fi
        else
            if [[ "$OS" == "darwin" ]]; then
                print_warning "Docker Desktop 未运行。请从应用程序文件夹启动它。"
            else
                print_warning "Docker 守护进程未运行。尝试: sudo systemctl start docker"
            fi
        fi
    else
        print_error "Docker 安装验证失败"
        return 1
    fi
}

# 主函数
main() {
    print_info "Docker 安装脚本"
    print_info "================"
    
    # 检查是否以 root 身份运行
    if [[ $EUID -eq 0 ]]; then
        print_error "此脚本不应以 root 身份运行"
        print_info "请以普通用户身份运行。脚本会在需要时使用 sudo。"
        exit 1
    fi
    
    # 检测平台
    detect_platform
    
    # 检查当前安装
    local current_version=$(check_current_version)
    if [[ "$current_version" != "not_installed" ]]; then
        print_info "Docker 已安装 (版本: $current_version)"
        
        # 检查 Docker 是否正常工作
        if docker info >/dev/null 2>&1; then
            print_success "Docker 已安装且工作正常"
            check_docker_group
            exit 0
        else
            print_warning "Docker 已安装但工作不正常"
            print_info "继续进行安装/修复..."
        fi
    else
        print_info "Docker 目前未安装"
    fi
    
    # 根据平台安装 Docker
    case "$OS" in
        linux)
            install_docker_linux
            ;;
        darwin)
            install_docker_macos
            ;;
    esac
    
    # 验证安装
    verify_installation
    
    print_success "安装完成！"
    print_info ""
    print_info "使用示例："
    print_info "  docker --version                      # 检查 Docker 版本"
    print_info "  docker info                           # 显示系统信息"
    print_info "  docker run hello-world                # 使用 hello-world 测试"
    print_info "  docker run -it ubuntu bash            # 运行交互式 Ubuntu 容器"
    print_info "  docker ps                             # 列出运行中的容器"
    print_info "  docker images                         # 列出镜像"
    print_info ""
    
    if [[ "$OS" == "linux" ]]; then
        print_info "注意: 如果遇到权限错误，您可能需要："
        print_info "  1. 退出并重新登录，或运行: newgrp docker"
        print_info "  2. 或在 docker 命令前使用 sudo"
    fi
    
    print_info "更多信息请访问: https://docs.docker.com/"
}

# Run main function
main "$@"
