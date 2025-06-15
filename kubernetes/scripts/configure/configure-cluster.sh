#!/bin/bash
#
# 脚本名称: configure-cluster.sh
# 功能描述: Kubernetes 集群配置脚本
# 创建时间: 2025-06-14
# 版本信息: v1.0.0
# 依赖条件: kubectl, jq
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
readonly PROFILE="${PROFILE:-production}"
readonly BACKUP_DIR="${BACKUP_DIR:-/tmp/k8s-config-backup-$(date +%Y%m%d_%H%M%S)}"
readonly CONFIG_TEMPLATES_DIR="$SCRIPT_DIR/../templates"

# 配置文件列表
CONFIG_FILES=()

# 清理函数
cleanup() {
    log INFO "配置完成，备份文件保存在: $BACKUP_DIR"
}

# 设置清理陷阱
trap cleanup EXIT

# 显示帮助信息
show_help() {
    cat << EOF
Kubernetes 集群配置脚本

使用方法: $0 [选项]

选项:
    --profile PROFILE       配置文件 (production|development|testing, 默认: $PROFILE)
    --backup-dir DIR        备份目录 (默认: $BACKUP_DIR)
    --enable-rbac           启用 RBAC 权限控制
    --enable-psp            启用 Pod 安全策略
    --enable-network-policy 启用网络策略
    --enable-monitoring     启用监控组件
    --enable-logging        启用日志收集
    --skip-validation       跳过配置验证
    -v, --verbose           详细输出模式
    -d, --dry-run           干运行模式
    -h, --help              显示帮助信息

配置文件:
    production              生产环境配置（高安全性、高可用性）
    development             开发环境配置（便于调试、宽松策略）
    testing                 测试环境配置（平衡性能和安全）

示例:
    # 生产环境配置
    $0 --profile production --enable-rbac --enable-psp

    # 开发环境配置
    $0 --profile development

    # 启用所有安全特性
    $0 --enable-rbac --enable-psp --enable-network-policy

环境变量:
    PROFILE                 配置文件
    BACKUP_DIR              备份目录
EOF
}

# 参数解析
parse_arguments() {
    local enable_rbac=false
    local enable_psp=false
    local enable_network_policy=false
    local enable_monitoring=false
    local enable_logging=false
    local skip_validation=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --enable-rbac)
                enable_rbac=true
                shift
                ;;
            --enable-psp)
                enable_psp=true
                shift
                ;;
            --enable-network-policy)
                enable_network_policy=true
                shift
                ;;
            --enable-monitoring)
                enable_monitoring=true
                shift
                ;;
            --enable-logging)
                enable_logging=true
                shift
                ;;
            --skip-validation)
                skip_validation=true
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
    
    # 设置全局变量
    ENABLE_RBAC=$enable_rbac
    ENABLE_PSP=$enable_psp
    ENABLE_NETWORK_POLICY=$enable_network_policy
    ENABLE_MONITORING=$enable_monitoring
    ENABLE_LOGGING=$enable_logging
    SKIP_VALIDATION=$skip_validation
}

# 验证配置文件
validate_profile() {
    log INFO "验证配置文件: $PROFILE"
    
    case $PROFILE in
        production|development|testing)
            log INFO "使用 $PROFILE 环境配置"
            ;;
        *)
            error_exit "不支持的配置文件: $PROFILE" $ERR_CONFIG
            ;;
    esac
}

# 创建备份目录
create_backup_dir() {
    log INFO "创建备份目录: $BACKUP_DIR"
    execute_command "mkdir -p $BACKUP_DIR"
}

# 备份现有配置
backup_existing_configs() {
    log INFO "备份现有配置..."
    
    # 备份关键配置
    local configs_to_backup=(
        "configmaps"
        "secrets"
        "networkpolicies"
        "podsecuritypolicies"
        "roles"
        "rolebindings"
        "clusterroles"
        "clusterrolebindings"
    )
    
    for config in "${configs_to_backup[@]}"; do
        log DEBUG "备份 $config..."
        local backup_file="$BACKUP_DIR/${config}.yaml"
        
        if execute_command "kubectl get $config --all-namespaces -o yaml > $backup_file 2>/dev/null"; then
            log DEBUG "$config 备份完成: $backup_file"
        else
            log WARN "$config 备份失败或不存在"
        fi
    done
    
    log INFO "配置备份完成"
}

# 配置命名空间
configure_namespaces() {
    log INFO "配置命名空间..."
    
    local namespaces
    case $PROFILE in
        production)
            namespaces=("production" "monitoring" "logging" "ingress-system" "cert-manager")
            ;;
        development)
            namespaces=("development" "testing" "monitoring")
            ;;
        testing)
            namespaces=("testing" "staging" "monitoring")
            ;;
    esac
    
    for namespace in "${namespaces[@]}"; do
        log INFO "创建命名空间: $namespace"
        
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $namespace
  labels:
    environment: $PROFILE
    managed-by: configure-cluster
spec: {}
EOF
    done
    
    # 配置默认网络策略（如果启用）
    if [[ "$ENABLE_NETWORK_POLICY" == "true" ]]; then
        configure_namespace_network_policies "${namespaces[@]}"
    fi
    
    log INFO "命名空间配置完成"
}

# 配置网络策略
configure_namespace_network_policies() {
    local namespaces=("$@")
    
    log INFO "配置命名空间网络策略..."
    
    for namespace in "${namespaces[@]}"; do
        log DEBUG "为命名空间 $namespace 配置网络策略"
        
        # 默认拒绝所有入站流量
        cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: $namespace
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF
        
        # 允许命名空间内通信
        cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-intranamespace
  namespace: $namespace
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: $namespace
EOF
        
        # 允许来自 ingress 的流量
        if [[ "$namespace" != "ingress-system" ]]; then
            cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-ingress
  namespace: $namespace
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-system
EOF
        fi
        
        # 允许来自监控系统的流量
        if [[ "$namespace" != "monitoring" ]]; then
            cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-monitoring
  namespace: $namespace
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 9090
EOF
        fi
    done
}

# 配置 RBAC
configure_rbac() {
    log INFO "配置 RBAC 权限控制..."
    
    # 创建开发者角色
    cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "create"]
EOF
    
    # 创建运维角色
    cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: operator
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
- nonResourceURLs: ["*"]
  verbs: ["*"]
EOF
    
    # 创建只读角色
    cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewer
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps", "extensions", "networking.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
EOF
    
    # 配置环境特定的服务账户
    configure_service_accounts
    
    log INFO "RBAC 配置完成"
}

# 配置服务账户
configure_service_accounts() {
    log INFO "配置服务账户..."
    
    local namespaces
    case $PROFILE in
        production)
            namespaces=("production" "monitoring" "logging")
            ;;
        development)
            namespaces=("development" "testing")
            ;;
        testing)
            namespaces=("testing" "staging")
            ;;
    esac
    
    for namespace in "${namespaces[@]}"; do
        # 创建应用服务账户
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-service-account
  namespace: $namespace
automountServiceAccountToken: false
EOF
        
        # 创建 RoleBinding
        cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-developer-binding
  namespace: $namespace
subjects:
- kind: ServiceAccount
  name: app-service-account
  namespace: $namespace
roleRef:
  kind: ClusterRole
  name: developer
  apiGroup: rbac.authorization.k8s.io
EOF
    done
}

# 配置资源配额
configure_resource_quotas() {
    log INFO "配置资源配额..."
    
    local namespaces
    case $PROFILE in
        production)
            namespaces=("production")
            ;;
        development)
            namespaces=("development")
            ;;
        testing)
            namespaces=("testing")
            ;;
    esac
    
    for namespace in "${namespaces[@]}"; do
        local cpu_limit memory_limit storage_limit pod_limit
        
        case $PROFILE in
            production)
                cpu_limit="20"
                memory_limit="40Gi"
                storage_limit="100Gi"
                pod_limit="50"
                ;;
            development)
                cpu_limit="10"
                memory_limit="20Gi"
                storage_limit="50Gi"
                pod_limit="30"
                ;;
            testing)
                cpu_limit="8"
                memory_limit="16Gi"
                storage_limit="30Gi"
                pod_limit="25"
                ;;
        esac
        
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: resource-quota
  namespace: $namespace
spec:
  hard:
    requests.cpu: "$cpu_limit"
    requests.memory: "$memory_limit"
    requests.storage: "$storage_limit"
    pods: "$pod_limit"
    persistentvolumeclaims: "10"
    services: "10"
    secrets: "20"
    configmaps: "20"
EOF
        
        # 配置 LimitRange
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: limit-range
  namespace: $namespace
spec:
  limits:
  - type: Container
    default:
      cpu: "200m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "2"
      memory: "4Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
  - type: Pod
    max:
      cpu: "4"
      memory: "8Gi"
  - type: PersistentVolumeClaim
    max:
      storage: "10Gi"
    min:
      storage: "1Gi"
EOF
    done
    
    log INFO "资源配额配置完成"
}

# 配置 Pod 安全策略
configure_pod_security_policies() {
    log INFO "配置 Pod 安全策略..."
    
    # 限制性 PSP（生产环境）
    cat << EOF | kubectl apply -f -
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
EOF
    
    # 宽松 PSP（开发环境）
    if [[ "$PROFILE" == "development" ]]; then
        cat << EOF | kubectl apply -f -
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: permissive
spec:
  privileged: true
  allowPrivilegeEscalation: true
  allowedCapabilities:
    - '*'
  volumes:
    - '*'
  runAsUser:
    rule: 'RunAsAny'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
EOF
    fi
    
    # 创建相应的 RBAC 绑定
    configure_psp_rbac
    
    log INFO "Pod 安全策略配置完成"
}

# 配置 PSP RBAC
configure_psp_rbac() {
    log INFO "配置 PSP RBAC 绑定..."
    
    # 限制性 PSP 角色
    cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: restricted-psp-user
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs: ['use']
  resourceNames: ['restricted']
EOF
    
    # 绑定到默认服务账户
    cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: restricted-psp-binding
roleRef:
  kind: ClusterRole
  name: restricted-psp-user
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: default
  namespace: production
- kind: ServiceAccount
  name: default
  namespace: testing
EOF
    
    if [[ "$PROFILE" == "development" ]]; then
        # 宽松 PSP 角色（仅开发环境）
        cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: permissive-psp-user
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs: ['use']
  resourceNames: ['permissive']
EOF
        
        cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: permissive-psp-binding
roleRef:
  kind: ClusterRole
  name: permissive-psp-user
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: default
  namespace: development
EOF
    fi
}

# 配置监控组件
configure_monitoring() {
    log INFO "配置监控组件..."
    
    # 创建监控命名空间（如果不存在）
    execute_command "kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -"
    
    # 配置 ServiceMonitor CRD（如果 Prometheus Operator 已安装）
    if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
        configure_service_monitors
    else
        log WARN "Prometheus Operator 未安装，跳过 ServiceMonitor 配置"
    fi
    
    # 配置基础监控 ConfigMap
    configure_monitoring_config
    
    log INFO "监控组件配置完成"
}

# 配置服务监控
configure_service_monitors() {
    log INFO "配置 ServiceMonitor..."
    
    # kube-state-metrics ServiceMonitor
    cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kube-state-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kube-state-metrics
  endpoints:
  - port: http-metrics
    interval: 30s
    path: /metrics
EOF
    
    # node-exporter ServiceMonitor
    cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: node-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: node-exporter
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
EOF
}

# 配置监控配置
configure_monitoring_config() {
    log INFO "配置监控配置..."
    
    # Prometheus 配置
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
      - "/etc/prometheus/rules/*.yml"
    
    scrape_configs:
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https
      
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
        - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/\${1}/proxy/metrics
EOF
}

# 配置日志收集
configure_logging() {
    log INFO "配置日志收集..."
    
    # 创建日志命名空间
    execute_command "kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -"
    
    # 配置 Fluentd DaemonSet
    configure_fluentd
    
    log INFO "日志收集配置完成"
}

# 配置 Fluentd
configure_fluentd() {
    log INFO "配置 Fluentd..."
    
    # Fluentd ConfigMap
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
  namespace: logging
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/*.log
      pos_file /var/log/fluentd-containers.log.pos
      tag kubernetes.*
      read_from_head true
      <parse>
        @type json
        time_format %Y-%m-%dT%H:%M:%S.%NZ
      </parse>
    </source>
    
    <filter kubernetes.**>
      @type kubernetes_metadata
    </filter>
    
    <match **>
      @type stdout
    </match>
EOF
    
    # Fluentd ServiceAccount
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
  namespace: logging
EOF
    
    # Fluentd ClusterRole
    cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluentd
rules:
- apiGroups: [""]
  resources: ["pods", "namespaces"]
  verbs: ["get", "list", "watch"]
EOF
    
    # Fluentd ClusterRoleBinding
    cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fluentd
roleRef:
  kind: ClusterRole
  name: fluentd
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: fluentd
  namespace: logging
EOF
}

# 验证配置
validate_configuration() {
    if [[ "$SKIP_VALIDATION" == "true" ]]; then
        log INFO "跳过配置验证"
        return $SUCCESS
    fi
    
    log INFO "验证集群配置..."
    
    # 检查命名空间
    log DEBUG "检查命名空间..."
    local expected_namespaces
    case $PROFILE in
        production)
            expected_namespaces=("production" "monitoring" "logging" "ingress-system" "cert-manager")
            ;;
        development)
            expected_namespaces=("development" "testing" "monitoring")
            ;;
        testing)
            expected_namespaces=("testing" "staging" "monitoring")
            ;;
    esac
    
    for namespace in "${expected_namespaces[@]}"; do
        if kubectl get namespace "$namespace" >/dev/null 2>&1; then
            log DEBUG "命名空间 $namespace 存在"
        else
            log ERROR "命名空间 $namespace 不存在"
        fi
    done
    
    # 检查 RBAC
    if [[ "$ENABLE_RBAC" == "true" ]]; then
        log DEBUG "检查 RBAC 配置..."
        local required_roles=("developer" "operator" "viewer")
        for role in "${required_roles[@]}"; do
            if kubectl get clusterrole "$role" >/dev/null 2>&1; then
                log DEBUG "ClusterRole $role 存在"
            else
                log ERROR "ClusterRole $role 不存在"
            fi
        done
    fi
    
    # 检查网络策略
    if [[ "$ENABLE_NETWORK_POLICY" == "true" ]]; then
        log DEBUG "检查网络策略..."
        for namespace in "${expected_namespaces[@]}"; do
            local policies=$(kubectl get networkpolicy -n "$namespace" --no-headers 2>/dev/null | wc -l)
            if [[ $policies -gt 0 ]]; then
                log DEBUG "命名空间 $namespace 有 $policies 个网络策略"
            else
                log WARN "命名空间 $namespace 没有网络策略"
            fi
        done
    fi
    
    log INFO "配置验证完成"
}

# 显示配置总结
show_summary() {
    log INFO "集群配置总结"
    
    cat << EOF

🎉 Kubernetes 集群配置完成！

配置信息:
  - 环境配置: $PROFILE
  - RBAC 启用: $ENABLE_RBAC
  - Pod 安全策略: $ENABLE_PSP
  - 网络策略: $ENABLE_NETWORK_POLICY
  - 监控组件: $ENABLE_MONITORING
  - 日志收集: $ENABLE_LOGGING

创建的命名空间:
$(kubectl get namespaces --show-labels | grep "managed-by=configure-cluster" | awk '{print "  - " $1}')

资源配额:
$(kubectl get resourcequota --all-namespaces --no-headers | awk '{print "  - " $1 "/" $2}')

备份位置: $BACKUP_DIR

后续操作:
  # 查看所有命名空间
  kubectl get namespaces
  
  # 查看资源配额
  kubectl get resourcequota --all-namespaces
  
  # 查看网络策略
  kubectl get networkpolicy --all-namespaces
  
  # 查看 RBAC 配置
  kubectl get clusterroles,clusterrolebindings

EOF
}

# 主函数
main() {
    log INFO "开始 Kubernetes 集群配置..."
    
    # 解析参数
    parse_arguments "$@"
    
    # 验证配置文件
    validate_profile
    
    # 检查 Kubernetes 连接
    check_kubernetes
    
    # 创建备份目录
    create_backup_dir
    
    # 备份现有配置
    backup_existing_configs
    
    # 配置命名空间
    configure_namespaces
    
    # 配置资源配额
    configure_resource_quotas
    
    # 配置 RBAC（如果启用）
    if [[ "$ENABLE_RBAC" == "true" ]]; then
        configure_rbac
    fi
    
    # 配置 Pod 安全策略（如果启用）
    if [[ "$ENABLE_PSP" == "true" ]]; then
        configure_pod_security_policies
    fi
    
    # 配置监控（如果启用）
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        configure_monitoring
    fi
    
    # 配置日志（如果启用）
    if [[ "$ENABLE_LOGGING" == "true" ]]; then
        configure_logging
    fi
    
    # 验证配置
    validate_configuration
    
    # 显示总结
    show_summary
    
    log INFO "Kubernetes 集群配置完成！"
}

# 执行主函数
main "$@"
