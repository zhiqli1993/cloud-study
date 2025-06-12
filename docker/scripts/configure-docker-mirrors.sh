#!/bin/bash

# Docker 国内镜像源自动配置脚本
# 适用于 Linux 系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 检查是否为root用户或具有sudo权限
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    elif command -v sudo &> /dev/null; then
        SUDO="sudo"
        log_info "检测到sudo权限，将使用sudo执行命令"
    else
        log_error "需要root权限或sudo权限来配置Docker"
        exit 1
    fi
}

# 检查Docker是否已安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    log_success "Docker已安装"
}

# 备份现有配置
backup_config() {
    if [ -f /etc/docker/daemon.json ]; then
        log_info "备份现有Docker配置..."
        $SUDO cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
        log_success "配置已备份"
    fi
}

# 创建Docker配置目录
create_docker_dir() {
    log_info "创建Docker配置目录..."
    $SUDO mkdir -p /etc/docker
}

# 生成Docker daemon配置
generate_config() {
    log_info "生成Docker镜像源配置..."
    
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
    
    log_success "配置文件已生成"
}

# 验证配置文件格式
validate_config() {
    log_info "验证配置文件格式..."
    if ! python3 -m json.tool /etc/docker/daemon.json > /dev/null 2>&1; then
        log_error "配置文件格式错误"
        exit 1
    fi
    log_success "配置文件格式正确"
}

# 重启Docker服务
restart_docker() {
    log_info "重启Docker服务..."
    
    if command -v systemctl &> /dev/null; then
        $SUDO systemctl daemon-reload
        $SUDO systemctl restart docker
        log_success "Docker服务已重启"
    else
        log_warning "无法自动重启Docker服务，请手动重启"
        return 1
    fi
}

# 验证配置
verify_config() {
    log_info "验证镜像源配置..."
    
    # 等待Docker服务完全启动
    sleep 3
    
    if docker info 2>/dev/null | grep -q "Registry Mirrors"; then
        log_success "镜像源配置成功！"
        echo
        echo "配置的镜像源："
        docker info 2>/dev/null | grep -A 10 "Registry Mirrors:" | head -n 6
    else
        log_warning "无法验证镜像源配置，请检查Docker服务状态"
    fi
}

# 测试镜像拉取
test_pull() {
    log_info "测试镜像拉取速度..."
    echo
    echo "测试拉取 hello-world 镜像："
    
    if time docker pull hello-world; then
        log_success "镜像拉取测试成功！"
    else
        log_warning "镜像拉取测试失败，请检查网络连接"
    fi
}

# 显示使用说明
show_usage() {
    echo "Docker 国内镜像源配置脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -t, --test     配置完成后测试镜像拉取"
    echo "  -v, --verify   仅验证当前配置"
    echo
    echo "示例:"
    echo "  $0              # 配置镜像源"
    echo "  $0 -t           # 配置镜像源并测试"
    echo "  $0 -v           # 验证当前配置"
}

# 仅验证配置
verify_only() {
    check_docker
    verify_config
}

# 主函数
main() {
    local test_pull_flag=false
    local verify_only_flag=false
    
    # 解析命令行参数
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
                log_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 如果只是验证配置
    if [ "$verify_only_flag" = true ]; then
        verify_only
        exit 0
    fi
    
    echo "========================================"
    echo "    Docker 国内镜像源配置脚本"
    echo "========================================"
    echo
    
    # 执行配置流程
    check_permissions
    check_docker
    backup_config
    create_docker_dir
    generate_config
    validate_config
    restart_docker
    verify_config
    
    # 如果指定了测试标志
    if [ "$test_pull_flag" = true ]; then
        echo
        test_pull
    fi
    
    echo
    log_success "Docker 国内镜像源配置完成！"
    echo
    echo "常用命令："
    echo "  docker info                    # 查看Docker信息和镜像源配置"
    echo "  docker pull nginx:latest       # 测试镜像拉取"
    echo "  docker system prune -a         # 清理Docker缓存"
    echo
    echo "如需恢复原配置，请使用备份的配置文件："
    echo "  sudo cp /etc/docker/daemon.json.backup.* /etc/docker/daemon.json"
    echo "  sudo systemctl restart docker"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
