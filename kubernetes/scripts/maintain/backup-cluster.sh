#!/bin/bash
#
# 脚本名称: backup-cluster.sh
# 功能描述: Kubernetes 集群备份脚本
# 创建时间: 2025-06-14
# 版本信息: v1.0.0
# 依赖条件: kubectl, etcdctl
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
readonly BACKUP_DIR="${BACKUP_DIR:-/backup/kubernetes/$(date +%Y%m%d_%H%M%S)}"
readonly BACKUP_TYPE="${BACKUP_TYPE:-full}"
readonly RETENTION_DAYS="${RETENTION_DAYS:-30}"
readonly COMPRESSION="${COMPRESSION:-true}"
readonly ENCRYPTION="${ENCRYPTION:-false}"
readonly ENCRYPTION_KEY="${ENCRYPTION_KEY:-}"
readonly REMOTE_BACKUP="${REMOTE_BACKUP:-false}"
readonly REMOTE_DESTINATION="${REMOTE_DESTINATION:-}"

# etcd 相关配置
readonly ETCD_ENDPOINTS="${ETCD_ENDPOINTS:-https://127.0.0.1:2379}"
readonly ETCD_CERT_FILE="${ETCD_CERT_FILE:-/etc/kubernetes/pki/etcd/healthcheck-client.crt}"
readonly ETCD_KEY_FILE="${ETCD_KEY_FILE:-/etc/kubernetes/pki/etcd/healthcheck-client.key}"
readonly ETCD_CA_FILE="${ETCD_CA_FILE:-/etc/kubernetes/pki/etcd/ca.crt}"

# 备份统计
BACKUP_SIZE=0
BACKUP_DURATION=0
BACKED_UP_RESOURCES=0

# 清理函数
cleanup() {
    local exit_code=$?
    log INFO "备份完成，总耗时: ${BACKUP_DURATION}s，备份大小: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "未知")"
    
    if [[ $exit_code -eq 0 ]]; then
        log INFO "备份文件保存在: $BACKUP_DIR"
    else
        log ERROR "备份过程中发生错误"
    fi
}

# 设置清理陷阱
trap cleanup EXIT

# 显示帮助信息
show_help() {
    cat << EOF
Kubernetes 集群备份脚本

使用方法: $0 [选项]

选项:
    --backup-dir DIR        备份目录 (默认: $BACKUP_DIR)
    --backup-type TYPE      备份类型 (full|resources|etcd, 默认: $BACKUP_TYPE)
    --retention-days DAYS   备份保留天数 (默认: $RETENTION_DAYS)
    --compression           启用压缩 (默认: $COMPRESSION)
    --encryption            启用加密
    --encryption-key KEY    加密密钥
    --remote-backup         启用远程备份
    --remote-dest DEST      远程备份目标
    --etcd-endpoints URLs   etcd 端点 (默认: $ETCD_ENDPOINTS)
    --etcd-cert FILE        etcd 客户端证书
    --etcd-key FILE         etcd 客户端密钥
    --etcd-ca FILE          etcd CA 证书
    --exclude-namespaces NS 排除的命名空间 (逗号分隔)
    --include-pv            包含 PersistentVolume 数据
    --schedule CRON         定时备份 (cron 表达式)
    -v, --verbose           详细输出模式
    -d, --dry-run           干运行模式
    -h, --help              显示帮助信息

备份类型:
    full                    完整备份（etcd + 资源 + 配置）
    resources               仅备份 Kubernetes 资源
    etcd                    仅备份 etcd 数据

示例:
    # 完整备份
    $0 --backup-type full --compression

    # 仅备份资源
    $0 --backup-type resources --exclude-namespaces "kube-system,kube-public"

    # etcd 备份
    $0 --backup-type etcd --encryption --encryption-key "your-key"

    # 远程备份
    $0 --remote-backup --remote-dest "s3://my-bucket/k8s-backups/"

环境变量:
    BACKUP_DIR              备份目录
    BACKUP_TYPE             备份类型
    RETENTION_DAYS          保留天数
    ETCD_ENDPOINTS          etcd 端点
    ENCRYPTION_KEY          加密密钥
EOF
}

# 参数解析
parse_arguments() {
    local exclude_namespaces=""
    local include_pv=false
    local schedule=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --backup-type)
                BACKUP_TYPE="$2"
                shift 2
                ;;
            --retention-days)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            --compression)
                COMPRESSION=true
                shift
                ;;
            --encryption)
                ENCRYPTION=true
                shift
                ;;
            --encryption-key)
                ENCRYPTION_KEY="$2"
                shift 2
                ;;
            --remote-backup)
                REMOTE_BACKUP=true
                shift
                ;;
            --remote-dest)
                REMOTE_DESTINATION="$2"
                shift 2
                ;;
            --etcd-endpoints)
                ETCD_ENDPOINTS="$2"
                shift 2
                ;;
            --etcd-cert)
                ETCD_CERT_FILE="$2"
                shift 2
                ;;
            --etcd-key)
                ETCD_KEY_FILE="$2"
                shift 2
                ;;
            --etcd-ca)
                ETCD_CA_FILE="$2"
                shift 2
                ;;
            --exclude-namespaces)
                exclude_namespaces="$2"
                shift 2
                ;;
            --include-pv)
                include_pv=true
                shift
                ;;
            --schedule)
                schedule="$2"
                shift 2
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
    EXCLUDE_NAMESPACES="$exclude_namespaces"
    INCLUDE_PV="$include_pv"
    SCHEDULE="$schedule"
}

# 验证参数
validate_parameters() {
    log INFO "验证备份参数..."
    
    # 验证备份类型
    case $BACKUP_TYPE in
        full|resources|etcd)
            ;;
        *)
            error_exit "不支持的备份类型: $BACKUP_TYPE" $ERR_CONFIG
            ;;
    esac
    
    # 验证保留天数
    if [[ ! "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || [[ $RETENTION_DAYS -lt 1 ]]; then
        error_exit "无效的保留天数: $RETENTION_DAYS" $ERR_CONFIG
    fi
    
    # 验证加密配置
    if [[ "$ENCRYPTION" == "true" && -z "$ENCRYPTION_KEY" ]]; then
        error_exit "启用加密时必须提供加密密钥" $ERR_CONFIG
    fi
    
    # 验证远程备份配置
    if [[ "$REMOTE_BACKUP" == "true" && -z "$REMOTE_DESTINATION" ]]; then
        error_exit "启用远程备份时必须提供目标地址" $ERR_CONFIG
    fi
    
    # 验证 etcd 证书文件
    if [[ "$BACKUP_TYPE" == "etcd" || "$BACKUP_TYPE" == "full" ]]; then
        if [[ ! -f "$ETCD_CERT_FILE" ]]; then
            log WARN "etcd 客户端证书文件不存在: $ETCD_CERT_FILE"
        fi
        if [[ ! -f "$ETCD_KEY_FILE" ]]; then
            log WARN "etcd 客户端密钥文件不存在: $ETCD_KEY_FILE"
        fi
        if [[ ! -f "$ETCD_CA_FILE" ]]; then
            log WARN "etcd CA 证书文件不存在: $ETCD_CA_FILE"
        fi
    fi
    
    log INFO "参数验证完成"
}

# 检查依赖
check_dependencies() {
    log INFO "检查备份依赖..."
    
    # 检查 kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        error_exit "kubectl 未安装" $ERR_DEPENDENCY
    fi
    
    # 检查 etcdctl（如果需要备份 etcd）
    if [[ "$BACKUP_TYPE" == "etcd" || "$BACKUP_TYPE" == "full" ]]; then
        if ! command -v etcdctl >/dev/null 2>&1; then
            log WARN "etcdctl 未安装，将尝试从容器中执行"
        fi
    fi
    
    # 检查压缩工具
    if [[ "$COMPRESSION" == "true" ]]; then
        if ! command -v gzip >/dev/null 2>&1 && ! command -v tar >/dev/null 2>&1; then
            error_exit "压缩工具 (gzip/tar) 未安装" $ERR_DEPENDENCY
        fi
    fi
    
    # 检查加密工具
    if [[ "$ENCRYPTION" == "true" ]]; then
        if ! command -v gpg >/dev/null 2>&1 && ! command -v openssl >/dev/null 2>&1; then
            error_exit "加密工具 (gpg/openssl) 未安装" $ERR_DEPENDENCY
        fi
    fi
    
    # 检查远程备份工具
    if [[ "$REMOTE_BACKUP" == "true" ]]; then
        case $REMOTE_DESTINATION in
            s3://*)
                if ! command -v aws >/dev/null 2>&1; then
                    error_exit "AWS CLI 未安装" $ERR_DEPENDENCY
                fi
                ;;
            gs://*)
                if ! command -v gsutil >/dev/null 2>&1; then
                    error_exit "Google Cloud SDK 未安装" $ERR_DEPENDENCY
                fi
                ;;
            *@*:*)
                if ! command -v rsync >/dev/null 2>&1 && ! command -v scp >/dev/null 2>&1; then
                    error_exit "rsync 或 scp 未安装" $ERR_DEPENDENCY
                fi
                ;;
        esac
    fi
    
    log INFO "依赖检查完成"
}

# 创建备份目录
create_backup_dir() {
    log INFO "创建备份目录: $BACKUP_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log INFO "[DRY-RUN] 将创建备份目录: $BACKUP_DIR"
        return $SUCCESS
    fi
    
    execute_command "mkdir -p $BACKUP_DIR"
    
    # 创建子目录
    execute_command "mkdir -p $BACKUP_DIR/etcd"
    execute_command "mkdir -p $BACKUP_DIR/resources"
    execute_command "mkdir -p $BACKUP_DIR/configs"
    execute_command "mkdir -p $BACKUP_DIR/logs"
    
    # 创建备份元数据文件
    create_backup_metadata
    
    log INFO "备份目录创建完成"
}

# 创建备份元数据
create_backup_metadata() {
    local metadata_file="$BACKUP_DIR/backup-metadata.json"
    
    cat << EOF > "$metadata_file"
{
    "backup_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "backup_type": "$BACKUP_TYPE",
    "kubernetes_version": "$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null || echo 'unknown')",
    "cluster_name": "$(kubectl config current-context 2>/dev/null || echo 'unknown')",
    "backup_tool_version": "v1.0.0",
    "compression_enabled": $COMPRESSION,
    "encryption_enabled": $ENCRYPTION,
    "backup_size_bytes": 0,
    "resources_count": 0,
    "namespaces": [],
    "backup_duration_seconds": 0,
    "backup_status": "in_progress"
}
EOF
    
    log DEBUG "备份元数据文件创建完成: $metadata_file"
}

# 更新备份元数据
update_backup_metadata() {
    local metadata_file="$BACKUP_DIR/backup-metadata.json"
    local status="${1:-completed}"
    
    if [[ -f "$metadata_file" ]]; then
        # 计算备份大小
        local backup_size=$(du -sb "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "0")
        
        # 获取命名空间列表
        local namespaces=$(kubectl get namespaces -o json 2>/dev/null | jq -r '.items[].metadata.name' 2>/dev/null | paste -sd',' || echo "unknown")
        
        # 更新元数据
        jq --arg status "$status" \
           --arg size "$backup_size" \
           --arg duration "$BACKUP_DURATION" \
           --arg resources "$BACKED_UP_RESOURCES" \
           --arg namespaces "$namespaces" \
           '.backup_status = $status | 
            .backup_size_bytes = ($size | tonumber) | 
            .backup_duration_seconds = ($duration | tonumber) | 
            .resources_count = ($resources | tonumber) | 
            .namespaces = ($namespaces | split(","))' \
            "$metadata_file" > "${metadata_file}.tmp" && mv "${metadata_file}.tmp" "$metadata_file"
    fi
}

# 备份 etcd
backup_etcd() {
    log INFO "开始备份 etcd..."
    
    local etcd_backup_file="$BACKUP_DIR/etcd/etcd-snapshot-$(date +%Y%m%d_%H%M%S).db"
    
    # 检查 etcdctl 可用性
    local etcdctl_cmd
    if command -v etcdctl >/dev/null 2>&1; then
        etcdctl_cmd="etcdctl"
    else
        # 尝试从 etcd Pod 中执行
        local etcd_pod=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [[ -n "$etcd_pod" ]]; then
            etcdctl_cmd="kubectl exec -n kube-system $etcd_pod -- etcdctl"
        else
            error_exit "无法找到 etcdctl 命令或 etcd Pod" $ERR_DEPENDENCY
        fi
    fi
    
    # 构建 etcdctl 命令
    local etcdctl_args=""
    if [[ -f "$ETCD_CERT_FILE" && -f "$ETCD_KEY_FILE" && -f "$ETCD_CA_FILE" ]]; then
        etcdctl_args="--endpoints=$ETCD_ENDPOINTS --cert=$ETCD_CERT_FILE --key=$ETCD_KEY_FILE --cacert=$ETCD_CA_FILE"
    fi
    
    # 执行备份
    log INFO "创建 etcd 快照..."
    if execute_command "$etcdctl_cmd $etcdctl_args snapshot save $etcd_backup_file"; then
        log INFO "etcd 快照创建成功: $etcd_backup_file"
        
        # 验证快照
        if execute_command "$etcdctl_cmd $etcdctl_args snapshot status $etcd_backup_file"; then
            log INFO "etcd 快照验证成功"
        else
            log WARN "etcd 快照验证失败"
        fi
    else
        error_exit "etcd 快照创建失败" $ERR_GENERAL
    fi
    
    log INFO "etcd 备份完成"
}

# 备份 Kubernetes 资源
backup_resources() {
    log INFO "开始备份 Kubernetes 资源..."
    
    local resources_dir="$BACKUP_DIR/resources"
    
    # 获取所有命名空间
    local namespaces
    if [[ -n "$EXCLUDE_NAMESPACES" ]]; then
        namespaces=$(kubectl get namespaces -o json | jq -r ".items[].metadata.name" | grep -v -E "^($(echo "$EXCLUDE_NAMESPACES" | tr ',' '|'))$")
    else
        namespaces=$(kubectl get namespaces -o json | jq -r '.items[].metadata.name')
    fi
    
    # 备份集群级别资源
    backup_cluster_resources "$resources_dir"
    
    # 备份命名空间级别资源
    while read -r namespace; do
        [[ -z "$namespace" ]] && continue
        backup_namespace_resources "$namespace" "$resources_dir"
    done <<< "$namespaces"
    
    # 备份自定义资源
    backup_custom_resources "$resources_dir"
    
    log INFO "Kubernetes 资源备份完成"
}

# 备份集群级别资源
backup_cluster_resources() {
    local resources_dir="$1"
    local cluster_dir="$resources_dir/cluster"
    
    log INFO "备份集群级别资源..."
    execute_command "mkdir -p $cluster_dir"
    
    # 定义集群级别资源
    local cluster_resources=(
        "nodes"
        "persistentvolumes"
        "storageclasses"
        "clusterroles"
        "clusterrolebindings"
        "podsecuritypolicies"
        "customresourcedefinitions"
        "validatingadmissionwebhooks"
        "mutatingadmissionwebhooks"
        "priorityclasses"
        "ingressclasses"
    )
    
    for resource in "${cluster_resources[@]}"; do
        log DEBUG "备份集群资源: $resource"
        local resource_file="$cluster_dir/${resource}.yaml"
        
        if kubectl get "$resource" >/dev/null 2>&1; then
            if execute_command "kubectl get $resource -o yaml > $resource_file"; then
                local count=$(kubectl get "$resource" --no-headers 2>/dev/null | wc -l)
                log DEBUG "$resource 备份完成，共 $count 个对象"
                BACKED_UP_RESOURCES=$((BACKED_UP_RESOURCES + count))
            else
                log WARN "$resource 备份失败"
            fi
        else
            log DEBUG "$resource 不存在或不可访问"
        fi
    done
}

# 备份命名空间级别资源
backup_namespace_resources() {
    local namespace="$1"
    local resources_dir="$2"
    local namespace_dir="$resources_dir/namespaces/$namespace"
    
    log DEBUG "备份命名空间 $namespace 的资源..."
    execute_command "mkdir -p $namespace_dir"
    
    # 定义命名空间级别资源
    local namespace_resources=(
        "pods"
        "services"
        "endpoints"
        "configmaps"
        "secrets"
        "persistentvolumeclaims"
        "deployments"
        "replicasets"
        "statefulsets"
        "daemonsets"
        "jobs"
        "cronjobs"
        "ingresses"
        "networkpolicies"
        "roles"
        "rolebindings"
        "serviceaccounts"
        "horizontalpodautoscalers"
        "poddisruptionbudgets"
        "resourcequotas"
        "limitranges"
    )
    
    for resource in "${namespace_resources[@]}"; do
        log DEBUG "备份命名空间资源: $namespace/$resource"
        local resource_file="$namespace_dir/${resource}.yaml"
        
        if kubectl get "$resource" -n "$namespace" >/dev/null 2>&1; then
            if execute_command "kubectl get $resource -n $namespace -o yaml > $resource_file"; then
                local count=$(kubectl get "$resource" -n "$namespace" --no-headers 2>/dev/null | wc -l)
                if [[ $count -gt 0 ]]; then
                    log DEBUG "$namespace/$resource 备份完成，共 $count 个对象"
                    BACKED_UP_RESOURCES=$((BACKED_UP_RESOURCES + count))
                else
                    # 删除空文件
                    rm -f "$resource_file"
                fi
            else
                log WARN "$namespace/$resource 备份失败"
            fi
        fi
    done
}

# 备份自定义资源
backup_custom_resources() {
    local resources_dir="$1"
    local crds_dir="$resources_dir/custom-resources"
    
    log INFO "备份自定义资源..."
    execute_command "mkdir -p $crds_dir"
    
    # 获取所有 CRD
    local crds=$(kubectl get crd -o json | jq -r '.items[].metadata.name' 2>/dev/null)
    
    while read -r crd; do
        [[ -z "$crd" ]] && continue
        
        log DEBUG "备份自定义资源: $crd"
        local crd_file="$crds_dir/${crd}.yaml"
        
        # 备份 CRD 定义
        execute_command "kubectl get crd $crd -o yaml > ${crd_file}"
        
        # 备份 CRD 实例（如果存在）
        local cr_instances_file="$crds_dir/${crd}-instances.yaml"
        if kubectl get "$crd" --all-namespaces >/dev/null 2>&1; then
            if execute_command "kubectl get $crd --all-namespaces -o yaml > $cr_instances_file"; then
                local count=$(kubectl get "$crd" --all-namespaces --no-headers 2>/dev/null | wc -l)
                log DEBUG "$crd 实例备份完成，共 $count 个对象"
                BACKED_UP_RESOURCES=$((BACKED_UP_RESOURCES + count))
            fi
        fi
    done <<< "$crds"
}

# 备份配置文件
backup_configs() {
    log INFO "备份集群配置文件..."
    
    local configs_dir="$BACKUP_DIR/configs"
    
    # 备份 kubeconfig
    if [[ -f "$HOME/.kube/config" ]]; then
        execute_command "cp $HOME/.kube/config $configs_dir/kubeconfig"
        log DEBUG "kubeconfig 备份完成"
    fi
    
    # 备份 Kubernetes 配置文件（如果在主节点）
    local k8s_configs=(
        "/etc/kubernetes/admin.conf"
        "/etc/kubernetes/kubelet.conf"
        "/etc/kubernetes/controller-manager.conf"
        "/etc/kubernetes/scheduler.conf"
        "/etc/kubernetes/manifests"
        "/etc/kubernetes/pki"
    )
    
    for config in "${k8s_configs[@]}"; do
        if [[ -e "$config" ]]; then
            local config_name=$(basename "$config")
            if [[ -d "$config" ]]; then
                execute_command "cp -r $config $configs_dir/$config_name"
            else
                execute_command "cp $config $configs_dir/$config_name"
            fi
            log DEBUG "配置 $config_name 备份完成"
        fi
    done
    
    log INFO "配置文件备份完成"
}

# 备份持久卷数据
backup_persistent_volumes() {
    if [[ "$INCLUDE_PV" != "true" ]]; then
        log INFO "跳过持久卷数据备份"
        return $SUCCESS
    fi
    
    log INFO "备份持久卷数据..."
    
    local pv_dir="$BACKUP_DIR/persistent-volumes"
    execute_command "mkdir -p $pv_dir"
    
    # 获取所有 PVC
    local pvcs=$(kubectl get pvc --all-namespaces -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"')
    
    while read -r pvc; do
        [[ -z "$pvc" ]] && continue
        
        local namespace="${pvc%%/*}"
        local pvc_name="${pvc##*/}"
        
        log DEBUG "备份 PVC 数据: $namespace/$pvc_name"
        
        # 创建数据备份 Pod
        create_backup_pod "$namespace" "$pvc_name" "$pv_dir"
        
    done <<< "$pvcs"
    
    log INFO "持久卷数据备份完成"
}

# 创建备份 Pod
create_backup_pod() {
    local namespace="$1"
    local pvc_name="$2"
    local pv_dir="$3"
    
    local backup_pod_name="backup-$pvc_name-$(date +%s)"
    local backup_file="$pv_dir/${namespace}-${pvc_name}.tar.gz"
    
    # 创建备份 Pod
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $backup_pod_name
  namespace: $namespace
spec:
  containers:
  - name: backup
    image: busybox:1.35
    command: ['sh', '-c', 'tar czf /backup/data.tar.gz -C /data . && sleep 30']
    volumeMounts:
    - name: data
      mountPath: /data
    - name: backup
      mountPath: /backup
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: $pvc_name
  - name: backup
    hostPath:
      path: $(dirname "$backup_file")
      type: DirectoryOrCreate
  restartPolicy: Never
EOF
    
    # 等待 Pod 完成
    if kubectl wait --for=condition=Ready pod/$backup_pod_name -n $namespace --timeout=300s >/dev/null 2>&1; then
        log DEBUG "PVC $namespace/$pvc_name 数据备份完成"
    else
        log WARN "PVC $namespace/$pvc_name 数据备份失败"
    fi
    
    # 清理备份 Pod
    kubectl delete pod $backup_pod_name -n $namespace >/dev/null 2>&1
}

# 压缩备份
compress_backup() {
    if [[ "$COMPRESSION" != "true" ]]; then
        return $SUCCESS
    fi
    
    log INFO "压缩备份文件..."
    
    local compressed_file="${BACKUP_DIR}.tar.gz"
    local backup_parent_dir=$(dirname "$BACKUP_DIR")
    local backup_name=$(basename "$BACKUP_DIR")
    
    if execute_command "tar -czf $compressed_file -C $backup_parent_dir $backup_name"; then
        log INFO "备份压缩完成: $compressed_file"
        
        # 更新备份目录路径
        BACKUP_DIR="$compressed_file"
        
        # 删除原始目录
        execute_command "rm -rf ${BACKUP_DIR%.tar.gz}"
    else
        log ERROR "备份压缩失败"
        return $ERR_GENERAL
    fi
}

# 加密备份
encrypt_backup() {
    if [[ "$ENCRYPTION" != "true" ]]; then
        return $SUCCESS
    fi
    
    log INFO "加密备份文件..."
    
    local encrypted_file="${BACKUP_DIR}.enc"
    
    # 使用 OpenSSL 加密
    if command -v openssl >/dev/null 2>&1; then
        if execute_command "openssl enc -aes-256-cbc -salt -in $BACKUP_DIR -out $encrypted_file -k $ENCRYPTION_KEY"; then
            log INFO "备份加密完成: $encrypted_file"
            
            # 删除原始文件
            execute_command "rm -f $BACKUP_DIR"
            BACKUP_DIR="$encrypted_file"
        else
            log ERROR "备份加密失败"
            return $ERR_GENERAL
        fi
    else
        log ERROR "OpenSSL 未安装，无法加密"
        return $ERR_DEPENDENCY
    fi
}

# 远程备份
upload_to_remote() {
    if [[ "$REMOTE_BACKUP" != "true" ]]; then
        return $SUCCESS
    fi
    
    log INFO "上传备份到远程存储..."
    
    case $REMOTE_DESTINATION in
        s3://*)
            upload_to_s3
            ;;
        gs://*)
            upload_to_gcs
            ;;
        *@*:*)
            upload_via_scp
            ;;
        *)
            log ERROR "不支持的远程存储类型: $REMOTE_DESTINATION"
            return $ERR_CONFIG
            ;;
    esac
}

# 上传到 S3
upload_to_s3() {
    local s3_path="$REMOTE_DESTINATION$(basename "$BACKUP_DIR")"
    
    if execute_command "aws s3 cp $BACKUP_DIR $s3_path"; then
        log INFO "备份上传到 S3 完成: $s3_path"
    else
        log ERROR "S3 上传失败"
        return $ERR_GENERAL
    fi
}

# 上传到 Google Cloud Storage
upload_to_gcs() {
    local gcs_path="$REMOTE_DESTINATION$(basename "$BACKUP_DIR")"
    
    if execute_command "gsutil cp $BACKUP_DIR $gcs_path"; then
        log INFO "备份上传到 GCS 完成: $gcs_path"
    else
        log ERROR "GCS 上传失败"
        return $ERR_GENERAL
    fi
}

# 通过 SCP 上传
upload_via_scp() {
    if execute_command "scp $BACKUP_DIR $REMOTE_DESTINATION"; then
        log INFO "备份通过 SCP 上传完成: $REMOTE_DESTINATION"
    else
        log ERROR "SCP 上传失败"
        return $ERR_GENERAL
    fi
}

# 清理旧备份
cleanup_old_backups() {
    log INFO "清理旧备份文件..."
    
    local backup_parent_dir=$(dirname "$BACKUP_DIR")
    
    # 查找并删除超过保留天数的备份
    if [[ -d "$backup_parent_dir" ]]; then
        find "$backup_parent_dir" -name "20*" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
        find "$backup_parent_dir" -name "*.tar.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \; 2>/dev/null || true
        find "$backup_parent_dir" -name "*.enc" -mtime +$RETENTION_DAYS -exec rm -f {} \; 2>/dev/null || true
        
        log INFO "旧备份清理完成（保留 $RETENTION_DAYS 天）"
    fi
}

# 验证备份
verify_backup() {
    log INFO "验证备份完整性..."
    
    local backup_file="$BACKUP_DIR"
    local verification_passed=true
    
    # 检查备份文件是否存在
    if [[ ! -e "$backup_file" ]]; then
        log ERROR "备份文件不存在: $backup_file"
        verification_passed=false
    fi
    
    # 检查文件大小
    local file_size=$(du -sb "$backup_file" 2>/dev/null | cut -f1 || echo "0")
    if [[ $file_size -eq 0 ]]; then
        log ERROR "备份文件大小为 0"
        verification_passed=false
    else
        log INFO "备份文件大小: $(du -sh "$backup_file" | cut -f1)"
    fi
    
    # 如果是压缩文件，验证压缩完整性
    if [[ "$backup_file" == *.tar.gz ]]; then
        if execute_command "tar -tzf $backup_file >/dev/null"; then
            log INFO "压缩文件完整性验证通过"
        else
            log ERROR "压缩文件损坏"
            verification_passed=false
        fi
    fi
    
    if [[ "$verification_passed" == "true" ]]; then
        log INFO "备份验证通过"
        return $SUCCESS
    else
        log ERROR "备份验证失败"
        return $ERR_GENERAL
    fi
}

# 安装定时备份
install_cron_job() {
    if [[ -z "$SCHEDULE" ]]; then
        return $SUCCESS
    fi
    
    log INFO "安装定时备份任务..."
    
    local cron_command="$0"
    local current_args=""
    
    # 构建 cron 命令参数
    [[ "$BACKUP_TYPE" != "full" ]] && current_args="$current_args --backup-type $BACKUP_TYPE"
    [[ "$COMPRESSION" == "true" ]] && current_args="$current_args --compression"
    [[ "$ENCRYPTION" == "true" ]] && current_args="$current_args --encryption --encryption-key $ENCRYPTION_KEY"
    [[ "$REMOTE_BACKUP" == "true" ]] && current_args="$current_args --remote-backup --remote-dest $REMOTE_DESTINATION"
    [[ -n "$EXCLUDE_NAMESPACES" ]] && current_args="$current_args --exclude-namespaces $EXCLUDE_NAMESPACES"
    
    local cron_entry="$SCHEDULE $cron_command $current_args"
    
    # 添加到 crontab
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    
    log INFO "定时备份任务已安装: $SCHEDULE"
}

# 显示备份总结
show_summary() {
    log INFO "备份操作总结"
    
    local backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "未知")
    
    cat << EOF

🎉 Kubernetes 集群备份完成！

备份信息:
  - 备份类型: $BACKUP_TYPE
  - 备份位置: $BACKUP_DIR
  - 备份大小: $backup_size
  - 备份时长: ${BACKUP_DURATION}s
  - 资源数量: $BACKED_UP_RESOURCES
  - 压缩启用: $COMPRESSION
  - 加密启用: $ENCRYPTION
  - 远程备份: $REMOTE_BACKUP

备份内容:
$(if [[ "$BACKUP_TYPE" == "etcd" || "$BACKUP_TYPE" == "full" ]]; then echo "  ✅ etcd 数据快照"; fi)
$(if [[ "$BACKUP_TYPE" == "resources" || "$BACKUP_TYPE" == "full" ]]; then echo "  ✅ Kubernetes 资源"; fi)
$(if [[ "$BACKUP_TYPE" == "full" ]]; then echo "  ✅ 配置文件"; fi)
$(if [[ "$INCLUDE_PV" == "true" ]]; then echo "  ✅ 持久卷数据"; fi)

恢复命令:
  # 从备份恢复（示例）
  kubectl apply -f $BACKUP_DIR/resources/

下次备份保留至: $(date -d "+$RETENTION_DAYS days" +%Y-%m-%d)

EOF

    if [[ -n "$SCHEDULE" ]]; then
        log INFO "定时备份已配置: $SCHEDULE"
    fi
}

# 主函数
main() {
    local start_time=$(date +%s)
    
    log INFO "开始 Kubernetes 集群备份..."
    
    # 解析参数
    parse_arguments "$@"
    
    # 验证参数
    validate_parameters
    
    # 检查依赖
    check_dependencies
    
    # 检查 Kubernetes 连接
    check_kubernetes
    
    # 创建备份目录
    create_backup_dir
    
    # 根据备份类型执行相应的备份
    case $BACKUP_TYPE in
        etcd)
            backup_etcd
            ;;
        resources)
            backup_resources
            ;;
        full)
            backup_etcd
            backup_resources
            backup_configs
            backup_persistent_volumes
            ;;
    esac
    
    # 计算备份时长
    local end_time=$(date +%s)
    BACKUP_DURATION=$((end_time - start_time))
    
    # 更新备份元数据
    update_backup_metadata "completed"
    
    # 压缩备份
    compress_backup
    
    # 加密备份
    encrypt_backup
    
    # 验证备份
    verify_backup
    
    # 上传到远程存储
    upload_to_remote
    
    # 清理旧备份
    cleanup_old_backups
    
    # 安装定时任务
    install_cron_job
    
    # 显示总结
    show_summary
    
    log INFO "Kubernetes 集群备份完成！"
}

# 执行主函数
main "$@"
