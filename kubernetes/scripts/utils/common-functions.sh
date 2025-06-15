#!/bin/bash
#
# 脚本名称: common-functions.sh
# 功能描述: Kubernetes 脚本公共函数库
# 创建时间: 2025-06-14
# 版本信息: v1.0.0
# 依赖条件: bash 4.0+, kubectl
# 支持平台: Ubuntu 18.04+, CentOS 7+, RHEL 7+, macOS 10.14+
#

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# 错误码定义
readonly SUCCESS=0
readonly ERR_GENERAL=1
readonly ERR_PERMISSION=2
readonly ERR_NETWORK=3
readonly ERR_DEPENDENCY=4
readonly ERR_CONFIG=5
readonly ERR_RESOURCE=6

# 全局变量
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LOG_FILE="${LOG_FILE:-/tmp/k8s-scripts.log}"
VERBOSE=${VERBOSE:-false}
DRY_RUN=${DRY_RUN:-false}

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)
            echo -e "${GREEN}[INFO]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        DEBUG)
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "${BLUE}[DEBUG]${NC} $message" | tee -a "$LOG_FILE"
            fi
            ;;
        *)
            echo -e "$message" | tee -a "$LOG_FILE"
            ;;
    esac
    
    # 写入详细日志到文件
    echo "[$timestamp] [${level}] [${SCRIPT_NAME}] $message" >> "$LOG_FILE"
}

# 错误处理函数
error_exit() {
    local message="$1"
    local exit_code="${2:-$ERR_GENERAL}"
    log ERROR "$message"
    exit "$exit_code"
}

# 命令执行函数
execute_command() {
    local cmd="$*"
    log DEBUG "执行命令: $cmd"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log INFO "[DRY-RUN] 将执行: $cmd"
        return $SUCCESS
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        eval "$cmd"
    else
        eval "$cmd" >/dev/null 2>&1
    fi
    
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log ERROR "命令执行失败: $cmd (退出码: $exit_code)"
        return $exit_code
    fi
    
    log DEBUG "命令执行成功: $cmd"
    return $SUCCESS
}

# 系统检测函数
check_system() {
    log INFO "开始系统环境检查..."
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log INFO "操作系统: $NAME $VERSION"
        
        case $ID in
            ubuntu)
                if [[ $(echo "$VERSION_ID >= 18.04" | bc -l) -eq 0 ]]; then
                    error_exit "Ubuntu 版本过低，需要 18.04 或更高版本" $ERR_GENERAL
                fi
                ;;
            centos|rhel)
                if [[ $(echo "$VERSION_ID >= 7" | bc -l) -eq 0 ]]; then
                    error_exit "CentOS/RHEL 版本过低，需要 7 或更高版本" $ERR_GENERAL
                fi
                ;;
            debian)
                if [[ $(echo "$VERSION_ID >= 9" | bc -l) -eq 0 ]]; then
                    error_exit "Debian 版本过低，需要 9 或更高版本" $ERR_GENERAL
                fi
                ;;
        esac
    elif [[ $(uname) == "Darwin" ]]; then
        local macos_version=$(sw_vers -productVersion)
        log INFO "操作系统: macOS $macos_version"
        
        if [[ $(echo "$macos_version >= 10.14" | bc -l) -eq 0 ]]; then
            error_exit "macOS 版本过低，需要 10.14 或更高版本" $ERR_GENERAL
        fi
    else
        error_exit "不支持的操作系统" $ERR_GENERAL
    fi
    
    # 检查系统架构
    local arch=$(uname -m)
    log INFO "系统架构: $arch"
    case $arch in
        x86_64|amd64)
            ;;
        arm64|aarch64)
            ;;
        *)
            error_exit "不支持的系统架构: $arch" $ERR_GENERAL
            ;;
    esac
    
    # 检查系统权限
    if [[ $EUID -eq 0 ]]; then
        log WARN "当前以 root 用户运行，请确保这是必要的"
    fi
    
    # 检查基本命令
    local required_commands=("curl" "wget" "tar" "gzip")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error_exit "缺少必要命令: $cmd" $ERR_DEPENDENCY
        fi
    done
    
    # 检查系统资源
    check_system_resources
    
    log INFO "系统环境检查完成"
    return $SUCCESS
}

# 系统资源检查
check_system_resources() {
    log INFO "检查系统资源..."
    
    # 检查内存
    local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_mem_gb=$((total_mem_kb / 1024 / 1024))
    log INFO "总内存: ${total_mem_gb}GB"
    
    if [[ $total_mem_gb -lt 2 ]]; then
        log WARN "内存不足 2GB，可能影响 Kubernetes 运行"
    fi
    
    # 检查磁盘空间
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    log INFO "根分区使用率: ${disk_usage}%"
    
    if [[ $disk_usage -gt 80 ]]; then
        log WARN "磁盘使用率超过 80%，建议清理空间"
    fi
    
    # 检查CPU核心数
    local cpu_cores=$(nproc)
    log INFO "CPU 核心数: $cpu_cores"
    
    if [[ $cpu_cores -lt 2 ]]; then
        log WARN "CPU 核心数少于 2，可能影响性能"
    fi
}

# 依赖检查函数
check_dependencies() {
    log INFO "开始依赖检查..."
    
    local dependencies=(
        "docker:Docker容器运行时"
        "kubectl:Kubernetes命令行工具"
        "systemctl:系统服务管理工具"
        "iptables:网络防火墙工具"
        "jq:JSON处理工具"
    )
    
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        local cmd="${dep%%:*}"
        local desc="${dep##*:}"
        
        if command -v "$cmd" >/dev/null 2>&1; then
            local version
            case $cmd in
                docker)
                    version=$(docker --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
                    ;;
                kubectl)
                    version=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || echo "unknown")
                    ;;
                *)
                    version="installed"
                    ;;
            esac
            log INFO "$desc: $version"
        else
            log WARN "缺少依赖: $desc ($cmd)"
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log ERROR "缺少以下依赖: ${missing_deps[*]}"
        log INFO "请先安装缺少的依赖，然后重新运行脚本"
        return $ERR_DEPENDENCY
    fi
    
    log INFO "依赖检查完成"
    return $SUCCESS
}

# 网络连接检查
check_network() {
    log INFO "检查网络连接..."
    
    local test_urls=(
        "https://kubernetes.io"
        "https://github.com"
        "https://docker.io"
        "https://gcr.io"
    )
    
    for url in "${test_urls[@]}"; do
        if curl -s --connect-timeout 5 --max-time 10 "$url" >/dev/null; then
            log INFO "网络连接正常: $url"
        else
            log WARN "网络连接失败: $url"
        fi
    done
}

# Docker 检查
check_docker() {
    log INFO "检查 Docker 环境..."
    
    if ! command -v docker >/dev/null 2>&1; then
        error_exit "Docker 未安装" $ERR_DEPENDENCY
    fi
    
    if ! docker version >/dev/null 2>&1; then
        error_exit "Docker 服务未运行" $ERR_GENERAL
    fi
    
    # 检查 Docker 版本
    local docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    log INFO "Docker 版本: $docker_version"
    
    # 检查 Docker 权限
    if ! docker ps >/dev/null 2>&1; then
        error_exit "当前用户无 Docker 权限，请将用户添加到 docker 组" $ERR_PERMISSION
    fi
    
    # 检查 Docker 存储
    local docker_info=$(docker system df 2>/dev/null)
    if [[ -n "$docker_info" ]]; then
        log DEBUG "Docker 存储信息:\n$docker_info"
    fi
    
    log INFO "Docker 环境检查完成"
    return $SUCCESS
}

# Kubernetes 集群连接检查
check_kubernetes() {
    log INFO "检查 Kubernetes 集群连接..."
    
    if ! command -v kubectl >/dev/null 2>&1; then
        error_exit "kubectl 未安装" $ERR_DEPENDENCY
    fi
    
    # 检查集群连接
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log WARN "无法连接到 Kubernetes 集群"
        return $ERR_NETWORK
    fi
    
    # 获取集群信息
    local cluster_info=$(kubectl cluster-info 2>/dev/null)
    log INFO "集群信息:\n$cluster_info"
    
    # 检查节点状态
    local nodes=$(kubectl get nodes --no-headers 2>/dev/null)
    if [[ -n "$nodes" ]]; then
        log INFO "集群节点:\n$nodes"
    fi
    
    # 检查权限
    if kubectl auth can-i "*" "*" >/dev/null 2>&1; then
        log INFO "当前用户具有集群管理权限"
    else
        log WARN "当前用户权限有限"
    fi
    
    log INFO "Kubernetes 集群检查完成"
    return $SUCCESS
}

# 文件下载函数
download_file() {
    local url="$1"
    local output="$2"
    local description="${3:-文件}"
    
    log INFO "下载 $description: $url"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log INFO "[DRY-RUN] 将下载: $url -> $output"
        return $SUCCESS
    fi
    
    # 创建输出目录
    local output_dir=$(dirname "$output")
    mkdir -p "$output_dir"
    
    # 使用 curl 下载
    if command -v curl >/dev/null 2>&1; then
        if curl -L -o "$output" "$url" --connect-timeout 30 --max-time 300 --retry 3; then
            log INFO "下载完成: $output"
            return $SUCCESS
        fi
    fi
    
    # 使用 wget 下载
    if command -v wget >/dev/null 2>&1; then
        if wget -O "$output" "$url" --timeout=30 --tries=3; then
            log INFO "下载完成: $output"
            return $SUCCESS
        fi
    fi
    
    error_exit "文件下载失败: $url" $ERR_NETWORK
}

# 文件校验函数
verify_file() {
    local file="$1"
    local expected_hash="$2"
    local hash_type="${3:-sha256}"
    
    if [[ ! -f "$file" ]]; then
        error_exit "文件不存在: $file" $ERR_GENERAL
    fi
    
    if [[ -n "$expected_hash" ]]; then
        log INFO "验证文件校验和: $file"
        
        local actual_hash
        case $hash_type in
            md5)
                actual_hash=$(md5sum "$file" | cut -d' ' -f1)
                ;;
            sha1)
                actual_hash=$(sha1sum "$file" | cut -d' ' -f1)
                ;;
            sha256)
                actual_hash=$(sha256sum "$file" | cut -d' ' -f1)
                ;;
            *)
                error_exit "不支持的校验类型: $hash_type" $ERR_GENERAL
                ;;
        esac
        
        if [[ "$actual_hash" != "$expected_hash" ]]; then
            error_exit "文件校验失败: $file" $ERR_GENERAL
        fi
        
        log INFO "文件校验成功: $file"
    fi
    
    return $SUCCESS
}

# 备份文件函数
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.bak.$(date +%Y%m%d_%H%M%S)}"
    
    if [[ -f "$file" ]]; then
        local backup_file="${file}${backup_suffix}"
        log INFO "备份文件: $file -> $backup_file"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log INFO "[DRY-RUN] 将备份: $file -> $backup_file"
            return $SUCCESS
        fi
        
        cp "$file" "$backup_file" || error_exit "文件备份失败: $file" $ERR_GENERAL
        log INFO "备份完成: $backup_file"
    fi
    
    return $SUCCESS
}

# 服务管理函数
manage_service() {
    local action="$1"
    local service="$2"
    
    log INFO "服务操作: $action $service"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log INFO "[DRY-RUN] 将执行: systemctl $action $service"
        return $SUCCESS
    fi
    
    case $action in
        start|stop|restart|enable|disable)
            execute_command "systemctl $action $service"
            ;;
        status)
            systemctl status "$service" --no-pager -l
            ;;
        *)
            error_exit "不支持的服务操作: $action" $ERR_GENERAL
            ;;
    esac
    
    return $?
}

# 等待服务就绪
wait_for_service() {
    local service="$1"
    local timeout="${2:-60}"
    local interval="${3:-5}"
    
    log INFO "等待服务就绪: $service (超时: ${timeout}s)"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if systemctl is-active --quiet "$service"; then
            log INFO "服务已就绪: $service"
            return $SUCCESS
        fi
        
        log DEBUG "等待服务启动: $service (已等待 ${elapsed}s)"
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    error_exit "服务启动超时: $service" $ERR_GENERAL
}

# 端口检查函数
check_port() {
    local host="${1:-localhost}"
    local port="$2"
    local timeout="${3:-10}"
    
    log DEBUG "检查端口连通性: $host:$port"
    
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w "$timeout" "$host" "$port" 2>/dev/null; then
            return $SUCCESS
        fi
    elif command -v telnet >/dev/null 2>&1; then
        if timeout "$timeout" telnet "$host" "$port" </dev/null >/dev/null 2>&1; then
            return $SUCCESS
        fi
    else
        # 使用 bash 内置功能
        if timeout "$timeout" bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null; then
            exec 3>&-
            return $SUCCESS
        fi
    fi
    
    return $ERR_NETWORK
}

# 等待端口就绪
wait_for_port() {
    local host="${1:-localhost}"
    local port="$2"
    local timeout="${3:-60}"
    local interval="${4:-5}"
    
    log INFO "等待端口就绪: $host:$port (超时: ${timeout}s)"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if check_port "$host" "$port" 5; then
            log INFO "端口已就绪: $host:$port"
            return $SUCCESS
        fi
        
        log DEBUG "等待端口开放: $host:$port (已等待 ${elapsed}s)"
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    error_exit "端口连接超时: $host:$port" $ERR_NETWORK
}

# 资源清理函数
cleanup_resources() {
    local temp_files=("$@")
    
    log INFO "清理临时资源..."
    
    for file in "${temp_files[@]}"; do
        if [[ -f "$file" ]]; then
            log DEBUG "删除临时文件: $file"
            rm -f "$file"
        elif [[ -d "$file" ]]; then
            log DEBUG "删除临时目录: $file"
            rm -rf "$file"
        fi
    done
    
    log INFO "资源清理完成"
}

# 陷阱处理函数
trap_handler() {
    local exit_code=$?
    log WARN "脚本被中断，开始清理..."
    
    # 这里可以添加清理逻辑
    # cleanup_resources
    
    exit $exit_code
}

# 设置陷阱
trap trap_handler INT TERM

# 参数解析辅助函数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -l|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit $SUCCESS
                ;;
            *)
                log ERROR "未知参数: $1"
                show_help
                exit $ERR_GENERAL
                ;;
        esac
    done
}

# 帮助信息
show_help() {
    cat << EOF
使用方法: $SCRIPT_NAME [选项]

选项:
    -v, --verbose       详细输出模式
    -d, --dry-run       干运行模式（不执行实际操作）
    -l, --log-file      指定日志文件路径
    -h, --help          显示帮助信息

环境变量:
    VERBOSE            设置为 true 启用详细输出
    DRY_RUN            设置为 true 启用干运行模式
    LOG_FILE           指定日志文件路径

示例:
    $SCRIPT_NAME --verbose
    $SCRIPT_NAME --dry-run --log-file /tmp/my-script.log
EOF
}

# 脚本执行时的基础检查
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 直接执行时进行基础检查
    parse_arguments "$@"
    
    log INFO "Kubernetes 脚本公共函数库已加载"
    log INFO "日志文件: $LOG_FILE"
    
    # 可以在这里添加测试函数调用
    case "${1:-}" in
        check_system)
            check_system
            ;;
        check_dependencies)
            check_dependencies
            ;;
        check_network)
            check_network
            ;;
        check_docker)
            check_docker
            ;;
        check_kubernetes)
            check_kubernetes
            ;;
        *)
            log INFO "可用的检查命令:"
            log INFO "  check_system       - 系统环境检查"
            log INFO "  check_dependencies - 依赖工具检查"
            log INFO "  check_network      - 网络连接检查"
            log INFO "  check_docker       - Docker 环境检查"
            log INFO "  check_kubernetes   - Kubernetes 集群检查"
            ;;
    esac
fi
