#!/bin/bash
#
# 脚本名称: health-check.sh
# 功能描述: Kubernetes 集群健康检查脚本
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
readonly CHECK_NAMESPACES="${CHECK_NAMESPACES:-all}"
readonly CHECK_NODES="${CHECK_NODES:-all}"
readonly HEALTH_REPORT_FILE="${HEALTH_REPORT_FILE:-/tmp/k8s-health-report-$(date +%Y%m%d_%H%M%S).json}"
readonly WARNING_THRESHOLD="${WARNING_THRESHOLD:-80}"
readonly CRITICAL_THRESHOLD="${CRITICAL_THRESHOLD:-90}"
readonly CHECK_INTERVAL="${CHECK_INTERVAL:-5}"
readonly MAX_RETRIES="${MAX_RETRIES:-3}"

# 检查结果统计
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNING_CHECKS=0
FAILED_CHECKS=0

# 健康检查结果
HEALTH_RESULTS=()

# 显示帮助信息
show_help() {
    cat << EOF
Kubernetes 集群健康检查脚本

使用方法: $0 [选项]

选项:
    --namespaces NAMESPACES     检查的命名空间 (默认: $CHECK_NAMESPACES)
    --nodes NODES               检查的节点 (默认: $CHECK_NODES)
    --report-file FILE          健康报告文件路径 (默认: $HEALTH_REPORT_FILE)
    --warning-threshold NUM     警告阈值百分比 (默认: $WARNING_THRESHOLD)
    --critical-threshold NUM    严重阈值百分比 (默认: $CRITICAL_THRESHOLD)
    --interval SECONDS          检查间隔秒数 (默认: $CHECK_INTERVAL)
    --max-retries NUM           最大重试次数 (默认: $MAX_RETRIES)
    --continuous                持续监控模式
    --summary-only              仅显示摘要信息
    --json                      输出 JSON 格式结果
    -v, --verbose               详细输出模式
    -h, --help                  显示帮助信息

检查项目:
    - 集群基本状态
    - 节点健康状态
    - 系统组件状态
    - Pod 运行状态
    - 资源使用情况
    - 网络连通性
    - 存储状态
    - 证书有效期

示例:
    # 基本健康检查
    $0

    # 检查特定命名空间
    $0 --namespaces "default,kube-system"

    # 持续监控
    $0 --continuous --interval 30

    # 生成详细报告
    $0 --verbose --report-file /tmp/health-report.json

环境变量:
    CHECK_NAMESPACES            检查的命名空间
    CHECK_NODES                 检查的节点
    HEALTH_REPORT_FILE          健康报告文件路径
    WARNING_THRESHOLD           警告阈值
    CRITICAL_THRESHOLD          严重阈值
EOF
}

# 参数解析
parse_arguments() {
    local continuous=false
    local summary_only=false
    local json_output=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --namespaces)
                CHECK_NAMESPACES="$2"
                shift 2
                ;;
            --nodes)
                CHECK_NODES="$2"
                shift 2
                ;;
            --report-file)
                HEALTH_REPORT_FILE="$2"
                shift 2
                ;;
            --warning-threshold)
                WARNING_THRESHOLD="$2"
                shift 2
                ;;
            --critical-threshold)
                CRITICAL_THRESHOLD="$2"
                shift 2
                ;;
            --interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            --max-retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            --continuous)
                continuous=true
                shift
                ;;
            --summary-only)
                summary_only=true
                shift
                ;;
            --json)
                json_output=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
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
    CONTINUOUS_MODE=$continuous
    SUMMARY_ONLY=$summary_only
    JSON_OUTPUT=$json_output
}

# 添加检查结果
add_check_result() {
    local component="$1"
    local check_name="$2"
    local status="$3"
    local message="$4"
    local details="${5:-}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    case $status in
        "PASS")
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            ;;
        "WARN")
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            ;;
        "FAIL")
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            ;;
    esac
    
    local result=$(cat << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "component": "$component",
    "check_name": "$check_name",
    "status": "$status",
    "message": "$message",
    "details": $([[ -n "$details" ]] && echo "\"$details\"" || echo "null")
}
EOF
)
    
    HEALTH_RESULTS+=("$result")
    
    # 输出检查结果
    if [[ "$SUMMARY_ONLY" != "true" ]]; then
        case $status in
            "PASS")
                log INFO "✅ [$component] $check_name: $message"
                ;;
            "WARN")
                log WARN "⚠️  [$component] $check_name: $message"
                ;;
            "FAIL")
                log ERROR "❌ [$component] $check_name: $message"
                ;;
        esac
        
        if [[ -n "$details" && "$VERBOSE" == "true" ]]; then
            log DEBUG "   详细信息: $details"
        fi
    fi
}

# 检查集群基本状态
check_cluster_status() {
    log INFO "检查集群基本状态..."
    
    # 检查 API Server 连通性
    if kubectl cluster-info >/dev/null 2>&1; then
        local cluster_info=$(kubectl cluster-info 2>/dev/null)
        add_check_result "cluster" "api_server_connectivity" "PASS" "API Server 连接正常" "$cluster_info"
    else
        add_check_result "cluster" "api_server_connectivity" "FAIL" "无法连接到 API Server"
        return $ERR_NETWORK
    fi
    
    # 检查集群版本
    local server_version=$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null)
    if [[ -n "$server_version" && "$server_version" != "null" ]]; then
        add_check_result "cluster" "server_version" "PASS" "Kubernetes 版本: $server_version"
    else
        add_check_result "cluster" "server_version" "WARN" "无法获取服务器版本信息"
    fi
    
    # 检查组件状态
    check_component_status
    
    return $SUCCESS
}

# 检查组件状态
check_component_status() {
    log DEBUG "检查系统组件状态..."
    
    # 检查组件状态（旧版本兼容）
    if kubectl get componentstatuses >/dev/null 2>&1; then
        local unhealthy_components=$(kubectl get componentstatuses -o json 2>/dev/null | \
            jq -r '.items[] | select(.conditions[0].type != "Healthy") | .metadata.name' 2>/dev/null)
        
        if [[ -z "$unhealthy_components" ]]; then
            add_check_result "cluster" "component_status" "PASS" "所有系统组件健康"
        else
            add_check_result "cluster" "component_status" "FAIL" "发现不健康的组件" "$unhealthy_components"
        fi
    else
        # 新版本使用 Pod 状态检查
        local system_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v Running | wc -l)
        if [[ $system_pods -eq 0 ]]; then
            add_check_result "cluster" "system_pods" "PASS" "所有系统 Pod 运行正常"
        else
            local failed_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v Running)
            add_check_result "cluster" "system_pods" "FAIL" "发现异常的系统 Pod" "$failed_pods"
        fi
    fi
}

# 检查节点健康状态
check_nodes_health() {
    log INFO "检查节点健康状态..."
    
    local nodes
    if [[ "$CHECK_NODES" == "all" ]]; then
        nodes=$(kubectl get nodes -o json 2>/dev/null | jq -r '.items[].metadata.name' 2>/dev/null)
    else
        nodes=$(echo "$CHECK_NODES" | tr ',' '\n')
    fi
    
    if [[ -z "$nodes" ]]; then
        add_check_result "nodes" "node_list" "FAIL" "无法获取节点列表"
        return $ERR_GENERAL
    fi
    
    local total_nodes=0
    local ready_nodes=0
    local unhealthy_nodes=()
    
    while read -r node; do
        [[ -z "$node" ]] && continue
        total_nodes=$((total_nodes + 1))
        
        # 检查节点就绪状态
        local node_ready=$(kubectl get node "$node" -o json 2>/dev/null | \
            jq -r '.status.conditions[] | select(.type=="Ready") | .status' 2>/dev/null)
        
        if [[ "$node_ready" == "True" ]]; then
            ready_nodes=$((ready_nodes + 1))
            add_check_result "nodes" "node_ready_$node" "PASS" "节点 $node 就绪"
        else
            unhealthy_nodes+=("$node")
            add_check_result "nodes" "node_ready_$node" "FAIL" "节点 $node 未就绪"
        fi
        
        # 检查节点资源使用情况
        check_node_resources "$node"
        
        # 检查节点条件
        check_node_conditions "$node"
        
    done <<< "$nodes"
    
    # 节点总体状态
    if [[ $ready_nodes -eq $total_nodes ]]; then
        add_check_result "nodes" "overall_status" "PASS" "所有节点 ($total_nodes) 都已就绪"
    else
        local unhealthy_count=${#unhealthy_nodes[@]}
        add_check_result "nodes" "overall_status" "FAIL" "$unhealthy_count/$total_nodes 节点异常" "$(IFS=,; echo "${unhealthy_nodes[*]}")"
    fi
}

# 检查节点资源使用情况
check_node_resources() {
    local node="$1"
    
    log DEBUG "检查节点 $node 资源使用情况..."
    
    # 获取节点资源信息
    local node_info=$(kubectl top node "$node" --no-headers 2>/dev/null)
    if [[ -n "$node_info" ]]; then
        local cpu_usage=$(echo "$node_info" | awk '{print $2}' | sed 's/%//')
        local memory_usage=$(echo "$node_info" | awk '{print $4}' | sed 's/%//')
        
        # 检查 CPU 使用率
        if [[ $cpu_usage -ge $CRITICAL_THRESHOLD ]]; then
            add_check_result "nodes" "cpu_usage_$node" "FAIL" "节点 $node CPU 使用率过高: ${cpu_usage}%"
        elif [[ $cpu_usage -ge $WARNING_THRESHOLD ]]; then
            add_check_result "nodes" "cpu_usage_$node" "WARN" "节点 $node CPU 使用率较高: ${cpu_usage}%"
        else
            add_check_result "nodes" "cpu_usage_$node" "PASS" "节点 $node CPU 使用率正常: ${cpu_usage}%"
        fi
        
        # 检查内存使用率
        if [[ $memory_usage -ge $CRITICAL_THRESHOLD ]]; then
            add_check_result "nodes" "memory_usage_$node" "FAIL" "节点 $node 内存使用率过高: ${memory_usage}%"
        elif [[ $memory_usage -ge $WARNING_THRESHOLD ]]; then
            add_check_result "nodes" "memory_usage_$node" "WARN" "节点 $node 内存使用率较高: ${memory_usage}%"
        else
            add_check_result "nodes" "memory_usage_$node" "PASS" "节点 $node 内存使用率正常: ${memory_usage}%"
        fi
    else
        add_check_result "nodes" "resource_metrics_$node" "WARN" "无法获取节点 $node 资源使用信息"
    fi
    
    # 检查磁盘压力
    local disk_pressure=$(kubectl get node "$node" -o json 2>/dev/null | \
        jq -r '.status.conditions[] | select(.type=="DiskPressure") | .status' 2>/dev/null)
    
    if [[ "$disk_pressure" == "False" ]]; then
        add_check_result "nodes" "disk_pressure_$node" "PASS" "节点 $node 磁盘压力正常"
    else
        add_check_result "nodes" "disk_pressure_$node" "WARN" "节点 $node 存在磁盘压力"
    fi
}

# 检查节点条件
check_node_conditions() {
    local node="$1"
    
    log DEBUG "检查节点 $node 状态条件..."
    
    local conditions=("MemoryPressure" "DiskPressure" "PIDPressure" "NetworkUnavailable")
    
    for condition in "${conditions[@]}"; do
        local status=$(kubectl get node "$node" -o json 2>/dev/null | \
            jq -r ".status.conditions[] | select(.type==\"$condition\") | .status" 2>/dev/null)
        
        # 对于这些条件，False 表示正常，True 表示有问题
        if [[ "$status" == "False" ]]; then
            add_check_result "nodes" "${condition,,}_$node" "PASS" "节点 $node $condition 状态正常"
        elif [[ "$status" == "True" ]]; then
            add_check_result "nodes" "${condition,,}_$node" "FAIL" "节点 $node 存在 $condition"
        else
            add_check_result "nodes" "${condition,,}_$node" "WARN" "节点 $node 无法获取 $condition 状态"
        fi
    done
}

# 检查 Pod 状态
check_pods_health() {
    log INFO "检查 Pod 健康状态..."
    
    local namespaces
    if [[ "$CHECK_NAMESPACES" == "all" ]]; then
        namespaces=$(kubectl get namespaces -o json 2>/dev/null | jq -r '.items[].metadata.name' 2>/dev/null)
    else
        namespaces=$(echo "$CHECK_NAMESPACES" | tr ',' '\n')
    fi
    
    if [[ -z "$namespaces" ]]; then
        add_check_result "pods" "namespace_list" "FAIL" "无法获取命名空间列表"
        return $ERR_GENERAL
    fi
    
    local total_pods=0
    local running_pods=0
    local failed_pods=()
    
    while read -r namespace; do
        [[ -z "$namespace" ]] && continue
        
        log DEBUG "检查命名空间 $namespace 中的 Pod..."
        
        # 获取命名空间中的所有 Pod
        local pods_info=$(kubectl get pods -n "$namespace" -o json 2>/dev/null)
        if [[ -z "$pods_info" ]]; then
            continue
        fi
        
        # 检查每个 Pod 的状态
        local pod_names=$(echo "$pods_info" | jq -r '.items[].metadata.name' 2>/dev/null)
        while read -r pod_name; do
            [[ -z "$pod_name" ]] && continue
            total_pods=$((total_pods + 1))
            
            check_pod_status "$namespace" "$pod_name"
            
        done <<< "$pod_names"
        
    done <<< "$namespaces"
    
    # Pod 总体状态摘要
    local healthy_pods=$((total_pods - ${#failed_pods[@]}))
    if [[ ${#failed_pods[@]} -eq 0 ]]; then
        add_check_result "pods" "overall_status" "PASS" "所有 Pod ($total_pods) 状态正常"
    else
        add_check_result "pods" "overall_status" "WARN" "${#failed_pods[@]}/$total_pods Pod 存在问题"
    fi
}

# 检查单个 Pod 状态
check_pod_status() {
    local namespace="$1"
    local pod_name="$2"
    
    local pod_info=$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)
    if [[ -z "$pod_info" ]]; then
        add_check_result "pods" "pod_info_${namespace}_${pod_name}" "FAIL" "无法获取 Pod $namespace/$pod_name 信息"
        return
    fi
    
    local phase=$(echo "$pod_info" | jq -r '.status.phase' 2>/dev/null)
    local ready=$(echo "$pod_info" | jq -r '.status.conditions[] | select(.type=="Ready") | .status' 2>/dev/null)
    local restart_count=$(echo "$pod_info" | jq -r '.status.containerStatuses[]?.restartCount // 0' 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo "0")
    
    case $phase in
        "Running")
            if [[ "$ready" == "True" ]]; then
                if [[ $restart_count -gt 5 ]]; then
                    add_check_result "pods" "pod_status_${namespace}_${pod_name}" "WARN" "Pod $namespace/$pod_name 运行但重启次数较多: $restart_count"
                else
                    add_check_result "pods" "pod_status_${namespace}_${pod_name}" "PASS" "Pod $namespace/$pod_name 运行正常"
                fi
            else
                add_check_result "pods" "pod_status_${namespace}_${pod_name}" "WARN" "Pod $namespace/$pod_name 运行但未就绪"
            fi
            ;;
        "Succeeded")
            add_check_result "pods" "pod_status_${namespace}_${pod_name}" "PASS" "Pod $namespace/$pod_name 成功完成"
            ;;
        "Failed")
            local reason=$(echo "$pod_info" | jq -r '.status.reason // "Unknown"' 2>/dev/null)
            add_check_result "pods" "pod_status_${namespace}_${pod_name}" "FAIL" "Pod $namespace/$pod_name 失败: $reason"
            ;;
        "Pending")
            local conditions=$(echo "$pod_info" | jq -r '.status.conditions[]? | select(.status=="False") | .message' 2>/dev/null)
            add_check_result "pods" "pod_status_${namespace}_${pod_name}" "WARN" "Pod $namespace/$pod_name 挂起" "$conditions"
            ;;
        *)
            add_check_result "pods" "pod_status_${namespace}_${pod_name}" "WARN" "Pod $namespace/$pod_name 状态未知: $phase"
            ;;
    esac
    
    # 检查容器状态
    check_container_status "$namespace" "$pod_name" "$pod_info"
}

# 检查容器状态
check_container_status() {
    local namespace="$1"
    local pod_name="$2"
    local pod_info="$3"
    
    local container_statuses=$(echo "$pod_info" | jq -c '.status.containerStatuses[]?' 2>/dev/null)
    
    while read -r container_status; do
        [[ -z "$container_status" ]] && continue
        
        local container_name=$(echo "$container_status" | jq -r '.name' 2>/dev/null)
        local ready=$(echo "$container_status" | jq -r '.ready' 2>/dev/null)
        local restart_count=$(echo "$container_status" | jq -r '.restartCount' 2>/dev/null)
        local state=$(echo "$container_status" | jq -r '.state | keys[0]' 2>/dev/null)
        
        case $state in
            "running")
                if [[ "$ready" == "true" ]]; then
                    add_check_result "containers" "container_${namespace}_${pod_name}_${container_name}" "PASS" "容器 $container_name 运行正常"
                else
                    add_check_result "containers" "container_${namespace}_${pod_name}_${container_name}" "WARN" "容器 $container_name 运行但未就绪"
                fi
                ;;
            "waiting")
                local reason=$(echo "$container_status" | jq -r '.state.waiting.reason // "Unknown"' 2>/dev/null)
                add_check_result "containers" "container_${namespace}_${pod_name}_${container_name}" "WARN" "容器 $container_name 等待中: $reason"
                ;;
            "terminated")
                local reason=$(echo "$container_status" | jq -r '.state.terminated.reason // "Unknown"' 2>/dev/null)
                local exit_code=$(echo "$container_status" | jq -r '.state.terminated.exitCode // "Unknown"' 2>/dev/null)
                add_check_result "containers" "container_${namespace}_${pod_name}_${container_name}" "FAIL" "容器 $container_name 已终止: $reason (退出码: $exit_code)"
                ;;
        esac
        
        # 检查重启次数
        if [[ $restart_count -gt 10 ]]; then
            add_check_result "containers" "restart_count_${namespace}_${pod_name}_${container_name}" "FAIL" "容器 $container_name 重启次数过多: $restart_count"
        elif [[ $restart_count -gt 5 ]]; then
            add_check_result "containers" "restart_count_${namespace}_${pod_name}_${container_name}" "WARN" "容器 $container_name 重启次数较多: $restart_count"
        fi
        
    done <<< "$container_statuses"
}

# 检查存储状态
check_storage_health() {
    log INFO "检查存储健康状态..."
    
    # 检查 PersistentVolume 状态
    local pvs=$(kubectl get pv -o json 2>/dev/null | jq -r '.items[]?' 2>/dev/null)
    if [[ -n "$pvs" ]]; then
        local total_pvs=0
        local available_pvs=0
        local bound_pvs=0
        local failed_pvs=0
        
        while read -r pv_info; do
            [[ -z "$pv_info" ]] && continue
            total_pvs=$((total_pvs + 1))
            
            local pv_name=$(echo "$pv_info" | jq -r '.metadata.name' 2>/dev/null)
            local phase=$(echo "$pv_info" | jq -r '.status.phase' 2>/dev/null)
            
            case $phase in
                "Available")
                    available_pvs=$((available_pvs + 1))
                    add_check_result "storage" "pv_${pv_name}" "PASS" "PV $pv_name 可用"
                    ;;
                "Bound")
                    bound_pvs=$((bound_pvs + 1))
                    add_check_result "storage" "pv_${pv_name}" "PASS" "PV $pv_name 已绑定"
                    ;;
                "Released"|"Failed")
                    failed_pvs=$((failed_pvs + 1))
                    add_check_result "storage" "pv_${pv_name}" "FAIL" "PV $pv_name 状态异常: $phase"
                    ;;
                *)
                    add_check_result "storage" "pv_${pv_name}" "WARN" "PV $pv_name 状态未知: $phase"
                    ;;
            esac
        done <<< "$(kubectl get pv -o json 2>/dev/null | jq -c '.items[]?' 2>/dev/null)"
        
        add_check_result "storage" "pv_summary" "PASS" "PV 总计: $total_pvs (可用: $available_pvs, 绑定: $bound_pvs, 异常: $failed_pvs)"
    else
        add_check_result "storage" "pv_check" "PASS" "集群中没有 PersistentVolume"
    fi
    
    # 检查 PersistentVolumeClaim 状态
    check_pvc_status
    
    # 检查 StorageClass
    check_storage_class
}

# 检查 PVC 状态
check_pvc_status() {
    local namespaces
    if [[ "$CHECK_NAMESPACES" == "all" ]]; then
        namespaces=$(kubectl get namespaces -o json 2>/dev/null | jq -r '.items[].metadata.name' 2>/dev/null)
    else
        namespaces=$(echo "$CHECK_NAMESPACES" | tr ',' '\n')
    fi
    
    local total_pvcs=0
    local bound_pvcs=0
    local pending_pvcs=0
    
    while read -r namespace; do
        [[ -z "$namespace" ]] && continue
        
        local pvcs=$(kubectl get pvc -n "$namespace" -o json 2>/dev/null | jq -c '.items[]?' 2>/dev/null)
        while read -r pvc_info; do
            [[ -z "$pvc_info" ]] && continue
            total_pvcs=$((total_pvcs + 1))
            
            local pvc_name=$(echo "$pvc_info" | jq -r '.metadata.name' 2>/dev/null)
            local phase=$(echo "$pvc_info" | jq -r '.status.phase' 2>/dev/null)
            
            case $phase in
                "Bound")
                    bound_pvcs=$((bound_pvcs + 1))
                    add_check_result "storage" "pvc_${namespace}_${pvc_name}" "PASS" "PVC $namespace/$pvc_name 已绑定"
                    ;;
                "Pending")
                    pending_pvcs=$((pending_pvcs + 1))
                    add_check_result "storage" "pvc_${namespace}_${pvc_name}" "WARN" "PVC $namespace/$pvc_name 挂起"
                    ;;
                *)
                    add_check_result "storage" "pvc_${namespace}_${pvc_name}" "FAIL" "PVC $namespace/$pvc_name 状态异常: $phase"
                    ;;
            esac
        done <<< "$pvcs"
    done <<< "$namespaces"
    
    if [[ $total_pvcs -gt 0 ]]; then
        add_check_result "storage" "pvc_summary" "PASS" "PVC 总计: $total_pvcs (绑定: $bound_pvcs, 挂起: $pending_pvcs)"
    fi
}

# 检查 StorageClass
check_storage_class() {
    local storage_classes=$(kubectl get storageclass -o json 2>/dev/null | jq -r '.items[].metadata.name' 2>/dev/null)
    
    if [[ -n "$storage_classes" ]]; then
        local sc_count=$(echo "$storage_classes" | wc -l)
        add_check_result "storage" "storage_class" "PASS" "存储类数量: $sc_count"
        
        # 检查默认存储类
        local default_sc=$(kubectl get storageclass -o json 2>/dev/null | \
            jq -r '.items[] | select(.metadata.annotations["storageclass.kubernetes.io/is-default-class"]=="true") | .metadata.name' 2>/dev/null)
        
        if [[ -n "$default_sc" ]]; then
            add_check_result "storage" "default_storage_class" "PASS" "默认存储类: $default_sc"
        else
            add_check_result "storage" "default_storage_class" "WARN" "未设置默认存储类"
        fi
    else
        add_check_result "storage" "storage_class" "WARN" "集群中没有存储类"
    fi
}

# 检查网络连通性
check_network_connectivity() {
    log INFO "检查网络连通性..."
    
    # 检查 CoreDNS
    check_coredns_status
    
    # 检查服务发现
    check_service_discovery
    
    # 检查网络策略
    check_network_policies
}

# 检查 CoreDNS 状态
check_coredns_status() {
    local coredns_pods=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o json 2>/dev/null | jq -r '.items[]?.metadata.name' 2>/dev/null)
    
    if [[ -n "$coredns_pods" ]]; then
        local running_dns_pods=0
        local total_dns_pods=0
        
        while read -r pod_name; do
            [[ -z "$pod_name" ]] && continue
            total_dns_pods=$((total_dns_pods + 1))
            
            local pod_status=$(kubectl get pod "$pod_name" -n kube-system -o json 2>/dev/null | jq -r '.status.phase' 2>/dev/null)
            if [[ "$pod_status" == "Running" ]]; then
                running_dns_pods=$((running_dns_pods + 1))
            fi
        done <<< "$coredns_pods"
        
        if [[ $running_dns_pods -eq $total_dns_pods ]]; then
            add_check_result "network" "coredns_status" "PASS" "CoreDNS Pod 运行正常 ($running_dns_pods/$total_dns_pods)"
        else
            add_check_result "network" "coredns_status" "FAIL" "CoreDNS Pod 异常 ($running_dns_pods/$total_dns_pods)"
        fi
        
        # 测试 DNS 解析
        test_dns_resolution
    else
        add_check_result "network" "coredns_status" "FAIL" "未找到 CoreDNS Pod"
    fi
}

# 测试 DNS 解析
test_dns_resolution() {
    log DEBUG "测试 DNS 解析..."
    
    # 创建测试 Pod 进行 DNS 解析测试
    local test_pod_name="dns-test-$(date +%s)"
    local test_namespace="default"
    
    cat << EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: $test_pod_name
  namespace: $test_namespace
spec:
  containers:
  - name: test
    image: busybox:1.35
    command: ['sleep', '60']
  restartPolicy: Never
EOF
    
    # 等待 Pod 运行
    if kubectl wait --for=condition=Ready pod/$test_pod_name -n $test_namespace --timeout=30s >/dev/null 2>&1; then
        # 测试 DNS 解析
        local dns_test=$(kubectl exec $test_pod_name -n $test_namespace -- nslookup kubernetes.default.svc.cluster.local 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            add_check_result "network" "dns_resolution" "PASS" "DNS 解析正常"
        else
            add_check_result "network" "dns_resolution" "FAIL" "DNS 解析失败"
        fi
    else
        add_check_result "network" "dns_resolution" "WARN" "无法创建 DNS 测试 Pod"
    fi
    
    # 清理测试 Pod
    kubectl delete pod $test_pod_name -n $test_namespace >/dev/null 2>&1
}

# 检查服务发现
check_service_discovery() {
    local services_count=$(kubectl get services --all-namespaces --no-headers 2>/dev/null | wc -l)
    
    if [[ $services_count -gt 0 ]]; then
        add_check_result "network" "service_discovery" "PASS" "服务总数: $services_count"
        
        # 检查 kubernetes 默认服务
        local k8s_service=$(kubectl get service kubernetes -n default -o json 2>/dev/null)
        if [[ -n "$k8s_service" ]]; then
            add_check_result "network" "kubernetes_service" "PASS" "Kubernetes 默认服务正常"
        else
            add_check_result "network" "kubernetes_service" "FAIL" "Kubernetes 默认服务异常"
        fi
    else
        add_check_result "network" "service_discovery" "WARN" "集群中没有服务"
    fi
}

# 检查网络策略
check_network_policies() {
    local network_policies=$(kubectl get networkpolicies --all-namespaces --no-headers 2>/dev/null | wc -l)
    
    if [[ $network_policies -gt 0 ]]; then
        add_check_result "network" "network_policies" "PASS" "网络策略数量: $network_policies"
    else
        add_check_result "network" "network_policies" "PASS" "集群中没有网络策略"
    fi
}

# 检查证书有效期
check_certificates() {
    log INFO "检查证书有效期..."
    
    # 检查 API Server 证书
    check_apiserver_certificates
    
    # 检查 kubelet 证书
    check_kubelet_certificates
    
    # 检查 etcd 证书
    check_etcd_certificates
}

# 检查 API Server 证书
check_apiserver_certificates() {
    local cert_dir="/etc/kubernetes/pki"
    
    if [[ -d "$cert_dir" ]]; then
        local certs=("apiserver.crt" "apiserver-kubelet-client.crt" "front-proxy-client.crt")
        
        for cert in "${certs[@]}"; do
            local cert_path="$cert_dir/$cert"
            if [[ -f "$cert_path" ]]; then
                local expiry_date=$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | cut -d= -f2)
                local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null)
                local current_timestamp=$(date +%s)
                local days_left=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                
                if [[ $days_left -lt 30 ]]; then
                    add_check_result "certificates" "cert_$cert" "FAIL" "证书 $cert 将在 $days_left 天后过期"
                elif [[ $days_left -lt 90 ]]; then
                    add_check_result "certificates" "cert_$cert" "WARN" "证书 $cert 将在 $days_left 天后过期"
                else
                    add_check_result "certificates" "cert_$cert" "PASS" "证书 $cert 有效期正常 ($days_left 天)"
                fi
            else
                add_check_result "certificates" "cert_$cert" "WARN" "证书文件 $cert 不存在"
            fi
        done
    else
        add_check_result "certificates" "cert_directory" "WARN" "证书目录 $cert_dir 不存在"
    fi
}

# 检查 kubelet 证书
check_kubelet_certificates() {
    local kubelet_cert_dir="/var/lib/kubelet/pki"
    
    if [[ -d "$kubelet_cert_dir" ]]; then
        local kubelet_cert="$kubelet_cert_dir/kubelet-client-current.pem"
        if [[ -f "$kubelet_cert" ]]; then
            local expiry_date=$(openssl x509 -in "$kubelet_cert" -noout -enddate 2>/dev/null | cut -d= -f2)
            local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null)
            local current_timestamp=$(date +%s)
            local days_left=$(( (expiry_timestamp - current_timestamp) / 86400 ))
            
            if [[ $days_left -lt 30 ]]; then
                add_check_result "certificates" "kubelet_cert" "FAIL" "kubelet 证书将在 $days_left 天后过期"
            elif [[ $days_left -lt 90 ]]; then
                add_check_result "certificates" "kubelet_cert" "WARN" "kubelet 证书将在 $days_left 天后过期"
            else
                add_check_result "certificates" "kubelet_cert" "PASS" "kubelet 证书有效期正常 ($days_left 天)"
            fi
        else
            add_check_result "certificates" "kubelet_cert" "WARN" "kubelet 证书文件不存在"
        fi
    else
        add_check_result "certificates" "kubelet_cert_dir" "WARN" "kubelet 证书目录不存在"
    fi
}

# 检查 etcd 证书
check_etcd_certificates() {
    local etcd_cert_dir="/etc/kubernetes/pki/etcd"
    
    if [[ -d "$etcd_cert_dir" ]]; then
        local etcd_certs=("server.crt" "peer.crt" "healthcheck-client.crt")
        
        for cert in "${etcd_certs[@]}"; do
            local cert_path="$etcd_cert_dir/$cert"
            if [[ -f "$cert_path" ]]; then
                local expiry_date=$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | cut -d= -f2)
                local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null)
                local current_timestamp=$(date +%s)
                local days_left=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                
                if [[ $days_left -lt 30 ]]; then
                    add_check_result "certificates" "etcd_cert_$cert" "FAIL" "etcd 证书 $cert 将在 $days_left 天后过期"
                elif [[ $days_left -lt 90 ]]; then
                    add_check_result "certificates" "etcd_cert_$cert" "WARN" "etcd 证书 $cert 将在 $days_left 天后过期"
                else
                    add_check_result "certificates" "etcd_cert_$cert" "PASS" "etcd 证书 $cert 有效期正常 ($days_left 天)"
                fi
            else
                add_check_result "certificates" "etcd_cert_$cert" "WARN" "etcd 证书文件 $cert 不存在"
            fi
        done
    else
        add_check_result "certificates" "etcd_cert_dir" "WARN" "etcd 证书目录不存在"
    fi
}

# 生成健康报告
generate_health_report() {
    log INFO "生成健康检查报告..."
    
    local report_data=$(cat << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "cluster_info": {
        "server_version": "$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null)",
        "nodes_count": $(kubectl get nodes --no-headers 2>/dev/null | wc -l),
        "namespaces_count": $(kubectl get namespaces --no-headers 2>/dev/null | wc -l)
    },
    "summary": {
        "total_checks": $TOTAL_CHECKS,
        "passed_checks": $PASSED_CHECKS,
        "warning_checks": $WARNING_CHECKS,
        "failed_checks": $FAILED_CHECKS,
        "success_rate": $(echo "scale=2; $PASSED_CHECKS * 100 / $TOTAL_CHECKS" | bc 2>/dev/null || echo "0")
    },
    "checks": [
        $(IFS=,; echo "${HEALTH_RESULTS[*]}")
    ]
}
EOF
)
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "$report_data"
    else
        echo "$report_data" > "$HEALTH_REPORT_FILE"
        log INFO "健康检查报告已保存到: $HEALTH_REPORT_FILE"
    fi
}

# 显示摘要信息
show_summary() {
    local health_status
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        health_status="❌ 不健康"
    elif [[ $WARNING_CHECKS -gt 0 ]]; then
        health_status="⚠️  需要关注"
    else
        health_status="✅ 健康"
    fi
    
    local success_rate=$(echo "scale=1; $PASSED_CHECKS * 100 / $TOTAL_CHECKS" | bc 2>/dev/null || echo "0")
    
    cat << EOF

🏥 Kubernetes 集群健康检查摘要
=====================================

整体状态: $health_status
成功率: ${success_rate}%

检查统计:
  ✅ 通过: $PASSED_CHECKS
  ⚠️  警告: $WARNING_CHECKS  
  ❌ 失败: $FAILED_CHECKS
  📊 总计: $TOTAL_CHECKS

检查时间: $(date)
报告文件: $HEALTH_REPORT_FILE

EOF

    if [[ $FAILED_CHECKS -gt 0 ]]; then
        log ERROR "发现 $FAILED_CHECKS 个严重问题，请及时处理"
        exit $ERR_GENERAL
    elif [[ $WARNING_CHECKS -gt 0 ]]; then
        log WARN "发现 $WARNING_CHECKS 个警告，建议关注"
        exit $SUCCESS
    else
        log INFO "集群健康状态良好"
        exit $SUCCESS
    fi
}

# 执行健康检查
run_health_check() {
    log INFO "开始 Kubernetes 集群健康检查..."
    
    # 重置统计
    TOTAL_CHECKS=0
    PASSED_CHECKS=0
    WARNING_CHECKS=0
    FAILED_CHECKS=0
    HEALTH_RESULTS=()
    
    # 执行各项检查
    check_cluster_status
    check_nodes_health
    check_pods_health
    check_storage_health
    check_network_connectivity
    check_certificates
    
    # 生成报告
    generate_health_report
    
    # 显示摘要
    show_summary
}

# 持续监控模式
run_continuous_monitoring() {
    log INFO "启动持续监控模式..."
    log INFO "检查间隔: ${CHECK_INTERVAL}s"
    log INFO "按 Ctrl+C 停止监控"
    
    while true; do
        log INFO "$(date): 开始健康检查..."
        run_health_check
        
        log INFO "等待 ${CHECK_INTERVAL} 秒后进行下一次检查..."
        sleep "$CHECK_INTERVAL"
    done
}

# 主函数
main() {
    # 解析参数
    parse_arguments "$@"
    
    # 检查依赖
    check_kubernetes
    
    if [[ "$CONTINUOUS_MODE" == "true" ]]; then
        run_continuous_monitoring
    else
        run_health_check
    fi
}

# 执行主函数
main "$@"
