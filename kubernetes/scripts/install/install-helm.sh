#!/bin/bash
#
# 脚本名称: install-helm.sh
# 功能描述: Helm 包管理器自动化安装脚本
# 创建时间: 2025-06-14
# 版本信息: v1.0.0
# 依赖条件: kubectl, curl
# 支持平台: Ubuntu 18.04+, CentOS 7+, RHEL 7+, macOS 10.14+
#

# 获取脚本目录
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
UTILS_DIR="$(dirname "$SCRIPT_DIR")/utils"

# 加载公共函数库
if [[ -f "$UTILS_DIR/common-functions.sh" ]]; then
    source "$UTILS_DIR/common-functions.sh"
else
    echo "错误: 无法找到公共函数库 $UTILS_DIR/common-functions.sh"
    exit 1
fi

# 全局变量
readonly HELM_VERSION="${HELM_VERSION:-3.13.0}"
readonly INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
readonly HELM_REPO_URL="${HELM_REPO_URL:-https://get.helm.sh}"
readonly HELM_CONFIG_DIR="${HOME}/.config/helm"

# 临时文件列表
TEMP_FILES=()

# 清理函数
cleanup() {
    log INFO "开始清理临时文件..."
    cleanup_resources "${TEMP_FILES[@]}"
}

# 设置清理陷阱
trap cleanup EXIT

# 显示帮助信息
show_help() {
    cat << EOF
Helm 包管理器安装脚本

使用方法: $0 [选项]

选项:
    --version VERSION       Helm 版本 (默认: $HELM_VERSION)
    --install-dir DIR       安装目录 (默认: $INSTALL_DIR)
    --config-repos          配置常用 Helm 仓库
    -v, --verbose           详细输出模式
    -d, --dry-run           干运行模式
    -h, --help              显示帮助信息

示例:
    # 默认安装
    $0

    # 安装指定版本
    $0 --version 3.12.0

    # 安装并配置仓库
    $0 --config-repos

环境变量:
    HELM_VERSION            Helm 版本
    INSTALL_DIR             安装目录
    HELM_REPO_URL           Helm 下载源
EOF
}

# 参数解析
parse_arguments() {
    local config_repos=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                HELM_VERSION="$2"
                shift 2
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --config-repos)
                config_repos=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
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
    
    CONFIG_REPOS=$config_repos
}

# 检查系统要求
check_requirements() {
    log INFO "检查系统要求..."
    
    # 检查 kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        error_exit "kubectl 未安装，请先安装 kubectl" $ERR_DEPENDENCY
    fi
    
    # 检查 Kubernetes 连接
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log WARN "无法连接到 Kubernetes 集群，但可以继续安装 Helm"
    fi
    
    # 检查安装目录权限
    if [[ ! -w "$INSTALL_DIR" ]]; then
        error_exit "没有写入权限: $INSTALL_DIR" $ERR_PERMISSION
    fi
    
    log INFO "系统要求检查完成"
}

# 检查是否已安装
check_existing_installation() {
    log INFO "检查现有 Helm 安装..."
    
    if command -v helm >/dev/null 2>&1; then
        local current_version=$(helm version --short 2>/dev/null | cut -d':' -f2 | tr -d ' ')
        log INFO "发现已安装的 Helm 版本: $current_version"
        
        if [[ "$current_version" == "v$HELM_VERSION" ]]; then
            log INFO "目标版本 $HELM_VERSION 已安装"
            exit $SUCCESS
        else
            log INFO "将升级 Helm 从 $current_version 到 v$HELM_VERSION"
        fi
    else
        log INFO "未发现 Helm 安装"
    fi
}

# 下载 Helm
download_helm() {
    log INFO "下载 Helm $HELM_VERSION..."
    
    # 检测系统架构
    local arch
    case $(uname -m) in
        x86_64|amd64)
            arch="amd64"
            ;;
        arm64|aarch64)
            arch="arm64"
            ;;
        armv7l)
            arch="arm"
            ;;
        *)
            error_exit "不支持的系统架构: $(uname -m)" $ERR_GENERAL
            ;;
    esac
    
    # 检测操作系统
    local os
    case $(uname -s) in
        Linux)
            os="linux"
            ;;
        Darwin)
            os="darwin"
            ;;
        *)
            error_exit "不支持的操作系统: $(uname -s)" $ERR_GENERAL
            ;;
    esac
    
    # 构建下载 URL
    local helm_package="helm-v${HELM_VERSION}-${os}-${arch}.tar.gz"
    local download_url="${HELM_REPO_URL}/${helm_package}"
    local temp_dir="/tmp/helm-install-$$"
    local download_file="$temp_dir/$helm_package"
    
    # 创建临时目录
    execute_command "mkdir -p $temp_dir"
    TEMP_FILES+=("$temp_dir")
    
    # 下载文件
    download_file "$download_url" "$download_file" "Helm $HELM_VERSION"
    
    # 解压文件
    log INFO "解压 Helm 包..."
    execute_command "tar -zxf $download_file -C $temp_dir"
    
    # 安装 Helm
    install_helm_binary "$temp_dir/${os}-${arch}/helm"
}

# 安装 Helm 二进制文件
install_helm_binary() {
    local helm_binary="$1"
    
    log INFO "安装 Helm 到 $INSTALL_DIR..."
    
    if [[ ! -f "$helm_binary" ]]; then
        error_exit "Helm 二进制文件不存在: $helm_binary" $ERR_GENERAL
    fi
    
    # 复制二进制文件
    execute_command "cp $helm_binary $INSTALL_DIR/helm"
    execute_command "chmod +x $INSTALL_DIR/helm"
    
    # 验证安装
    if ! execute_command "$INSTALL_DIR/helm version --short"; then
        error_exit "Helm 安装验证失败" $ERR_GENERAL
    fi
    
    log INFO "Helm 安装成功"
}

# 配置 Helm
configure_helm() {
    log INFO "配置 Helm..."
    
    # 创建配置目录
    execute_command "mkdir -p $HELM_CONFIG_DIR"
    
    # 初始化 Helm（Helm 3 不需要 Tiller）
    log INFO "Helm 3 无需 Tiller 初始化"
    
    # 配置自动补全（如果支持）
    configure_auto_completion
    
    log INFO "Helm 配置完成"
}

# 配置自动补全
configure_auto_completion() {
    log INFO "配置 Helm 自动补全..."
    
    local shell_type=$(basename "$SHELL")
    
    case $shell_type in
        bash)
            local completion_file="$HOME/.bash_completion.d/helm"
            execute_command "mkdir -p $(dirname $completion_file)"
            execute_command "helm completion bash > $completion_file"
            log INFO "Bash 自动补全已配置: $completion_file"
            ;;
        zsh)
            local completion_dir="${HOME}/.zsh/completions"
            execute_command "mkdir -p $completion_dir"
            execute_command "helm completion zsh > $completion_dir/_helm"
            log INFO "Zsh 自动补全已配置: $completion_dir/_helm"
            ;;
        fish)
            execute_command "helm completion fish > ~/.config/fish/completions/helm.fish"
            log INFO "Fish 自动补全已配置"
            ;;
        *)
            log WARN "不支持的 Shell: $shell_type，跳过自动补全配置"
            ;;
    esac
}

# 配置常用仓库
configure_repositories() {
    log INFO "配置常用 Helm 仓库..."
    
    # 常用仓库列表
    local repositories=(
        "stable:https://charts.helm.sh/stable"
        "bitnami:https://charts.bitnami.com/bitnami"
        "ingress-nginx:https://kubernetes.github.io/ingress-nginx"
        "jetstack:https://charts.jetstack.io"
        "prometheus-community:https://prometheus-community.github.io/helm-charts"
        "grafana:https://grafana.github.io/helm-charts"
        "elastic:https://helm.elastic.co"
        "hashicorp:https://helm.releases.hashicorp.com"
    )
    
    for repo in "${repositories[@]}"; do
        local repo_name="${repo%%:*}"
        local repo_url="${repo##*:}"
        
        log INFO "添加仓库: $repo_name"
        if execute_command "helm repo add $repo_name $repo_url"; then
            log INFO "仓库 $repo_name 添加成功"
        else
            log WARN "仓库 $repo_name 添加失败"
        fi
    done
    
    # 更新仓库
    log INFO "更新仓库索引..."
    execute_command "helm repo update"
    
    # 显示已配置的仓库
    log INFO "已配置的仓库列表:"
    execute_command "helm repo list"
}

# 验证安装
verify_installation() {
    log INFO "验证 Helm 安装..."
    
    # 检查版本
    local installed_version=$(helm version --short 2>/dev/null)
    if [[ -n "$installed_version" ]]; then
        log INFO "Helm 版本: $installed_version"
    else
        error_exit "无法获取 Helm 版本信息" $ERR_GENERAL
    fi
    
    # 检查 Kubernetes 连接
    if kubectl cluster-info >/dev/null 2>&1; then
        log INFO "测试 Helm 与 Kubernetes 连接..."
        
        # 创建测试命名空间
        local test_namespace="helm-test-$$"
        execute_command "kubectl create namespace $test_namespace"
        
        # 测试 Helm 基本功能
        test_helm_functionality "$test_namespace"
        
        # 清理测试资源
        execute_command "kubectl delete namespace $test_namespace"
    else
        log WARN "无法连接到 Kubernetes 集群，跳过集成测试"
    fi
    
    log INFO "Helm 安装验证完成"
}

# 测试 Helm 功能
test_helm_functionality() {
    local test_namespace="$1"
    
    log INFO "测试 Helm 基本功能..."
    
    # 创建简单的测试 Chart
    local test_chart_dir="/tmp/test-chart-$$"
    execute_command "helm create $test_chart_dir"
    TEMP_FILES+=("$test_chart_dir")
    
    # 模拟安装（dry-run）
    if execute_command "helm install test-release $test_chart_dir --namespace $test_namespace --dry-run"; then
        log INFO "Helm dry-run 测试成功"
    else
        log WARN "Helm dry-run 测试失败"
    fi
    
    # 模板渲染测试
    if execute_command "helm template test-release $test_chart_dir --namespace $test_namespace >/dev/null"; then
        log INFO "Helm 模板渲染测试成功"
    else
        log WARN "Helm 模板渲染测试失败"
    fi
    
    log INFO "Helm 功能测试完成"
}

# 显示安装总结
show_summary() {
    log INFO "Helm 安装总结"
    
    local helm_version=$(helm version --short 2>/dev/null || echo "未知")
    
    cat << EOF

🎉 Helm 安装完成！

安装信息:
  - Helm 版本: $helm_version
  - 安装位置: $INSTALL_DIR/helm
  - 配置目录: $HELM_CONFIG_DIR

常用命令:
  # 查看版本
  helm version
  
  # 搜索 Chart
  helm search repo nginx
  
  # 安装应用
  helm install my-release stable/nginx
  
  # 查看发布
  helm list
  
  # 卸载应用
  helm uninstall my-release

仓库管理:
  # 添加仓库
  helm repo add bitnami https://charts.bitnami.com/bitnami
  
  # 更新仓库
  helm repo update
  
  # 查看仓库
  helm repo list

Chart 开发:
  # 创建 Chart
  helm create my-chart
  
  # 验证 Chart
  helm lint my-chart
  
  # 打包 Chart
  helm package my-chart

EOF

    if [[ "$CONFIG_REPOS" == "true" ]]; then
        log INFO "已配置常用 Helm 仓库，使用 'helm repo list' 查看"
    else
        log INFO "使用 --config-repos 参数可以自动配置常用仓库"
    fi
    
    log INFO "Helm 安装和配置完成！"
}

# 主函数
main() {
    log INFO "开始 Helm 安装..."
    
    # 解析参数
    parse_arguments "$@"
    
    # 检查系统要求
    check_system
    check_requirements
    
    # 检查现有安装
    check_existing_installation
    
    # 下载和安装 Helm
    download_helm
    
    # 配置 Helm
    configure_helm
    
    # 配置仓库（如果需要）
    if [[ "$CONFIG_REPOS" == "true" ]]; then
        configure_repositories
    fi
    
    # 验证安装
    verify_installation
    
    # 显示总结
    show_summary
    
    log INFO "Helm 安装完成！"
}

# 执行主函数
main "$@"
